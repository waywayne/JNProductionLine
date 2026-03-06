# 🔵 蓝牙测试快速开始

## ⚡ 最快方式（推荐）

**如果已知设备地址，直接使用 Channel 5 连接（跳过扫描和服务查找）：**

```cmd
# 直接测试（最快，最可靠）
test_bluetooth.bat test 00:11:22:33:44:55 5

# 或使用 Python 命令
python scripts/bluetooth_spp_test.py --connect 00:11:22:33:44:55 --channel 5 --test mac
```

**项目默认配置：**
- RFCOMM Channel: **5**
- UUID: `00007033-1000-8000-00805f9b34fb`

---

## 🚀 完整测试（Windows）

### 方法 1: 使用批处理脚本（推荐）

双击 `test_bluetooth.bat` 查看所有命令，或在命令行中使用：

```cmd
# 1. 查看已配对设备（最简单）
test_bluetooth.bat paired

# 2. 扫描蓝牙设备
test_bluetooth.bat scan

# 3. 查找设备服务
test_bluetooth.bat services 00:11:22:33:44:55

# 4. 连接设备（使用 Channel 5）
test_bluetooth.bat connect 00:11:22:33:44:55 5

# 5. 测试通信（使用 Channel 5）
test_bluetooth.bat test 00:11:22:33:44:55 5
```

### 方法 2: 直接使用 Python 命令

```bash
# 1. 查看已配对设备
python scripts/bluetooth_spp_test.py --paired

# 2. 扫描蓝牙设备
python scripts/bluetooth_spp_test.py --scan

# 3. 查找设备服务
python scripts/bluetooth_spp_test.py --services 00:11:22:33:44:55 --uuid 00007033-1000-8000-00805f9b34fb

# 4. 连接设备（使用 Channel 5）
python scripts/bluetooth_spp_test.py --connect 00:11:22:33:44:55 --channel 5

# 5. 测试读取 MAC 地址（使用 Channel 5）
python scripts/bluetooth_spp_test.py --connect 00:11:22:33:44:55 --channel 5 --test mac
```

---

## 📋 典型测试流程

### 推荐流程（最简单）

```cmd
# 步骤 1: 在 Windows 设置中配对设备
# 设置 → 蓝牙和其他设备 → 添加设备

# 步骤 2: 查看已配对设备，获取设备地址
test_bluetooth.bat paired

# 输出示例：
# FriendlyName                    InstanceId
# ------------                    ----------
# Kanaan-00LI                     BTHENUM\{...}

# 步骤 3: 直接使用 Channel 5 测试（跳过服务查找）
test_bluetooth.bat test 00:11:22:33:44:55 5

# ✅ 成功！记录设备地址供后续使用
```

### 完整流程（如果需要查找 Channel）

```cmd
# 步骤 1: 扫描或查看已配对设备
test_bluetooth.bat scan
# 或
test_bluetooth.bat paired

# 步骤 2: 查找设备服务（获取 Channel 号）
test_bluetooth.bat services 00:11:22:33:44:55

# 输出示例：
# 服务 1:
#   名称: Serial Port
#   RFCOMM Channel: 5    ← 记住这个数字

# 步骤 3: 使用找到的 Channel 测试
test_bluetooth.bat test 00:11:22:33:44:55 5
```

### 后续测试（最快）

如果已知设备地址：

```cmd
# 直接测试（使用默认 Channel 5）
test_bluetooth.bat test 00:11:22:33:44:55 5
```

---

## ✅ 成功标志

### 连接成功
```
✅ 连接成功
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 通信成功
```
📤 发送 GTP 命令...
   Module ID: 0x0000
   Message ID: 0x0000
   Payload: 0d 01

📥 接收数据...
   原始数据 (hex): c2 c5 d2 d0 ...
   
✅ 测试完成
```

---

## ❌ 常见问题

### 问题 1: 扫描不到设备

**原因**: 设备未处于可发现模式

**解决**:
```cmd
# 方案 A: 先配对设备，然后查看已配对设备
test_bluetooth.bat paired

# 方案 B: 如果知道设备地址，直接连接
test_bluetooth.bat connect 00:11:22:33:44:55 1
```

### 问题 2: 连接失败

**检查清单**:
- [ ] 设备是否已配对？
- [ ] 设备蓝牙是否开启？
- [ ] Channel 号是否正确？
- [ ] 设备是否被其他程序占用？

**解决**:
```cmd
# 重新查找服务，确认 Channel
test_bluetooth.bat services 00:11:22:33:44:55
```

### 问题 3: PyBluez 未安装

**自动安装**:
```cmd
# 批处理脚本会自动安装
test_bluetooth.bat paired
```

**手动安装**:
```cmd
pip install pybluez
```

---

## 📖 详细文档

查看完整文档：[docs/BLUETOOTH_TEST_GUIDE.md](docs/BLUETOOTH_TEST_GUIDE.md)

---

## 🔧 项目配置

### 默认配置
```
UUID: 00007033-1000-8000-00805f9b34fb
RFCOMM Channel: 5
```

### 常用设备信息模板

```
设备名称: Kanaan-00LI
设备地址: 00:11:22:33:44:55
RFCOMM Channel: 5
UUID: 00007033-1000-8000-00805f9b34fb
```

---

## 💡 提示

1. **优先使用已配对设备** - 最可靠
2. **记录 Channel 号** - 避免重复查找
3. **使用批处理脚本** - 更简单
4. **测试成功后** - 在 Flutter 应用中使用相同参数

---

## 🎯 下一步

测试成功后，在 Flutter 应用中使用：

```dart
// 方式 1: 使用默认配置（推荐）
await pythonBluetoothService.sendGTPCommand(
  deviceAddress: '00:11:22:33:44:55',  // 从测试中获取
  commandPayload: Uint8List.fromList([0x0D, 0x01]),
  channel: 5,  // 使用 Channel 5
);

// 方式 2: 让应用自动处理（会使用默认 Channel 5）
await testState.testPythonBluetooth(
  deviceAddress: '00:11:22:33:44:55',
  channel: 5,
);
```

---

## 📞 需要帮助？

1. 查看详细文档：`docs/BLUETOOTH_TEST_GUIDE.md`
2. 查看脚本源码：`scripts/bluetooth_spp_test.py`
3. 运行帮助命令：`test_bluetooth.bat` （不带参数）
