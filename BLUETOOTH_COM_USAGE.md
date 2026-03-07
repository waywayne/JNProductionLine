# 📱 蓝牙 COM 口通讯使用指南

## 概述

`BluetoothComService` 是一个专门用于通过蓝牙虚拟 COM 口与设备通讯的服务类。

### 优势

相比 Python 蓝牙 SPP 方式：

| 特性 | Python 蓝牙 SPP | 蓝牙 COM 口 |
|------|----------------|-------------|
| 可靠性 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 速度 | 慢 | 快 |
| 配置复杂度 | 高（需要查找 Channel） | 低（自动配置） |
| Windows 兼容性 | 一般 | 优秀 |
| 依赖 | PyBluez | 无（系统原生） |
| 稳定性 | 一般 | 优秀 |

---

## 前提条件

### 1. 蓝牙设备已配对

在 Windows 设置中配对蓝牙设备：

```
设置 → 蓝牙和其他设备 → 添加蓝牙或其他设备 → 蓝牙
```

### 2. 确认 COM 口已创建

配对成功后，Windows 会自动创建虚拟 COM 口。

**查看方法**：

```
设备管理器 → 端口 (COM 和 LPT)
```

查找类似以下的设备：
- `Standard Serial over Bluetooth link (COM3)`
- `Kanaan-00KX (COM5)`
- 或任何包含蓝牙的 COM 端口

---

## 快速开始

### 1. 导入服务

```dart
import 'package:jn_production_line/services/bluetooth_com_service.dart';
```

### 2. 创建服务实例

```dart
final bluetoothComService = BluetoothComService();
bluetoothComService.setLogState(logState);
```

### 3. 查找蓝牙 COM 口

```dart
// 方法 1: 查找所有蓝牙 COM 口
final bluetoothPorts = BluetoothComService.findBluetoothComPorts();
print('找到蓝牙 COM 口: $bluetoothPorts');

// 方法 2: 查看所有可用端口
final allPorts = BluetoothComService.getAvailablePorts();
print('所有可用端口: $allPorts');

// 方法 3: 查看端口详细信息
for (final port in allPorts) {
  final info = BluetoothComService.getPortInfo(port);
  print('端口: ${info['name']}');
  print('  描述: ${info['description']}');
  print('  制造商: ${info['manufacturer']}');
}
```

### 4. 连接到蓝牙 COM 口

```dart
// 连接到 COM3，使用默认波特率 115200
final success = await bluetoothComService.connect('COM3');

if (success) {
  print('✅ 连接成功');
} else {
  print('❌ 连接失败');
}
```

### 5. 发送 GTP 命令

```dart
// 读取蓝牙 MAC 地址
final commandPayload = Uint8List.fromList([0x0D, 0x01]);

final response = await bluetoothComService.sendGTPCommand(
  commandPayload,
  timeout: Duration(seconds: 5),
);

if (response != null) {
  print('✅ 收到响应: $response');
} else {
  print('❌ 未收到响应');
}
```

### 6. 测试读取蓝牙 MAC 地址

```dart
final macAddress = await bluetoothComService.testReadBluetoothMAC();

if (macAddress != null) {
  print('✅ 蓝牙 MAC 地址: $macAddress');
} else {
  print('❌ 读取失败');
}
```

### 7. 断开连接

```dart
await bluetoothComService.disconnect();
```

---

## 完整示例

### 示例 1: 基本使用

```dart
import 'package:jn_production_line/services/bluetooth_com_service.dart';
import 'dart:typed_data';

Future<void> testBluetoothCom() async {
  final service = BluetoothComService();
  
  try {
    // 1. 查找蓝牙 COM 口
    print('查找蓝牙 COM 口...');
    final bluetoothPorts = BluetoothComService.findBluetoothComPorts();
    
    if (bluetoothPorts.isEmpty) {
      print('❌ 未找到蓝牙 COM 口');
      print('   请确保蓝牙设备已配对并连接');
      return;
    }
    
    print('✅ 找到蓝牙 COM 口: $bluetoothPorts');
    
    // 2. 连接到第一个蓝牙 COM 口
    final portName = bluetoothPorts.first;
    print('连接到 $portName...');
    
    final success = await service.connect(portName);
    
    if (!success) {
      print('❌ 连接失败');
      return;
    }
    
    print('✅ 连接成功');
    
    // 3. 测试读取蓝牙 MAC 地址
    print('读取蓝牙 MAC 地址...');
    final macAddress = await service.testReadBluetoothMAC();
    
    if (macAddress != null) {
      print('✅ 蓝牙 MAC 地址: $macAddress');
    } else {
      print('❌ 读取失败');
    }
    
    // 4. 断开连接
    await service.disconnect();
    print('✅ 已断开连接');
    
  } catch (e) {
    print('❌ 错误: $e');
  }
}
```

### 示例 2: 在 TestState 中使用

```dart
class TestState extends ChangeNotifier {
  final BluetoothComService _bluetoothComService = BluetoothComService();
  
  // 初始化
  void initBluetoothComService() {
    _bluetoothComService.setLogState(_logState);
  }
  
  // 测试蓝牙 COM 口
  Future<bool> testBluetoothCom({String? portName}) async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('📱 开始蓝牙 COM 口测试');
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // 如果没有指定端口，自动查找
      String? targetPort = portName;
      if (targetPort == null) {
        _logState?.info('🔍 查找蓝牙 COM 口...');
        final bluetoothPorts = BluetoothComService.findBluetoothComPorts();
        
        if (bluetoothPorts.isEmpty) {
          _logState?.error('❌ 未找到蓝牙 COM 口');
          _logState?.info('   建议:');
          _logState?.info('   1. 在 Windows 设置中配对蓝牙设备');
          _logState?.info('   2. 确保蓝牙设备已连接');
          _logState?.info('   3. 在设备管理器中查看 COM 口');
          return false;
        }
        
        targetPort = bluetoothPorts.first;
        _logState?.success('✅ 找到蓝牙 COM 口: $targetPort');
      }
      
      // 连接
      _logState?.info('📡 连接到 $targetPort...');
      final success = await _bluetoothComService.connect(targetPort);
      
      if (!success) {
        _logState?.error('❌ 连接失败');
        return false;
      }
      
      // 测试读取蓝牙 MAC 地址
      _logState?.info('📖 测试读取蓝牙 MAC 地址...');
      final macAddress = await _bluetoothComService.testReadBluetoothMAC();
      
      if (macAddress == null) {
        _logState?.error('❌ 读取失败');
        await _bluetoothComService.disconnect();
        return false;
      }
      
      _logState?.success('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.success('✅ 蓝牙 COM 口测试成功');
      _logState?.success('   端口: $targetPort');
      _logState?.success('   MAC 地址: $macAddress');
      _logState?.success('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // 断开连接
      await _bluetoothComService.disconnect();
      
      return true;
      
    } catch (e) {
      _logState?.error('❌ 测试失败: $e');
      return false;
    }
  }
  
  @override
  void dispose() {
    _bluetoothComService.dispose();
    super.dispose();
  }
}
```

---

## API 参考

### 静态方法

#### `getAvailablePorts()`

获取所有可用的串口（包括蓝牙 COM 口）。

```dart
List<String> ports = BluetoothComService.getAvailablePorts();
// 返回: ['COM1', 'COM3', 'COM5', ...]
```

#### `findBluetoothComPorts()`

查找所有蓝牙 COM 口。

```dart
List<String> bluetoothPorts = BluetoothComService.findBluetoothComPorts();
// 返回: ['COM3', 'COM5', ...]
```

#### `getPortInfo(String portName)`

获取端口详细信息。

```dart
Map<String, String> info = BluetoothComService.getPortInfo('COM3');
// 返回:
// {
//   'name': 'COM3',
//   'description': 'Standard Serial over Bluetooth link',
//   'manufacturer': 'Microsoft',
//   'serialNumber': '...',
//   'productId': '...',
//   'vendorId': '...',
// }
```

### 实例方法

#### `connect(String portName, {...})`

连接到蓝牙 COM 口。

**参数**：
- `portName`: COM 口名称，如 `'COM3'`
- `baudRate`: 波特率，默认 `115200`
- `dataBits`: 数据位，默认 `8`
- `stopBits`: 停止位，默认 `1`
- `parity`: 校验位，默认 `SerialPortParity.none`
- `useDualLineUartInit`: 是否使用双线 UART 初始化，默认 `false`

**返回**: `Future<bool>` - 连接是否成功

```dart
final success = await service.connect(
  'COM3',
  baudRate: 115200,
  useDualLineUartInit: false,
);
```

#### `sendGTPCommand(Uint8List commandPayload, {...})`

发送 GTP 命令并等待响应。

**参数**：
- `commandPayload`: 命令负载数据
- `moduleId`: 模块 ID，默认 `0x0000`
- `messageId`: 消息 ID，默认 `0x0000`
- `timeout`: 超时时间，默认 `5 秒`

**返回**: `Future<Map<String, dynamic>?>` - 响应数据或 `null`

```dart
final response = await service.sendGTPCommand(
  Uint8List.fromList([0x0D, 0x01]),
  timeout: Duration(seconds: 5),
);
```

#### `testReadBluetoothMAC({...})`

测试读取蓝牙 MAC 地址。

**参数**：
- `timeout`: 超时时间，默认 `5 秒`

**返回**: `Future<String?>` - MAC 地址或 `null`

```dart
final macAddress = await service.testReadBluetoothMAC();
// 返回: '48:08:EB:60:00:00' 或 null
```

#### `disconnect()`

断开连接。

```dart
await service.disconnect();
```

#### `dispose()`

清理资源。

```dart
service.dispose();
```

### 属性

#### `isConnected`

是否已连接。

```dart
bool connected = service.isConnected;
```

#### `currentPortName`

当前端口名称。

```dart
String? portName = service.currentPortName;
```

#### `dataStream`

数据流（用于监听原始数据）。

```dart
Stream<Uint8List> stream = service.dataStream;
```

---

## 常见问题

### Q1: 找不到蓝牙 COM 口？

**A**: 请确保：
1. 蓝牙设备已在 Windows 设置中配对
2. 蓝牙设备已连接（状态显示"已连接"）
3. 在设备管理器中查看是否有蓝牙 COM 口

### Q2: 连接失败？

**A**: 可能原因：
1. COM 口被其他程序占用
2. 蓝牙设备已断开连接
3. 权限不足
4. 驱动未安装

### Q3: 波特率应该设置多少？

**A**: 蓝牙 SPP 常用波特率：
- **115200**（推荐，最常用）
- 9600
- 57600
- 230400

### Q4: 需要双线 UART 初始化吗？

**A**: 通常不需要。
- 蓝牙 COM 口：`useDualLineUartInit: false`（默认）
- 物理串口：`useDualLineUartInit: true`

### Q5: 如何监听原始数据？

**A**: 使用 `dataStream`：

```dart
service.dataStream.listen((data) {
  print('收到数据: ${data.length} bytes');
  print('Hex: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
});
```

---

## 最佳实践

### 1. 自动查找蓝牙 COM 口

```dart
final bluetoothPorts = BluetoothComService.findBluetoothComPorts();
if (bluetoothPorts.isNotEmpty) {
  await service.connect(bluetoothPorts.first);
}
```

### 2. 显示端口选择列表

```dart
final allPorts = BluetoothComService.getAvailablePorts();
for (final port in allPorts) {
  final info = BluetoothComService.getPortInfo(port);
  print('${info['name']}: ${info['description']}');
}
```

### 3. 错误处理

```dart
try {
  final success = await service.connect('COM3');
  if (!success) {
    // 处理连接失败
  }
} catch (e) {
  // 处理异常
  print('错误: $e');
}
```

### 4. 资源清理

```dart
@override
void dispose() {
  service.dispose();
  super.dispose();
}
```

---

## 性能对比

### 连接速度

| 方式 | 平均时间 |
|------|----------|
| Python 蓝牙 SPP（智能连接） | 3-9 秒 |
| 蓝牙 COM 口 | < 1 秒 |

### 数据传输

| 方式 | 延迟 | 稳定性 |
|------|------|--------|
| Python 蓝牙 SPP | 较高 | 一般 |
| 蓝牙 COM 口 | 低 | 优秀 |

---

## 总结

### ✅ 优点

1. **简单易用**：无需查找 RFCOMM Channel
2. **稳定可靠**：Windows 原生支持
3. **速度快**：连接和数据传输都更快
4. **无依赖**：不需要 Python 和 PyBluez

### 🎯 推荐使用场景

- ✅ Windows 平台蓝牙通讯
- ✅ 需要稳定可靠的连接
- ✅ 需要快速连接和数据传输
- ✅ 生产环境部署

### 📊 与其他方式对比

| 方式 | 推荐度 | 适用场景 |
|------|--------|----------|
| **蓝牙 COM 口** | ⭐⭐⭐⭐⭐ | Windows 平台首选 |
| Python 蓝牙 SPP | ⭐⭐⭐ | 跨平台开发、调试 |
| 物理串口 | ⭐⭐⭐⭐⭐ | 有线连接、最稳定 |
