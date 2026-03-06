#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Windows 蓝牙 SPP 测试工具
支持自定义 UUID 和 RFCOMM channel
"""

import sys
import io

# 设置标准输出为 UTF-8 编码，解决 Windows GBK 编码问题
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

import bluetooth
import struct
import binascii
import argparse
import time
from typing import Optional


class GTPProtocol:
    """GTP 协议封装和解析"""
    
    PREAMBLE = 0xC2C5D2D0
    VERSION = 0x00
    TYPE_CLI = 0x03
    
    @staticmethod
    def calculate_crc8(data):
        """计算 CRC8 (CRC-8/MAXIM)"""
        crc = 0xFF
        for byte in data:
            crc ^= byte
            for _ in range(8):
                if crc & 0x80:
                    crc = ((crc << 1) ^ 0x31) & 0xFF
                else:
                    crc = (crc << 1) & 0xFF
        return crc ^ 0xFF
    
    @staticmethod
    def calculate_crc32(data):
        """计算 CRC32"""
        crc = 0xFFFFFFFF
        for byte in data:
            crc ^= byte
            for _ in range(8):
                if crc & 1:
                    crc = (crc >> 1) ^ 0xEDB88320
                else:
                    crc >>= 1
        return (~crc) & 0xFFFFFFFF
    
    @staticmethod
    def build_cli_message(payload, module_id=0x0000, message_id=0x0000):
        """构建 CLI 消息"""
        cli = bytearray()
        cli.extend(struct.pack('<H', 0x2323))  # Start
        cli.extend(struct.pack('<H', module_id))  # Module ID
        cli.extend(struct.pack('<H', 0x0000))  # CRC16 placeholder
        cli.extend(struct.pack('<H', message_id))  # Message ID
        cli.append(0x00)  # Flags
        cli.append(0x00)  # Result
        cli.extend(struct.pack('<H', len(payload)))  # Payload Length
        cli.extend(struct.pack('<H', 0x0000))  # SN
        cli.extend(payload)  # Payload
        cli.extend(struct.pack('<H', 0x0A0D))  # Tail
        
        # 计算并填充 CRC16
        crc32 = GTPProtocol.calculate_crc32(payload)
        crc16 = crc32 & 0xFFFF
        struct.pack_into('<H', cli, 4, crc16)
        
        return bytes(cli)
    
    @staticmethod
    def build_gtp_packet(cli_payload, module_id=0x0000, message_id=0x0000):
        """构建完整的 GTP 数据包"""
        cli_message = GTPProtocol.build_cli_message(cli_payload, module_id, message_id)
        
        header = bytearray()
        header.extend(struct.pack('<I', GTPProtocol.PREAMBLE))
        
        header_fields = bytearray()
        header_fields.append(GTPProtocol.VERSION)
        length_field = 1 + 2 + 1 + 1 + 2 + 1 + len(cli_message) + 4
        header_fields.extend(struct.pack('<H', length_field))
        header_fields.append(GTPProtocol.TYPE_CLI)
        header_fields.append(0x04)
        header_fields.extend(struct.pack('<H', 0x0000))
        
        crc8 = GTPProtocol.calculate_crc8(header_fields)
        
        packet = bytearray()
        packet.extend(header)
        packet.extend(header_fields)
        packet.append(crc8)
        packet.extend(cli_message)
        
        crc32_data = bytes(header_fields) + bytes([crc8]) + cli_message
        crc32 = GTPProtocol.calculate_crc32(crc32_data)
        packet.extend(struct.pack('<I', crc32))
        
        return bytes(packet)


class BluetoothSPPClient:
    """蓝牙 SPP 客户端"""
    
    # 自定义 UUID（项目专用）
    DEFAULT_UUID = "00007033-1000-8000-00805f9b34fb"
    
    def __init__(self, device_address: str, uuid: Optional[str] = None, channel: Optional[int] = None):
        self.device_address = device_address
        self.uuid = uuid or self.DEFAULT_UUID
        self.channel = channel
        self.socket = None
    
    def connect(self):
        """连接到蓝牙设备"""
        print("━" * 50)
        print(f"🔗 连接到设备: {self.device_address}")
        print(f"   UUID: {self.uuid}")
        
        if self.channel is not None:
            print(f"   使用 RFCOMM Channel: {self.channel}")
            self.socket = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
            self.socket.connect((self.device_address, self.channel))
        else:
            print("   正在查找服务...")
            services = bluetooth.find_service(
                uuid=self.uuid,
                address=self.device_address
            )
            
            if not services:
                raise Exception(f"未找到 UUID {self.uuid} 的服务")
            
            service = services[0]
            print(f"   找到服务: {service['name']}")
            print(f"   RFCOMM Channel: {service['port']}")
            
            self.socket = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
            self.socket.connect((service['host'], service['port']))
        
        print("✅ 连接成功!")
        print("━" * 50)
    
    def send_gtp_command(self, cmd_payload: bytes, module_id: int = 0x0000, message_id: int = 0x0000):
        """发送 GTP 命令"""
        if not self.socket:
            raise Exception("未连接到设备")
        
        packet = GTPProtocol.build_gtp_packet(cmd_payload, module_id, message_id)
        
        print(f"\n📤 发送 GTP 数据包 ({len(packet)} 字节):")
        hex_str = binascii.hexlify(packet, ' ').decode().upper()
        # 每行显示 16 字节
        for i in range(0, len(hex_str), 48):  # 16 bytes * 3 chars per byte
            print(f"   {hex_str[i:i+48]}")
        
        self.socket.send(packet)
        print("✅ 发送成功\n")
    
    def receive_data(self, timeout: int = 5) -> Optional[bytes]:
        """接收数据"""
        if not self.socket:
            raise Exception("未连接到设备")
        
        self.socket.settimeout(timeout)
        
        try:
            data = self.socket.recv(1024)
            print(f"📥 收到数据 ({len(data)} 字节):")
            hex_str = binascii.hexlify(data, ' ').decode().upper()
            for i in range(0, len(hex_str), 48):
                print(f"   {hex_str[i:i+48]}")
            return data
        except bluetooth.BluetoothError as e:
            print(f"⚠️  接收超时或错误: {e}")
            return None
    
    def disconnect(self):
        """断开连接"""
        if self.socket:
            self.socket.close()
            self.socket = None
            print("\n🔌 已断开连接")
            print("━" * 50)


def scan_devices():
    """扫描蓝牙设备（最大1分钟，找到设备后立即返回）"""
    print("━" * 50)
    print("🔍 正在扫描蓝牙设备...")
    print("   最大扫描时间: 1分钟")
    print("   找到设备后立即返回")
    print("   提示: 请确保蓝牙已开启且设备可被发现")
    print("━" * 50)
    
    import time
    start_time = time.time()
    max_duration = 60  # 最大1分钟
    scan_interval = 8  # 每次扫描8秒
    
    all_devices = {}  # 使用字典去重，key=地址, value=名称
    
    try:
        while time.time() - start_time < max_duration:
            elapsed = int(time.time() - start_time)
            print(f"   扫描中... ({elapsed}秒)")
            
            try:
                # 每次扫描8秒
                nearby_devices = bluetooth.discover_devices(
                    duration=scan_interval,
                    lookup_names=True,
                    flush_cache=True,
                    lookup_class=False
                )
                
                # 合并新发现的设备
                for addr, name in nearby_devices:
                    if addr not in all_devices:
                        all_devices[addr] = name
                        print(f"   ✓ 发现设备: {name} ({addr})")
                
                # 如果找到设备，立即返回
                if all_devices:
                    print(f"\n✅ 找到 {len(all_devices)} 个设备，停止扫描")
                    break
                    
            except Exception as e:
                print(f"   扫描出错: {e}")
                # 继续尝试
                
    except KeyboardInterrupt:
        print("\n⚠️  用户中断扫描")
    except Exception as e:
        print(f"❌ 扫描失败: {e}")
        print("   可能原因:")
        print("   1. 蓝牙适配器未启用")
        print("   2. 没有蓝牙权限")
        print("   3. PyBluez 安装不完整")
        return []
    
    if not all_devices:
        print("未找到任何设备")
        print("   建议:")
        print("   1. 确保目标设备已开启蓝牙")
        print("   2. 确保目标设备处于可发现模式")
        print("   3. 尝试在系统设置中手动配对设备")
        return []
    
    # 转换为列表格式
    nearby_devices = [(addr, name) for addr, name in all_devices.items()]
    
    print(f"\n找到 {len(nearby_devices)} 个设备:\n")
    for i, (addr, name) in enumerate(nearby_devices, 1):
        print(f"{i}. {name}")
        print(f"   地址: {addr}\n")
    
    print("━" * 50)
    return nearby_devices


def list_paired_devices():
    """列出系统已配对的蓝牙设备（Windows）"""
    print("━" * 50)
    print("🔗 查找已配对的蓝牙设备...")
    print("━" * 50)
    
    devices = []
    
    try:
        import subprocess
        import re
        import json
        
        # 方法 1: 使用 PyBluez 读取本地蓝牙适配器附近的设备
        # 注意：这只能找到可发现的设备，不是已配对的设备
        print("   正在查询系统蓝牙设备...")
        
        # 方法 2: 使用 PowerShell 获取已配对的蓝牙设备
        result = subprocess.run(
            ['powershell', '-Command', 
             'Get-PnpDevice -Class Bluetooth | Where-Object {$_.Status -eq "OK"} | Select-Object FriendlyName, InstanceId | ConvertTo-Json'],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0 and result.stdout.strip():
            try:
                # 解析 JSON 输出
                ps_devices = json.loads(result.stdout)
                
                # 如果只有一个设备，PowerShell 返回对象而不是数组
                if isinstance(ps_devices, dict):
                    ps_devices = [ps_devices]
                
                print(f"\n✅ 找到 {len(ps_devices)} 个已配对设备:\n")
                
                for idx, dev in enumerate(ps_devices, 1):
                    name = dev.get('FriendlyName', 'Unknown')
                    instance_id = dev.get('InstanceId', '')
                    
                    # 尝试从 InstanceId 中提取蓝牙地址
                    # 格式通常是: BTHENUM\{...}\8&1234abcd&0&BLUETOOTHDEVICE_AABBCCDDEEFF
                    # 或: BTHENUM\{...}\7&12345678&0&AABBCCDDEEFF
                    mac_address = None
                    
                    # 尝试多种模式提取 MAC 地址
                    patterns = [
                        r'BLUETOOTHDEVICE_([0-9A-F]{12})',  # BLUETOOTHDEVICE_AABBCCDDEEFF
                        r'&0&([0-9A-F]{12})',                # &0&AABBCCDDEEFF
                        r'_([0-9A-F]{12})$',                 # 结尾的12位十六进制
                    ]
                    
                    for pattern in patterns:
                        match = re.search(pattern, instance_id, re.IGNORECASE)
                        if match:
                            mac_hex = match.group(1)
                            # 转换为标准 MAC 地址格式 AA:BB:CC:DD:EE:FF
                            mac_address = ':'.join([mac_hex[i:i+2] for i in range(0, 12, 2)])
                            break
                    
                    if mac_address:
                        print(f"{idx}. {name}")
                        print(f"   地址: {mac_address}")
                        devices.append({
                            'name': name,
                            'address': mac_address
                        })
                    else:
                        print(f"{idx}. {name}")
                        print(f"   InstanceId: {instance_id}")
                        print(f"   ⚠️  无法提取 MAC 地址")
                
                # 输出 JSON 格式供 Dart 解析
                if devices:
                    print("\n" + "━" * 50)
                    print("JSON_DEVICES_START")
                    print(json.dumps(devices, ensure_ascii=False))
                    print("JSON_DEVICES_END")
                else:
                    print("\n⚠️  未能提取任何设备的 MAC 地址")
                    print("   建议: 直接使用已知的设备地址")
                    
            except json.JSONDecodeError as e:
                print(f"解析 PowerShell 输出失败: {e}")
                print("原始输出:")
                print(result.stdout)
        else:
            print("无法获取已配对设备列表")
            if result.stderr:
                print(f"错误: {result.stderr}")
            
    except Exception as e:
        print(f"获取已配对设备失败: {e}")
        import traceback
        traceback.print_exc()
    
    print("━" * 50)
    
    return devices


def find_services(device_address: str, uuid: str = None):
    """查找设备的所有服务或指定UUID的服务"""
    print("━" * 50)
    print(f"🔍 查找设备 {device_address} 的服务...")
    if uuid:
        print(f"   UUID: {uuid}")
    print("━" * 50)
    
    try:
        if uuid:
            # 查找指定 UUID 的服务
            services = bluetooth.find_service(uuid=uuid, address=device_address)
        else:
            # 查找所有服务
            services = bluetooth.find_service(address=device_address)
        
        if not services:
            print("未找到任何服务")
            print("\n建议:")
            print("1. 确保设备已配对")
            print("2. 确保设备已开启蓝牙")
            print("3. 尝试指定 UUID (如 SPP: 00001101-0000-1000-8000-00805f9b34fb)")
            return []
        
        print(f"\n找到 {len(services)} 个服务:\n")
        
        for i, service in enumerate(services, 1):
            print(f"服务 {i}:")
            print(f"  名称: {service.get('name', 'Unknown')}")
            print(f"  主机: {service.get('host', 'N/A')}")
            print(f"  RFCOMM Channel: {service.get('port', 'N/A')}")
            print(f"  服务 ID: {service.get('service-id', 'N/A')}")
            print(f"  服务类: {service.get('service-classes', 'N/A')}")
            print(f"  协议: {service.get('protocol', 'N/A')}")
            print()
        
        print("━" * 50)
        return services
        
    except Exception as e:
        print(f"❌ 查找服务失败: {e}")
        return []


def test_read_mac(client: BluetoothSPPClient):
    """测试读取蓝牙 MAC 地址"""
    print("\n📖 测试: 读取蓝牙 MAC 地址")
    print("━" * 50)
    
    # CMD: 0x0D (蓝牙命令), OPT: 0x01 (读取)
    cmd_payload = bytes([0x0D, 0x01])
    
    client.send_gtp_command(cmd_payload, module_id=0x0000, message_id=0x0000)
    response = client.receive_data(timeout=5)
    
    if response:
        print("✅ 测试完成")
    else:
        print("❌ 未收到响应")


def main():
    parser = argparse.ArgumentParser(description='Windows 蓝牙 SPP 测试工具')
    parser.add_argument('--scan', action='store_true', help='扫描可发现的蓝牙设备')
    parser.add_argument('--paired', action='store_true', help='列出已配对的蓝牙设备')
    parser.add_argument('--services', metavar='ADDRESS', help='查找设备的服务')
    parser.add_argument('--uuid', metavar='UUID', help=f'指定服务UUID (默认: {BluetoothSPPClient.DEFAULT_UUID})')
    parser.add_argument('--connect', metavar='ADDRESS', help='连接到设备')
    parser.add_argument('--channel', type=int, metavar='N', help='RFCOMM channel (1-30)')
    parser.add_argument('--test', choices=['mac'], help='运行测试')
    parser.add_argument('--env-cmd', action='store_true', help='从环境变量读取命令')
    
    args = parser.parse_args()
    
    try:
        if args.scan:
            scan_devices()
        elif args.paired:
            list_paired_devices()
        elif args.services:
            find_services(args.services, uuid=args.uuid)
        elif args.connect:
            client = BluetoothSPPClient(
                args.connect,
                uuid=args.uuid,
                channel=args.channel
            )
            
            client.connect()
            
            if args.test == 'mac':
                test_read_mac(client)
            elif args.env_cmd:
                # 从环境变量读取命令
                import os
                cmd_hex = os.environ.get('BT_CMD_PAYLOAD', '')
                module_id_hex = os.environ.get('BT_MODULE_ID', '0000')
                message_id_hex = os.environ.get('BT_MESSAGE_ID', '0000')
                
                if cmd_hex:
                    # 解析十六进制字符串
                    cmd_bytes = bytes.fromhex(cmd_hex)
                    module_id = int(module_id_hex, 16)
                    message_id = int(message_id_hex, 16)
                    
                    print(f"\n📖 执行环境变量命令")
                    print("━" * 50)
                    client.send_gtp_command(cmd_bytes, module_id=module_id, message_id=message_id)
                    response = client.receive_data(timeout=5)
                    
                    if response:
                        print("✅ 测试完成")
                    else:
                        print("❌ 未收到响应")
                else:
                    print("⚠️  未设置 BT_CMD_PAYLOAD 环境变量")
            else:
                print("\n提示: 使用 --test mac 运行测试")
                print("或手动发送命令...")
                time.sleep(2)
            
            client.disconnect()
        
        else:
            parser.print_help()
    
    except KeyboardInterrupt:
        print("\n\n⚠️  用户中断")
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
