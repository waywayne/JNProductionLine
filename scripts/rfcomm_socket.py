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

def socket_to_stdout(sock):
    """从 socket 读取数据并输出到 stdout（非阻塞）"""
    try:
        while True:
            try:
                data = sock.recv(1024)
                if not data:
                    log("Socket 连接已关闭（读取端）")
                    break
                
                # 记录接收到的数据
                data_hex = ' '.join(f'{b:02X}' for b in data)
                log(f"📥 接收到 {len(data)} 字节: {data_hex[:100]}{'...' if len(data_hex) > 100 else ''}")
                
                # 输出到 stdout（Dart 会读取）
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
                
            except socket.timeout:
                # 超时是正常的，继续循环
                time.sleep(0.01)
                continue
            except bluetooth.BluetoothError as e:
                # 检查是否是超时错误
                error_msg = str(e).lower()
                if 'timed out' in error_msg or 'timeout' in error_msg:
                    # 超时是正常的，继续循环
                    time.sleep(0.01)
                    continue
                else:
                    # 其他蓝牙错误，退出
                    log(f"蓝牙读取错误: {e}")
                    break
            
    except Exception as e:
        log(f"读取异常: {e}")

def stdin_to_socket(sock):
    """从 stdin 读取数据并发送到 socket（非阻塞）"""
    try:
        # 设置 stdin 为非阻塞模式
        import fcntl
        flags = fcntl.fcntl(sys.stdin.fileno(), fcntl.F_GETFL)
        fcntl.fcntl(sys.stdin.fileno(), fcntl.F_SETFL, flags | os.O_NONBLOCK)
        
        while True:
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
                # 发送后短暂延迟，确保设备接收
                time.sleep(0.05)
            
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
    
    # 创建两个线程：一个读取 socket 输出到 stdout，一个从 stdin 写入 socket
    read_thread = threading.Thread(target=socket_to_stdout, args=(sock,), daemon=True)
    write_thread = threading.Thread(target=stdin_to_socket, args=(sock,), daemon=True)
    
    read_thread.start()
    write_thread.start()
    
    # 等待线程结束
    try:
        read_thread.join()
        write_thread.join()
    except KeyboardInterrupt:
        log("收到中断信号")
    finally:
        sock.close()
        log("Socket 已关闭")

if __name__ == "__main__":
    main()
