#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RFCOMM Socket 简单桥接脚本
使用 Python bluetooth socket 连接，完全透传原始数据到 stdin/stdout
不进行任何 GTP 组装，不使用 rfcomm bind（不会断开系统蓝牙连接）

数据流：
  Dart stdin  →  Python  →  BT socket (发送到设备)
  BT socket   →  Python  →  Dart stdout (接收设备数据)
"""

import sys
import os
import socket
import time
import threading
import select
import signal
import atexit

# 尝试导入 bluetooth 模块
try:
    import bluetooth
    HAS_PYBLUEZ = True
except ImportError:
    HAS_PYBLUEZ = False

def log(message):
    """输出日志到 stderr（不影响二进制数据通道）"""
    timestamp = time.strftime('%H:%M:%S')
    print(f"[{timestamp}] [RFCOMM-SOCKET-SIMPLE] {message}", file=sys.stderr, flush=True)

def create_rfcomm_socket(mac_address, channel, max_retries=3):
    """创建 RFCOMM socket 连接，优先 PyBluez，失败后回退到原始 socket，带重试"""
    
    for attempt in range(max_retries):
        if attempt > 0:
            log(f"🔄 第 {attempt + 1}/{max_retries} 次重试连接...")
            time.sleep(1.0 + attempt)  # 递增等待，让系统释放资源
        
        sock = None
        
        # 方法1: PyBluez
        if HAS_PYBLUEZ:
            sock = _create_pybluez_socket(mac_address, channel)
        
        # 方法2: 原始 socket（PyBluez 不可用或失败时）
        if sock is None:
            sock = _create_raw_socket(mac_address, channel)
        
        if sock is not None:
            return sock
        
        log(f"⚠️ 连接尝试 {attempt + 1}/{max_retries} 失败")
    
    return None

def _create_pybluez_socket(mac_address, channel):
    """使用 PyBluez 创建连接"""
    try:
        log(f"尝试 PyBluez 连接: {mac_address} CH{channel}")
        sock = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
        # 注意：不要在 connect 之前调用 settimeout，某些 BlueZ 版本会导致 EBADFD (Errno 77)
        sock.connect((mac_address, channel))
        # 连接成功后再设置超时
        sock.settimeout(0.1)
        log(f"✅ PyBluez RFCOMM 连接成功")
        return sock
    except Exception as e:
        log(f"⚠️ PyBluez 连接失败: {e}，将尝试原始 socket")
        try:
            sock.close()
        except:
            pass
        return None

def _create_raw_socket(mac_address, channel):
    """使用原始 socket 创建 RFCOMM 连接（不需要 PyBluez）"""
    AF_BLUETOOTH = 31
    BTPROTO_RFCOMM = 3
    sock = None
    
    try:
        log(f"尝试原始 socket 连接: {mac_address} CH{channel}")
        sock = socket.socket(AF_BLUETOOTH, socket.SOCK_STREAM, BTPROTO_RFCOMM)
        # 不在 connect 前设置 timeout，避免 EBADFD
        sock.connect((mac_address, channel))
        sock.settimeout(0.1)
        log(f"✅ 原始 socket RFCOMM 连接成功")
        return sock
    except Exception as e:
        log(f"❌ 原始 socket 连接失败: {e}")
        try:
            if sock:
                sock.close()
        except:
            pass
        return None

def socket_to_stdout(sock, keep_alive_event):
    """从 BT socket 读取数据并立即输出到 stdout（完全透传，零延迟）"""
    recv_count = 0
    total_bytes = 0
    
    try:
        while keep_alive_event.is_set():
            try:
                data = sock.recv(4096)
                if not data:
                    log("BT socket 连接已关闭（读取端）")
                    keep_alive_event.clear()
                    break
                
                recv_count += 1
                total_bytes += len(data)
                
                data_hex = ' '.join(f'{b:02X}' for b in data)
                log(f"📥 BT→stdout #{recv_count} [{len(data)}B] (累计:{total_bytes}B): {data_hex[:150]}{'...' if len(data_hex) > 150 else ''}")
                
                # 立即输出到 stdout，不做任何缓冲或延迟
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
                
            except socket.timeout:
                # socket 超时是正常的（非阻塞模式），继续等待
                continue
            except Exception as e:
                # PyBluez 的 BluetoothError 不继承自 socket.timeout，
                # 需要通过错误消息判断是否为超时
                error_msg = str(e).lower()
                if 'timed out' in error_msg or 'timeout' in error_msg:
                    continue
                elif 'resource temporarily unavailable' in error_msg:
                    # EAGAIN - 非阻塞模式下无数据可读
                    continue
                else:
                    log(f"❌ BT socket 读取错误: {type(e).__name__}: {e}")
                    keep_alive_event.clear()
                    break
                    
    except Exception as e:
        log(f"❌ 读取线程异常: {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc(file=sys.stderr)
        keep_alive_event.clear()
    finally:
        log(f"📊 读取线程结束，共接收 {recv_count} 次，{total_bytes} 字节")

def stdin_to_socket(sock, keep_alive_event):
    """从 Dart stdin 读取数据并发送到 BT socket"""
    send_count = 0
    total_bytes = 0
    
    try:
        import fcntl
        flags = fcntl.fcntl(sys.stdin.fileno(), fcntl.F_GETFL)
        fcntl.fcntl(sys.stdin.fileno(), fcntl.F_SETFL, flags | os.O_NONBLOCK)
        
        while keep_alive_event.is_set():
            try:
                readable, _, _ = select.select([sys.stdin], [], [], 0.05)
            except (ValueError, OSError):
                # stdin 已关闭
                break
            
            if not readable:
                continue
            
            try:
                data = sys.stdin.buffer.read(4096)
            except (OSError, IOError):
                data = None
            
            if not data:
                log("stdin 已关闭（Dart 进程退出）")
                keep_alive_event.clear()
                break
            
            send_count += 1
            total_bytes += len(data)
            data_hex = ' '.join(f'{b:02X}' for b in data)
            log(f"📨 stdin→BT #{send_count} [{len(data)}B]: {data_hex[:150]}{'...' if len(data_hex) > 150 else ''}")
            
            # 发送数据到 BT socket（带重试）
            sent = 0
            while sent < len(data) and keep_alive_event.is_set():
                try:
                    n = sock.send(data[sent:])
                    if n == 0:
                        log("BT socket 连接已关闭（写入端）")
                        keep_alive_event.clear()
                        return
                    sent += n
                except socket.timeout:
                    time.sleep(0.01)
                    continue
                except Exception as e:
                    # PyBluez BluetoothError 超时也需要处理
                    error_msg = str(e).lower()
                    if 'timed out' in error_msg or 'timeout' in error_msg:
                        time.sleep(0.01)
                        continue
                    elif 'resource temporarily unavailable' in error_msg:
                        time.sleep(0.01)
                        continue
                    else:
                        log(f"❌ BT socket 发送错误: {type(e).__name__}: {e}")
                        keep_alive_event.clear()
                        return
            
            if sent == len(data):
                log(f"✅ 发送完成 [{sent}B]")
                
    except Exception as e:
        log(f"❌ 写入线程异常: {e}")
        keep_alive_event.clear()
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
    
    # 创建 socket 连接
    sock = create_rfcomm_socket(mac_address, channel)
    if not sock:
        log("❌ 所有连接尝试均失败")
        sys.exit(1)
    
    # 注册 atexit 确保 socket 在任何退出情况下都会关闭
    def cleanup_socket():
        try:
            sock.close()
            log("🧹 atexit: socket 已关闭")
        except:
            pass
    atexit.register(cleanup_socket)
    
    # 创建 keep_alive 事件（任一线程出错时停止所有线程）
    keep_alive_event = threading.Event()
    keep_alive_event.set()
    
    # 处理信号
    def signal_handler(signum, frame):
        log(f"收到信号 {signum}")
        keep_alive_event.clear()
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    log("✅ 连接已建立，开始双向数据透传")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    # 启动双向数据传输（两个线程）
    read_thread = threading.Thread(
        target=socket_to_stdout, 
        args=(sock, keep_alive_event), 
        daemon=True,
        name="bt-read"
    )
    write_thread = threading.Thread(
        target=stdin_to_socket, 
        args=(sock, keep_alive_event), 
        daemon=True,
        name="bt-write"
    )
    
    read_thread.start()
    write_thread.start()
    
    # 主线程等待 keep_alive 被清除
    try:
        while keep_alive_event.is_set():
            # 检查两个线程是否还活着
            if not read_thread.is_alive() and not write_thread.is_alive():
                log("两个数据传输线程均已退出")
                break
            time.sleep(0.1)
    except KeyboardInterrupt:
        log("收到中断信号")
    
    # 清理
    keep_alive_event.clear()
    
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    log("清理资源...")
    try:
        sock.close()
    except:
        pass
    
    # 等待线程结束
    read_thread.join(timeout=2)
    write_thread.join(timeout=2)
    log("✅ 清理完成")

if __name__ == "__main__":
    main()
