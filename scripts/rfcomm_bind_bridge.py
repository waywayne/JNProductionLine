#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RFCOMM Bind 桥接脚本
使用 rfcomm bind 创建 /dev/rfcomm0，然后桥接到 stdin/stdout
这种方式与第三方工具一致
"""

import sys
import os
import time
import subprocess
import fcntl
import select
import threading

def log(message):
    """输出日志到 stderr"""
    print(f"[RFCOMM-BIND] {message}", file=sys.stderr, flush=True)

def disconnect_acl(mac):
    """断开已有的 ACL 连接，解决 Errno 52 (Invalid exchange)"""
    log(f"🔌 断开 {mac} 已有 ACL 连接...")
    try:
        subprocess.run(['hcitool', 'dc', mac],
                       stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL, timeout=3)
    except Exception:
        pass
    try:
        subprocess.run(['bluetoothctl', 'disconnect', mac],
                       stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL, timeout=3)
    except Exception:
        pass
    time.sleep(1)
    log("🔌 ACL 断开完成")


def cleanup_rfcomm(mac=None):
    """彻底清理 RFCOMM 资源"""
    my_pid = os.getpid()
    log(f"🧹 清理 RFCOMM 资源 (PID: {my_pid})")
    
    # 1. 杀死所有旧的 rfcomm 相关进程（排除自己）
    try:
        result = subprocess.run(['pgrep', '-f', 'rfcomm'],
                              capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            for pid_str in result.stdout.strip().split('\n'):
                if pid_str and pid_str.strip():
                    try:
                        pid = int(pid_str.strip())
                        if pid != my_pid:
                            subprocess.run(['kill', '-9', str(pid)], timeout=1)
                            log(f"   已杀死旧进程 PID: {pid}")
                    except:
                        pass
    except:
        pass
    
    # 2. 杀死所有 cat 进程
    try:
        subprocess.run(['pkill', '-9', 'cat'], stderr=subprocess.DEVNULL, timeout=2)
    except:
        pass
    
    # 3. 释放所有 rfcomm 绑定
    try:
        subprocess.run(['sudo', 'rfcomm', 'release', 'all'],
                      stderr=subprocess.DEVNULL, timeout=2)
        log("   已释放所有 rfcomm 绑定")
    except:
        pass
    
    # 4. 关闭所有打开的 /dev/rfcomm* 设备文件
    try:
        result = subprocess.run(['lsof', '/dev/rfcomm*'],
                              capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            for line in result.stdout.split('\n')[1:]:
                parts = line.split()
                if len(parts) > 1:
                    try:
                        pid = int(parts[1])
                        if pid != my_pid:
                            subprocess.run(['kill', '-9', str(pid)], timeout=1)
                            log(f"   已杀死占用设备文件的进程 PID: {pid}")
                    except:
                        pass
    except:
        pass
    
    # 5. 断开已有 ACL 连接（解决 Errno 52）
    if mac:
        disconnect_acl(mac)
    
    # 6. 等待内核完全释放资源
    time.sleep(1)
    log("🧹 清理完成")

def setup_rfcomm_bind(mac_address, channel):
    """使用 rfcomm bind 创建设备文件"""
    log(f"设置 RFCOMM 绑定")
    log(f"  MAC: {mac_address}")
    log(f"  通道: {channel}")
    
    # 1. 清理旧的绑定（包括断开已有 ACL）
    cleanup_rfcomm(mac=mac_address)
    time.sleep(0.5)
    
    # 2. 绑定设备
    try:
        result = subprocess.run(
            ['sudo', 'rfcomm', 'bind', '0', mac_address, str(channel)],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode != 0:
            log(f"❌ 绑定失败: {result.stderr}")
            return False
        
        log(f"✅ RFCOMM 绑定成功")
        
        # 3. 等待设备文件出现
        device_path = '/dev/rfcomm0'
        for i in range(20):
            if os.path.exists(device_path):
                log(f"✅ 设备文件已创建: {device_path}")
                # 等待设备完全准备好
                time.sleep(1)
                return True
            time.sleep(0.5)
        
        log(f"❌ 设备文件未出现: {device_path}")
        return False
        
    except subprocess.TimeoutExpired:
        log(f"❌ 绑定超时")
        return False
    except Exception as e:
        log(f"❌ 绑定异常: {e}")
        return False

def device_to_stdout(device_fd, keep_alive_event):
    """从设备读取数据并输出到 stdout"""
    log("🎧 开始监听设备数据...")
    recv_count = 0
    timeout_count = 0
    consecutive_empty_reads = 0  # 连续空读取计数
    
    # GTP 数据包缓冲区
    buffer = bytearray()
    GTP_PREAMBLE = bytes([0xD0, 0xD2, 0xC5, 0xC2])
    last_data_time = time.time()
    last_activity_time = time.time()  # 最后活动时间（包括发送）
    
    try:
        while keep_alive_event.is_set():
            # 使用 select 检查是否有数据
            readable, _, _ = select.select([device_fd], [], [], 0.05)  # 50ms 超时，更快响应
            
            if readable:
                try:
                    data = os.read(device_fd, 4096)  # 增大读取缓冲区
                    if not data:
                        # RFCOMM 设备文件经常有虚假的空读取，需要多次确认
                        consecutive_empty_reads += 1
                        if consecutive_empty_reads >= 20:  # 连续 20 次空读取才认为真的断开
                            log("设备连接已关闭（读取端）")
                            break
                        time.sleep(0.1)  # 空读取时等待一下再重试
                        continue
                    
                    recv_count += 1
                    timeout_count = 0  # 重置超时计数
                    consecutive_empty_reads = 0  # 重置连续空读取计数
                    last_data_time = time.time()
                    last_activity_time = time.time()
                    
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
                            # 保留最后 3 字节（可能是前导码的一部分）
                            if len(buffer) > 3:
                                # 输出非 GTP 数据（可能是设备的其他响应）
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
                            # 等待更多数据
                            break
                        
                        # 读取 Length 字段 (offset 5-6, little endian)
                        gtp_length = buffer[5] | (buffer[6] << 8)
                        total_length = 4 + gtp_length  # Preamble(4) + Length 指示的长度
                        
                        log(f"🔍 GTP Length: {gtp_length}, 总长度: {total_length}, 缓冲区: {len(buffer)}")
                        
                        if len(buffer) < total_length:
                            # 数据不完整，等待更多数据
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
                    
                except OSError as e:
                    if e.errno == 11:  # EAGAIN
                        timeout_count += 1
                        continue
                    else:
                        log(f"读取错误: {e}")
                        break
            else:
                timeout_count += 1
                
                # 如果缓冲区有数据且超过 300ms 没有新数据，输出缓冲区内容
                if buffer and (time.time() - last_data_time) > 0.3:
                    buffer_hex = ' '.join(f'{b:02X}' for b in buffer)
                    log(f"⏱️ 超时，输出缓冲区数据 [{len(buffer)} 字节]: {buffer_hex[:100]}")
                    sys.stdout.buffer.write(bytes(buffer))
                    sys.stdout.buffer.flush()
                    buffer.clear()
                
                if timeout_count % 400 == 0:
                    log(f"⏳ 持续监听中... (已接收: {recv_count} 次)")
            
    except Exception as e:
        log(f"读取异常: {e}")
    finally:
        # 输出剩余缓冲区数据
        if buffer:
            buffer_hex = ' '.join(f'{b:02X}' for b in buffer)
            log(f"📤 输出剩余缓冲区数据 [{len(buffer)} 字节]: {buffer_hex[:100]}")
            sys.stdout.buffer.write(bytes(buffer))
            sys.stdout.buffer.flush()

def stdin_to_device(device_fd, keep_alive_event, activity_callback=None):
    """从 stdin 读取数据并发送到设备"""
    log("📤 开始监听 stdin 数据...")
    send_count = 0
    
    try:
        while keep_alive_event.is_set():
            # 使用 select 检查 stdin 是否有数据
            readable, _, _ = select.select([sys.stdin.buffer], [], [], 0.1)
            
            if readable:
                try:
                    data = sys.stdin.buffer.read(1024)
                    if not data:
                        # stdin 暂时为空，继续等待（不退出）
                        continue
                    
                    send_count += 1
                    data_len = len(data)
                    data_hex = ' '.join(f'{b:02X}' for b in data)
                    log(f"📨 准备发送 {data_len} 字节 (第 {send_count} 次)")
                    log(f"   数据: {data_hex}")
                    
                    # 通知活动
                    if activity_callback:
                        activity_callback()
                    
                    # 发送数据
                    sent = 0
                    while sent < data_len:
                        n = os.write(device_fd, data[sent:])
                        sent += n
                        if sent < data_len:
                            log(f"   已发送 {sent}/{data_len} 字节")
                    
                    log(f"✅ 数据发送完成: {data_len} 字节")
                    
                    # 发送后延迟，确保设备有足够时间处理
                    time.sleep(0.1)  # 100ms 延迟
                    
                except OSError as e:
                    if e.errno == 11:  # EAGAIN
                        continue
                    else:
                        log(f"发送错误: {e}")
                        break
            
    except Exception as e:
        log(f"写入异常: {e}")
    finally:
        log("📤 发送线程结束")

def main():
    if len(sys.argv) != 3:
        print("用法: rfcomm_bind_bridge.py <MAC地址> <通道>", file=sys.stderr)
        sys.exit(1)
    
    mac_address = sys.argv[1]
    channel = int(sys.argv[2])
    
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    log("RFCOMM Bind 桥接模式")
    log(f"MAC: {mac_address}")
    log(f"通道: {channel}")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    # 1. 设置 RFCOMM 绑定
    if not setup_rfcomm_bind(mac_address, channel):
        log("❌ RFCOMM 绑定失败")
        sys.exit(1)
    
    # 2. 打开设备文件（带重试，rfcomm bind 后需要时间建立连接）
    # 注意：rfcomm bind 只是创建绑定，真正的连接在第一次 open() 时发起
    device_path = '/dev/rfcomm0'
    device_fd = None
    log("⏳ 打开设备文件并建立 RFCOMM 连接...")
    
    for attempt in range(10):  # 增加到 10 次重试
        try:
            device_fd = os.open(device_path, os.O_RDWR | os.O_NONBLOCK)
            log(f"✅ 设备文件已打开: {device_path}")
            break
        except OSError as e:
            if e.errno == 113:  # No route to host - 设备尚未准备好
                log(f"⚠️ 尝试 {attempt + 1}/10: 设备尚未准备好 (Errno 113)，等待 2 秒后重试...")
                time.sleep(2)
            elif e.errno == 52:  # Invalid exchange - ACL 冲突
                log(f"⚠️ 尝试 {attempt + 1}/10: ACL 冲突 (Errno 52)，断开后重试...")
                disconnect_acl(mac_address)
                time.sleep(1)
            else:
                log(f"❌ 打开设备文件失败: {e}")
                raise
    
    if device_fd is None:
        log(f"❌ 打开设备文件失败: 连接无法建立")
        cleanup_rfcomm()
        sys.exit(1)
    
    # 4. 设置 stdin 为非阻塞
    flags = fcntl.fcntl(sys.stdin.buffer, fcntl.F_GETFL)
    fcntl.fcntl(sys.stdin.buffer, fcntl.F_SETFL, flags | os.O_NONBLOCK)
    
    log("✅ 连接已建立，开始数据传输")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    # 5. 创建 keep_alive 事件
    keep_alive_event = threading.Event()
    keep_alive_event.set()
    
    # 6. 启动双向数据传输（两个线程，主线程等待）
    try:
        # 设备 -> stdout（读取线程）
        read_thread = threading.Thread(target=device_to_stdout, args=(device_fd, keep_alive_event), daemon=True)
        read_thread.start()
        
        # stdin -> 设备（写入线程）
        write_thread = threading.Thread(target=stdin_to_device, args=(device_fd, keep_alive_event), daemon=True)
        write_thread.start()
        
        # 主线程等待，直到 keep_alive 被清除
        while keep_alive_event.is_set():
            if not read_thread.is_alive() and not write_thread.is_alive():
                break
            time.sleep(0.2)
        
    except KeyboardInterrupt:
        log("收到中断信号")
    except Exception as e:
        log(f"运行异常: {e}")
    finally:
        # 停止 keep_alive 事件
        keep_alive_event.clear()
        
        # 等待线程结束
        read_thread.join(timeout=2)
        write_thread.join(timeout=2)
        
        # 清理
        log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        log("清理资源...")
        try:
            os.close(device_fd)
        except:
            pass
        cleanup_rfcomm()
        log("✅ 清理完成")

if __name__ == "__main__":
    main()
