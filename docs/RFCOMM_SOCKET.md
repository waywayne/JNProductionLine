# RFCOMM Socket 实现说明

## 概述

本项目使用 **RFCOMM Socket** 方式实现蓝牙 SPP 通信，这是最底层、最可靠的蓝牙通信方式。

## 架构

```
┌─────────────────┐
│  Flutter/Dart   │
│   Application   │
└────────┬────────┘
         │ stdin/stdout
         ↓
┌─────────────────┐
│  Python Bridge  │
│ rfcomm_socket.py│
└────────┬────────┘
         │ Bluetooth Socket
         ↓
┌─────────────────┐
│  RFCOMM Socket  │
│   (BlueZ API)   │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  蓝牙设备 (SPP) │
└─────────────────┘
```

## 为什么使用 RFCOMM Socket？

### 对比其他方案

| 方案 | 优点 | 缺点 |
|------|------|------|
| **RFCOMM Socket** | ✅ 最底层，最可靠<br>✅ 真正的双向通信<br>✅ 无需设备文件<br>✅ 不会超时阻塞 | ⚠️ 需要 Python 桥接 |
| rfcomm bind + 文件 | ✅ 简单 | ❌ 打开写入句柄超时<br>❌ 需要管理设备文件 |
| rfcomm connect | ✅ 传统方式 | ❌ 需要前台进程<br>❌ 容易出错 |

### 核心优势

1. **真正的 Socket 通信** - 使用 Linux BlueZ 的原生 Bluetooth Socket API
2. **无阻塞问题** - 不需要打开设备文件，避免超时
3. **双向通信** - Socket 天然支持同时读写
4. **更稳定** - 直接使用蓝牙协议栈，无中间层

## 依赖安装

### Python 蓝牙库

```bash
# Ubuntu/Debian
sudo apt-get install -y python3 python3-pip python3-bluez

# 或使用 pip 安装
pip3 install pybluez
```

### 验证安装

```bash
python3 -c "import bluetooth; print('✅ PyBluez 已安装')"
```

## 工作原理

### 1. 连接流程

```dart
// Dart 启动 Python 进程
Process.start('python3', ['scripts/rfcomm_socket.py', MAC, CHANNEL])

// Python 创建 RFCOMM socket
sock = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
sock.connect((mac_address, channel))

// 双向数据传输
- Python stdout → Dart (接收数据)
- Dart stdin → Python (发送数据)
```

### 2. 数据流向

**接收数据：**
```
蓝牙设备 → RFCOMM Socket → Python stdout → Dart Process.stdout → 应用
```

**发送数据：**
```
应用 → Dart Process.stdin → Python stdin → RFCOMM Socket → 蓝牙设备
```

## 使用方法

### 在 Dart 中连接

```dart
final service = LinuxBluetoothSppService();
await service.connect(
  '48:08:EB:60:00:6A',  // MAC 地址
  deviceName: 'My Device',
  channel: 5,  // 可选，会自动 SDP 查询
);
```

### 发送数据

```dart
final data = Uint8List.fromList([0x01, 0x02, 0x03]);
await service.sendData(data);
```

### 接收数据

```dart
service.dataStream.listen((data) {
  print('收到数据: $data');
});
```

## Python 脚本说明

### rfcomm_socket.py

**功能：**
- 创建 RFCOMM socket 连接
- 双向数据转发（socket ↔ stdio）
- 错误处理和日志输出

**参数：**
```bash
python3 rfcomm_socket.py <MAC地址> <通道>
```

**示例：**
```bash
python3 scripts/rfcomm_socket.py 48:08:EB:60:00:6A 5
```

## 故障排查

### 1. Python 模块未安装

**错误：**
```
ModuleNotFoundError: No module named 'bluetooth'
```

**解决：**
```bash
sudo apt-get install python3-bluez
# 或
pip3 install pybluez
```

### 2. 权限问题

**错误：**
```
bluetooth.btcommon.BluetoothError: (13, 'Permission denied')
```

**解决：**
```bash
# 使用 sudo 运行应用
sudo jn-production-line
```

### 3. 设备未配对

**错误：**
```
bluetooth.btcommon.BluetoothError: (112, 'Host is down')
```

**解决：**
```bash
# 先配对设备
bluetoothctl pair <MAC>
bluetoothctl trust <MAC>
```

### 4. 通道号错误

**错误：**
```
bluetooth.btcommon.BluetoothError: (111, 'Connection refused')
```

**解决：**
- 让应用自动 SDP 查询通道（不指定 channel 参数）
- 或使用 `sdptool browse <MAC>` 手动查询正确通道

## 性能优化

### 1. 连接超时

```python
# 在 rfcomm_socket.py 中设置超时
sock.settimeout(10)  # 10秒超时
```

### 2. 缓冲区大小

```python
# 调整接收缓冲区
data = sock.recv(1024)  # 默认 1024 字节
```

### 3. 数据刷新

```python
# 确保数据立即发送
sock.sendall(data)
```

## 与其他平台对比

| 平台 | 实现方式 |
|------|---------|
| **Linux** | RFCOMM Socket (PyBluez) |
| **Windows** | flutter_blue_plus (BLE) 或 Win32 API |
| **macOS** | IOBluetooth Framework |
| **Android** | BluetoothSocket (Java) |
| **iOS** | ExternalAccessory Framework |

## 参考资料

- [PyBluez 文档](https://pybluez.readthedocs.io/)
- [BlueZ RFCOMM 协议](http://www.bluez.org/)
- [Bluetooth SPP Profile](https://www.bluetooth.com/specifications/specs/serial-port-profile-1-1/)

## 总结

RFCOMM Socket 是 Linux 上最可靠的蓝牙 SPP 通信方式：

✅ **简单** - 标准的 socket 编程模型
✅ **可靠** - 直接使用蓝牙协议栈
✅ **高效** - 无中间层，性能最优
✅ **稳定** - 无超时、无阻塞问题

这就是专业的蓝牙通信实现方式！🎉
