#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Windows 蓝牙 SPP 测试工具
支持自定义 UUID 和 RFCOMM channel
"""

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
    
    def __init__(self, device_address: str, uuid: Optional[str] = None, channel: Optional[int] = None):
        self.device_address = device_address
        self.uuid = uuid or "00001101-0000-1000-8000-00805F9B34FB"
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
    """扫描蓝牙设备"""
    print("━" * 50)
    print("🔍 正在扫描蓝牙设备...")
    print("━" * 50)
    
    nearby_devices = bluetooth.discover_devices(
        duration=8,
        lookup_names=True,
        flush_cache=True,
        lookup_class=False
    )
    
    if not nearby_devices:
        print("未找到任何设备")
        return []
    
    print(f"\n找到 {len(nearby_devices)} 个设备:\n")
    for i, (addr, name) in enumerate(nearby_devices, 1):
        print(f"{i}. {name}")
        print(f"   地址: {addr}\n")
    
    print("━" * 50)
    return nearby_devices


def find_services(device_address: str):
    """查找设备的所有服务"""
    print("━" * 50)
    print(f"🔍 查找设备 {device_address} 的服务...")
    print("━" * 50)
    
    services = bluetooth.find_service(address=device_address)
    
    if not services:
        print("未找到任何服务")
        return []
    
    print(f"\n找到 {len(services)} 个服务:\n")
    
    for i, service in enumerate(services, 1):
        print(f"服务 {i}:")
        print(f"  名称: {service.get('name', 'Unknown')}")
        print(f"  RFCOMM Channel: {service.get('port', 'N/A')}")
        print(f"  服务 ID: {service.get('service-id', 'N/A')}")
        print(f"  协议: {service.get('protocol', 'N/A')}")
        print()
    
    print("━" * 50)
    return services


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
    parser.add_argument('--scan', action='store_true', help='扫描蓝牙设备')
    parser.add_argument('--services', metavar='ADDRESS', help='查找设备的服务')
    parser.add_argument('--connect', metavar='ADDRESS', help='连接到设备')
    parser.add_argument('--uuid', metavar='UUID', help='自定义 UUID (默认: 标准 SPP UUID)')
    parser.add_argument('--channel', type=int, metavar='N', help='RFCOMM channel (1-30)')
    parser.add_argument('--test', choices=['mac'], help='运行测试')
    parser.add_argument('--env-cmd', action='store_true', help='从环境变量读取命令')
    
    args = parser.parse_args()
    
    try:
        if args.scan:
            scan_devices()
        
        elif args.services:
            find_services(args.services)
        
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
