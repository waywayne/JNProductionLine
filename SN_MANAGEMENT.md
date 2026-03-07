# 📋 SN 码管理系统

## 概述

实现了完整的 SN 码生成、分配、记录和查询系统，自动管理 WiFi MAC 和蓝牙 MAC 地址分配。

---

## SN 码规则

### 格式

```
PPP-F-YMMDD-L-BBBBB-SSSS
```

### 字段说明

| 字段 | 长度 | 说明 | 示例 |
|------|------|------|------|
| **PPP** | 3 | 产品线代码 | `637` (Kanaan-K2) |
| **F** | 1 | 工厂代码 | `1` (比亚迪) |
| **YMMDD** | 5 | 生产日期（年月日） | `51216` (2025年12月16日) |
| **L** | 1 | 产线代码 | `1` (产线1) |
| **BBBBB** | 5 | 流水号（递增） | `00001` |
| **SSSS** | 4 | 校验码（Base36） | `0000` |

### 示例

```
完整 SN: 6371512161000010000
格式化显示: 637-1-51216-1-00001-0000

解析:
- 产品线: 637 (Kanaan-K2 AI拍摄眼镜)
- 工厂: 1 (比亚迪)
- 日期: 51216 (2025年12月16日)
- 产线: 1
- 流水号: 00001
- 校验码: 0000
```

---

## MAC 地址范围

### WiFi MAC 地址

```
起始: 48:08:EB:50:00:50
结束: 48:08:EB:5F:FF:FF
```

### 蓝牙 MAC 地址

```
起始: 48:08:EB:60:00:50
结束: 48:08:EB:6F:FF:FF
```

---

## 产品线定义

| 代码 | 产品名称 |
|------|----------|
| `637` | Kanaan-K2 AI拍摄眼镜 |
| `638` | 瞳行 AI 拍摄眼镜 |

---

## 工厂定义

| 代码 | 工厂名称 |
|------|----------|
| `1` | 比亚迪 |
| `2` | 工厂 B |

---

## 自动化测试流程

### 1. 产测开始后的 SN 处理流程

```
产测开始 (CMD 0x00)
    ↓
读取 SN 码 (CMD 0xFD)
    ↓
SN 是否存在？
    ├─ 是 → 查询数据库
    │       ├─ 找到记录 → 使用已有的 WiFi MAC 和蓝牙 MAC
    │       └─ 未找到 → 预分配新的 MAC 地址并记录
    │
    └─ 否 → 生成新 SN
            ├─ 分配 WiFi MAC
            ├─ 分配蓝牙 MAC
            ├─ 写入 SN (CMD 0xFE)
            └─ 记录到数据库
```

### 2. 详细步骤

#### 步骤 1: 读取 SN 码

```dart
// 发送读取 SN 命令
final command = ProductionTestCommands.createReadSNCommand();
final response = await serialService.sendCommandAndWaitResponse(command);

// 解析响应
final sn = ProductionTestCommands.parseReadSNResponse(response['payload']);
```

#### 步骤 2: 查询或生成

```dart
if (sn != null && sn.isNotEmpty) {
  // SN 已存在，查询数据库
  final record = snManager.querySN(sn);
  
  if (record != null) {
    // 使用已有记录
    wifiMac = record.wifiMac;
    btMac = record.btMac;
  } else {
    // 预分配新 MAC 并记录
    wifiMac = snManager.allocateWifiMac();
    btMac = snManager.allocateBtMac();
    await snManager.createRecord(
      sn: sn,
      hardwareVersion: hardwareVersion,
      wifiMac: wifiMac,
      btMac: btMac,
    );
  }
} else {
  // SN 不存在，生成新 SN
  final sequenceNumber = snManager.getNextSequenceNumber(
    productLine: config.productLine,
    factory: config.factory,
    productionLine: config.productionLine,
  );
  
  sn = snManager.generateSN(
    productLine: config.productLine,
    factory: config.factory,
    productionLine: config.productionLine,
    sequenceNumber: sequenceNumber,
  );
  
  wifiMac = snManager.allocateWifiMac();
  btMac = snManager.allocateBtMac();
  
  // 写入 SN 到设备
  final writeCommand = ProductionTestCommands.createWriteSNCommand(sn);
  await serialService.sendCommandAndWaitResponse(writeCommand);
  
  // 记录到数据库
  await snManager.createRecord(
    sn: sn,
    hardwareVersion: hardwareVersion,
    wifiMac: wifiMac,
    btMac: btMac,
  );
}
```

#### 步骤 3: 使用分配的 MAC 地址

```dart
// 写入 WiFi MAC
await writeWifiMac(wifiMac);

// 写入蓝牙 MAC
await writeBluetoothMac(btMac);
```

---

## GTP 命令

### SN 码读取 (0xFD)

**请求**:
```
CMD: 0xFD
Payload: 无
```

**响应**:
```
CMD: 0xFD
Payload: [SN码字符串] + \0

示例: 0xFD + "6371512161000010000" + 0x00
```

### SN 码写入 (0xFE)

**请求**:
```
CMD: 0xFE
Payload: [SN码字符串] + \0

示例: 0xFE + "6371512161000010000" + 0x00
```

**响应**:
```
CMD: 0xFE
Payload: [SN码字符串] + \0 (回显确认)
```

---

## 数据存储

### 存储位置

```
应用文档目录/sn_records.json
```

### 数据格式

```json
{
  "6371512161000010000": {
    "sn": "6371512161000010000",
    "hardware_version": "1.0.0",
    "wifi_mac": "48:08:EB:50:00:50",
    "bt_mac": "48:08:EB:60:00:50",
    "created_at": "2025-12-16T10:30:00.000",
    "updated_at": "2025-12-16T10:30:00.000"
  },
  "6371512161000020001": {
    "sn": "6371512161000020001",
    "hardware_version": "1.0.0",
    "wifi_mac": "48:08:EB:50:00:51",
    "bt_mac": "48:08:EB:60:00:51",
    "created_at": "2025-12-16T10:35:00.000",
    "updated_at": "2025-12-16T10:35:00.000"
  }
}
```

---

## API 使用

### 初始化

```dart
final snManager = SNManagerService();
await snManager.init();
```

### 生成 SN 码

```dart
final sn = snManager.generateSN(
  productLine: '637',      // Kanaan-K2
  factory: '1',            // 比亚迪
  productionLine: '1',     // 产线1
  sequenceNumber: 1,       // 流水号
);

print(sn); // 6371512161000010000
print(snManager.formatSN(sn)); // 637-1-51216-1-00001-0000
```

### 验证 SN 码

```dart
final isValid = snManager.validateSN('6371512161000010000');
print(isValid); // true
```

### 分配 MAC 地址

```dart
final wifiMac = snManager.allocateWifiMac();
print(wifiMac); // 48:08:EB:50:00:50

final btMac = snManager.allocateBtMac();
print(btMac); // 48:08:EB:60:00:50
```

### 创建记录

```dart
final record = await snManager.createRecord(
  sn: '6371512161000010000',
  hardwareVersion: '1.0.0',
  wifiMac: '48:08:EB:50:00:50',
  btMac: '48:08:EB:60:00:50',
);
```

### 查询记录

```dart
final record = snManager.querySN('6371512161000010000');
if (record != null) {
  print('WiFi MAC: ${record.wifiMac}');
  print('蓝牙 MAC: ${record.btMac}');
}
```

### 获取下一个流水号

```dart
final nextSeq = snManager.getNextSequenceNumber(
  productLine: '637',
  factory: '1',
  productionLine: '1',
);
print(nextSeq); // 2 (如果今天已有1条记录)
```

### 导出数据

```dart
final csv = await snManager.exportToCSV();
print(csv);
// SN,硬件版本,WiFi MAC,蓝牙 MAC,创建时间,更新时间
// 6371512161000010000,1.0.0,48:08:EB:50:00:50,48:08:EB:60:00:50,...
```

### 获取统计信息

```dart
final stats = snManager.getStatistics();
print(stats);
// {
//   'total_records': 10,
//   'current_wifi_mac_index': 10,
//   'current_bt_mac_index': 10,
//   'next_wifi_mac': '48:08:EB:50:00:5A',
//   'next_bt_mac': '48:08:EB:60:00:5A',
// }
```

---

## 配置界面

在通用配置页面中添加 SN 生成配置：

### 配置项

1. **产品线代码** (3位)
   - 默认: `637` (Kanaan-K2)
   - 可选: `638` (瞳行)

2. **工厂代码** (1位)
   - 默认: `1` (比亚迪)
   - 可选: `2` (工厂B)

3. **产线代码** (1位)
   - 默认: `1`
   - 范围: 1-9

### 访问路径

```
菜单 → 产测通用配置 → 7. SN 生成配置
```

---

## 自动化测试集成

### 测试序列更新

在自动化测试中添加 SN 处理步骤：

```dart
final testSequence = [
  // ... 其他测试项
  {'name': '7. 产测初始化', 'executor': _autoTestProductionInit},
  {'name': '8. 产测开始', 'executor': _autoTestProductionStart},
  {'name': '9. SN 码处理', 'executor': _autoTestSNProcess},  // ← 新增
  {'name': '10. EMMC容量检测', 'executor': _autoTestEMMCCapacity},
  // ... 其他测试项
];
```

### SN 处理实现

```dart
Future<bool> _autoTestSNProcess() async {
  try {
    // 1. 读取 SN
    final sn = await _readSN();
    
    // 2. 查询或生成
    if (sn != null) {
      final record = _snManager.querySN(sn);
      if (record != null) {
        _currentWifiMac = record.wifiMac;
        _currentBtMac = record.btMac;
      } else {
        await _allocateAndRecord(sn);
      }
    } else {
      await _generateAndWriteSN();
    }
    
    return true;
  } catch (e) {
    _logState?.error('SN 处理失败: $e');
    return false;
  }
}
```

---

## 最佳实践

### 1. 每日重置流水号

流水号每天从 00001 开始，自动根据日期区分。

### 2. 备份数据

定期导出 CSV 备份：

```dart
final csv = await snManager.exportToCSV();
await File('backup_${DateTime.now()}.csv').writeAsString(csv);
```

### 3. 验证 SN

写入前验证格式：

```dart
if (!snManager.validateSN(sn)) {
  throw Exception('SN 格式错误');
}
```

### 4. 错误处理

```dart
try {
  await snManager.createRecord(...);
} catch (e) {
  // 记录失败，但不影响测试继续
  _logState?.warning('记录 SN 失败: $e');
}
```

---

## 故障排查

### Q1: SN 重复

**原因**: 流水号计算错误或数据库未同步

**解决**: 
```dart
// 手动设置流水号
final nextSeq = snManager.getNextSequenceNumber(...);
print('下一个流水号: $nextSeq');
```

### Q2: MAC 地址冲突

**原因**: 索引未正确更新

**解决**:
```dart
// 查看当前索引
final stats = snManager.getStatistics();
print('当前 WiFi MAC 索引: ${stats['current_wifi_mac_index']}');
```

### Q3: 数据丢失

**原因**: 文件损坏或权限问题

**解决**:
```dart
// 从备份恢复
await snManager.init(); // 重新加载
```

---

## 总结

### ✅ 已实现功能

1. ✅ SN 码自动生成（含校验码）
2. ✅ WiFi MAC 自动分配
3. ✅ 蓝牙 MAC 自动分配
4. ✅ SN 与 MAC 关联记录
5. ✅ 数据持久化存储
6. ✅ SN 读取/写入命令
7. ✅ 流水号自动递增
8. ✅ 数据导出 (CSV)
9. ✅ 统计信息查询

### 🎯 使用流程

```
配置产品线/工厂/产线
    ↓
启动自动化测试
    ↓
产测开始 → 读取 SN
    ↓
SN 存在？
├─ 是 → 使用已有 MAC
└─ 否 → 生成并写入 SN
    ↓
分配 WiFi/蓝牙 MAC
    ↓
记录到数据库
    ↓
继续后续测试
```

### 📊 数据流

```
ProductionConfig (配置)
    ↓
SNManagerService (管理)
    ↓
sn_records.json (存储)
    ↓
设备 (写入)
```
