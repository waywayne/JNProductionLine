# 📋 SN 码数据库查询实现

## 概述

已实现 SN 码读取后的数据库查询功能，支持自动检测设备是否已存在，并根据情况使用已有 MAC 地址或分配新的 MAC 地址。

---

## 🔄 工作流程

### 完整流程图

```
SN 码读取
    ↓
设备返回 SN 码
    ↓
查询数据库
    ├─ SN 已存在？
    │   ├─ 是 → 加载已有记录
    │   │       ├─ 读取 WiFi MAC
    │   │       ├─ 读取蓝牙 MAC
    │   │       ├─ 读取硬件版本
    │   │       └─ 更新 _currentDeviceIdentity
    │   │
    │   └─ 否 → 标记为新设备
    │           └─ 在写入步骤分配新 MAC
    ↓
继续测试流程
```

---

## 📝 实现细节

### 1. 服务初始化

**文件**: `lib/models/test_state.dart`

```dart
// 导入 SNManagerService
import '../services/sn_manager_service.dart';

// 在 TestState 类中添加实例
final SNManagerService _snManager = SNManagerService();
```

### 2. SN 码读取逻辑

**方法**: `_autoTestReadSN()`

#### 场景 1: SN 已存在于数据库

```dart
final existingRecord = _snManager.querySN(snCode);

if (existingRecord != null) {
  // 加载已有记录
  _logState?.info('📋 SN码已存在于数据库中');
  _logState?.info('   WiFi MAC: ${existingRecord.wifiMac}');
  _logState?.info('   蓝牙 MAC: ${existingRecord.btMac}');
  _logState?.info('   硬件版本: ${existingRecord.hardwareVersion}');
  _logState?.info('   创建时间: ${existingRecord.createdAt}');
  
  // 更新设备标识信息
  _currentDeviceIdentity = {
    'sn': snCode,
    'wifiMac': existingRecord.wifiMac ?? '',
    'bluetoothMac': existingRecord.btMac ?? '',
    'hardwareVersion': existingRecord.hardwareVersion,
  };
  
  _logState?.success('✅ 已加载设备信息，将使用已有的MAC地址');
}
```

**日志示例**:
```
✅ SN码读取成功: 6371512161000010000
📋 SN码已存在于数据库中
   WiFi MAC: 48:08:EB:50:00:50
   蓝牙 MAC: 48:08:EB:60:00:50
   硬件版本: 1.0.0
   创建时间: 2026-03-07 10:30:00.000
✅ 已加载设备信息，将使用已有的MAC地址
```

#### 场景 2: SN 不存在于数据库

```dart
else {
  // SN不存在，标记为新设备
  _logState?.info('📋 SN码不在数据库中，将在写入步骤分配新的MAC地址');
  
  // 暂时只保存SN码
  _currentDeviceIdentity = {
    'sn': snCode,
  };
}
```

**日志示例**:
```
✅ SN码读取成功: 6371512161000020000
📋 SN码不在数据库中，将在写入步骤分配新的MAC地址
```

---

## 🎯 使用场景

### 场景 A: 重测已测试设备

**情况**: 设备之前已经测试过，SN 和 MAC 已写入数据库

**流程**:
1. 读取设备 SN 码
2. 查询数据库，找到已有记录
3. 加载已有的 WiFi MAC 和蓝牙 MAC
4. 使用已有 MAC 地址进行后续测试
5. 验证 MAC 地址是否匹配

**优势**:
- ✅ 保持 MAC 地址一致性
- ✅ 避免重复分配 MAC
- ✅ 可追溯测试历史

### 场景 B: 测试新设备

**情况**: 设备第一次测试，SN 未在数据库中

**流程**:
1. 读取设备 SN 码（可能为空或旧值）
2. 查询数据库，未找到记录
3. 标记为新设备
4. 在 SN 写入步骤生成新 SN 和分配新 MAC
5. 创建新的数据库记录

**优势**:
- ✅ 自动分配连续的 MAC 地址
- ✅ 记录完整的设备信息
- ✅ 支持批量生产

### 场景 C: 设备未写入 SN

**情况**: 设备从未写入过 SN 码

**流程**:
1. 读取设备 SN 码，返回空或错误
2. 跳过数据库查询
3. 在 SN 写入步骤生成新 SN
4. 分配新的 MAC 地址
5. 创建新的数据库记录

---

## 📊 数据结构

### SNRecord 模型

```dart
class SNRecord {
  final String sn;                  // SN 码
  final String hardwareVersion;     // 硬件版本
  final String? wifiMac;            // WiFi MAC 地址
  final String? btMac;              // 蓝牙 MAC 地址
  final DateTime createdAt;         // 创建时间
  final DateTime updatedAt;         // 更新时间
}
```

### _currentDeviceIdentity 结构

```dart
// 已存在的设备
{
  'sn': '6371512161000010000',
  'wifiMac': '48:08:EB:50:00:50',
  'bluetoothMac': '48:08:EB:60:00:50',
  'hardwareVersion': '1.0.0'
}

// 新设备（MAC 地址待分配）
{
  'sn': '6371512161000020000'
}
```

---

## 🔍 数据库操作

### 查询 SN 记录

```dart
SNRecord? querySN(String sn)
```

**参数**:
- `sn`: SN 码字符串

**返回**:
- `SNRecord?`: 找到返回记录，未找到返回 `null`

**示例**:
```dart
final record = _snManager.querySN('6371512161000010000');
if (record != null) {
  print('WiFi MAC: ${record.wifiMac}');
  print('蓝牙 MAC: ${record.btMac}');
}
```

### 创建新记录

```dart
Future<SNRecord> createRecord({
  required String sn,
  required String hardwareVersion,
  String? wifiMac,
  String? btMac,
})
```

**参数**:
- `sn`: SN 码
- `hardwareVersion`: 硬件版本
- `wifiMac`: WiFi MAC（可选，未提供则自动分配）
- `btMac`: 蓝牙 MAC（可选，未提供则自动分配）

**返回**:
- `SNRecord`: 创建的记录

**示例**:
```dart
final record = await _snManager.createRecord(
  sn: '6371512161000010000',
  hardwareVersion: '1.0.0',
);
// 自动分配 MAC 地址
print('WiFi MAC: ${record.wifiMac}');
print('蓝牙 MAC: ${record.btMac}');
```

---

## 🔄 测试序列集成

### 测试顺序

```
8.  产测开始
9.  SN码读取           ← 查询数据库
    ├─ SN 已存在 → 加载 MAC 地址
    └─ SN 不存在 → 标记为新设备
10. SN码写入           ← 如果是新设备，分配 MAC
11. 蓝牙MAC写入         ← 使用已有或新分配的 MAC
12. 蓝牙MAC读取
13. WiFi MAC写入       ← 使用已有或新分配的 MAC
14. WiFi MAC读取
15. 硬件版本号写入
16. 硬件版本号读取
...
```

---

## 📝 日志示例

### 完整日志流程

#### 已存在的设备

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📖 开始SN码读取
📤 发送SN码读取命令: [FD]
✅ SN码读取成功: 6371512161000010000
📋 SN码已存在于数据库中
   WiFi MAC: 48:08:EB:50:00:50
   蓝牙 MAC: 48:08:EB:60:00:50
   硬件版本: 1.0.0
   创建时间: 2026-03-07 10:30:00.000
✅ 已加载设备信息，将使用已有的MAC地址
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### 新设备

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📖 开始SN码读取
📤 发送SN码读取命令: [FD]
✅ SN码读取成功: 6371512161000020000
📋 SN码不在数据库中，将在写入步骤分配新的MAC地址
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### 设备未写入 SN

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📖 开始SN码读取
📤 发送SN码读取命令: [FD]
⚠️ 设备未写入SN码
   将在下一步写入新的SN码
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 🎯 优势

### 1. **智能识别**
- 自动检测设备是否已测试
- 区分新设备和重测设备

### 2. **MAC 地址管理**
- 已测试设备：使用已有 MAC，保持一致性
- 新设备：自动分配连续 MAC，避免冲突

### 3. **可追溯性**
- 记录创建时间和更新时间
- 支持查询测试历史
- 便于故障排查

### 4. **数据完整性**
- 自动保存到本地数据库
- 支持导出为 CSV
- 数据持久化存储

---

## ⚠️ 注意事项

### 1. **数据库初始化**

在使用前需要初始化 `SNManagerService`:

```dart
await _snManager.init();
```

### 2. **空值处理**

查询结果可能为 `null`，需要判断：

```dart
final record = _snManager.querySN(snCode);
if (record != null) {
  // 使用已有记录
} else {
  // 新设备
}
```

### 3. **MAC 地址可选**

`SNRecord` 中的 `wifiMac` 和 `btMac` 是可选的：

```dart
_currentDeviceIdentity = {
  'sn': snCode,
  'wifiMac': existingRecord.wifiMac ?? '',  // 使用 ?? 提供默认值
  'bluetoothMac': existingRecord.btMac ?? '',
  'hardwareVersion': existingRecord.hardwareVersion,
};
```

### 4. **并发安全**

`SNManagerService` 使用单例模式，确保全局唯一实例。

---

## 🔗 相关文档

- **SN 管理系统**: `SN_MANAGEMENT.md`
- **测试序列**: `TEST_SEQUENCE_UPDATE.md`
- **WiFi MAC 实现**: `WIFI_MAC_IMPLEMENTATION.md`
- **蓝牙名称规则**: `BLUETOOTH_NAME_RULE.md`

---

## 总结

✅ **已实现**:
1. SN 码读取后自动查询数据库
2. 已存在设备：加载已有 MAC 地址
3. 新设备：标记并在写入步骤分配新 MAC
4. 完整的日志输出和状态跟踪

✅ **工作流程**:
```
读取 SN → 查询数据库 → 已存在？→ 是 → 加载 MAC
                              ↓
                              否 → 标记新设备 → 分配 MAC
```

✅ **优势**:
- 智能识别设备状态
- 自动管理 MAC 地址
- 保持数据一致性
- 支持重测和追溯

SN 码数据库查询功能已完整实现！🎉
