#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
方案7: 使用 gatttool/hcitool 命令行工具
通过系统命令行工具进行蓝牙连接，兼容性最好
"""

import sys
import os
import time
import subprocess
import threading
import select
import fcntl

def log(message):
    """输出日志到 stderr"""
    print(f"[CMD-SPP] {message}", file=sys.stderr, flush=True)

class CommandLineSPP:
    """命令行工具 SPP 连接器"""
    
    def __init__(self, mac_address, channel=5):
        self.mac_address = mac_address
        self.channel = channel
        self.device_path = '/dev/rfcomm0'
        self.device_fd = None
        self.keep_alive = threading.Event()
        self.keep_alive.set()
        self.recv_count = 0
        
    def run_command(self, cmd, timeout=30):
        """运行命令并返回结果"""
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return result.returncode == 0, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return False, '', 'Command timeout'
        except Exception as e:
            return False, '', str(e)
    
    def check_bluetooth(self):
        """检查蓝牙状态"""
        log("🔍 检查蓝牙状态...")
        
        # 检查 hciconfig
        success, stdout, stderr = self.run_command(['hciconfig'])
        if not success:
            log(f"❌ hciconfig 失败: {stderr}")
            return False
        
        if 'hci0' not in stdout:
            log("❌ 未找到蓝牙适配器")
            return False
        
        if 'UP RUNNING' not in stdout:
            log("⚠️ 蓝牙适配器未启动，正在启动...")
            self.run_command(['sudo', 'hciconfig', 'hci0', 'up'])
            time.sleep(1)
        
        log("✅ 蓝牙适配器正常")
        return True
    
    def pair_device(self):
        """配对设备"""
        log(f"🔗 检查设备配对状态: {self.mac_address}")
        
        # 检查是否已配对
        success, stdout, stderr = self.run_command([
            'bluetoothctl', 'info', self.mac_address
        ])
        
        if 'Paired: yes' in stdout:
            log("✅ 设备已配对")
            return True
        
        log("⚠️ 设备未配对，开始配对...")
        
        # 使用 bluetoothctl 配对
        pair_script = f'''
echo "power on"
sleep 1
echo "agent on"
sleep 0.5
echo "default-agent"
sleep 0.5
echo "scan on"
sleep 5
echo "scan off"
sleep 0.5
echo "pair {self.mac_address}"
sleep 3
echo "trust {self.mac_address}"
sleep 1
echo "quit"
'''
        
        try:
            process = subprocess.Popen(
                ['bluetoothctl'],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            stdout, stderr = process.communicate(pair_script, timeout=30)
            log(f"配对输出: {stdout[:200]}...")
        except Exception as e:
            log(f"❌ 配对失败: {e}")
            return False
        
        # 再次检查
        success, stdout, stderr = self.run_command([
            'bluetoothctl', 'info', self.mac_address
        ])
        
        if 'Paired: yes' in stdout:
            log("✅ 配对成功")
            return True
        
        log("⚠️ 配对可能未完成，继续尝试连接")
        return True
    
    def bind_rfcomm(self):
        """绑定 RFCOMM 设备"""
        log(f"🔗 绑定 RFCOMM 设备: 通道 {self.channel}")
        
        # 先释放旧的绑定
        self.run_command(['sudo', 'rfcomm', 'release', '0'])
        time.sleep(0.5)
        
        # 绑定新设备
        success, stdout, stderr = self.run_command([
            'sudo', 'rfcomm', 'bind', '0', 
            self.mac_address, str(self.channel)
        ])
        
        if not success:
            log(f"❌ RFCOMM 绑定失败: {stderr}")
            return False
        
        # 等待设备文件出现
        for i in range(10):
            if os.path.exists(self.device_path):
                log(f"✅ RFCOMM 设备已创建: {self.device_path}")
                return True
            time.sleep(0.5)
        
        log(f"❌ RFCOMM 设备文件未出现: {self.device_path}")
        return False
    
    def open_device(self):
        """打开设备文件"""
        try:
            log(f"📂 打开设备文件: {self.device_path}")
            self.device_fd = os.open(self.device_path, os.O_RDWR | os.O_NONBLOCK)
            log("✅ 设备文件已打开")
            return True
        except Exception as e:
            log(f"❌ 打开设备失败: {e}")
            return False
    
    def read_thread(self):
        """读取线程"""
        log("🎧 开始监听设备数据...")
        timeout_count = 0
        empty_count = 0
        
        try:
            while self.keep_alive.is_set():
                readable, _, _ = select.select([self.device_fd], [], [], 0.5)
                
                if readable:
                    try:
                        data = os.read(self.device_fd, 1024)
                        if not data:
                            empty_count += 1
                            if empty_count > 10:
                                log("设备连接已关闭")
                                break
                            continue
                        
                        self.recv_count += 1
                        empty_count = 0
                        
                        data_hex = ' '.join(f'{b:02X}' for b in data)
                        log(f"📥 接收到 {len(data)} 字节 (第 {self.recv_count} 次): {data_hex[:100]}")
                        
                        sys.stdout.buffer.write(data)
                        sys.stdout.buffer.flush()
                        
                    except OSError as e:
                        if e.errno == 11:  # EAGAIN
                            continue
                        log(f"读取错误: {e}")
                        break
                else:
                    timeout_count += 1
                    if timeout_count % 200 == 0:
                        log(f"⏳ 持续监听中... (已接收: {self.recv_count} 次)")
                        
        except Exception as e:
            log(f"读取异常: {e}")
    
    def write_thread(self):
        """写入线程"""
        log("📤 开始监听 stdin 数据...")
        
        flags = fcntl.fcntl(sys.stdin.fileno(), fcntl.F_GETFL)
        fcntl.fcntl(sys.stdin.fileno(), fcntl.F_SETFL, flags | os.O_NONBLOCK)
        
        try:
            while self.keep_alive.is_set():
                readable, _, _ = select.select([sys.stdin], [], [], 0.5)
                
                if readable:
                    try:
                        data = sys.stdin.buffer.read(1024)
                        if not data:
                            log("stdin 已关闭")
                            break
                        
                        data_len = len(data)
                        data_hex = ' '.join(f'{b:02X}' for b in data)
                        log(f"📨 准备发送 {data_len} 字节: {data_hex}")
                        
                        sent = 0
                        while sent < data_len:
                            n = os.write(self.device_fd, data[sent:])
                            sent += n
                        
                        log(f"✅ 数据发送完成: {data_len} 字节")
                        time.sleep(0.2)
                        
                    except OSError as e:
                        if e.errno == 11:
                            continue
                        log(f"写入错误: {e}")
                        break
                        
        except Exception as e:
            log(f"写入异常: {e}")
    
    def run(self):
        """运行连接"""
        if not self.check_bluetooth():
            return False
        
        if not self.pair_device():
            return False
        
        if not self.bind_rfcomm():
            return False
        
        if not self.open_device():
            return False
        
        log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        log("✅ 命令行工具 SPP 连接成功")
        log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        # 启动读写线程
        read_t = threading.Thread(target=self.read_thread, daemon=True)
        write_t = threading.Thread(target=self.write_thread, daemon=True)
        
        read_t.start()
        write_t.start()
        
        read_t.join()
        write_t.join()
        
        return True
    
    def disconnect(self):
        """断开连接"""
        self.keep_alive.clear()
        if self.device_fd:
            try:
                os.close(self.device_fd)
            except:
                pass
        self.run_command(['sudo', 'rfcomm', 'release', '0'])
        log("🔌 连接已断开")

def main():
    if len(sys.argv) != 3:
        print("用法: rfcomm_gatttool.py <MAC地址> <通道>", file=sys.stderr)
        sys.exit(1)
    
    mac_address = sys.argv[1]
    channel = int(sys.argv[2])
    
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    log("命令行工具 SPP 连接模式")
    log(f"MAC: {mac_address}")
    log(f"通道: {channel}")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    spp = CommandLineSPP(mac_address, channel)
    
    try:
        spp.run()
    except KeyboardInterrupt:
        log("收到中断信号")
    finally:
        spp.disconnect()
        log("✅ 清理完成")

if __name__ == "__main__":
    main()
