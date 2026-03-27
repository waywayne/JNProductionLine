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

def cleanup_rfcomm():
    """清理 RFCOMM 设备"""
    try:
        subprocess.run(['sudo', 'rfcomm', 'release', '0'],
                      stderr=subprocess.DEVNULL, timeout=2)
    except:
        pass

def setup_rfcomm_bind(mac_address, channel):
    """使用 rfcomm bind 创建设备文件"""
    log(f"设置 RFCOMM 绑定")
    log(f"  MAC: {mac_address}")
    log(f"  通道: {channel}")
    
    # 1. 清理旧的绑定
    cleanup_rfcomm()
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
    empty_read_count = 0
    
    try:
        while keep_alive_event.is_set():
            # 使用 select 检查是否有数据
            readable, _, _ = select.select([device_fd], [], [], 0.5)
            
            if readable:
                try:
                    data = os.read(device_fd, 1024)
                    if not data:
                        empty_read_count += 1
                        # 连续多次空读取才认为连接关闭
                        if empty_read_count > 10:
                            log("设备连接已关闭（读取端）")
                            break
                        continue
                    
                    recv_count += 1
                    timeout_count = 0  # 重置超时计数
                    empty_read_count = 0  # 重置空读取计数
                    
                    # 记录接收到的数据
                    data_hex = ' '.join(f'{b:02X}' for b in data)
                    log(f"📥 接收到 {len(data)} 字节 (第 {recv_count} 次): {data_hex[:100]}{'...' if len(data_hex) > 100 else ''}")
                    
                    # 输出到 stdout（Dart 会读取）
                    sys.stdout.buffer.write(data)
                    sys.stdout.buffer.flush()
                    
                except OSError as e:
                    if e.errno == 11:  # EAGAIN
                        timeout_count += 1
                        if timeout_count % 200 == 0:
                            log(f"⏳ 持续监听中... (已接收: {recv_count} 次)")
                        continue
                    else:
                        log(f"读取错误: {e}")
                        break
            else:
                timeout_count += 1
                if timeout_count % 200 == 0:
                    log(f"⏳ 持续监听中... (已接收: {recv_count} 次)")
            
    except Exception as e:
        log(f"读取异常: {e}")

def stdin_to_device(device_fd, keep_alive_event):
    """从 stdin 读取数据并发送到设备"""
    log("📤 开始监听 stdin 数据...")
    
    try:
        while keep_alive_event.is_set():
            # 使用 select 检查 stdin 是否有数据
            readable, _, _ = select.select([sys.stdin.buffer], [], [], 0.5)
            
            if readable:
                try:
                    data = sys.stdin.buffer.read(1024)
                    if not data:
                        log("stdin 已关闭")
                        break
                    
                    data_len = len(data)
                    data_hex = ' '.join(f'{b:02X}' for b in data)
                    log(f"📨 准备发送 {data_len} 字节")
                    log(f"   数据: {data_hex}")
                    
                    # 发送数据
                    sent = 0
                    while sent < data_len:
                        n = os.write(device_fd, data[sent:])
                        sent += n
                        if sent < data_len:
                            log(f"   已发送 {sent}/{data_len} 字节")
                    
                    log(f"✅ 数据发送完成: {data_len} 字节")
                    
                    # 发送后延迟，确保设备有足够时间处理
                    time.sleep(0.3)  # 300ms 延迟
                    
                except OSError as e:
                    if e.errno == 11:  # EAGAIN
                        continue
                    else:
                        log(f"发送错误: {e}")
                        break
            
    except Exception as e:
        log(f"写入异常: {e}")

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
    try:
        # 设备 -> stdout（后台线程）
        read_thread = threading.Thread(target=device_to_stdout, args=(device_fd, keep_alive_event), daemon=True)
        read_thread.start()
        
        # stdin -> 设备（主线程）
        stdin_to_device(device_fd, keep_alive_event)
        
    except KeyboardInterrupt:
        log("收到中断信号")
    except Exception as e:
        log(f"运行异常: {e}")
    finally:
        # 5. 清理
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
