# SPP 蓝牙连接说明

## 概述

本项目使用 **Serial Port Profile (SPP)** 进行经典蓝牙通信，用于产测设备的数据传输。

## SPP 连接原理

### 1. 什么是 SPP？

**Serial Port Profile (SPP)** 是蓝牙协议栈中的一个配置文件，用于在蓝牙设备之间模拟串口通信。

- **标准 UUID**: `00001101-0000-1000-8000-00805F9B34FB`
- **传输协议**: RFCOMM (基于 L2CAP)
- **用途**: 串口数据传输、无线串口替代

### 2. RFCOMM 通道

RFCOMM 是蓝牙协议栈中的一个层，提供类似 RS-232 串口的通信接口。

- **通道范围**: 1-30 (理论上最多支持 30 个并发连接)
- **实际限制**: Android 设备通常支持最多 7 个蓝牙连接
- **动态分配**: 通道号由设备的 SDP 服务器动态分配

### 3. SDP (Service Discovery Protocol)

SDP 是蓝牙设备用来发布和查询服务的协议。

**连接流程：**
```
客户端                          服务端
  |                               |
  |------ SDP 查询 (SPP UUID) --->|
  |                               |
  |<----- 返回 RFCOMM 通道号 -----|
  |                               |
  |------ 连接到 RFCOMM 通道 ----->|
  |                               |
  |<===== 建立 SPP 连接 =========>|
```

## 使用的库

### Android: `flutter_bluetooth_serial`

```dart
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

// 连接到设备 - 自动处理 SDP 查询和 RFCOMM 连接
BluetoothConnection connection = await BluetoothConnection.toAddress(address);
```

**特点：**
- ✅ 自动通过 SDP 查找 SPP 服务
- ✅ 自动连接到正确的 RFCOMM 通道
- ✅ 不需要手动指定 UUID 或通道号
- ❌ 当前版本不支持指定自定义 UUID
- ❌ 仅支持标准 SPP 服务

### Windows: `flutter_bluetooth_classic_serial`

```dart
import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart';

// 连接到已配对的设备
final bluetoothClassic = FlutterBluetoothClassic();
await bluetoothClassic.connect(deviceAddress);
```

**特点：**
- ✅ 支持 Windows 平台
- ✅ 使用系统配对的设备
- ✅ 自动处理 SPP 连接
- ❌ 需要在系统设置中预先配对设备

## 常见问题

### Q1: 为什么不需要指定 channel 或 UUID？

**A:** `BluetoothConnection.toAddress()` 内部实现了完整的 SPP 连接流程：

1. 发送 SDP 查询请求，查找 SPP 服务 (UUID: 00001101-...)
2. 从 SDP 响应中获取 RFCOMM 通道号
3. 使用获取的通道号建立 RFCOMM 连接
4. 返回可用的连接对象

这个过程是**自动的、透明的**，开发者不需要手动处理。

### Q2: 如果设备使用非标准 SPP UUID 怎么办？

**A:** 当前版本的 `flutter_bluetooth_serial` 不支持指定自定义 UUID。

**解决方案：**
1. 等待库更新 (参考 GitHub issue #41)
2. 使用其他支持自定义 UUID 的蓝牙库
3. 修改设备固件，使用标准 SPP UUID

### Q3: 连接失败的常见原因？

**可能原因：**
1. **设备未提供 SPP 服务**
   - 检查设备是否支持 SPP
   - 使用蓝牙扫描工具查看设备的服务列表

2. **设备未配对**
   - Android: 需要先配对设备
   - Windows: 必须在系统设置中配对

3. **RFCOMM 通道不可用**
   - 设备可能已经有其他连接
   - 重启设备或断开其他连接

4. **权限问题**
   - 确保应用有蓝牙权限
   - Android 12+ 需要 BLUETOOTH_CONNECT 权限

### Q4: 如何验证设备支持 SPP？

**方法 1: 使用 Android 蓝牙扫描工具**
```
nRF Connect for Mobile
Bluetooth Scanner
```

**方法 2: 查看设备文档**
- 查找 "SPP" 或 "Serial Port Profile"
- 查找 UUID: 00001101-0000-1000-8000-00805F9B34FB

**方法 3: 代码测试**
```dart
try {
  final connection = await BluetoothConnection.toAddress(address);
  print('设备支持 SPP');
  await connection.close();
} catch (e) {
  print('设备不支持 SPP 或连接失败: $e');
}
```

## 技术细节

### RFCOMM 帧结构

```
+--------+--------+--------+--------+
| Address| Control| Length | Data   |
| (1字节)| (1字节)| (1-2字节)|(0-N字节)|
+--------+--------+--------+--------+
```

### SPP 数据传输

```dart
// 发送数据
connection.output.add(Uint8List.fromList([0x01, 0x02, 0x03]));
await connection.output.allSent;

// 接收数据
connection.input.listen((Uint8List data) {
  print('收到数据: $data');
});
```

### 连接状态管理

```dart
// 检查连接状态
if (connection.isConnected) {
  // 连接正常
}

// 监听断开事件
connection.input.listen(
  (data) { /* 处理数据 */ },
  onDone: () {
    print('连接已断开');
  },
  onError: (error) {
    print('连接错误: $error');
  },
);
```

## 参考资料

- [Bluetooth SPP Specification](https://www.bluetooth.com/specifications/specs/serial-port-profile-1-1/)
- [flutter_bluetooth_serial GitHub](https://github.com/edufolly/flutter_bluetooth_serial)
- [RFCOMM Protocol](https://www.bluetooth.com/specifications/specs/rfcomm-1-1/)
- [SDP Protocol](https://www.bluetooth.com/specifications/specs/service-discovery-protocol-1-2/)

## 总结

- ✅ SPP 连接**不需要**手动指定 channel 或 RFCOMM 通道
- ✅ `BluetoothConnection.toAddress()` **自动处理** SDP 查询和通道连接
- ✅ 只需要提供设备的 **MAC 地址**即可
- ⚠️ 设备必须支持**标准 SPP 服务** (UUID: 00001101-...)
- ⚠️ 当前版本**不支持**自定义 UUID 或非标准服务
