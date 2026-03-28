#!/usr/bin/env python3
"""
RFCOMM Socket 桥接脚本
用于在 Linux 上创建 RFCOMM socket 并通过 stdio 与 Dart 通信
"""

import sys
import os
import socket
import bluetooth
import struct
import threading
import time
import select

def log(message):
    """输出日志到 stderr"""
    print(f"[RFCOMM] {message}", file=sys.stderr, flush=True)

def create_rfcomm_socket(mac_address, channel):
    """创建 RFCOMM socket 连接"""
    try:
        log(f"正在连接到 {mac_address} 通道 {channel}...")
        
        # 创建 RFCOMM socket
        sock = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
        
        # 设置连接超时
        sock.settimeout(10)
        
        # 连接到设备
        sock.connect((mac_address, channel))
        
        # 连接成功后设置为非阻塞模式（使用短超时）
        sock.settimeout(0.1)  # 100ms 超时，避免永久阻塞
        
        log(f"✅ RFCOMM Socket 连接成功")
        return sock
        
    except bluetooth.BluetoothError as e:
        log(f"❌ 蓝牙连接失败: {e}")
        return None
    except Exception as e:
        log(f"❌ 连接异常: {e}")
        return None

def socket_to_stdout(sock, keep_alive_event):
    """从 socket 读取数据并输出到 stdout（非阻塞）"""
    try:
        log("🎧 开始监听 Socket 数据...")
        recv_count = 0
        timeout_count = 0
        empty_count = 0
        
        # GTP 数据包缓冲区
        buffer = bytearray()
        GTP_PREAMBLE = bytes([0xD0, 0xD2, 0xC5, 0xC2])
        last_data_time = time.time()
        
        while keep_alive_event.is_set():
            try:
                data = sock.recv(4096)  # 增大读取缓冲区
                if not data:
                    empty_count += 1
                    if empty_count > 10:
                        log("Socket 连接已关闭（读取端）")
                        break
                    continue
                
                recv_count += 1
                empty_count = 0  # 重置空读取计数
                last_data_time = time.time()
                
                # 记录接收到的原始数据
                data_hex = ' '.join(f'{b:02X}' for b in data)
                log(f"📥 接收到 {len(data)} 字节 (第 {recv_count} 次): {data_hex[:150]}{'...' if len(data_hex) > 150 else ''}")
                
                # 添加到缓冲区
                buffer.extend(data)
                
                # 处理缓冲区中的完整 GTP 数据包
                while len(buffer) >= 4:
                    # 查找 GTP 前导码
                    preamble_index = buffer.find(GTP_PREAMBLE)
                    
                    if preamble_index == -1:
                        # 没有找到前导码，检查是否有部分前导码在末尾
                        if len(buffer) > 3:
                            # 输出非 GTP 数据
                            non_gtp_data = bytes(buffer[:-3])
                            buffer = buffer[-3:]
                            if non_gtp_data:
                                non_gtp_hex = ' '.join(f'{b:02X}' for b in non_gtp_data)
                                log(f"📤 输出非 GTP 数据 [{len(non_gtp_data)} 字节]: {non_gtp_hex[:100]}")
                                sys.stdout.buffer.write(non_gtp_data)
                                sys.stdout.buffer.flush()
                        break
                    
                    # 跳过前导码之前的垃圾数据
                    if preamble_index > 0:
                        garbage = bytes(buffer[:preamble_index])
                        garbage_hex = ' '.join(f'{b:02X}' for b in garbage)
                        log(f"⚠️ 跳过 {preamble_index} 字节垃圾数据: {garbage_hex[:50]}")
                        buffer = buffer[preamble_index:]
                    
                    # 检查是否有足够的数据读取 Length 字段
                    if len(buffer) < 7:
                        break
                    
                    # 读取 Length 字段 (offset 5-6, little endian)
                    gtp_length = buffer[5] | (buffer[6] << 8)
                    total_length = 4 + gtp_length
                    
                    log(f"🔍 GTP Length: {gtp_length}, 总长度: {total_length}, 缓冲区: {len(buffer)}")
                    
                    if len(buffer) < total_length:
                        log(f"⏳ 等待更多数据 (需要: {total_length}, 当前: {len(buffer)})")
                        break
                    
                    # 提取完整的 GTP 数据包
                    gtp_packet = bytes(buffer[:total_length])
                    buffer = buffer[total_length:]
                    
                    gtp_hex = ' '.join(f'{b:02X}' for b in gtp_packet)
                    log(f"📦 完整 GTP 数据包 [{len(gtp_packet)} 字节]: {gtp_hex[:150]}{'...' if len(gtp_hex) > 150 else ''}")
                    
                    # 输出完整的 GTP 数据包到 stdout
                    sys.stdout.buffer.write(gtp_packet)
                    sys.stdout.buffer.flush()
                
            except socket.timeout:
                timeout_count += 1
                # 如果缓冲区有数据且超过 500ms 没有新数据，输出缓冲区内容
                if buffer and (time.time() - last_data_time) > 0.5:
                    buffer_hex = ' '.join(f'{b:02X}' for b in buffer)
                    log(f"⏱️ 超时，输出缓冲区数据 [{len(buffer)} 字节]: {buffer_hex[:100]}")
                    sys.stdout.buffer.write(bytes(buffer))
                    sys.stdout.buffer.flush()
                    buffer.clear()
                if timeout_count % 200 == 0:
                    log(f"⏳ 持续监听中... (已接收: {recv_count} 次)")
                time.sleep(0.01)
                continue
            except bluetooth.BluetoothError as e:
                error_msg = str(e).lower()
                if 'timed out' in error_msg or 'timeout' in error_msg:
                    timeout_count += 1
                    if buffer and (time.time() - last_data_time) > 0.5:
                        buffer_hex = ' '.join(f'{b:02X}' for b in buffer)
                        log(f"⏱️ 超时，输出缓冲区数据 [{len(buffer)} 字节]: {buffer_hex[:100]}")
                        sys.stdout.buffer.write(bytes(buffer))
                        sys.stdout.buffer.flush()
                        buffer.clear()
                    if timeout_count % 200 == 0:
                        log(f"⏳ 持续监听中... (已接收: {recv_count} 次)")
                    time.sleep(0.01)
                    continue
                else:
                    log(f"蓝牙读取错误: {e}")
                    break
            
    except Exception as e:
        log(f"读取异常: {e}")
    finally:
        # 输出剩余缓冲区数据
        if buffer:
            buffer_hex = ' '.join(f'{b:02X}' for b in buffer)
            log(f"📤 输出剩余缓冲区数据 [{len(buffer)} 字节]: {buffer_hex[:100]}")
            sys.stdout.buffer.write(bytes(buffer))
            sys.stdout.buffer.flush()

def stdin_to_socket(sock, keep_alive_event):
    """从 stdin 读取数据并发送到 socket（非阻塞）"""
    try:
        # 设置 stdin 为非阻塞模式
        import fcntl
        flags = fcntl.fcntl(sys.stdin.fileno(), fcntl.F_GETFL)
        fcntl.fcntl(sys.stdin.fileno(), fcntl.F_SETFL, flags | os.O_NONBLOCK)
        
        while keep_alive_event.is_set():
            # 使用 select 等待数据（带超时）
            readable, _, _ = select.select([sys.stdin], [], [], 0.1)
            
            if readable:
                # 从 stdin 读取数据（Dart 会写入）
                data = sys.stdin.buffer.read(1024)
                if not data:
                    log("Stdin 已关闭")
                    break
                
                # 发送到 socket（带重试）
                sent = 0
                data_len = len(data)
                log(f"准备发送 {data_len} 字节数据")
                
                while sent < data_len:
                    try:
                        n = sock.send(data[sent:])
                        if n == 0:
                            log("Socket 连接已关闭（写入端）")
                            return
                        sent += n
                        log(f"已发送 {sent}/{data_len} 字节")
                    except socket.timeout:
                        # 发送缓冲区满，稍后重试
                        time.sleep(0.01)
                        continue
                    except bluetooth.BluetoothError as e:
                        # 检查是否是超时错误
                        error_msg = str(e).lower()
                        if 'timed out' in error_msg or 'timeout' in error_msg:
                            # 超时重试
                            time.sleep(0.01)
                            continue
                        else:
                            # 其他蓝牙错误，退出
                            log(f"蓝牙发送错误: {e}")
                            return
                
                log(f"✅ 数据发送完成: {data_len} 字节")
                # 发送后延迟，确保设备有足够时间处理
                # 蓝牙传输比串口慢，需要更长的处理时间
                time.sleep(0.2)  # 200ms 延迟
            
            # 短暂休眠，避免 CPU 占用过高
            time.sleep(0.01)
            
    except Exception as e:
        log(f"写入异常: {e}")

def main():
    if len(sys.argv) != 3:
        print("用法: rfcomm_socket.py <MAC地址> <通道>", file=sys.stderr)
        sys.exit(1)
    
    mac_address = sys.argv[1]
    channel = int(sys.argv[2])
    
    # 创建 socket 连接
    sock = create_rfcomm_socket(mac_address, channel)
    if not sock:
        sys.exit(1)
    
    log("启动双向数据传输...")
    
    # 创建 keep_alive 事件
    keep_alive_event = threading.Event()
    keep_alive_event.set()
    
    # 创建两个线程：一个读取 socket 输出到 stdout，一个从 stdin 写入 socket
    read_thread = threading.Thread(target=socket_to_stdout, args=(sock, keep_alive_event), daemon=True)
    write_thread = threading.Thread(target=stdin_to_socket, args=(sock, keep_alive_event), daemon=True)
    
    read_thread.start()
    write_thread.start()
    
    # 等待线程结束
    try:
        read_thread.join()
        write_thread.join()
    except KeyboardInterrupt:
        log("收到中断信号")
        keep_alive_event.clear()
    finally:
        sock.close()
        log("Socket 已关闭")

if __name__ == "__main__":
    main()
