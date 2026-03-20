# Linux 蓝牙 RFCOMM 连接配对要求

## 问题描述

在 Linux 系统上使用 `rfcomm connect` 建立 RFCOMM 连接时，可能会遇到以下错误：

```
Can't connect RFCOMM socket: Connection refused
```

## 根本原因

**RFCOMM 连接需要设备先完成配对（Pairing）！**

这是 Linux BlueZ 蓝牙栈的安全要求：
1. **配对（Pairing）** - 设备之间建立信任关系
2. **信任（Trust）** - 标记设备为可信任
3. **连接（Connect）** - 建立蓝牙基础连接
4. **RFCOMM 绑定** - 在已连接的设备上建立 RFCOMM 通道

如果跳过前面的步骤直接执行 `rfcomm connect`，会被拒绝连接。

## 解决方案

### 完整的连接流程

```bash
# 1. 配对设备
bluetoothctl << EOF
power on
agent NoInputNoOutput
default-agent
pair AA:BB:CC:DD:EE:FF
yes
EOF

# 2. 信任设备
bluetoothctl << EOF
trust AA:BB:CC:DD:EE:FF
EOF

# 3. 连接设备
bluetoothctl << EOF
connect AA:BB:CC:DD:EE:FF
EOF

# 4. 建立 RFCOMM 连接
rfcomm connect 0 AA:BB:CC:DD:EE:FF 1
```

### 代码实现

应用已自动实现完整流程，在 `LinuxBluetoothSppService.connect()` 方法中：

```dart
// 1. 配对设备
final paired = await pairDevice(deviceAddress);

// 2. 信任设备
final trusted = await trustDevice(deviceAddress);

// 3. 建立蓝牙基础连接
final btConnected = await connectBluetoothDevice(deviceAddress);

// 4. 建立 RFCOMM 连接
final connectProcess = await Process.start('rfcomm', [
  'connect', '0', deviceAddress, targetChannel.toString()
]);
```

## 常见错误和解决方法

### 1. Connection refused

**原因**: 设备未配对或未连接

**解决**: 
```bash
# 检查配对状态
bluetoothctl paired-devices | grep AA:BB:CC:DD:EE:FF

# 检查连接状态
bluetoothctl info AA:BB:CC:DD:EE:FF | grep "Connected"
```

### 2. Input/output error

**原因**: 设备已断开或通道号错误

**解决**:
```bash
# 重新连接设备
bluetoothctl connect AA:BB:CC:DD:EE:FF

# 查询正确的通道号
sdptool browse AA:BB:CC:DD:EE:FF
```

### 3. Device not available

**原因**: 蓝牙适配器未开启或设备不在范围内

**解决**:
```bash
# 开启蓝牙适配器
hciconfig hci0 up
bluetoothctl power on

# 扫描设备
hcitool scan
```

## 配对模式说明

### NoInputNoOutput

适用于**无需 PIN 码**的设备（如生产测试设备）：

```bash
agent NoInputNoOutput
default-agent
```

### DisplayYesNo

适用于需要用户确认的设备：

```bash
agent DisplayYesNo
default-agent
```

### KeyboardDisplay

适用于需要输入 PIN 码的设备：

```bash
agent KeyboardDisplay
default-agent
# 然后输入 PIN 码
```

## 手动配对测试

如果自动配对失败，可以手动配对：

```bash
# 1. 进入 bluetoothctl 交互模式
sudo bluetoothctl

# 2. 开启蓝牙
[bluetooth]# power on

# 3. 设置代理
[bluetooth]# agent NoInputNoOutput
[bluetooth]# default-agent

# 4. 扫描设备
[bluetooth]# scan on
# 等待找到设备...
[bluetooth]# scan off

# 5. 配对
[bluetooth]# pair AA:BB:CC:DD:EE:FF

# 6. 信任
[bluetooth]# trust AA:BB:CC:DD:EE:FF

# 7. 连接
[bluetooth]# connect AA:BB:CC:DD:EE:FF

# 8. 退出
[bluetooth]# exit
```

## 清除配对

如果需要重新配对：

```bash
# 移除设备
bluetoothctl remove AA:BB:CC:DD:EE:FF

# 或移除所有设备
bluetoothctl remove *
```

## 调试技巧

### 查看详细日志

```bash
# 查看 bluetoothd 日志
sudo journalctl -u bluetooth -f

# 查看 dbus 日志
dbus-monitor --system "type='signal',interface='org.bluez.Device1'"
```

### 检查设备信息

```bash
# 查看设备详细信息
bluetoothctl info AA:BB:CC:DD:EE:FF

# 查看所有已配对设备
bluetoothctl paired-devices

# 查看所有已连接设备
bluetoothctl devices Connected
```

### 测试 RFCOMM 连接

```bash
# 查询 SPP 服务
sdptool browse AA:BB:CC:DD:EE:FF | grep -A 10 "Serial Port"

# 测试 RFCOMM 绑定
sudo rfcomm bind 0 AA:BB:CC:DD:EE:FF 1

# 检查设备文件
ls -l /dev/rfcomm0

# 测试读写
sudo cat /dev/rfcomm0 &
echo "test" | sudo tee /dev/rfcomm0
```

## 参考资料

- [BlueZ Documentation](http://www.bluez.org/documentation/)
- [RFCOMM Protocol](https://www.bluetooth.com/specifications/specs/rfcomm-1-1/)
- [Linux Bluetooth Wiki](https://wiki.archlinux.org/title/Bluetooth)
