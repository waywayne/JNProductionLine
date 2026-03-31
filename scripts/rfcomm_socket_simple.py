#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RFCOMM Socket 简单桥接脚本
使用 PyBluez bluetooth socket 连接，完全透传原始数据到 stdin/stdout
不进行任何 GTP 组装，不使用 rfcomm bind

数据流：
  Dart stdin  →  Python  →  BT socket (发送到设备)
  BT socket   →  Python  →  Dart stdout (接收设备数据)

连接策略（参考 bluetooth_spp_test.py 已验证可行的方式）：
  1. 杀掉残留进程 + rfcomm release（不要 bluetoothctl disconnect，会导致 Errno 112）
  2. 使用 PyBluez BluetoothSocket，设 5s connect 超时
  3. 指定通道失败时，自动扫描常用通道 1-10
"""

import sys
import os
import socket
import time
import threading
import select
import signal
import atexit
import subprocess

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


# ============================================================
# 连接前清理
# ============================================================

def cleanup_bluez_state(mac_address):
    """清理 BlueZ 层面的残留状态，避免 Errno 52/12"""
    log("🧹 清理 BlueZ 残留状态...")
    
    # 1. 杀掉残留的桥接进程（不杀自己）
    my_pid = os.getpid()
    try:
        result = subprocess.run(
            ['pgrep', '-f', 'rfcomm_socket_simple.py'],
            capture_output=True, text=True, timeout=3
        )
        for line in result.stdout.strip().split('\n'):
            pid = line.strip()
            if pid and int(pid) != my_pid:
                try:
                    os.kill(int(pid), 9)
                    log(f"   杀掉残留进程 PID={pid}")
                except:
                    pass
    except:
        pass
    
    # 2. 释放所有 rfcomm 绑定
    try:
        subprocess.run(['rfcomm', 'release', 'all'],
                       capture_output=True, timeout=3)
        log("   rfcomm release all")
    except:
        pass
    
    # ⚠️ 不要调用 bluetoothctl disconnect！会导致 Errno 112 (Host is down)
    # RFCOMM socket.connect() 会自行建立 ACL 连接，无需预先断开
    
    # 等待系统释放资源
    time.sleep(0.5)
    log("   ✅ 清理完成")


# ============================================================
# 连接方法
# ============================================================

def connect_pybluez(mac_address, channel, timeout=5):
    """使用 PyBluez 连接到指定通道（与 bluetooth_spp_test.py 相同方式）"""
    sock = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
    sock.settimeout(timeout)  # connect 超时（bluetooth_spp_test.py 验证可行）
    sock.connect((mac_address, channel))
    # 连接成功后切换为 0.1s 读超时（用于非阻塞 recv）
    sock.settimeout(0.1)
    return sock

def connect_raw_socket(mac_address, channel, timeout=5):
    """使用原始 AF_BLUETOOTH socket 连接"""
    AF_BLUETOOTH = 31
    BTPROTO_RFCOMM = 3
    sock = socket.socket(AF_BLUETOOTH, socket.SOCK_STREAM, BTPROTO_RFCOMM)
    sock.settimeout(timeout)
    sock.connect((mac_address, channel))
    sock.settimeout(0.1)
    return sock

def try_connect_channel(mac_address, channel):
    """尝试连接到指定通道，返回 (socket, 方法名) 或 (None, 错误信息)"""
    # 方法 1: PyBluez（优先）
    if HAS_PYBLUEZ:
        try:
            log(f"   尝试 PyBluez CH{channel}...")
            sock = connect_pybluez(mac_address, channel)
            log(f"   ✅ PyBluez CH{channel} 连接成功")
            return sock, "PyBluez"
        except Exception as e:
            log(f"   ⚠️ PyBluez CH{channel}: {e}")
    
    # 方法 2: 原始 socket
    try:
        log(f"   尝试原始 socket CH{channel}...")
        sock = connect_raw_socket(mac_address, channel)
        log(f"   ✅ 原始 socket CH{channel} 连接成功")
        return sock, "raw_socket"
    except Exception as e:
        log(f"   ❌ 原始 socket CH{channel}: {e}")
    
    return None, None

def create_rfcomm_connection(mac_address, channel):
    """创建 RFCOMM 连接，失败时自动扫描通道"""
    
    # 阶段 1: 尝试指定通道
    log(f"📡 尝试连接 {mac_address} CH{channel}")
    sock, method = try_connect_channel(mac_address, channel)
    if sock:
        return sock, channel, method
    
    # 阶段 2: 指定通道失败，扫描常用通道（参考 bluetooth_spp_test.py _smart_connect）
    log(f"⚠️ CH{channel} 连接失败，开始扫描常用通道...")
    scan_channels = [ch for ch in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] if ch != channel]
    
    for ch in scan_channels:
        sock, method = try_connect_channel(mac_address, ch)
        if sock:
            log(f"✅ 通道扫描成功: CH{ch} ({method})")
            return sock, ch, method
    
    return None, None, None


# ============================================================
# 数据透传线程
# ============================================================

def socket_to_stdout(sock, keep_alive_event):
    """从 BT socket 读取数据并立即输出到 stdout（完全透传）"""
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
                log(f"📥 BT→stdout #{recv_count} [{len(data)}B] (累计:{total_bytes}B): {data_hex[:200]}")
                
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
                
            except socket.timeout:
                continue
            except Exception as e:
                # PyBluez BluetoothError 不继承 socket.timeout，用消息判断
                error_msg = str(e).lower()
                if 'timed out' in error_msg or 'timeout' in error_msg:
                    continue
                elif 'resource temporarily unavailable' in error_msg:
                    continue
                else:
                    log(f"❌ BT socket 读取错误: {type(e).__name__}: {e}")
                    keep_alive_event.clear()
                    break
                    
    except Exception as e:
        log(f"❌ 读取线程异常: {type(e).__name__}: {e}")
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
            log(f"📨 stdin→BT #{send_count} [{len(data)}B]: {data_hex[:200]}")
            
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


# ============================================================
# 主程序
# ============================================================

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
    
    # 步骤 1: 清理 BlueZ 残留状态（解决 Errno 52/12）
    cleanup_bluez_state(mac_address)
    
    # 步骤 2: 建立 RFCOMM 连接（带通道扫描）
    sock, actual_channel, method = create_rfcomm_connection(mac_address, channel)
    if not sock:
        log("❌ 所有连接尝试均失败")
        log("   可能原因:")
        log("   1. 设备未开机或不在范围内")
        log("   2. 设备未配对（需先在系统蓝牙中配对）")
        log("   3. 设备不支持 SPP/RFCOMM")
        log("   4. 所有 RFCOMM 通道均被拒绝")
        sys.exit(1)
    
    log(f"✅ 连接成功: {mac_address} CH{actual_channel} ({method})")
    
    # 注册 atexit 确保 socket 在任何退出情况下都会关闭
    def cleanup_socket():
        try:
            sock.close()
            log("🧹 atexit: socket 已关闭")
        except:
            pass
    atexit.register(cleanup_socket)
    
    # 创建 keep_alive 事件
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
    
    # 启动双向数据传输
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
    
    # 主线程等待
    try:
        while keep_alive_event.is_set():
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
    
    read_thread.join(timeout=2)
    write_thread.join(timeout=2)
    log("✅ 清理完成")

if __name__ == "__main__":
    main()
