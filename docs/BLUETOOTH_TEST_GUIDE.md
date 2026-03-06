# 蓝牙 SPP 测试指南

本指南介绍如何使用 Python 命令行工具单独测试蓝牙 SPP 连接。

## 前置条件

1. 已安装 Python 3.7+
2. 已安装 PyBluez：`pip install pybluez`
3. Windows 系统已启用蓝牙

## 测试步骤

### 1. 查看已配对的设备（推荐第一步）

```bash
python scripts/bluetooth_spp_test.py --paired
```

**输出示例**：
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔗 查找已配对的蓝牙设备...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

已配对的设备:
FriendlyName                    InstanceId
------------                    ----------
Kanaan-00LI                     BTHENUM\{00001101-...}\7&1234ABCD
Bluetooth Mouse                 BTHENUM\{00001124-...}\8&5678EFGH

提示: 可以直接使用设备的蓝牙地址连接
```

---

### 2. 扫描可发现的蓝牙设备

```bash
python scripts/bluetooth_spp_test.py --scan
```

**说明**：
- 最大扫描时间：1分钟
- 找到设备后立即返回
- 设备必须处于**可发现模式**

**输出示例**：
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 正在扫描蓝牙设备...
   最大扫描时间: 1分钟
   找到设备后立即返回
   提示: 请确保蓝牙已开启且设备可被发现
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   扫描中... (0秒)
   ✓ 发现设备: Kanaan-00LI (00:11:22:33:44:55)

✅ 找到 1 个设备，停止扫描

找到 1 个设备:

1. Kanaan-00LI
   地址: 00:11:22:33:44:55
```

---

### 3. 查找设备的服务和 RFCOMM Channel

#### 方式 A: 查找所有服务

```bash
python scripts/bluetooth_spp_test.py --services 00:11:22:33:44:55
```

#### 方式 B: 查找指定 UUID 的服务（推荐）

```bash
python scripts/bluetooth_spp_test.py --services 00:11:22:33:44:55 --uuid 00007033-1000-8000-00805f9b34fb
```

**输出示例**：
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 查找设备 00:11:22:33:44:55 的服务...
   UUID: 00007033-1000-8000-00805f9b34fb
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

找到 1 个服务:

服务 1:
  名称: Serial Port
  主机: 00:11:22:33:44:55
  RFCOMM Channel: 1          ← 记住这个 Channel 号
  服务 ID: 0x10001
  服务类: ['SerialPort']
  协议: RFCOMM
```

---

### 4. 连接设备并测试通信

#### 方式 A: 自动查找服务并连接（使用默认 UUID）

```bash
python scripts/bluetooth_spp_test.py --connect 00:11:22:33:44:55
```

#### 方式 B: 指定 RFCOMM Channel 直接连接（最快）

```bash
python scripts/bluetooth_spp_test.py --connect 00:11:22:33:44:55 --channel 1
```

#### 方式 C: 指定自定义 UUID

```bash
python scripts/bluetooth_spp_test.py --connect 00:11:22:33:44:55 --uuid 00007033-1000-8000-00805f9b34fb
```

**输出示例**：
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔗 连接到设备: 00:11:22:33:44:55
   UUID: 00007033-1000-8000-00805f9b34fb
   使用 RFCOMM Channel: 1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ 连接成功
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔌 已断开连接
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

### 5. 测试读取蓝牙 MAC 地址

```bash
python scripts/bluetooth_spp_test.py --connect 00:11:22:33:44:55 --channel 1 --test mac
```

**说明**：
- 发送 GTP 命令：`CMD=0x0D, OPT=0x01`
- 等待设备响应（5秒超时）

**输出示例**：
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔗 连接到设备: 00:11:22:33:44:55
   UUID: 00007033-1000-8000-00805f9b34fb
   使用 RFCOMM Channel: 1
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ 连接成功
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📖 测试: 读取蓝牙 MAC 地址
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📤 发送 GTP 命令...
   Module ID: 0x0000
   Message ID: 0x0000
   Payload: 0d 01

📥 接收数据...
   原始数据 (hex): c2 c5 d2 d0 00 1a 00 03 04 00 00 f5 00 00 00 00 00 00 0d 55 11 22 33 44 55 ab cd ef 12
   
✅ 测试完成

🔌 已断开连接
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 常见问题

### Q1: 扫描不到任何设备

**解决方案**：
1. ✅ **先在 Windows 设置中配对设备**
2. ✅ **使用 `--paired` 查看已配对设备**
3. ✅ **直接使用设备地址连接**
4. 确保设备蓝牙已开启
5. 确保设备处于可发现模式

### Q2: 连接失败

**检查清单**：
- [ ] 设备是否已配对？
- [ ] 设备蓝牙是否开启？
- [ ] UUID 是否正确？（项目默认：`00007033-1000-8000-00805f9b34fb`）
- [ ] RFCOMM Channel 是否正确？
- [ ] 设备是否被其他程序占用？

### Q3: 如何获取设备的蓝牙地址？

**方法 1**：Windows 设置
```
设置 → 蓝牙和其他设备 → 点击设备 → 查看属性
```

**方法 2**：使用 `--paired` 命令
```bash
python scripts/bluetooth_spp_test.py --paired
```

**方法 3**：使用 `--scan` 命令
```bash
python scripts/bluetooth_spp_test.py --scan
```

---

## 完整测试流程示例

```bash
# 1. 查看已配对设备
python scripts/bluetooth_spp_test.py --paired

# 2. 查找设备服务（获取 Channel）
python scripts/bluetooth_spp_test.py --services 00:11:22:33:44:55 --uuid 00007033-1000-8000-00805f9b34fb

# 3. 连接并测试（使用 Channel 1）
python scripts/bluetooth_spp_test.py --connect 00:11:22:33:44:55 --channel 1 --test mac

# 4. 如果成功，记录这些信息供后续使用：
#    - 设备地址: 00:11:22:33:44:55
#    - RFCOMM Channel: 1
#    - UUID: 00007033-1000-8000-00805f9b34fb
```

---

## 项目专用配置

### 默认 UUID
```
00007033-1000-8000-00805f9b34fb
```

### 常用命令

```bash
# 快速连接（已知地址和 Channel）
python scripts/bluetooth_spp_test.py --connect 00:11:22:33:44:55 --channel 1

# 查找服务
python scripts/bluetooth_spp_test.py --services 00:11:22:33:44:55

# 测试通信
python scripts/bluetooth_spp_test.py --connect 00:11:22:33:44:55 --channel 1 --test mac
```

---

## 参数说明

| 参数 | 说明 | 示例 |
|------|------|------|
| `--scan` | 扫描可发现的蓝牙设备 | `--scan` |
| `--paired` | 列出已配对的设备 | `--paired` |
| `--services ADDRESS` | 查找设备的服务 | `--services 00:11:22:33:44:55` |
| `--uuid UUID` | 指定服务 UUID | `--uuid 00007033-1000-8000-00805f9b34fb` |
| `--connect ADDRESS` | 连接到设备 | `--connect 00:11:22:33:44:55` |
| `--channel N` | 指定 RFCOMM Channel | `--channel 1` |
| `--test mac` | 测试读取 MAC 地址 | `--test mac` |

---

## 调试技巧

### 1. 查看详细错误信息

如果连接失败，查看完整的错误输出：

```bash
python scripts/bluetooth_spp_test.py --connect 00:11:22:33:44:55 --channel 1 2>&1
```

### 2. 测试不同的 Channel

如果不确定 Channel，可以逐个尝试：

```bash
python scripts/bluetooth_spp_test.py --connect 00:11:22:33:44:55 --channel 1
python scripts/bluetooth_spp_test.py --connect 00:11:22:33:44:55 --channel 2
python scripts/bluetooth_spp_test.py --connect 00:11:22:33:44:55 --channel 3
```

### 3. 验证 PyBluez 安装

```bash
python -c "import bluetooth; print('PyBluez version:', bluetooth.__version__)"
```

---

## 故障排除命令

```bash
# 检查 Python 版本
python --version

# 检查 PyBluez 是否安装
python -c "import bluetooth; print('OK')"

# 查看系统蓝牙适配器
python -c "import bluetooth; print('Local address:', bluetooth.read_local_bdaddr())"

# 测试基本蓝牙功能
python -c "import bluetooth; print('Devices:', bluetooth.discover_devices())"
```

---

## 成功标志

当看到以下输出时，表示连接成功：

```
✅ 连接成功
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

如果测试通信成功：

```
✅ 测试完成
```

---

## 下一步

成功测试后，可以在 Flutter 应用中使用相同的参数：

```dart
await pythonBluetoothService.sendGTPCommand(
  deviceAddress: '00:11:22:33:44:55',
  commandPayload: Uint8List.fromList([0x0D, 0x01]),
  channel: 1,  // 使用测试中找到的 Channel
);
```
