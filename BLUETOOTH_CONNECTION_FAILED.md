# 🔴 蓝牙连接失败诊断

## 当前问题

根据日志，连接失败的具体信息：

```
✅ 找到已配对设备: Kanaan-00KX (48:08:EB:60:00:00)
🔍 查找设备服务...
✅ 找到 0 个服务  ← 关键问题：找不到服务
⚠️  未找到服务，将使用默认配置
   使用默认 RFCOMM Channel: 5

🔗 连接到设备: 48:08:EB:60:00:00
   UUID: 00007033-1000-8000-00805f9b34fb
   使用 RFCOMM Channel: 5

❌ 错误:   ← 连接失败，但错误信息为空
```

---

## 问题分析

### 问题 1: 找不到服务

```
🔍 查找设备服务: 48:08:EB:60:00:00
   UUID: 00007033-1000-8000-00805f9b34fb
✅ 找到 0 个服务
```

**原因**：
- UUID `00007033-1000-8000-00805f9b34fb` 可能不是设备实际使用的 UUID
- 设备可能使用标准 SPP UUID: `00001101-0000-1000-8000-00805f9b34fb`
- 设备可能没有注册任何 SDP 服务

### 问题 2: Channel 5 连接失败

**可能原因**：
1. ❌ **Channel 不正确** - 设备可能使用其他 Channel (1-30)
2. ❌ **设备未开启 SPP 服务** - 设备蓝牙已连接但 SPP 未启用
3. ❌ **设备被占用** - 其他程序正在使用该连接
4. ❌ **权限问题** - Windows 蓝牙权限不足

---

## 解决方案

### 方案 1: 查找所有服务（不指定 UUID）

```bash
# 查找设备的所有服务
python scripts/bluetooth_spp_test.py --services 48:08:EB:60:00:00

# 不要指定 --uuid 参数，让它列出所有服务
```

**预期输出**：
```
找到 X 个服务:

服务 1:
  名称: Serial Port
  主机: 48:08:EB:60:00:00
  RFCOMM Channel: X    ← 这就是正确的 Channel
  服务 ID: 0x10001
  服务类: ['SerialPort']
  协议: RFCOMM
```

---

### 方案 2: 尝试标准 SPP UUID

```bash
# 使用标准 SPP UUID
python scripts/bluetooth_spp_test.py --services 48:08:EB:60:00:00 --uuid 00001101-0000-1000-8000-00805f9b34fb
```

---

### 方案 3: 逐个测试 Channel

```bash
# 使用批处理脚本自动测试
test_channels.bat 48:08:EB:60:00:00

# 或手动测试
python scripts/bluetooth_spp_test.py --connect 48:08:EB:60:00:00 --channel 1
python scripts/bluetooth_spp_test.py --connect 48:08:EB:60:00:00 --channel 2
python scripts/bluetooth_spp_test.py --connect 48:08:EB:60:00:00 --channel 3
# ... 直到找到可以连接的 Channel
```

---

### 方案 4: 检查设备状态

#### 步骤 1: 确认设备已配对且连接

```
Windows 设置 → 蓝牙和其他设备 → Kanaan-00KX
状态应该显示: "已连接"
```

#### 步骤 2: 检查设备服务

```
设备管理器 → 蓝牙 → Kanaan-00KX → 右键 → 属性 → 服务
```

查看是否启用了"串行端口"服务。

#### 步骤 3: 断开并重新连接

```
Windows 设置 → 蓝牙 → Kanaan-00KX → 断开连接
等待 5 秒
Windows 设置 → 蓝牙 → Kanaan-00KX → 连接
```

---

### 方案 5: 使用 Windows COM 端口

如果设备支持 SPP，Windows 会自动创建虚拟 COM 端口。

#### 查找 COM 端口

```
设备管理器 → 端口 (COM 和 LPT)
```

查找类似 "Standard Serial over Bluetooth link (COM3)" 的设备。

#### 使用 COM 端口连接

如果找到 COM 端口（如 COM3），可以直接使用串口连接：

```dart
// 在 Flutter 应用中
await serialService.connect('COM3', 115200);
```

这比蓝牙 SPP 更可靠！

---

## 快速测试命令

### 1. 查找所有服务

```bash
python scripts/bluetooth_spp_test.py --services 48:08:EB:60:00:00
```

### 2. 测试标准 SPP

```bash
python scripts/bluetooth_spp_test.py --connect 48:08:EB:60:00:00 --channel 1 --uuid 00001101-0000-1000-8000-00805f9b34fb
```

### 3. 测试不同 Channel

```bash
# Channel 1
python scripts/bluetooth_spp_test.py --connect 48:08:EB:60:00:00 --channel 1

# Channel 2
python scripts/bluetooth_spp_test.py --connect 48:08:EB:60:00:00 --channel 2

# Channel 3
python scripts/bluetooth_spp_test.py --connect 48:08:EB:60:00:00 --channel 3
```

---

## 常见错误和解决方法

### 错误 1: "An existing connection was forcibly closed"

**原因**: 设备突然断开或被其他程序占用

**解决**:
1. 断开设备并重新连接
2. 关闭其他可能使用蓝牙的程序
3. 重启蓝牙适配器

### 错误 2: "No route to host"

**原因**: 设备不在范围内或未开启

**解决**:
1. 确认设备已开启
2. 将设备靠近电脑
3. 检查设备电量

### 错误 3: "Permission denied"

**原因**: Windows 蓝牙权限不足

**解决**:
1. 以管理员身份运行程序
2. 检查 Windows 蓝牙权限设置
3. 重新配对设备

### 错误 4: "Connection refused"

**原因**: Channel 不正确或服务未启用

**解决**:
1. 使用 `--services` 查找正确的 Channel
2. 尝试其他 Channel
3. 检查设备是否启用了 SPP 服务

---

## 推荐流程

### 第一步: 查找服务

```bash
python scripts/bluetooth_spp_test.py --services 48:08:EB:60:00:00
```

**如果找到服务**：
- 记录 RFCOMM Channel 号
- 使用该 Channel 连接

**如果没有找到服务**：
- 进入第二步

### 第二步: 测试 Channel

```bash
test_channels.bat 48:08:EB:60:00:00
```

**如果找到可用 Channel**：
- 记录该 Channel 号
- 在应用中使用该 Channel

**如果所有 Channel 都失败**：
- 进入第三步

### 第三步: 使用 COM 端口

1. 打开设备管理器
2. 查找蓝牙 COM 端口
3. 使用串口连接代替蓝牙 SPP

---

## 下一步行动

请按顺序执行以下命令，并分享输出：

```bash
# 1. 查找所有服务（不指定 UUID）
python scripts/bluetooth_spp_test.py --services 48:08:EB:60:00:00

# 2. 如果上面没有找到服务，尝试标准 SPP UUID
python scripts/bluetooth_spp_test.py --services 48:08:EB:60:00:00 --uuid 00001101-0000-1000-8000-00805f9b34fb

# 3. 测试 Channel 1
python scripts/bluetooth_spp_test.py --connect 48:08:EB:60:00:00 --channel 1

# 4. 如果 Channel 1 失败，使用自动测试脚本
test_channels.bat 48:08:EB:60:00:00
```

---

## 临时解决方案

如果蓝牙 SPP 一直无法工作，可以使用以下替代方案：

### 方案 A: 使用蓝牙 COM 端口

```dart
// 在 Flutter 应用中直接使用 COM 端口
await serialService.connect('COM3', 115200);  // 替换为实际的 COM 端口号
```

### 方案 B: 使用 USB 连接

如果设备支持 USB 连接，这是最可靠的方式。

### 方案 C: 修改设备固件

如果可以修改设备固件，确保：
1. 启用 SPP 服务
2. 注册正确的 SDP 服务
3. 使用标准 SPP UUID: `00001101-0000-1000-8000-00805f9b34fb`

---

## 总结

**关键问题**: Channel 5 不正确

**解决方向**:
1. ✅ 查找设备的所有服务
2. ✅ 找到正确的 RFCOMM Channel
3. ✅ 使用正确的 Channel 连接
4. ✅ 或使用蓝牙 COM 端口代替

**下一步**: 运行 `python scripts/bluetooth_spp_test.py --services 48:08:EB:60:00:00` 并分享输出
