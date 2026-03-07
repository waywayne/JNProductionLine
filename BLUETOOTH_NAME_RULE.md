# 📱 蓝牙名称命名规则

## 规则说明

蓝牙设备名称使用 **蓝牙 MAC 地址后四位** 生成。

---

## 命名格式

```
Kanaan-XXXX
```

其中 `XXXX` 为蓝牙 MAC 地址的后四位（十六进制）。

---

## 示例

### 示例 1

**蓝牙 MAC 地址**: `48:08:EB:60:00:50`

**处理步骤**:
1. 移除分隔符: `480BEB600050`
2. 取后四位: `0050`
3. 生成名称: `Kanaan-0050`

### 示例 2

**蓝牙 MAC 地址**: `48:08:EB:60:12:AB`

**处理步骤**:
1. 移除分隔符: `480BEB6012AB`
2. 取后四位: `12AB`
3. 生成名称: `Kanaan-12AB`

### 示例 3

**蓝牙 MAC 地址**: `48:08:EB:6F:FF:FF`

**处理步骤**:
1. 移除分隔符: `480BEB6FFFFF`
2. 取后四位: `FFFF`
3. 生成名称: `Kanaan-FFFF`

---

## 实现逻辑

### 代码位置

**文件**: `lib/models/test_state.dart`

**方法**: `_autoTestBluetooth()`

### 核心代码

```dart
// 获取蓝牙 MAC 地址
final bluetoothMac = _currentDeviceIdentity!['bluetoothMac']!;

// 移除分隔符并取后四位
final macClean = bluetoothMac.replaceAll(':', '').replaceAll('-', '');
final last4Digits = macClean.length >= 4 
    ? macClean.substring(macClean.length - 4) 
    : macClean;

// 生成蓝牙名称
_bluetoothNameToSet = 'Kanaan-$last4Digits';
```

---

## 优势

### 1. **唯一性**

- 每个蓝牙 MAC 地址都是唯一的
- 确保设备名称不会重复

### 2. **可追溯性**

- 通过蓝牙名称可以快速定位 MAC 地址
- 便于生产和售后管理

### 3. **简洁性**

- 名称长度固定（11个字符）
- 易于识别和记忆

### 4. **一致性**

- 与 MAC 地址直接关联
- 避免 SN 码变更导致的不一致

---

## 测试流程

### 自动化测试中的蓝牙名称设置

```
产测开始
    ↓
SN 码读取/写入
    ↓
蓝牙 MAC 写入/读取
    ↓
WiFi MAC 写入/读取
    ↓
硬件版本号写入/读取
    ↓
... 其他测试 ...
    ↓
蓝牙功能测试
    ├─ 1. 生成蓝牙名称（使用 MAC 后四位）
    ├─ 2. 设置蓝牙名称
    ├─ 3. 验证蓝牙名称
    └─ 4. 用户手机连接测试
```

### 详细步骤

#### 步骤 1: 生成蓝牙名称

```dart
// 检查蓝牙 MAC 地址是否存在
if (_currentDeviceIdentity == null || 
    _currentDeviceIdentity!['bluetoothMac'] == null) {
  // 错误：未找到蓝牙MAC地址
  return false;
}

// 生成名称
final bluetoothMac = _currentDeviceIdentity!['bluetoothMac']!;
final macClean = bluetoothMac.replaceAll(':', '').replaceAll('-', '');
final last4Digits = macClean.substring(macClean.length - 4);
_bluetoothNameToSet = 'Kanaan-$last4Digits';
```

#### 步骤 2: 设置蓝牙名称

```dart
// 发送设置命令
final setNameCmd = ProductionTestCommands.createSetBluetoothNameCommand(
  _bluetoothNameToSet!
);

final setResponse = await _serialService.sendCommandAndWaitResponse(
  setNameCmd,
  moduleId: ProductionTestCommands.moduleId,
  messageId: ProductionTestCommands.messageId,
  timeout: const Duration(seconds: 5),
);
```

#### 步骤 3: 验证蓝牙名称

```dart
// 读取设备蓝牙名称
final getNameCmd = ProductionTestCommands.createGetBluetoothNameCommand();
final getResponse = await _serialService.sendCommandAndWaitResponse(
  getNameCmd,
  moduleId: ProductionTestCommands.moduleId,
  messageId: ProductionTestCommands.messageId,
  timeout: const Duration(seconds: 5),
);

// 解析并验证
final actualName = ProductionTestCommands.parseBluetoothNameResponse(payload);
if (actualName != _bluetoothNameToSet) {
  // 名称不匹配
  return false;
}
```

#### 步骤 4: 用户手机连接测试

```dart
// 显示弹窗提示用户
_bluetoothTestStep = '请使用手机蓝牙搜索并连接设备\n设备名称: $_bluetoothNameToSet';
notifyListeners();

// 等待用户确认
// 用户点击"测试成功"按钮后继续
```

---

## MAC 地址范围与名称示例

### 蓝牙 MAC 地址范围

```
起始: 48:08:EB:60:00:50
结束: 48:08:EB:6F:FF:FF
```

### 名称示例

| 蓝牙 MAC 地址 | 后四位 | 蓝牙名称 |
|--------------|--------|----------|
| `48:08:EB:60:00:50` | `0050` | `Kanaan-0050` |
| `48:08:EB:60:00:51` | `0051` | `Kanaan-0051` |
| `48:08:EB:60:01:00` | `0100` | `Kanaan-0100` |
| `48:08:EB:60:FF:FF` | `FFFF` | `Kanaan-FFFF` |
| `48:08:EB:61:00:00` | `0000` | `Kanaan-0000` |
| `48:08:EB:6F:FF:FF` | `FFFF` | `Kanaan-FFFF` |

**注意**: 不同 MAC 段的后四位可能重复（如 `60:FF:FF` 和 `6F:FF:FF` 都是 `FFFF`），但完整 MAC 地址仍然唯一。

---

## 与 SN 码的关系

### 数据关联

虽然蓝牙名称使用 MAC 地址生成，但在数据库中，SN 码、蓝牙 MAC 和 WiFi MAC 仍然是关联的：

```json
{
  "sn": "6371512161000010000",
  "bluetooth_mac": "48:08:EB:60:00:50",
  "wifi_mac": "48:08:EB:50:00:50",
  "hardware_version": "1.0.0"
}
```

### 查询方式

可以通过以下任一方式查询设备：

1. **通过 SN 码**: `6371512161000010000`
2. **通过蓝牙名称**: `Kanaan-0050` → 推导出 MAC `48:08:EB:60:00:50`
3. **通过蓝牙 MAC**: `48:08:EB:60:00:50`

---

## 错误处理

### 错误 1: 未找到蓝牙 MAC 地址

**原因**: 
- 蓝牙 MAC 尚未写入
- 设备标识信息未初始化

**解决**:
```
确保在蓝牙测试前已完成：
1. SN 码读取/写入
2. 蓝牙 MAC 写入/读取
```

### 错误 2: MAC 地址格式错误

**原因**:
- MAC 地址格式不正确
- 包含非法字符

**解决**:
```dart
// 验证 MAC 地址格式
final macRegex = RegExp(r'^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$', 
                        caseSensitive: false);
if (!macRegex.hasMatch(bluetoothMac)) {
  // MAC 地址格式错误
}
```

### 错误 3: 名称设置失败

**原因**:
- 设备未响应
- 命令格式错误

**解决**:
```
1. 检查串口连接
2. 重试设置命令
3. 查看设备日志
```

---

## 日志示例

### 成功日志

```
📱 开始蓝牙测试
   蓝牙MAC: 48:08:EB:60:00:50
   蓝牙名称: Kanaan-0050 (使用MAC后四位)
📤 发送设置蓝牙名称命令: [0D 4B 61 6E 61 61 6E 2D 30 30 35 30 00]
✅ 蓝牙名称设置成功
📤 发送获取蓝牙名称命令
📥 收到蓝牙名称: Kanaan-0050
✅ 蓝牙名称验证成功
```

### 失败日志

```
📱 开始蓝牙测试
❌ 蓝牙测试失败：未找到蓝牙MAC地址
```

---

## 配置要求

### 前置条件

在蓝牙测试前，必须完成以下步骤：

1. ✅ **产测开始** (CMD 0x00)
2. ✅ **SN 码读取** (CMD 0xFD)
3. ✅ **SN 码写入** (CMD 0xFE) - 如果需要
4. ✅ **蓝牙 MAC 写入** (CMD 0x0D, OPT 0x01)
5. ✅ **蓝牙 MAC 读取** (CMD 0x0D, OPT 0x02)

### 数据准备

确保 `_currentDeviceIdentity` 包含：

```dart
{
  'sn': '6371512161000010000',
  'bluetoothMac': '48:08:EB:60:00:50',  // 必需
  'wifiMac': '48:08:EB:50:00:50',
  'hardwareVersion': '1.0.0'
}
```

---

## 总结

### ✅ 命名规则

```
蓝牙名称 = "Kanaan-" + 蓝牙MAC地址后四位
```

### ✅ 示例

```
MAC: 48:08:EB:60:00:50  →  名称: Kanaan-0050
MAC: 48:08:EB:60:12:AB  →  名称: Kanaan-12AB
MAC: 48:08:EB:6F:FF:FF  →  名称: Kanaan-FFFF
```

### ✅ 优势

- 唯一性
- 可追溯性
- 简洁性
- 一致性

### ✅ 实现位置

**文件**: `lib/models/test_state.dart`  
**方法**: `_autoTestBluetooth()`  
**行号**: ~7424-7444

---

## 相关文档

- **测试序列**: `TEST_SEQUENCE_UPDATE.md`
- **SN 管理**: `SN_MANAGEMENT.md`
- **GTP 命令**: `lib/services/production_test_commands.dart`
