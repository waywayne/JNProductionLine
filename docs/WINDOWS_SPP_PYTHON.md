# Windows 平台蓝牙 SPP 协议交互 - Python 实现

## 概述

本文档介绍如何在 Windows 平台下使用 Python 直接实现蓝牙 SPP (Serial Port Profile) 协议交互，支持自定义 UUID 和 RFCOMM channel。

## 方案对比

| 方案 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| **PyBluez** | 成熟稳定，API 简单 | 需要编译，依赖复杂 | ⭐⭐⭐⭐ |
| **bleak** | 现代化，支持 BLE | 主要用于 BLE，Classic 支持有限 | ⭐⭐ |
| **pybluez2** | PyBluez 的 Python 3 版本 | 维护不活跃 | ⭐⭐⭐ |
| **Windows Socket API** | 原生支持，无需依赖 | 需要 C/C++ 编程 | ⭐⭐⭐⭐⭐ |
| **serial.tools.list_ports** | 简单易用 | 仅支持已配对的虚拟串口 | ⭐⭐⭐ |

## 推荐方案：PyBluez

### 1. 安装

```bash
# 方法 1: 使用 pip (可能需要 Visual Studio Build Tools)
pip install pybluez

# 方法 2: 使用预编译的 wheel (推荐)
# 从 https://www.lfd.uci.edu/~gohlke/pythonlibs/#pybluez 下载对应版本
pip install PyBluez‑0.23‑cp39‑cp39‑win_amd64.whl

# 方法 3: 使用 conda
conda install -c conda-forge pybluez
```

### 2. 基础使用示例

#### 扫描蓝牙设备

```python
import bluetooth

def scan_devices():
    """扫描附近的蓝牙设备"""
    print("正在扫描蓝牙设备...")
    nearby_devices = bluetooth.discover_devices(
        duration=8,
        lookup_names=True,
        flush_cache=True,
        lookup_class=False
    )
    
    print(f"找到 {len(nearby_devices)} 个设备:")
    for addr, name in nearby_devices:
        print(f"  {name} - {addr}")
    
    return nearby_devices

if __name__ == "__main__":
    devices = scan_devices()
```

#### 连接到 SPP 服务（标准 UUID）

```python
import bluetooth
import time

def connect_spp_standard(device_address):
    """连接到标准 SPP 服务 (UUID: 00001101-...)"""
    
    # 标准 SPP UUID
    SPP_UUID = "00001101-0000-1000-8000-00805F9B34FB"
    
    print(f"正在连接到设备: {device_address}")
    
    # 查找 SPP 服务
    services = bluetooth.find_service(
        uuid=SPP_UUID,
        address=device_address
    )
    
    if not services:
        print("未找到 SPP 服务")
        return None
    
    # 获取第一个 SPP 服务
    service = services[0]
    print(f"找到服务: {service['name']}")
    print(f"  主机: {service['host']}")
    print(f"  端口: {service['port']}")
    
    # 创建 RFCOMM socket
    sock = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
    
    try:
        # 连接到服务
        sock.connect((service['host'], service['port']))
        print("✅ 连接成功!")
        return sock
    except Exception as e:
        print(f"❌ 连接失败: {e}")
        sock.close()
        return None

# 使用示例
if __name__ == "__main__":
    device_addr = "AA:BB:CC:DD:EE:FF"  # 替换为你的设备地址
    sock = connect_spp_standard(device_addr)
    
    if sock:
        # 发送数据
        sock.send(b"Hello from Python!")
        
        # 接收数据
        data = sock.recv(1024)
        print(f"收到数据: {data}")
        
        # 关闭连接
        sock.close()
```

#### 连接到自定义 UUID 服务

```python
import bluetooth

def connect_spp_custom(device_address, custom_uuid):
    """连接到自定义 UUID 的蓝牙服务"""
    
    print(f"正在连接到设备: {device_address}")
    print(f"使用 UUID: {custom_uuid}")
    
    # 查找自定义 UUID 服务
    services = bluetooth.find_service(
        uuid=custom_uuid,
        address=device_address
    )
    
    if not services:
        print(f"未找到 UUID {custom_uuid} 的服务")
        return None
    
    service = services[0]
    print(f"找到服务: {service['name']}")
    print(f"  RFCOMM Channel: {service['port']}")
    
    # 创建并连接 socket
    sock = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
    
    try:
        sock.connect((service['host'], service['port']))
        print("✅ 连接成功!")
        return sock
    except Exception as e:
        print(f"❌ 连接失败: {e}")
        sock.close()
        return None

# 使用示例
if __name__ == "__main__":
    device_addr = "AA:BB:CC:DD:EE:FF"
    custom_uuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"  # 自定义 UUID
    
    sock = connect_spp_custom(device_addr, custom_uuid)
    if sock:
        sock.send(b"Hello with custom UUID!")
        sock.close()
```

#### 直接指定 RFCOMM Channel 连接

```python
import bluetooth

def connect_by_channel(device_address, channel):
    """直接通过 RFCOMM channel 连接（不使用 SDP 查询）"""
    
    print(f"正在连接到设备: {device_address}")
    print(f"RFCOMM Channel: {channel}")
    
    sock = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
    
    try:
        # 直接连接到指定 channel
        sock.connect((device_address, channel))
        print("✅ 连接成功!")
        return sock
    except Exception as e:
        print(f"❌ 连接失败: {e}")
        sock.close()
        return None

# 使用示例
if __name__ == "__main__":
    device_addr = "AA:BB:CC:DD:EE:FF"
    channel = 1  # RFCOMM channel 通常在 1-30 之间
    
    sock = connect_by_channel(device_addr, channel)
    if sock:
        sock.send(b"Hello via channel!")
        sock.close()
```

### 3. 完整的 GTP 协议交互示例

```python
import bluetooth
import struct
import binascii

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
        # CLI 结构
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
        crc16 = crc32 & 0xFFFF  # 取低 16 位
        struct.pack_into('<H', cli, 4, crc16)
        
        return bytes(cli)
    
    @staticmethod
    def build_gtp_packet(cli_payload, module_id=0x0000, message_id=0x0000):
        """构建完整的 GTP 数据包"""
        # 构建 CLI 消息
        cli_message = GTPProtocol.build_cli_message(cli_payload, module_id, message_id)
        
        # GTP Header
        header = bytearray()
        header.extend(struct.pack('<I', GTPProtocol.PREAMBLE))  # Preamble
        
        # Version + Length + Type + FC + Seq
        header_fields = bytearray()
        header_fields.append(GTPProtocol.VERSION)  # Version
        length_field = 1 + 2 + 1 + 1 + 2 + 1 + len(cli_message) + 4
        header_fields.extend(struct.pack('<H', length_field))  # Length
        header_fields.append(GTPProtocol.TYPE_CLI)  # Type
        header_fields.append(0x04)  # FC
        header_fields.extend(struct.pack('<H', 0x0000))  # Seq
        
        # 计算 CRC8
        crc8 = GTPProtocol.calculate_crc8(header_fields)
        
        # 组装完整数据包
        packet = bytearray()
        packet.extend(header)
        packet.extend(header_fields)
        packet.append(crc8)
        packet.extend(cli_message)
        
        # 计算 CRC32
        crc32_data = bytes(header_fields) + bytes([crc8]) + cli_message
        crc32 = GTPProtocol.calculate_crc32(crc32_data)
        packet.extend(struct.pack('<I', crc32))
        
        return bytes(packet)


class BluetoothSPPClient:
    """蓝牙 SPP 客户端"""
    
    def __init__(self, device_address, uuid=None, channel=None):
        self.device_address = device_address
        self.uuid = uuid or "00001101-0000-1000-8000-00805F9B34FB"
        self.channel = channel
        self.socket = None
    
    def connect(self):
        """连接到蓝牙设备"""
        print(f"连接到设备: {self.device_address}")
        print(f"UUID: {self.uuid}")
        
        if self.channel is not None:
            # 直接通过 channel 连接
            print(f"使用 RFCOMM Channel: {self.channel}")
            self.socket = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
            self.socket.connect((self.device_address, self.channel))
        else:
            # 通过 UUID 查找服务
            services = bluetooth.find_service(
                uuid=self.uuid,
                address=self.device_address
            )
            
            if not services:
                raise Exception(f"未找到 UUID {self.uuid} 的服务")
            
            service = services[0]
            print(f"找到服务: {service['name']}")
            print(f"RFCOMM Channel: {service['port']}")
            
            self.socket = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
            self.socket.connect((service['host'], service['port']))
        
        print("✅ 连接成功!")
    
    def send_gtp_command(self, cmd_payload, module_id=0x0000, message_id=0x0000):
        """发送 GTP 命令"""
        if not self.socket:
            raise Exception("未连接到设备")
        
        # 构建 GTP 数据包
        packet = GTPProtocol.build_gtp_packet(cmd_payload, module_id, message_id)
        
        # 打印发送的数据
        print(f"\n📤 发送 GTP 数据包 ({len(packet)} 字节):")
        print(f"   {binascii.hexlify(packet, ' ').decode().upper()}")
        
        # 发送数据
        self.socket.send(packet)
        print("✅ 发送成功")
    
    def receive_data(self, timeout=5):
        """接收数据"""
        if not self.socket:
            raise Exception("未连接到设备")
        
        self.socket.settimeout(timeout)
        
        try:
            data = self.socket.recv(1024)
            print(f"\n📥 收到数据 ({len(data)} 字节):")
            print(f"   {binascii.hexlify(data, ' ').decode().upper()}")
            return data
        except bluetooth.BluetoothError as e:
            print(f"⚠️  接收超时或错误: {e}")
            return None
    
    def disconnect(self):
        """断开连接"""
        if self.socket:
            self.socket.close()
            self.socket = None
            print("🔌 已断开连接")


# 使用示例
if __name__ == "__main__":
    # 设备配置
    DEVICE_ADDRESS = "AA:BB:CC:DD:EE:FF"  # 替换为你的设备地址
    
    # 方式 1: 使用标准 SPP UUID
    client = BluetoothSPPClient(DEVICE_ADDRESS)
    
    # 方式 2: 使用自定义 UUID
    # client = BluetoothSPPClient(
    #     DEVICE_ADDRESS,
    #     uuid="6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    # )
    
    # 方式 3: 直接指定 RFCOMM channel
    # client = BluetoothSPPClient(DEVICE_ADDRESS, channel=1)
    
    try:
        # 连接
        client.connect()
        
        # 发送读取蓝牙 MAC 地址命令
        # CMD: 0x0D (蓝牙命令), OPT: 0x01 (读取)
        cmd_payload = bytes([0x0D, 0x01])
        client.send_gtp_command(cmd_payload, module_id=0x0000, message_id=0x0000)
        
        # 接收响应
        response = client.receive_data(timeout=5)
        
        # 断开连接
        client.disconnect()
        
    except Exception as e:
        print(f"❌ 错误: {e}")
        client.disconnect()
```

### 4. 查找设备的 RFCOMM Channel

```python
import bluetooth

def find_all_services(device_address):
    """查找设备的所有服务和 RFCOMM channel"""
    
    print(f"查找设备 {device_address} 的所有服务...")
    
    # 查找所有服务
    services = bluetooth.find_service(address=device_address)
    
    if not services:
        print("未找到任何服务")
        return
    
    print(f"\n找到 {len(services)} 个服务:\n")
    
    for i, service in enumerate(services, 1):
        print(f"服务 {i}:")
        print(f"  名称: {service.get('name', 'Unknown')}")
        print(f"  描述: {service.get('description', 'N/A')}")
        print(f"  提供者: {service.get('provider', 'N/A')}")
        print(f"  协议: {service.get('protocol', 'N/A')}")
        print(f"  RFCOMM Channel: {service.get('port', 'N/A')}")
        print(f"  服务类: {service.get('service-classes', 'N/A')}")
        print(f"  配置文件: {service.get('profiles', 'N/A')}")
        print(f"  服务 ID: {service.get('service-id', 'N/A')}")
        print()

# 使用示例
if __name__ == "__main__":
    device_addr = "AA:BB:CC:DD:EE:FF"
    find_all_services(device_addr)
```

## 方案 2: 使用 Windows COM 端口

如果设备已经配对并创建了虚拟串口，可以直接使用 pyserial：

```python
import serial
import serial.tools.list_ports

def list_bluetooth_ports():
    """列出所有蓝牙虚拟串口"""
    ports = serial.tools.list_ports.comports()
    
    bluetooth_ports = []
    for port in ports:
        if 'Bluetooth' in port.description or 'BT' in port.description:
            bluetooth_ports.append(port)
            print(f"找到蓝牙串口: {port.device}")
            print(f"  描述: {port.description}")
            print(f"  硬件 ID: {port.hwid}")
            print()
    
    return bluetooth_ports

def connect_via_com(port_name, baudrate=9600):
    """通过 COM 端口连接"""
    ser = serial.Serial(
        port=port_name,
        baudrate=baudrate,
        timeout=1
    )
    
    print(f"✅ 已连接到 {port_name}")
    return ser

# 使用示例
if __name__ == "__main__":
    # 列出蓝牙端口
    bt_ports = list_bluetooth_ports()
    
    if bt_ports:
        # 连接到第一个蓝牙端口
        ser = connect_via_com(bt_ports[0].device)
        
        # 发送数据
        ser.write(b"Hello via COM port!")
        
        # 接收数据
        data = ser.read(100)
        print(f"收到: {data}")
        
        ser.close()
```

## 方案 3: 使用 C# 调用 Windows Bluetooth API

创建 `bluetooth_spp.py`:

```python
import clr
import sys

# 添加 Windows Runtime 引用
clr.AddReference('System.Runtime.WindowsRuntime')
from System import Byte, Array

# 导入 Windows.Devices.Bluetooth
from Windows.Devices.Bluetooth import BluetoothDevice
from Windows.Devices.Bluetooth.Rfcomm import RfcommDeviceService
from Windows.Networking.Sockets import StreamSocket

async def connect_bluetooth_async(device_address, service_uuid):
    """使用 Windows Bluetooth API 连接"""
    
    # 从地址获取设备
    device = await BluetoothDevice.FromBluetoothAddressAsync(int(device_address, 16))
    
    # 获取 RFCOMM 服务
    services = await device.GetRfcommServicesForIdAsync(
        RfcommServiceId.FromUuid(Guid.Parse(service_uuid))
    )
    
    if services.Services.Count == 0:
        raise Exception("未找到服务")
    
    service = services.Services[0]
    
    # 创建 socket 并连接
    socket = StreamSocket()
    await socket.ConnectAsync(
        service.ConnectionHostName,
        service.ConnectionServiceName
    )
    
    return socket
```

## 故障排查

### 问题 1: PyBluez 安装失败

**解决方案**:
1. 安装 Visual Studio Build Tools
2. 使用预编译的 wheel 文件
3. 使用 conda 安装

### 问题 2: 找不到设备或服务

**解决方案**:
1. 确保设备已配对
2. 确保设备在范围内
3. 检查设备是否支持 SPP
4. 使用 `find_all_services()` 查看所有可用服务

### 问题 3: 连接超时

**解决方案**:
1. 增加超时时间
2. 检查防火墙设置
3. 确认 RFCOMM channel 正确
4. 重启蓝牙适配器

## 参考资料

- [PyBluez 文档](https://pybluez.github.io/)
- [Windows Bluetooth API](https://docs.microsoft.com/en-us/windows/uwp/devices-sensors/bluetooth)
- [RFCOMM Protocol](https://www.bluetooth.com/specifications/specs/rfcomm-1-1/)
- [Python Serial](https://pyserial.readthedocs.io/)
