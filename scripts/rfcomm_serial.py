#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
方案6: 串口设备直接读写
直接读写 /dev/rfcomm0 设备文件，无需 Python bluetooth 库
适用于已经通过 rfcomm bind 绑定的设备
"""

import sys
import os
import time
import threading
import select
import serial
import fcntl

def log(message):
    """输出日志到 stderr"""
    print(f"[SERIAL-SPP] {message}", file=sys.stderr, flush=True)

class SerialSPP:
    """串口 SPP 连接器"""
    
    def __init__(self, device_path='/dev/rfcomm0', baudrate=115200):
        self.device_path = device_path
        self.baudrate = baudrate
        self.serial = None
        self.keep_alive = threading.Event()
        self.keep_alive.set()
        self.recv_count = 0
        
    def connect(self):
        """连接串口设备"""
        try:
            log(f"🔗 正在打开串口设备: {self.device_path}")
            
            # 检查设备文件是否存在
            if not os.path.exists(self.device_path):
                log(f"❌ 设备文件不存在: {self.device_path}")
                log("   请先使用 'sudo rfcomm bind 0 <MAC> <Channel>' 绑定设备")
                return False
            
            # 打开串口
            self.serial = serial.Serial(
                port=self.device_path,
                baudrate=self.baudrate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=0.5,  # 读取超时
                write_timeout=2,  # 写入超时
            )
            
            log(f"✅ 串口已打开: {self.device_path}")
            log(f"   波特率: {self.baudrate}")
            return True
            
        except serial.SerialException as e:
            log(f"❌ 串口打开失败: {e}")
            return False
        except Exception as e:
            log(f"❌ 连接异常: {e}")
            return False
    
    def read_thread(self):
        """读取线程：从串口读取数据并输出到 stdout"""
        log("🎧 开始监听串口数据...")
        timeout_count = 0
        
        try:
            while self.keep_alive.is_set():
                try:
                    if self.serial.in_waiting > 0:
                        data = self.serial.read(self.serial.in_waiting)
                        if data:
                            self.recv_count += 1
                            timeout_count = 0
                            
                            data_hex = ' '.join(f'{b:02X}' for b in data)
                            log(f"📥 接收到 {len(data)} 字节 (第 {self.recv_count} 次): {data_hex[:100]}{'...' if len(data_hex) > 100 else ''}")
                            
                            # 输出到 stdout
                            sys.stdout.buffer.write(data)
                            sys.stdout.buffer.flush()
                    else:
                        timeout_count += 1
                        if timeout_count % 200 == 0:
                            log(f"⏳ 持续监听中... (已接收: {self.recv_count} 次)")
                        time.sleep(0.01)
                        
                except serial.SerialException as e:
                    log(f"❌ 串口读取错误: {e}")
                    break
                    
        except Exception as e:
            log(f"❌ 读取线程异常: {e}")
    
    def write_thread(self):
        """写入线程：从 stdin 读取数据并发送到串口"""
        log("📤 开始监听 stdin 数据...")
        
        # 设置 stdin 为非阻塞
        flags = fcntl.fcntl(sys.stdin.fileno(), fcntl.F_GETFL)
        fcntl.fcntl(sys.stdin.fileno(), fcntl.F_SETFL, flags | os.O_NONBLOCK)
        
        try:
            while self.keep_alive.is_set():
                try:
                    readable, _, _ = select.select([sys.stdin], [], [], 0.5)
                    
                    if readable:
                        data = sys.stdin.buffer.read(1024)
                        if not data:
                            log("stdin 已关闭")
                            break
                        
                        data_len = len(data)
                        data_hex = ' '.join(f'{b:02X}' for b in data)
                        log(f"📨 准备发送 {data_len} 字节: {data_hex}")
                        
                        # 发送数据
                        self.serial.write(data)
                        self.serial.flush()
                        
                        log(f"✅ 数据发送完成: {data_len} 字节")
                        time.sleep(0.2)  # 发送后延迟
                        
                except serial.SerialException as e:
                    log(f"❌ 串口写入错误: {e}")
                    break
                    
        except Exception as e:
            log(f"❌ 写入线程异常: {e}")
    
    def run(self):
        """运行双向数据传输"""
        if not self.connect():
            return False
        
        log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        log("✅ 串口 SPP 连接成功")
        log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        # 启动读写线程
        read_t = threading.Thread(target=self.read_thread, daemon=True)
        write_t = threading.Thread(target=self.write_thread, daemon=True)
        
        read_t.start()
        write_t.start()
        
        # 等待线程结束
        read_t.join()
        write_t.join()
        
        return True
    
    def disconnect(self):
        """断开连接"""
        self.keep_alive.clear()
        if self.serial and self.serial.is_open:
            self.serial.close()
            log("🔌 串口已关闭")

def main():
    if len(sys.argv) < 2:
        print("用法: rfcomm_serial.py <设备路径> [波特率]", file=sys.stderr)
        print("示例: rfcomm_serial.py /dev/rfcomm0 115200", file=sys.stderr)
        sys.exit(1)
    
    device_path = sys.argv[1]
    baudrate = int(sys.argv[2]) if len(sys.argv) > 2 else 115200
    
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    log("串口 SPP 连接模式")
    log(f"设备: {device_path}")
    log(f"波特率: {baudrate}")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    spp = SerialSPP(device_path, baudrate)
    
    try:
        spp.run()
    except KeyboardInterrupt:
        log("收到中断信号")
    finally:
        spp.disconnect()
        log("✅ 清理完成")

if __name__ == "__main__":
    main()
