# 🔍 蓝牙测试调试指南

## 问题描述

命令行可以找到设备，但 Flutter 应用中找不到设备。

## 调试步骤

### 1. 验证命令行工作正常

```bash
# 测试已配对设备
python scripts/bluetooth_spp_test.py --paired

# 测试扫描
python scripts/bluetooth_spp_test.py --scan
```

**预期输出**：
- `--paired`: 应该显示已配对设备列表和 JSON 输出
- `--scan`: 应该找到至少 1 个设备

---

### 2. 检查 Flutter 应用日志

在 Flutter 应用中点击"Python 蓝牙测试"后，查看日志中的以下关键信息：

#### 关键日志标记

```
🔗 查找已配对的蓝牙设备...
Python --paired 输出:           ← 查看 Python 脚本的完整输出
JSON 标记位置: start=X, end=Y   ← 确认是否找到 JSON 标记
提取的 JSON: [...]              ← 查看提取的 JSON 数据
✅ 找到 X 个已配对设备          ← 最终结果
```

#### 如果看到这些警告

```
⚠️  未找到 JSON 标记
原始输出（未找到 JSON）:
```

**原因**：Python 脚本输出格式不正确或执行失败

**解决**：
1. 检查 Python 脚本是否正确执行
2. 查看原始输出中的错误信息
3. 确认 PowerShell 命令是否成功

---

### 3. 常见问题诊断

#### 问题 A: 超时错误

```
❌ 查找已配对设备异常: TimeoutException
```

**原因**：PowerShell 查询时间过长（>15秒）

**解决**：
- 检查系统蓝牙设备数量
- 尝试手动运行 PowerShell 命令：
  ```powershell
  Get-PnpDevice -Class Bluetooth | Where-Object {$_.Status -eq "OK"} | Select-Object FriendlyName, InstanceId | ConvertTo-Json
  ```

#### 问题 B: JSON 解析失败

```
⚠️  解析设备列表失败: FormatException
```

**原因**：PowerShell 输出格式不符合预期

**解决**：
1. 查看"提取的 JSON"日志
2. 手动验证 JSON 格式
3. 检查是否有特殊字符

#### 问题 C: 未提取到 MAC 地址

```
⚠️  无法提取 MAC 地址
InstanceId: BTHENUM\{...}\...
```

**原因**：InstanceId 格式不匹配正则表达式

**解决**：
1. 查看 InstanceId 的实际格式
2. 更新 Python 脚本中的正则表达式模式
3. 手动提供设备地址

---

### 4. 手动提供设备地址（最可靠）

如果自动检测失败，直接使用已知的设备地址：

```dart
// 在代码中直接指定
await testState.testPythonBluetooth(
  deviceAddress: '00:11:22:33:44:55',  // 替换为实际地址
  channel: 5,
);
```

#### 如何获取设备地址

**方法 1**：Windows 设置
```
设置 → 蓝牙和其他设备 → 点击设备 → 更多蓝牙选项 → 查看属性
```

**方法 2**：PowerShell
```powershell
Get-PnpDevice -Class Bluetooth | Where-Object {$_.Status -eq "OK"} | Select-Object FriendlyName, InstanceId
```
从 InstanceId 中提取 12 位十六进制数字，转换为 MAC 地址格式。

**方法 3**：设备管理器
```
设备管理器 → 蓝牙 → 右键设备 → 属性 → 详细信息 → 蓝牙设备地址
```

---

### 5. 启用详细日志

确保在 Flutter 应用中启用 DEBUG 级别日志：

```dart
// 在 LogState 中设置
logState.setMinLevel(LogLevel.debug);
```

这样可以看到：
- Python 脚本的完整输出
- JSON 解析过程
- 设备列表解析详情

---

### 6. 测试流程对比

#### 命令行测试（成功）

```bash
python scripts/bluetooth_spp_test.py --paired

# 输出:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔗 查找已配对的蓝牙设备...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   正在查询系统蓝牙设备...

✅ 找到 1 个已配对设备:

1. Kanaan-00LI
   地址: 00:11:22:33:44:55

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
JSON_DEVICES_START
[{"name": "Kanaan-00LI", "address": "00:11:22:33:44:55"}]
JSON_DEVICES_END
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Flutter 应用测试（应该看到）

```
[INFO   ] 🔗 查找已配对的蓝牙设备...
[DEBUG  ] Python --paired 输出:
[DEBUG  ]    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[DEBUG  ]    🔗 查找已配对的蓝牙设备...
[DEBUG  ]    ...
[DEBUG  ]    JSON_DEVICES_START
[DEBUG  ]    [{"name": "Kanaan-00LI", "address": "00:11:22:33:44:55"}]
[DEBUG  ]    JSON_DEVICES_END
[DEBUG  ] JSON 标记位置: start=XXX, end=YYY
[DEBUG  ] 提取的 JSON: [{"name": "Kanaan-00LI", "address": "00:11:22:33:44:55"}]
[SUCCESS] ✅ 找到 1 个已配对设备
[INFO   ]    Kanaan-00LI (00:11:22:33:44:55)
```

---

### 7. 快速解决方案

如果调试太复杂，使用以下快速方案：

#### 方案 A: 直接指定设备地址和 Channel

```dart
// 跳过所有扫描和查找
await pythonBluetoothService.sendGTPCommand(
  deviceAddress: '00:11:22:33:44:55',  // 已知地址
  commandPayload: Uint8List.fromList([0x0D, 0x01]),
  channel: 5,  // 已知 Channel
);
```

#### 方案 B: 使用批处理脚本测试

```cmd
# 先用批处理脚本确认设备信息
test_bluetooth.bat paired

# 然后在应用中使用找到的地址
```

---

### 8. 报告问题时提供的信息

如果问题仍未解决，请提供以下信息：

1. **命令行输出**：
   ```bash
   python scripts/bluetooth_spp_test.py --paired > paired_output.txt
   ```

2. **Flutter 应用日志**：
   - 完整的 DEBUG 级别日志
   - 特别是"Python --paired 输出"部分

3. **系统信息**：
   - Windows 版本
   - Python 版本
   - PyBluez 版本

4. **设备信息**：
   - 设备名称
   - 是否已配对
   - 是否可连接

---

## 总结

### 优先级排序

1. ✅ **最高优先级**：直接使用已知地址和 Channel 5
2. ✅ **次优先级**：查看 DEBUG 日志，诊断问题
3. ✅ **最后手段**：手动提取设备地址

### 关键命令

```bash
# 测试 Python 脚本
python scripts/bluetooth_spp_test.py --paired

# 直接连接（最可靠）
python scripts/bluetooth_spp_test.py --connect 00:11:22:33:44:55 --channel 5 --test mac
```

### 关键配置

```dart
// Flutter 应用中直接指定
deviceAddress: '00:11:22:33:44:55'
channel: 5
uuid: '00007033-1000-8000-00805f9b34fb'
```
