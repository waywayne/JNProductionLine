# 蓝牙手动连接指南

## 问题：为什么脚本连接失败但系统设置可以连接？

### 原因分析

1. **设备需要用户确认配对** - 系统设置会弹出配对确认对话框
2. **代理模式不匹配** - `NoInputNoOutput` 代理不适用于需要确认的设备
3. **设备可发现模式** - 系统设置会自动处理设备发现

## 解决方案

### 方法1：使用 bluetoothctl 交互模式（推荐）

```bash
# 1. 进入 bluetoothctl 交互模式
sudo bluetoothctl

# 2. 在 bluetoothctl 提示符下执行以下命令：
[bluetooth]# power on
[bluetooth]# agent on
[bluetooth]# default-agent
[bluetooth]# scan on

# 等待几秒，看到你的设备后：
[bluetooth]# scan off

# 3. 连接设备（会弹出配对请求）
[bluetooth]# connect 48:08:EB:60:00:6A

# 如果提示配对确认，输入：
[bluetooth]# yes

# 4. 信任设备（可选，避免下次重新配对）
[bluetooth]# trust 48:08:EB:60:00:6A

# 5. 退出
[bluetooth]# quit
```

### 方法2：使用 expect 自动化（需要安装 expect）

```bash
# 安装 expect
sudo apt-get install expect

# 运行简化脚本
sudo /path/to/test-bluetooth-simple.sh 48:08:EB:60:00:6A 7033
```

### 方法3：使用 D-Bus 直接连接（最可靠）

```bash
# 1. 获取设备路径
DEVICE_PATH=$(dbus-send --system --print-reply \
  --dest=org.bluez \
  / \
  org.freedesktop.DBus.ObjectManager.GetManagedObjects \
  | grep -A 1 "48:08:EB:60:00:6A" \
  | grep "object path" \
  | awk '{print $3}' \
  | tr -d '"')

# 2. 连接设备
dbus-send --system --print-reply \
  --dest=org.bluez \
  "$DEVICE_PATH" \
  org.bluez.Device1.Connect

# 3. 配对设备
dbus-send --system --print-reply \
  --dest=org.bluez \
  "$DEVICE_PATH" \
  org.bluez.Device1.Pair
```

## 完整手动测试流程

### 步骤 1: 准备设备

确保蓝牙设备：
- ✅ 已开机
- ✅ 处于可发现模式
- ✅ 在蓝牙范围内（< 10米）

### 步骤 2: 扫描设备

```bash
# 方法 A: 使用 hcitool
sudo hcitool scan

# 方法 B: 使用 bluetoothctl
echo "scan on" | bluetoothctl
sleep 5
echo "scan off" | bluetoothctl
echo "devices" | bluetoothctl
```

### 步骤 3: 交互式连接

```bash
# 启动 bluetoothctl
sudo bluetoothctl

# 执行连接命令
power on
agent on
default-agent
connect 48:08:EB:60:00:6A

# 等待配对提示，输入 yes
```

### 步骤 4: 验证连接

```bash
# 检查连接状态
echo "info 48:08:EB:60:00:6A" | bluetoothctl | grep "Connected"

# 应该显示: Connected: yes
```

### 步骤 5: SDP 查询

```bash
# 查询服务和通道
sudo sdptool browse 48:08:EB:60:00:6A | grep -A 10 "7033"

# 记录 Channel 号（例如：5）
```

### 步骤 6: 建立 RFCOMM

```bash
# 使用 bind 模式
sudo rfcomm bind 0 48:08:EB:60:00:6A 5

# 检查设备文件
ls -l /dev/rfcomm0

# 测试读写
sudo cat /dev/rfcomm0 &
echo "test" | sudo tee /dev/rfcomm0
```

## 常见问题

### Q1: "Device not available"

**原因**: 设备不在可发现模式或不在范围内

**解决**:
1. 确保设备已开机
2. 将设备设置为可发现模式
3. 靠近设备（< 5米）
4. 先用 `hcitool scan` 扫描确认设备可见

### Q2: "Failed to register agent"

**原因**: 已有其他代理注册

**解决**:
```bash
# 重启 bluetooth 服务
sudo systemctl restart bluetooth

# 或杀掉所有 bluetoothctl 进程
sudo pkill bluetoothctl
```

### Q3: "Connection refused"

**原因**: 设备未配对或未连接

**解决**:
1. 先配对: `pair 48:08:EB:60:00:6A`
2. 再连接: `connect 48:08:EB:60:00:6A`
3. 信任设备: `trust 48:08:EB:60:00:6A`

### Q4: "Invalid exchange"

**原因**: 蓝牙基础连接未建立

**解决**:
```bash
# 确保先建立蓝牙连接
echo "connect 48:08:EB:60:00:6A" | bluetoothctl
sleep 3

# 验证连接
echo "info 48:08:EB:60:00:6A" | bluetoothctl | grep "Connected: yes"

# 然后再执行 rfcomm
sudo rfcomm bind 0 48:08:EB:60:00:6A 5
```

## 应用集成建议

### 方案 1: 要求用户先在系统设置中配对

**优点**: 最简单可靠
**缺点**: 需要用户手动操作

```dart
// 在应用中提示用户
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('蓝牙配对'),
    content: Text(
      '请先在系统设置中配对蓝牙设备：\n'
      '1. 打开系统设置 > 蓝牙\n'
      '2. 找到设备并点击连接\n'
      '3. 确认配对请求\n'
      '4. 返回应用继续'
    ),
  ),
);
```

### 方案 2: 使用 D-Bus API

**优点**: 完全控制，可以处理配对请求
**缺点**: 需要实现 D-Bus 通信

```dart
// 使用 dbus 包
import 'package:dbus/dbus.dart';

Future<void> connectDevice(String mac) async {
  final client = DBusClient.system();
  
  // 连接设备
  await client.callMethod(
    destination: 'org.bluez',
    path: DBusObjectPath('/org/bluez/hci0/dev_${mac.replaceAll(':', '_')}'),
    interface: 'org.bluez.Device1',
    name: 'Connect',
  );
}
```

### 方案 3: 使用 expect 脚本

**优点**: 可以自动化交互
**缺点**: 需要安装 expect

```bash
#!/usr/bin/expect -f
spawn bluetoothctl
send "connect 48:08:EB:60:00:6A\r"
expect "Request confirmation"
send "yes\r"
expect "Connection successful"
```

## 推荐流程

对于生产测试应用，推荐以下流程：

1. **首次使用**: 提示用户在系统设置中配对设备
2. **后续使用**: 应用自动连接已配对设备
3. **连接失败**: 提示用户检查设备状态或重新配对

```dart
Future<bool> connectBluetooth(String mac) async {
  // 1. 检查是否已配对
  final paired = await checkPaired(mac);
  
  if (!paired) {
    // 提示用户手动配对
    await showPairingDialog();
    return false;
  }
  
  // 2. 连接已配对设备
  final connected = await connectPairedDevice(mac);
  
  if (!connected) {
    // 提示重新配对
    await showRepairDialog();
    return false;
  }
  
  // 3. 建立 RFCOMM
  return await establishRFCOMM(mac);
}
```

## 测试脚本

已提供以下测试脚本：

1. **test-bluetooth-full.sh** - 完整7步测试（已修复语法）
2. **test-bluetooth-simple.sh** - 简化版，模拟系统设置连接
3. **test-rfcomm-bind.sh** - 专门测试 RFCOMM bind 模式

使用方法：
```bash
# 简化版（推荐先用这个）
sudo ./scripts/test-bluetooth-simple.sh 48:08:EB:60:00:6A 7033

# 完整版
sudo ./scripts/test-bluetooth-full.sh -m 48:08:EB:60:00:6A -u 7033
```
