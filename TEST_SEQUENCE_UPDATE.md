# 📋 自动化测试序列调整

## 更新说明

已调整自动化测试顺序，在**产测开始**后优先处理 **SN 码、MAC 地址和硬件版本号**的读写操作。

---

## 🔄 新测试序列

### 阶段 1: 电源与功耗测试 (1-8)

```
1. 设备关机
2. 漏电流测试
3. 上电测试
4. 设备唤醒
5. 物奇功耗测试
6. ISP工作功耗测试
7. 产测初始化
8. 产测开始
```

### 阶段 2: 设备标识与配置 (9-16) ⭐ **优先处理**

```
9.  SN码读取           ← 新增，优先读取
10. SN码写入           ← 新增，优先写入
11. 蓝牙MAC写入         ← 从原位置14移动
12. 蓝牙MAC读取         ← 从原位置15移动
13. WiFi MAC写入       ← 新增
14. WiFi MAC读取       ← 新增
15. 硬件版本号写入      ← 从原位置33移动
16. 硬件版本号读取      ← 从原位置34移动
```

### 阶段 3: 功能测试 (17-38)

```
17. EMMC容量检测测试
18. 设备电压测试
19. 电量检测测试
20. 充电状态测试
21. 生成设备标识
22. (SPP蓝牙功能测试 - 已注释)
23. WiFi功能测试
24. Sensor测试
25. RTC设置时间测试
26. RTC获取时间测试
27. 光敏传感器测试
28. IMU传感器测试
29. 右触控测试
30. 左触控测试
31. LED灯(外侧)测试
32. LED灯(内侧)测试
33. 左SPK测试
34. 右SPK测试
35. 左MIC测试
36. 右MIC测试
37. TALK MIC测试
38. 蓝牙功能测试
```

### 阶段 4: 结束 (39)

```
39. 结束产测
```

---

## 📊 对比变化

### 原顺序 (35项)

```
8. 产测开始
9. EMMC容量检测测试
...
14. 蓝牙MAC写入
15. 蓝牙MAC读取
...
33. 硬件版本号写入
34. 硬件版本号读取
35. 结束产测
```

### 新顺序 (39项)

```
8. 产测开始
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
9.  SN码读取              ← 新增
10. SN码写入              ← 新增
11. 蓝牙MAC写入            ← 提前
12. 蓝牙MAC读取            ← 提前
13. WiFi MAC写入          ← 新增
14. WiFi MAC读取          ← 新增
15. 硬件版本号写入         ← 提前
16. 硬件版本号读取         ← 提前
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
17. EMMC容量检测测试
...
39. 结束产测
```

---

## 🎯 调整原因

### 1. **逻辑优先级**

设备标识信息（SN、MAC、版本号）是设备的"身份证"，应该在功能测试之前完成：

- ✅ **先确定设备身份**
- ✅ **再进行功能验证**

### 2. **数据依赖关系**

```
SN 码 → 查询/生成 → 分配 MAC 地址
   ↓
蓝牙 MAC + WiFi MAC
   ↓
硬件版本号
   ↓
功能测试（使用已分配的 MAC）
```

### 3. **故障排查便利**

如果在功能测试阶段失败，设备的标识信息已经写入，便于：
- 追溯测试历史
- 分析失败原因
- 重新测试时识别设备

### 4. **生产效率**

- 标识写入操作快速（<1秒）
- 提前完成可避免后续测试中断时信息丢失
- 支持断点续测

---

## 🔧 技术实现

### 修改的文件

**`lib/models/test_state.dart`**

#### 1. `_executeAllTests()` 方法

```dart
Future<void> _executeAllTests() async {
  final testSequence = [
    // ... 前8项保持不变
    {'name': '8. 产测开始', 'executor': _autoTestProductionStart},
    
    // ========== 优先处理：SN、MAC 地址、硬件版本号 ==========
    {'name': '9. SN码读取', 'executor': _autoTestReadSN},
    {'name': '10. SN码写入', 'executor': _autoTestWriteSN},
    {'name': '11. 蓝牙MAC写入', 'executor': _autoTestBluetoothMACWrite},
    {'name': '12. 蓝牙MAC读取', 'executor': _autoTestBluetoothMACRead},
    {'name': '13. WiFi MAC写入', 'executor': _autoTestWiFiMACWrite},
    {'name': '14. WiFi MAC读取', 'executor': _autoTestWiFiMACRead},
    {'name': '15. 硬件版本号写入', 'executor': _autoTestWriteHardwareVersion},
    {'name': '16. 硬件版本号读取', 'executor': _autoTestReadHardwareVersion},
    
    // ========== 其他功能测试 ==========
    // ...
  ];
}
```

#### 2. `_getTestSequence()` 方法

同步更新，保持与 `_executeAllTests()` 一致。

---

## 📝 新增测试项

### 1. SN码读取 (`_autoTestReadSN`)

**功能**: 读取设备中已写入的 SN 码

**命令**: `CMD 0xFD`

**逻辑**:
```dart
Future<bool> _autoTestReadSN() async {
  // 1. 发送读取命令
  final command = ProductionTestCommands.createReadSNCommand();
  
  // 2. 等待响应
  final response = await _serialService.sendCommandAndWaitResponse(command);
  
  // 3. 解析 SN
  final sn = ProductionTestCommands.parseReadSNResponse(response['payload']);
  
  // 4. 查询数据库
  if (sn != null) {
    final record = _snManager.querySN(sn);
    // 使用已有的 MAC 地址
  }
  
  return true;
}
```

### 2. SN码写入 (`_autoTestWriteSN`)

**功能**: 生成并写入新的 SN 码

**命令**: `CMD 0xFE + SN字符串 + \0`

**逻辑**:
```dart
Future<bool> _autoTestWriteSN() async {
  // 1. 生成 SN
  final sn = _snManager.generateSN(
    productLine: config.productLine,
    factory: config.factory,
    productionLine: config.productionLine,
    sequenceNumber: nextSeq,
  );
  
  // 2. 写入设备
  final command = ProductionTestCommands.createWriteSNCommand(sn);
  await _serialService.sendCommandAndWaitResponse(command);
  
  // 3. 分配 MAC 地址
  final wifiMac = _snManager.allocateWifiMac();
  final btMac = _snManager.allocateBtMac();
  
  // 4. 记录到数据库
  await _snManager.createRecord(
    sn: sn,
    hardwareVersion: hardwareVersion,
    wifiMac: wifiMac,
    btMac: btMac,
  );
  
  return true;
}
```

### 3. WiFi MAC写入 (`_autoTestWiFiMACWrite`)

**功能**: 写入分配的 WiFi MAC 地址

**命令**: 根据 WiFi 配置命令实现

### 4. WiFi MAC读取 (`_autoTestWiFiMACRead`)

**功能**: 读取并验证 WiFi MAC 地址

---

## 🔄 执行流程

### 完整流程图

```
┌─────────────────────────────────────────┐
│  1-7. 电源与功耗测试                      │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  8. 产测开始 (CMD 0x00)                  │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  9. 读取 SN 码 (CMD 0xFD)                │
│     ├─ SN 存在？                         │
│     │  ├─ 是 → 查询数据库                │
│     │  │       ├─ 找到 → 使用已有 MAC    │
│     │  │       └─ 未找到 → 分配新 MAC    │
│     │  └─ 否 → 跳到步骤10                │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  10. 写入 SN 码 (CMD 0xFE)               │
│      ├─ 生成新 SN                        │
│      ├─ 写入设备                         │
│      ├─ 分配 WiFi MAC                    │
│      ├─ 分配蓝牙 MAC                     │
│      └─ 记录到数据库                     │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  11-12. 蓝牙 MAC 写入/读取               │
│         使用分配的蓝牙 MAC 地址           │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  13-14. WiFi MAC 写入/读取               │
│         使用分配的 WiFi MAC 地址          │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  15-16. 硬件版本号 写入/读取              │
│         使用配置的硬件版本号              │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  17-38. 功能测试                         │
│         (EMMC, 电压, WiFi, 传感器等)     │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  39. 结束产测                            │
└─────────────────────────────────────────┘
```

---

## ✅ 优势

### 1. **逻辑清晰**
- 先标识，后功能
- 符合生产流程直觉

### 2. **数据完整**
- 即使功能测试失败，设备标识已记录
- 支持追溯和重测

### 3. **效率提升**
- 标识写入快速完成
- 避免重复操作

### 4. **易于维护**
- 标识相关测试集中在一起
- 便于调试和优化

---

## 📌 注意事项

### 1. **测试项总数变化**

- **原**: 35 项
- **新**: 39 项（+4项）

### 2. **新增的测试方法**

需要实现以下方法：
```dart
Future<bool> _autoTestReadSN()
Future<bool> _autoTestWriteSN()
Future<bool> _autoTestWiFiMACWrite()
Future<bool> _autoTestWiFiMACRead()
```

### 3. **依赖服务**

确保已初始化：
```dart
final _snManager = SNManagerService();
await _snManager.init();
```

### 4. **配置要求**

在 `ProductionConfig` 中配置：
- 产品线代码 (`productLine`)
- 工厂代码 (`factory`)
- 产线代码 (`productionLine`)

---

## 🎯 下一步工作

### 1. 实现新增的测试方法

- [ ] `_autoTestReadSN()`
- [ ] `_autoTestWriteSN()`
- [ ] `_autoTestWiFiMACWrite()`
- [ ] `_autoTestWiFiMACRead()`

### 2. 集成 SN 管理服务

- [ ] 在 `TestState` 中初始化 `SNManagerService`
- [ ] 实现 SN 查询和生成逻辑
- [ ] 实现 MAC 地址分配逻辑

### 3. 测试验证

- [ ] 单元测试
- [ ] 集成测试
- [ ] 生产环境验证

---

## 📚 相关文档

- **SN 管理系统**: `SN_MANAGEMENT.md`
- **GTP 命令**: `lib/services/production_test_commands.dart`
- **配置管理**: `lib/config/production_config.dart`

---

## 总结

测试序列已成功调整，现在的顺序更符合生产逻辑：

```
产测开始 → 标识写入 → 功能测试 → 结束产测
```

这样的顺序确保了设备标识信息的完整性和可追溯性，提升了生产效率和测试可靠性。🎉
