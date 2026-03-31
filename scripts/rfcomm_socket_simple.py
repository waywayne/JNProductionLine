#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RFCOMM Socket 简单桥接脚本
使用 Python bluetooth socket 连接，完全透传原始数据到 stdin/stdout
不进行任何 GTP 组装，不使用 rfcomm bind（不会断开系统蓝牙连接）
"""

import sys
import os
import socket
import time
import threading
import select

# 尝试导入 bluetooth 模块
try:
    import bluetooth
    HAS_PYBLUEZ = True
except ImportError:
    HAS_PYBLUEZ = False

def log(message):
    """输出日志到 stderr"""
    timestamp = time.strftime('%H:%M:%S')
    print(f"[{timestamp}] [RFCOMM-SOCKET-SIMPLE] {message}", file=sys.stderr, flush=True)

def create_rfcomm_socket(mac_address, channel):
    """创建 RFCOMM socket 连接"""
    if HAS_PYBLUEZ:
        return _create_pybluez_socket(mac_address, channel)
    else:
        return _create_raw_socket(mac_address, channel)

def _create_pybluez_socket(mac_address, channel):
    """使用 PyBluez 创建连接"""
    try:
        log(f"使用 PyBluez 连接: {mac_address} CH{channel}")
        sock = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
        sock.settimeout(10)
        sock.connect((mac_address, channel))
        sock.settimeout(0.1)
        log(f"✅ PyBluez RFCOMM 连接成功")
        return sock
    except Exception as e:
        log(f"❌ PyBluez 连接失败: {e}")
        return None

def _create_raw_socket(mac_address, channel):
    """使用原始 socket 创建 RFCOMM 连接（不需要 PyBluez）"""
    try:
        import struct
        log(f"使用原始 socket 连接: {mac_address} CH{channel}")
        
        # AF_BLUETOOTH = 31, BTPROTO_RFCOMM = 3
        AF_BLUETOOTH = 31
        BTPROTO_RFCOMM = 3
        
        sock = socket.socket(AF_BLUETOOTH, socket.SOCK_STREAM, BTPROTO_RFCOMM)
        sock.settimeout(10)
        
        # 将 MAC 地址转换为 bytes
        addr_bytes = bytes(reversed([int(x, 16) for x in mac_address.split(':')]))
        
        # struct sockaddr_rc: sa_family(2) + btaddr(6) + channel(1)
        # 使用 connect 需要传入 (mac, channel) 元组
        sock.connect((mac_address, channel))
        
        sock.settimeout(0.1)
        log(f"✅ 原始 socket RFCOMM 连接成功")
        return sock
    except Exception as e:
        log(f"❌ 原始 socket 连接失败: {e}")
        return None

def socket_to_stdout(sock, keep_alive_event):
    """从 socket 读取数据并直接输出到 stdout（完全透传）"""
    log("🎧 开始监听 Socket 数据（完全透传）...")
    recv_count = 0
    total_bytes = 0
    timeout_count = 0
    
    try:
        while keep_alive_event.is_set():
            try:
                data = sock.recv(4096)
                if not data:
                    log("Socket 连接已关闭")
                    break
                
                recv_count += 1
                total_bytes += len(data)
                timeout_count = 0
                
                data_hex = ' '.join(f'{b:02X}' for b in data)
                log(f"📥 接收 #{recv_count} [{len(data)}字节] (累计:{total_bytes}): {data_hex[:120]}{'...' if len(data_hex) > 120 else ''}")
                
                # 直接输出到 stdout，不做任何处理
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
                
            except socket.timeout:
                timeout_count += 1
                if timeout_count % 200 == 0:
                    log(f"⏳ 持续监听中... (已接收: {recv_count} 次, {total_bytes} 字节)")
                time.sleep(0.01)
                continue
            except (OSError, IOError) as e:
                error_msg = str(e).lower()
                if 'timed out' in error_msg or 'timeout' in error_msg:
                    timeout_count += 1
                    time.sleep(0.01)
                    continue
                else:
                    log(f"❌ 读取错误: {e}")
                    break
                    
    except Exception as e:
        log(f"❌ 读取异常: {e}")
    finally:
        log(f"📊 读取线程结束，共接收 {recv_count} 次，{total_bytes} 字节")

def stdin_to_socket(sock, keep_alive_event):
    """从 stdin 读取数据并发送到 socket"""
    log("📤 开始监听 stdin 数据...")
    send_count = 0
    total_bytes = 0
    
    try:
        import fcntl
        flags = fcntl.fcntl(sys.stdin.fileno(), fcntl.F_GETFL)
        fcntl.fcntl(sys.stdin.fileno(), fcntl.F_SETFL, flags | os.O_NONBLOCK)
        
        while keep_alive_event.is_set():
            readable, _, _ = select.select([sys.stdin], [], [], 0.1)
            
            if readable:
                data = sys.stdin.buffer.read(4096)
                if not data:
                    log("stdin 已关闭")
                    # 不立即退出，等待响应
                    time.sleep(3)
                    break
                
                send_count += 1
                total_bytes += len(data)
                data_hex = ' '.join(f'{b:02X}' for b in data)
                log(f"📨 发送 #{send_count} [{len(data)}字节]: {data_hex[:120]}{'...' if len(data_hex) > 120 else ''}")
                
                # 发送数据
                sent = 0
                while sent < len(data):
                    try:
                        n = sock.send(data[sent:])
                        if n == 0:
                            log("Socket 连接已关闭（写入端）")
                            return
                        sent += n
                    except socket.timeout:
                        time.sleep(0.01)
                        continue
                    except (OSError, IOError) as e:
                        error_msg = str(e).lower()
                        if 'timed out' in error_msg or 'timeout' in error_msg:
                            time.sleep(0.01)
                            continue
                        else:
                            log(f"❌ 发送错误: {e}")
                            return
                
                log(f"✅ 发送完成")
                
    except Exception as e:
        log(f"❌ 写入异常: {e}")
    finally:
        log(f"📊 发送线程结束，共发送 {send_count} 次，{total_bytes} 字节")

def main():
    if len(sys.argv) != 3:
        print("用法: rfcomm_socket_simple.py <MAC地址> <通道>", file=sys.stderr)
        sys.exit(1)
    
    mac_address = sys.argv[1]
    channel = int(sys.argv[2])
    
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    log("RFCOMM Socket 简单桥接模式（完全透传）")
    log(f"MAC: {mac_address}, 通道: {channel}")
    log(f"PyBluez: {'可用' if HAS_PYBLUEZ else '不可用（使用原始socket）'}")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    # 1. 创建 socket 连接
    sock = create_rfcomm_socket(mac_address, channel)
    if not sock:
        log("❌ 连接失败")
        sys.exit(1)
    
    # 2. 创建 keep_alive 事件
    keep_alive_event = threading.Event()
    keep_alive_event.set()
    
    log("✅ 连接已建立，开始数据传输")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    # 3. 启动双向数据传输
    read_thread = None
    try:
        # socket -> stdout（后台线程）
        read_thread = threading.Thread(
            target=socket_to_stdout, 
            args=(sock, keep_alive_event), 
            daemon=False
        )
        read_thread.start()
        
        # stdin -> socket（主线程）
        stdin_to_socket(sock, keep_alive_event)
        
        # 发送完成后，等待读取线程
        log("⏳ 等待读取线程...")
        read_thread.join(timeout=5)
        
    except KeyboardInterrupt:
        log("收到中断信号")
    except Exception as e:
        log(f"运行异常: {e}")
    finally:
        keep_alive_event.clear()
        
        if read_thread and read_thread.is_alive():
            read_thread.join(timeout=2)
        
        log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        log("清理资源...")
        try:
            sock.close()
        except:
            pass
        log("✅ 清理完成")

if __name__ == "__main__":
    main()
