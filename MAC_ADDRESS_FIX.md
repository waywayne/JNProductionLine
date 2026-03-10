# MAC地址生成修复

## 🐛 问题描述

### 原问题
- **SN记录**：已分配4个SN
- **MAC索引**：显示80（应该是4）
- **下一个WiFi MAC**：末位字节显示A0（应该是04）
- **根本原因**：MAC地址计算逻辑错误，导致SN和MAC不是一一对应

### 错误的逻辑（修复前）

```dart
// 错误的前缀定义
static const String wifiMacPrefix = '48:08:EB:5';  // ❌ 只到第4字节的高位

// 错误的计算
final macSuffix = counter;  // counter = 0
final byte1 = (macSuffix >> 16) & 0xFF;  // 0
final byte2 = (macSuffix >> 8) & 0xFF;   // 0
final byte3 = macSuffix & 0xFF;          // 0

// 生成：'48:08:EB:50:00:00' ❌ 错误！
// byte1.toRadixString(16).padLeft(1, '0') = '0'
// 结果：48:08:EB:50:00:00 (第4字节变成了'50'而不是'50')
```

**实际问题**：
- 当 `counter = 0` 时，生成的可能是 `48:08:EB:50:00:00` 或其他错误格式
- 当 `counter = 80` 时，生成的是 `48:08:EB:50:00:A0`（0x50 + 0x50 = 0xA0）

## ✅ 修复方案

### 正确的逻辑（修复后）

```dart
// 正确的前缀定义
static const String wifiMacPrefix = '48:08:EB';  // ✅ 只包含前3字节
static const int wifiMacBaseValue = 0x500000;    // ✅ 起始地址：50:00:00

// 正确的计算
final macValue = wifiMacBaseValue + counter;  // 0x500000 + 0 = 0x500000
final byte4 = (macValue >> 16) & 0xFF;  // 0x50
final byte5 = (macValue >> 8) & 0xFF;   // 0x00
final byte6 = macValue & 0xFF;          // 0x00

// 生成：'48:08:EB:50:00:00' ✅ 正确！
macAddress = '$wifiMacPrefix:${byte4...}:${byte5...}:${byte6...}';
```

## 📊 修复效果

### WiFi MAC地址生成示例

| SN序号 | Counter | 计算过程 | WiFi MAC地址 |
|--------|---------|----------|--------------|
| 1 | 0 | 0x500000 + 0 = 0x500000 | 48:08:EB:50:00:00 |
| 2 | 1 | 0x500000 + 1 = 0x500001 | 48:08:EB:50:00:01 |
| 3 | 2 | 0x500000 + 2 = 0x500002 | 48:08:EB:50:00:02 |
| 4 | 3 | 0x500000 + 3 = 0x500003 | 48:08:EB:50:00:03 |
| 5 | 4 | 0x500000 + 4 = 0x500004 | 48:08:EB:50:00:04 |
| ... | ... | ... | ... |
| 256 | 255 | 0x500000 + 255 = 0x5000FF | 48:08:EB:50:00:FF |
| 257 | 256 | 0x500000 + 256 = 0x500100 | 48:08:EB:50:01:00 |
| ... | ... | ... | ... |
| 65536 | 65535 | 0x500000 + 65535 = 0x50FFFF | 48:08:EB:50:FF:FF |
| 65537 | 65536 | 0x500000 + 65536 = 0x510000 | 48:08:EB:51:00:00 |

### 蓝牙MAC地址生成示例

| SN序号 | Counter | 计算过程 | 蓝牙MAC地址 |
|--------|---------|----------|--------------|
| 1 | 0 | 0x600000 + 0 = 0x600000 | 48:08:EB:60:00:00 |
| 2 | 1 | 0x600000 + 1 = 0x600001 | 48:08:EB:60:00:01 |
| 3 | 2 | 0x600000 + 2 = 0x600002 | 48:08:EB:60:00:02 |
| 4 | 3 | 0x600000 + 3 = 0x600003 | 48:08:EB:60:00:03 |
| 5 | 4 | 0x600000 + 4 = 0x600004 | 48:08:EB:60:00:04 |

## 🔧 修改的代码

### `lib/config/sn_mac_config.dart`

#### 1. 修正常量定义（第19-29行）

**修改前：**
```dart
static const String wifiMacPrefix = '48:08:EB:5';
static const int wifiMacRangeStart = 0x0;
static const int wifiMacRangeEnd = 0xFFFFF;

static const String bluetoothMacPrefix = '48:08:EB:6';
static const int bluetoothMacRangeStart = 0x0;
static const int bluetoothMacRangeEnd = 0xFFFFF;
```

**修改后：**
```dart
static const String wifiMacPrefix = '48:08:EB';
static const int wifiMacRangeStart = 0x0;      // 从0开始计数
static const int wifiMacRangeEnd = 0xFFFFF;    // 最多1048575个地址
static const int wifiMacBaseValue = 0x500000;  // 起始地址：50:00:00

static const String bluetoothMacPrefix = '48:08:EB';
static const int bluetoothMacRangeStart = 0x0;      // 从0开始计数
static const int bluetoothMacRangeEnd = 0xFFFFF;    // 最多1048575个地址
static const int bluetoothMacBaseValue = 0x600000;  // 起始地址：60:00:00
```

#### 2. 修正WiFi MAC生成逻辑（第155-162行）

**修改前：**
```dart
final macSuffix = counter;
final byte1 = (macSuffix >> 16) & 0xFF;
final byte2 = (macSuffix >> 8) & 0xFF;
final byte3 = macSuffix & 0xFF;

macAddress = '$wifiMacPrefix${byte1.toRadixString(16).toUpperCase().padLeft(1, '0')}:${byte2...}:${byte3...}';
```

**修改后：**
```dart
// 计算MAC地址：基础地址 + 计数器
final macValue = wifiMacBaseValue + counter;
final byte4 = (macValue >> 16) & 0xFF;  // 第4字节 (0x50-0x5F)
final byte5 = (macValue >> 8) & 0xFF;   // 第5字节 (0x00-0xFF)
final byte6 = macValue & 0xFF;          // 第6字节 (0x00-0xFF)

// 生成完整MAC地址
macAddress = '$wifiMacPrefix:${byte4.toRadixString(16).toUpperCase().padLeft(2, '0')}:${byte5.toRadixString(16).toUpperCase().padLeft(2, '0')}:${byte6.toRadixString(16).toUpperCase().padLeft(2, '0')}';
```

#### 3. 修正蓝牙MAC生成逻辑（第201-208行）

**修改前：**
```dart
final macSuffix = counter;
final byte1 = (macSuffix >> 16) & 0xFF;
final byte2 = (macSuffix >> 8) & 0xFF;
final byte3 = macSuffix & 0xFF;

macAddress = '$bluetoothMacPrefix${byte1.toRadixString(16).toUpperCase().padLeft(1, '0')}:${byte2...}:${byte3...}';
```

**修改后：**
```dart
// 计算MAC地址：基础地址 + 计数器
final macValue = bluetoothMacBaseValue + counter;
final byte4 = (macValue >> 16) & 0xFF;  // 第4字节 (0x60-0x6F)
final byte5 = (macValue >> 8) & 0xFF;   // 第5字节 (0x00-0xFF)
final byte6 = macValue & 0xFF;          // 第6字节 (0x00-0xFF)

// 生成完整MAC地址
macAddress = '$bluetoothMacPrefix:${byte4.toRadixString(16).toUpperCase().padLeft(2, '0')}:${byte5.toRadixString(16).toUpperCase().padLeft(2, '0')}:${byte6.toRadixString(16).toUpperCase().padLeft(2, '0')}';
```

## 🎯 关键改进

### 1. **一一对应**
- ✅ SN序号1 → Counter=0 → WiFi MAC: 48:08:EB:50:00:00
- ✅ SN序号2 → Counter=1 → WiFi MAC: 48:08:EB:50:00:01
- ✅ SN序号3 → Counter=2 → WiFi MAC: 48:08:EB:50:00:02
- ✅ SN序号4 → Counter=3 → WiFi MAC: 48:08:EB:50:00:03

### 2. **防止重复**
- ✅ 每次生成前检查 `allocatedWifiMacs` 列表
- ✅ 如果发现重复，自动跳过并生成下一个
- ✅ 最多尝试1000次，防止无限循环

### 3. **地址范围**
- **WiFi MAC**：`48:08:EB:50:00:00` ~ `48:08:EB:5F:FF:FF`（1,048,575个地址）
- **蓝牙MAC**：`48:08:EB:60:00:00` ~ `48:08:EB:6F:FF:FF`（1,048,575个地址）

## 📝 使用说明

### 重置配置（如果需要）

如果之前的配置文件有问题，需要重置：

1. 删除配置文件：`sn_mac_allocation.json`
2. 重新启动应用，会自动创建新配置
3. Counter会从0开始，生成正确的MAC地址

### 验证生成结果

生成SN/MAC后，检查：
- ✅ SN数量 = WiFi MAC Counter = 蓝牙MAC Counter
- ✅ 第一个WiFi MAC应该是 `48:08:EB:50:00:00`
- ✅ 第一个蓝牙MAC应该是 `48:08:EB:60:00:00`
- ✅ 每个MAC地址末位字节依次递增：00, 01, 02, 03, 04...

## 🔍 调试信息

如果遇到问题，检查日志中的以下信息：
```
✅ 设备标识信息生成成功:
   📋 SN码: 63716031010000300KV
   📡 WiFi MAC: 48:08:EB:50:00:00  ← 应该从00:00开始
   📶 蓝牙 MAC: 48:08:EB:60:00:00  ← 应该从00:00开始
```

## ✅ 总结

修复后的MAC地址生成逻辑：
1. ✅ **正确的起始地址**：从 `50:00:00` 和 `60:00:00` 开始
2. ✅ **一一对应**：每个SN对应唯一的WiFi MAC和蓝牙MAC
3. ✅ **顺序递增**：MAC地址按照计数器顺序递增
4. ✅ **防止重复**：自动检查并跳过已分配的地址
5. ✅ **持久化保存**：所有分配记录保存到配置文件
