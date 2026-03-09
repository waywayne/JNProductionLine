# 测试报告增强功能

## 📋 概述

本次更新为测试报告添加了阈值信息显示功能，并确保测试报告文件名使用正确的 SN 号。

## ✅ 已完成的功能

### 1. 测试数据（阈值信息）显示

#### 文本报告格式
测试报告的文本格式（.txt文件）现在会显示每个测试项的详细数据：

```
1. 物奇功耗测试 (电流)
   状态: 通过
   耗时: 15.3秒
   测试数据:
      测量值: 45.23 mA
      阈值: ≤ 50 mA
      结果: 通过
```

#### UI 弹窗显示
测试报告弹窗中，每个测试项下方会以等宽字体显示测试数据：

```
物奇功耗测试
  电流 | 15秒
  测量值: 45.23 mA
  阈值: ≤ 50 mA
  结果: 通过
```

### 2. 实现机制

#### 数据流程
```
1. 测试执行 → 调用 _recordTestData() 记录数据
   ↓
2. 测试完成 → 自动从 _lastTestData 获取数据
   ↓
3. 添加到 TestReportItem.testData
   ↓
4. 显示在报告中（UI 和文本格式）
```

#### 代码结构

**状态变量**（test_state.dart）
```dart
Map<String, dynamic>? _lastTestData; // 临时存储当前测试的数据
```

**记录方法**（test_state.dart）
```dart
void _recordTestData(Map<String, dynamic> data) {
  _lastTestData = data;
}
```

**自动添加到报告**（test_state.dart，第 5278-5292 行）
```dart
// 尝试获取测试数据（如果测试方法返回了额外的数据）
Map<String, dynamic>? testData;
if (_lastTestData != null) {
  testData = Map<String, dynamic>.from(_lastTestData!);
  _lastTestData = null; // 清空，避免影响下一个测试
}

final updatedItem = item.copyWith(
  status: result ? TestReportStatus.pass : TestReportStatus.fail,
  endTime: DateTime.now(),
  errorMessage: result ? null : '测试未通过',
  testData: testData,
);
```

### 3. 已添加阈值信息的测试项

#### 物奇功耗测试
```dart
_recordTestData({
  '测量值': '${currentMa.toStringAsFixed(2)} mA',
  '阈值': '≤ ${TestConfig.wuqiPowerThresholdMa} mA',
  '结果': '通过',
});
```

## 📝 需要添加阈值信息的其他测试项

以下测试项也有阈值，建议添加类似的数据记录：

### 1. 漏电流测试（_autoTestLeakageCurrent）
- 阈值：≤ TestConfig.leakageCurrentThresholdMa mA
- 建议记录：测量值、阈值、结果

### 2. ISP工作功耗测试（_autoTestIspWorkingPower）
- 阈值：≤ TestConfig.ispWorkingPowerThresholdMa mA
- 建议记录：测量值、阈值、结果

### 3. Touch 测试（左右触控）
- 阈值：CDC 变化 > 500
- 建议记录：CDC 值、阈值、结果

### 4. 电压测试（_autoTestVoltage）
- 阈值：电压范围
- 建议记录：测量值、阈值范围、结果

### 5. 电量检测测试（_autoTestBattery）
- 阈值：电量范围
- 建议记录：测量值、阈值范围、结果

## 🔧 如何为其他测试添加阈值信息

### 示例：为 ISP 工作功耗测试添加阈值信息

在测试方法中，测试通过或失败时调用 `_recordTestData()`：

```dart
Future<bool> _autoTestIspWorkingPower() async {
  // ... 测试逻辑 ...
  
  final currentMa = currentA * 1000;
  
  if (currentMa <= TestConfig.ispWorkingPowerThresholdMa) {
    _logState?.success('✅ ISP工作功耗测试通过');
    
    // 记录测试数据
    _recordTestData({
      '测量值': '${currentMa.toStringAsFixed(2)} mA',
      '阈值': '≤ ${TestConfig.ispWorkingPowerThresholdMa} mA',
      '结果': '通过',
    });
    
    return true;
  } else {
    _logState?.error('❌ 超过阈值');
    
    // 记录测试数据（失败情况）
    _recordTestData({
      '测量值': '${currentMa.toStringAsFixed(2)} mA',
      '阈值': '≤ ${TestConfig.ispWorkingPowerThresholdMa} mA',
      '差值': '+${(currentMa - TestConfig.ispWorkingPowerThresholdMa).toStringAsFixed(2)} mA',
      '结果': '失败',
    });
    
    return false;
  }
}
```

## 📊 SN 号显示问题

### 问题描述
测试报告文件名中显示 "UNKNOWN" 而不是正确的 SN 号。

### 现有解决方案
代码中已经实现了在 SN/MAC 生成后更新测试报告的逻辑（test_state.dart 第 6952-6966 行）：

```dart
// 更新测试报告中的设备信息
if (_currentTestReport != null) {
  _currentTestReport = TestReport(
    deviceSN: _currentDeviceIdentity!['sn'] ?? 'UNKNOWN',
    bluetoothMAC: _currentDeviceIdentity!['bluetoothMac'],
    wifiMAC: _currentDeviceIdentity!['wifiMac'],
    startTime: _currentTestReport!.startTime,
    endTime: _currentTestReport!.endTime,
    items: _currentTestReport!.items,
  );
  _logState?.info('   📝 已更新测试报告设备信息');
}
```

### 可能的原因
1. **SN 生成失败**：检查日志中是否有 "设备标识生成失败" 的错误
2. **更新逻辑未触发**：检查日志中是否有 "已更新测试报告设备信息" 的提示
3. **测试序列问题**：SN 生成（第 9-10 步）在测试报告初始化之后

### 验证方法
查看测试日志，确认以下信息：
1. `🏷️ 开始生成设备标识信息`
2. `✅ 设备标识信息生成成功`
3. `📝 已更新测试报告设备信息`
4. `SN: [实际的SN号]`

如果这些日志都正常，但文件名仍然是 UNKNOWN，可能需要检查：
- 测试是否在 SN 生成步骤之前就失败了
- 是否有异常导致更新逻辑被跳过

## 📁 修改的文件

### 核心文件
1. **lib/models/test_state.dart**
   - 添加 `_lastTestData` 状态变量
   - 添加 `_recordTestData()` 方法
   - 修改测试执行循环以记录 testData
   - 在物奇功耗测试中添加数据记录

2. **lib/models/test_report.dart**
   - 修改 `toFormattedString()` 方法以显示 testData

3. **lib/widgets/test_report_dialog.dart**
   - 修改测试项显示以包含 testData

### 新增文件
4. **lib/widgets/spk_test_dialog.dart**
   - SPK 测试弹窗组件

5. **TEST_REPORT_ENHANCEMENTS.md**
   - 本文档

## 🎯 后续建议

1. **为所有有阈值的测试添加数据记录**
   - 参考物奇功耗测试的实现
   - 使用 `_recordTestData()` 方法记录数据

2. **优化数据显示格式**
   - 考虑为不同类型的测试使用不同的显示格式
   - 添加单位和精度控制

3. **添加数据导出功能**
   - 支持导出为 CSV 格式
   - 方便数据分析和统计

4. **监控 SN 号更新**
   - 添加更多日志以跟踪 SN 号的生成和更新过程
   - 确保文件名始终使用最新的 SN 号
