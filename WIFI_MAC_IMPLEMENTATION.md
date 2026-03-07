# 📡 WiFi MAC 地址读写实现

## 概述

已完成 WiFi MAC 地址的读取和写入功能实现，包括 GTP 命令创建、响应解析和自动化测试集成。

---

## 🔧 GTP 命令格式

### 命令码

- **CMD**: `0x04` (cmdControlWifi)
- **写入 OPT**: `0x04`
- **读取 OPT**: `0x03`

### 写入命令

```
CMD 0x04 + OPT 0x04 + 6字节MAC地址
```

**示例**:
```
写入 MAC: 48:08:EB:50:00:50
命令: [04 04 48 08 EB 50 00 50]
```

### 读取命令

```
CMD 0x04 + OPT 0x03
```

**示例**:
```
命令: [04 03]
```

### 响应格式

```
CMD 0x04 + 6字节MAC地址
```

**示例**:
```
响应: [04 48 08 EB 50 00 50]
解析: 48:08:EB:50:00:50
```

---

## 📝 实现文件

### 1. `lib/services/production_test_commands.dart`

#### 新增方法

##### `createWiFiMACCommand(int opt, List<int> macBytes)`

创建 WiFi MAC 命令。

**参数**:
- `opt`: 操作码
  - `0x04`: 写入 WiFi MAC 地址
  - `0x03`: 读取 WiFi MAC 地址
- `macBytes`: MAC 地址字节数组（6字节），仅写入时需要

**返回**: `Uint8List` - GTP 命令字节数组

**示例**:
```dart
// 写入
final macBytes = [0x48, 0x08, 0xEB, 0x50, 0x00, 0x50];
final writeCmd = ProductionTestCommands.createWiFiMACCommand(0x04, macBytes);
// 结果: [04 04 48 08 EB 50 00 50]

// 读取
final readCmd = ProductionTestCommands.createWiFiMACCommand(0x03, []);
// 结果: [04 03]
```

##### `parseWiFiMACResponse(Uint8List payload)`

解析 WiFi MAC 响应。

**参数**:
- `payload`: 响应 payload

**返回**: `String?` - MAC 地址字符串（格式: `XX:XX:XX:XX:XX:XX`）

**示例**:
```dart
final payload = Uint8List.fromList([0x04, 0x48, 0x08, 0xEB, 0x50, 0x00, 0x50]);
final mac = ProductionTestCommands.parseWiFiMACResponse(payload);
// 结果: "48:08:EB:50:00:50"
```

---

### 2. `lib/models/test_state.dart`

#### 新增测试方法

##### `_autoTestWiFiMACWrite()`

WiFi MAC 地址写入测试。

**流程**:
1. 检查设备标识中是否有 WiFi MAC 地址
2. 将 MAC 地址字符串转换为字节数组
3. 创建写入命令 (CMD 0x04 + OPT 0x04 + 6字节MAC)
4. 发送命令并等待响应
5. 验证响应是否成功

**日志示例**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 开始WiFi MAC地址写入
📡 写入WiFi MAC: 48:08:EB:50:00:50
📤 发送WiFi MAC写入命令: [04 04 48 08 EB 50 00 50]
✅ WiFi MAC地址写入成功
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

##### `_autoTestWiFiMACRead()`

WiFi MAC 地址读取测试。

**流程**:
1. 检查设备标识中是否有 WiFi MAC 地址
2. 创建读取命令 (CMD 0x04 + OPT 0x03)
3. 发送命令并等待响应
4. 解析响应中的 MAC 地址
5. 对比读取值与期望值

**日志示例**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📖 开始WiFi MAC地址读取
📡 期望的WiFi MAC: 48:08:EB:50:00:50
📤 发送WiFi MAC读取命令: [04 03]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📡 WiFi MAC地址对比:
   写入的MAC: 48:08:EB:50:00:50
   读取的MAC: 48:08:EB:50:00:50
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ WiFi MAC地址读取成功，验证通过
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 🔄 测试序列集成

WiFi MAC 读写已集成到自动化测试序列中：

```
8.  产测开始
9.  SN码读取
10. SN码写入
11. 蓝牙MAC写入
12. 蓝牙MAC读取
13. WiFi MAC写入      ← 新增
14. WiFi MAC读取      ← 新增
15. 硬件版本号写入
16. 硬件版本号读取
...
```

---

## 📊 数据流程

### 完整流程

```
生成设备标识
    ↓
获取 WiFi MAC: 48:08:EB:50:00:50
    ↓
转换为字节: [0x48, 0x08, 0xEB, 0x50, 0x00, 0x50]
    ↓
创建写入命令: [04 04 48 08 EB 50 00 50]
    ↓
发送命令
    ↓
等待响应
    ↓
写入成功
    ↓
创建读取命令: [04 03]
    ↓
发送命令
    ↓
接收响应: [04 48 08 EB 50 00 50]
    ↓
解析 MAC: 48:08:EB:50:00:50
    ↓
对比验证
    ↓
验证通过 ✅
```

---

## 🎯 关键代码

### 命令创建

```dart
// 写入命令
static Uint8List createWiFiMACCommand(int opt, List<int> macBytes) {
  if (opt == 0x04) {
    // 写入WiFi MAC地址：CMD 0x04 + OPT 0x04 + 6字节MAC
    if (macBytes.length != 6) {
      throw ArgumentError('WiFi MAC地址必须是6字节');
    }
    final command = Uint8List(8);
    command[0] = cmdControlWifi; // 0x04
    command[1] = opt; // 0x04
    for (int i = 0; i < 6; i++) {
      command[2 + i] = macBytes[i];
    }
    return command;
  } else if (opt == 0x03) {
    // 读取WiFi MAC地址：CMD 0x04 + OPT 0x03
    final command = Uint8List(2);
    command[0] = cmdControlWifi; // 0x04
    command[1] = opt; // 0x03
    return command;
  } else {
    throw ArgumentError('无效的WiFi MAC操作码: $opt (应为0x03或0x04)');
  }
}
```

### 响应解析

```dart
static String? parseWiFiMACResponse(Uint8List payload) {
  if (payload.isEmpty || payload[0] != cmdControlWifi) {
    return null;
  }
  
  if (payload.length >= 7) {
    // 提取6字节MAC地址
    final macBytes = payload.sublist(1, 7);
    return macBytes
        .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
        .join(':');
  }
  
  return null;
}
```

### MAC 地址转换

```dart
// 字符串转字节数组
final wifiMacString = "48:08:EB:50:00:50";
final macParts = wifiMacString.split(':');
final macBytes = macParts.map((part) => int.parse(part, radix: 16)).toList();
// 结果: [0x48, 0x08, 0xEB, 0x50, 0x00, 0x50]
```

---

## ✅ 测试验证

### 写入测试

**输入**:
- WiFi MAC: `48:08:EB:50:00:50`

**命令**:
```
[04 04 48 08 EB 50 00 50]
```

**期望响应**:
- 成功响应（无错误）

### 读取测试

**命令**:
```
[04 03]
```

**期望响应**:
```
[04 48 08 EB 50 00 50]
```

**解析结果**:
```
48:08:EB:50:00:50
```

**验证**:
- 读取值 == 写入值 ✅

---

## 🔍 错误处理

### 错误类型

| 错误 | 原因 | 处理 |
|------|------|------|
| **WiFi MAC地址未生成** | 设备标识未初始化 | 提示先生成设备标识 |
| **WiFi MAC地址格式错误** | MAC 字符串格式不正确 | 返回失败 |
| **写入失败** | 设备无响应或返回错误 | 记录错误并返回失败 |
| **读取失败** | 设备无响应或返回错误 | 记录错误并返回失败 |
| **响应格式错误** | Payload 格式不符合预期 | 记录错误并返回失败 |
| **MAC地址不匹配** | 读取值与写入值不一致 | 记录详细对比并返回失败 |

### 错误日志示例

```
❌ WiFi MAC地址未生成
   提示：请先生成设备标识
```

```
❌ WiFi MAC地址不匹配
   写入的MAC: 48:08:EB:50:00:50
   读取的MAC: 48:08:EB:50:00:51
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 📋 与蓝牙 MAC 的对比

| 特性 | 蓝牙 MAC | WiFi MAC |
|------|----------|----------|
| **CMD** | `0x0D` | `0x04` |
| **写入 OPT** | `0x00` | `0x04` |
| **读取 OPT** | `0x01` | `0x03` |
| **命令长度（写入）** | 8 字节 | 8 字节 |
| **命令长度（读取）** | 2 字节 | 2 字节 |
| **响应格式** | CMD + 6字节MAC | CMD + 6字节MAC |
| **MAC 范围** | `48:08:EB:60:00:50` ~ `48:08:EB:6F:FF:FF` | `48:08:EB:50:00:50` ~ `48:08:EB:5F:FF:FF` |

---

## 🎯 使用示例

### 手动测试

```dart
// 1. 生成设备标识
await testState.generateDeviceIdentity();

// 2. 写入 WiFi MAC
final writeResult = await testState._autoTestWiFiMACWrite();
print('写入结果: $writeResult');

// 3. 读取 WiFi MAC
final readResult = await testState._autoTestWiFiMACRead();
print('读取结果: $readResult');
```

### 自动化测试

WiFi MAC 读写会在自动化测试序列中自动执行：

```dart
await testState.startAutoTest();
```

测试顺序：
1. 产测开始
2. SN 码读取
3. SN 码写入
4. 蓝牙 MAC 写入
5. 蓝牙 MAC 读取
6. **WiFi MAC 写入** ← 自动执行
7. **WiFi MAC 读取** ← 自动执行
8. 硬件版本号写入
9. 硬件版本号读取
10. 其他功能测试...

---

## 📌 注意事项

### 1. **前置条件**

WiFi MAC 读写测试需要：
- ✅ 已生成设备标识 (`_currentDeviceIdentity`)
- ✅ 设备标识中包含 `wifiMac` 字段
- ✅ 设备已连接并处于产测模式

### 2. **MAC 地址格式**

- **字符串格式**: `XX:XX:XX:XX:XX:XX` (大写，冒号分隔)
- **字节数组**: `[0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX]`
- **长度**: 固定 6 字节

### 3. **命令超时**

- 默认超时: 5 秒
- 如果设备响应慢，可以调整 `timeout` 参数

### 4. **错误重试**

当前实现不包含自动重试，如需重试：
- 在自动化测试中会根据配置重试
- 手动测试需要手动重新执行

---

## 🔗 相关文档

- **测试序列**: `TEST_SEQUENCE_UPDATE.md`
- **SN 管理**: `SN_MANAGEMENT.md`
- **蓝牙名称**: `BLUETOOTH_NAME_RULE.md`
- **GTP 命令**: `lib/services/production_test_commands.dart`

---

## 总结

✅ **已完成**:
1. WiFi MAC 命令创建方法 (`createWiFiMACCommand`)
2. WiFi MAC 响应解析方法 (`parseWiFiMACResponse`)
3. WiFi MAC 写入测试 (`_autoTestWiFiMACWrite`)
4. WiFi MAC 读取测试 (`_autoTestWiFiMACRead`)
5. 集成到自动化测试序列

✅ **命令格式**:
- 写入: `CMD 0x04 + OPT 0x04 + 6字节MAC`
- 读取: `CMD 0x04 + OPT 0x03`
- 响应: `CMD 0x04 + 6字节MAC`

✅ **测试流程**:
```
生成标识 → 写入MAC → 读取MAC → 验证对比 → 通过 ✅
```

WiFi MAC 地址读写功能已完整实现并集成到生产测试流程中！🎉
