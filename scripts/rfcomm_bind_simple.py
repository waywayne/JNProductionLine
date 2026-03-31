#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RFCOMM Bind 简单桥接脚本
使用 rfcomm bind 创建 /dev/rfcomm0，然后直接桥接到 stdin/stdout
不进行任何 GTP 组装，完全透传原始数据
"""

import sys
import os
import time
import subprocess
import fcntl
import select
import threading
import signal

def log(message):
    """输出日志到 stderr"""
    timestamp = time.strftime('%H:%M:%S')
    print(f"[{timestamp}] [RFCOMM-SIMPLE] {message}", file=sys.stderr, flush=True)

def cleanup_rfcomm():
    """清理 RFCOMM 设备"""
    try:
        subprocess.run(['sudo', 'rfcomm', 'release', '0'],
                      stderr=subprocess.DEVNULL, timeout=2)
    except:
        pass

def setup_rfcomm_bind(mac_address, channel):
    """使用 rfcomm bind 创建设备文件"""
    log(f"设置 RFCOMM 绑定: MAC={mac_address}, 通道={channel}")
    
    # 1. 清理旧的绑定
    cleanup_rfcomm()
    time.sleep(0.3)
    
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
                time.sleep(0.5)
                return True
            time.sleep(0.25)
        
        log(f"❌ 设备文件未出现: {device_path}")
        return False
        
    except subprocess.TimeoutExpired:
        log(f"❌ 绑定超时")
        return False
    except Exception as e:
        log(f"❌ 绑定异常: {e}")
        return False

def device_to_stdout(device_fd, keep_alive_event):
    """从设备读取数据并直接输出到 stdout（完全透传）"""
    log("🎧 开始监听设备数据（完全透传模式）...")
    recv_count = 0
    total_bytes = 0
    
    try:
        while keep_alive_event.is_set():
            # 使用 select 检查是否有数据，超时 100ms
            readable, _, _ = select.select([device_fd], [], [], 0.1)
            
            if readable:
                try:
                    # 读取数据
                    data = os.read(device_fd, 4096)
                    if not data:
                        continue
                    
                    recv_count += 1
                    total_bytes += len(data)
                    
                    # 记录接收到的原始数据
                    data_hex = ' '.join(f'{b:02X}' for b in data)
                    log(f"📥 接收 #{recv_count} [{len(data)}字节] (累计:{total_bytes}): {data_hex[:120]}{'...' if len(data_hex) > 120 else ''}")
                    
                    # 直接输出到 stdout，不做任何处理
                    sys.stdout.buffer.write(data)
                    sys.stdout.buffer.flush()
                    
                except OSError as e:
                    if e.errno == 11:  # EAGAIN - 非阻塞模式下无数据
                        continue
                    elif e.errno == 5:  # EIO - 设备断开
                        log(f"⚠️ 设备 I/O 错误，可能已断开")
                        break
                    else:
                        log(f"❌ 读取错误: {e}")
                        break
            
    except Exception as e:
        log(f"❌ 读取异常: {e}")
    finally:
        log(f"📊 读取线程结束，共接收 {recv_count} 次，{total_bytes} 字节")

def stdin_to_device(device_fd, keep_alive_event):
    """从 stdin 读取数据并发送到设备"""
    log("📤 开始监听 stdin 数据...")
    send_count = 0
    total_bytes = 0
    
    try:
        while keep_alive_event.is_set():
            # 使用 select 检查 stdin 是否有数据
            readable, _, _ = select.select([sys.stdin.buffer], [], [], 0.1)
            
            if readable:
                try:
                    data = sys.stdin.buffer.read(4096)
                    if not data:
                        log("stdin 已关闭（Dart 进程退出）")
                        keep_alive_event.clear()
                        break
                    
                    send_count += 1
                    total_bytes += len(data)
                    data_hex = ' '.join(f'{b:02X}' for b in data)
                    log(f"📨 发送 #{send_count} [{len(data)}字节]: {data_hex[:120]}{'...' if len(data_hex) > 120 else ''}")
                    
                    # 发送数据
                    sent = 0
                    while sent < len(data):
                        n = os.write(device_fd, data[sent:])
                        sent += n
                    
                    log(f"✅ 发送完成")
                    
                except OSError as e:
                    if e.errno == 11:  # EAGAIN
                        continue
                    else:
                        log(f"❌ 发送错误: {e}")
                        break
            
    except Exception as e:
        log(f"❌ 写入异常: {e}")
    finally:
        log(f"📊 发送线程结束，共发送 {send_count} 次，{total_bytes} 字节")

def main():
    if len(sys.argv) != 3:
        print("用法: rfcomm_bind_simple.py <MAC地址> <通道>", file=sys.stderr)
        sys.exit(1)
    
    mac_address = sys.argv[1]
    channel = int(sys.argv[2])
    
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    log("RFCOMM Bind 简单桥接模式（完全透传）")
    log(f"MAC: {mac_address}, 通道: {channel}")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    # 1. 设置 RFCOMM 绑定
    if not setup_rfcomm_bind(mac_address, channel):
        log("❌ RFCOMM 绑定失败")
        sys.exit(1)
    
    # 2. 打开设备文件
    device_path = '/dev/rfcomm0'
    try:
        device_fd = os.open(device_path, os.O_RDWR | os.O_NONBLOCK)
        log(f"✅ 设备文件已打开: {device_path}")
    except Exception as e:
        log(f"❌ 打开设备文件失败: {e}")
        cleanup_rfcomm()
        sys.exit(1)
    
    # 3. 设置 stdin 为非阻塞
    flags = fcntl.fcntl(sys.stdin.buffer, fcntl.F_GETFL)
    fcntl.fcntl(sys.stdin.buffer, fcntl.F_SETFL, flags | os.O_NONBLOCK)
    
    log("✅ 连接已建立，开始数据传输")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    # 4. 创建 keep_alive 事件
    keep_alive_event = threading.Event()
    keep_alive_event.set()
    
    # 5. 启动双向数据传输
    read_thread = None
    try:
        # 设备 -> stdout（后台线程）
        read_thread = threading.Thread(target=device_to_stdout, args=(device_fd, keep_alive_event), daemon=False)
        read_thread.start()
        
        # stdin -> 设备（主线程）
        stdin_to_device(device_fd, keep_alive_event)
        
        # 发送完成后，等待读取线程
        log("⏳ 等待读取线程...")
        read_thread.join(timeout=5)
        
    except KeyboardInterrupt:
        log("收到中断信号")
    except Exception as e:
        log(f"运行异常: {e}")
    finally:
        # 停止 keep_alive 事件
        keep_alive_event.clear()
        
        # 等待读取线程结束
        if read_thread and read_thread.is_alive():
            read_thread.join(timeout=2)
        
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
