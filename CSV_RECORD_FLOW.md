# CSV设备记录流程说明

## 概述

系统自动将SN分配和测试结果保存到CSV文件中，实现设备全生命周期追踪。

## CSV文件位置

```
~/Documents/JNProductionLine/device_records.csv
```

- **Windows**: `C:\Users\{用户名}\Documents\JNProductionLine\device_records.csv`
- **macOS**: `/Users/{用户名}/Documents/JNProductionLine/device_records.csv`
- **Linux**: `/home/{用户名}/Documents/JNProductionLine/device_records.csv`

## CSV文件格式

### 表头
```csv
分配时间,SN号,蓝牙MAC地址,WiFi MAC地址,测试状态,通过率,最后更新时间
```

### 数据示例
```csv
分配时间,SN号,蓝牙MAC地址,WiFi MAC地址,测试状态,通过率,最后更新时间
2026-03-11T15:30:00.000,6371603071000025951,48:08:EB:60:00:02,48:08:EB:50:00:02,未测试,-,2026-03-11T15:30:00.000
2026-03-11T15:35:00.000,6371603071000025952,48:08:EB:60:00:03,48:08:EB:50:00:03,通过,100.0%,2026-03-11T15:45:00.000
2026-03-11T15:50:00.000,6371603071000025953,48:08:EB:60:00:04,48:08:EB:50:00:04,失败,85.5%,2026-03-11T16:00:00.000
```

### 字段说明

| 字段 | 说明 | 示例 |
|------|------|------|
| 分配时间 | SN首次分配的时间（ISO 8601格式） | 2026-03-11T15:30:00.000 |
| SN号 | 设备序列号 | 6371603071000025951 |
| 蓝牙MAC地址 | 蓝牙MAC地址 | 48:08:EB:60:00:02 |
| WiFi MAC地址 | WiFi MAC地址 | 48:08:EB:50:00:02 |
| 测试状态 | 未测试/通过/失败 | 通过 |
| 通过率 | 测试通过率（百分比） | 100.0% |
| 最后更新时间 | 最后一次状态更新时间 | 2026-03-11T15:45:00.000 |

## 工作流程

### 1. SN分配时（状态：未测试）

**触发时机**：调用 `generateDeviceIdentity()` 从服务端获取SN后

**执行代码位置**：
```dart
// lib/models/test_state.dart - generateDeviceIdentity()
await _saveDeviceToGlobalRecord(testStatus: '未测试');
```

**CSV操作**：
- 如果SN不存在 → 添加新记录
- 如果SN已存在 → 更新记录（保留原分配时间）

**记录内容**：
```csv
2026-03-11T15:30:00.000,6371603071000025951,48:08:EB:60:00:02,48:08:EB:50:00:02,未测试,-,2026-03-11T15:30:00.000
```

### 2. 产测完成时（状态：通过/失败）

**触发时机**：测试流程结束，调用 `_finalizeTestReport()`

**执行代码位置**：
```dart
// lib/models/test_state.dart - _finalizeTestReport()
final testStatus = _currentTestReport!.allTestsPassed ? '通过' : '失败';
_saveDeviceToGlobalRecord(testStatus: testStatus);
```

**CSV操作**：
- 查找对应SN的记录
- 更新测试状态、通过率、最后更新时间
- **保留原分配时间**

**记录内容（测试通过）**：
```csv
2026-03-11T15:30:00.000,6371603071000025951,48:08:EB:60:00:02,48:08:EB:50:00:02,通过,100.0%,2026-03-11T15:45:00.000
```

**记录内容（测试失败）**：
```csv
2026-03-11T15:30:00.000,6371603071000025951,48:08:EB:60:00:02,48:08:EB:50:00:02,失败,85.5%,2026-03-11T15:45:00.000
```

## 更新逻辑

### 查找现有记录
```dart
// 通过SN号查找现有记录
int existingLineIndex = -1;
for (int i = 1; i < lines.length; i++) {
  if (lines[i].contains(snCode)) {
    existingLineIndex = i;
    break;
  }
}
```

### 更新策略

#### 如果记录已存在
```dart
// 保留原分配时间，更新其他字段
final oldLine = lines[existingLineIndex].split(',');
final allocTime = oldLine[0]; // 保留原分配时间
lines[existingLineIndex] = '$allocTime,$snCode,$bluetoothMac,$wifiMac,$testStatus,$passRate%,$timestamp';
```

#### 如果记录不存在
```dart
// 添加新记录
final recordLine = '$timestamp,$snCode,$bluetoothMac,$wifiMac,$testStatus,$passRate%,$timestamp\n';
await globalRecordFile.writeAsString(recordLine, mode: FileMode.append);
```

## 状态流转

```
┌─────────────┐
│  SN分配     │
│  (API获取)  │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  未测试     │ ← CSV记录创建（分配时间 = 当前时间）
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  测试中     │
└──────┬──────┘
       │
       ├─────────┐
       ▼         ▼
┌──────────┐ ┌──────────┐
│  通过    │ │  失败    │ ← CSV记录更新（保留分配时间，更新状态和最后更新时间）
└──────────┘ └──────────┘
```

## 通过率计算

```dart
final passRate = testStatus == '通过' 
    ? (_currentTestReport?.passRate.toStringAsFixed(1) ?? '100.0')
    : (testStatus == '失败' ? (_currentTestReport?.passRate.toStringAsFixed(1) ?? '0.0') : '-');
```

- **未测试**: `-`
- **通过**: 实际通过率（通常为100.0%）
- **失败**: 实际通过率（如85.5%）

## 日志输出

### SN分配时
```
📝 已记录到全局设备文件（未测试）
   📋 SN: 6371603071000025951
   📶 蓝牙MAC: 48:08:EB:60:00:02
   📡 WiFi MAC: 48:08:EB:50:00:02
   📊 状态: 未测试
   📁 文件: ~/Documents/JNProductionLine/device_records.csv
```

### 测试完成时
```
✅ 已更新设备记录（通过）
   📋 SN: 6371603071000025951
   📶 蓝牙MAC: 48:08:EB:60:00:02
   📡 WiFi MAC: 48:08:EB:50:00:02
   📊 状态: 通过
   📁 文件: ~/Documents/JNProductionLine/device_records.csv
```

## 异常处理

### 文件不存在
- 自动创建目录和文件
- 写入表头
- 添加第一条记录

### 写入失败
- 捕获异常并记录日志
- 不影响测试流程继续进行

### SN重复
- 更新现有记录而不是创建新记录
- 保留原分配时间

## 数据用途

1. **生产追溯**：记录每个设备的SN分配时间
2. **测试统计**：统计测试通过率和失败率
3. **质量分析**：分析不同批次的质量情况
4. **设备管理**：追踪设备的测试状态

## 注意事项

1. **时间格式**：使用ISO 8601格式，便于排序和解析
2. **分配时间不变**：一旦SN分配，分配时间永久保留
3. **状态可更新**：测试状态可以从"未测试"更新为"通过"或"失败"
4. **通过率精度**：保留1位小数（如85.5%）
5. **文件编码**：UTF-8编码，支持中文
6. **并发安全**：单线程写入，避免文件冲突

## 示例场景

### 场景1：首次测试设备
1. 从服务端获取SN → CSV记录（未测试）
2. 执行产测 → CSV更新（通过/失败）

### 场景2：重测设备
1. 读取设备SN → 服务端验证 → CSV记录已存在
2. 执行产测 → CSV更新状态（保留原分配时间）

### 场景3：批量生产
1. 设备1：分配SN → 未测试
2. 设备2：分配SN → 未测试
3. 设备1：测试完成 → 通过
4. 设备2：测试完成 → 失败
5. CSV文件包含完整的批次记录
