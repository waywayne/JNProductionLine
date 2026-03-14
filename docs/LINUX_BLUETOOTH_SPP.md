# Linux 蓝牙 SPP 使用指南

## 权限配置

### 自动配置（推荐）

运行安装脚本会自动配置所有必要的权限：

```bash
sudo ./scripts/install-linux.sh
```

安装脚本会自动完成以下配置：
1. ✅ 将用户添加到 `bluetooth` 组
2. ✅ 配置 PolicyKit 规则允许蓝牙操作
3. ✅ 配置 D-Bus 规则允许访问 BlueZ
4. ✅ 配置 udev 规则设置设备权限
5. ✅ 重启蓝牙服务应用配置

**重要**：配置完成后需要重新登录或运行 `newgrp bluetooth` 使权限生效。

### 验证权限

```bash
# 检查是否在 bluetooth 组
groups | grep bluetooth

# 测试蓝牙扫描（应该无需 sudo）
bluetoothctl scan on
bluetoothctl scan off

# 测试 SDP 查询（应该无需 sudo）
sdptool browse <设备MAC地址>
```

### 手动配置（如果需要）

如果自动配置失败，可以手动执行以下步骤：

#### 1. 添加用户到 bluetooth 组

```bash
sudo usermod -a -G bluetooth $USER
```

#### 2. 配置 PolicyKit 规则

创建 `/etc/polkit-1/rules.d/50-bluetooth.rules`：

```javascript
/* Allow users in bluetooth group to use bluetoothctl without password */
polkit.addRule(function(action, subject) {
    if ((action.id == "org.bluez.hci0.Adapter1.StartDiscovery" ||
         action.id == "org.bluez.hci0.Adapter1.StopDiscovery" ||
         action.id == "org.bluez.hci0.Device1.Connect" ||
         action.id == "org.bluez.hci0.Device1.Disconnect" ||
         action.id == "org.bluez.hci0.Device1.Pair" ||
         action.id == "org.bluez") &&
        subject.isInGroup("bluetooth")) {
        return polkit.Result.YES;
    }
});
```

#### 3. 配置 D-Bus 规则

创建 `/etc/dbus-1/system.d/bluetooth-group.conf`：

```xml
<!DOCTYPE busconfig PUBLIC
 "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <policy group="bluetooth">
    <allow send_destination="org.bluez"/>
    <allow send_interface="org.bluez.Manager"/>
    <allow send_interface="org.bluez.Adapter"/>
    <allow send_interface="org.bluez.Device"/>
    <allow send_interface="org.bluez.Service"/>
    <allow send_interface="org.bluez.Agent"/>
    <allow send_interface="org.bluez.ProfileManager1"/>
    <allow send_interface="org.bluez.AgentManager1"/>
    <allow send_interface="org.freedesktop.DBus.Properties"/>
    <allow send_interface="org.freedesktop.DBus.ObjectManager"/>
  </policy>
</busconfig>
```

#### 4. 配置 udev 规则

创建 `/etc/udev/rules.d/99-bluetooth.rules`：

```
# Bluetooth RFCOMM devices
KERNEL=="rfcomm[0-9]*", GROUP="bluetooth", MODE="0660"

# Bluetooth HCI devices
KERNEL=="hci[0-9]*", GROUP="bluetooth", MODE="0660"
```

#### 5. 应用配置

```bash
# 重新加载 udev 规则
sudo udevadm control --reload-rules
sudo udevadm trigger

# 重启服务
sudo systemctl restart dbus
sudo systemctl restart bluetooth

# 重新登录或刷新组
newgrp bluetooth
```

### 故障排除

#### 问题：仍然需要 sudo 才能扫描蓝牙

**可能原因**：
1. 用户未在 bluetooth 组中
2. 未重新登录使组权限生效
3. PolicyKit 或 D-Bus 规则未生效

**解决方案**：
```bash
# 1. 确认在 bluetooth 组
groups | grep bluetooth

# 2. 如果不在，添加并重新登录
sudo usermod -a -G bluetooth $USER
# 然后注销重新登录

# 3. 检查服务状态
systemctl status bluetooth
systemctl status dbus

# 4. 查看 PolicyKit 日志
journalctl -u polkit -n 50

# 5. 测试 D-Bus 访问
dbus-send --system --print-reply --dest=org.bluez / org.freedesktop.DBus.Introspectable.Introspect
```

#### 问题：rfcomm bind 失败

**解决方案**：
```bash
# 检查 rfcomm 模块
lsmod | grep rfcomm

# 如果未加载，加载模块
sudo modprobe rfcomm

# 设置开机自动加载
echo "rfcomm" | sudo tee -a /etc/modules
```

## 概述

基于 Linux 蓝牙栈实现的 SPP (Serial Port Profile) 协议通信服务，支持：
- 自定义 UUID 服务发现
- RFCOMM 通道自动绑定
- SPP 协议收发消息

## 蓝牙扫描策略

应用使用双重扫描策略确保可靠性：

### 主要方法：hcitool
- **优点**：实时扫描，不依赖缓存，每次都能发现新设备
- **命令**：`hcitool scan --flush`
- **特点**：直接与蓝牙硬件交互，绕过 BlueZ 缓存

### 备用方法：bluetoothctl
- **优点**：可以获取更详细的设备信息
- **命令**：`bluetoothctl scan on/off`
- **特点**：如果 hcitool 失败，自动切换到此方法

### 为什么需要两种方法？
1. **hcitool** 更可靠，但在某些系统上可能被弃用
2. **bluetoothctl** 更现代，但依赖缓存，重复扫描可能失效
3. 双重策略确保在各种环境下都能正常工作

## 系统要求

### Linux 环境
- BlueZ 蓝牙栈
- `bluetoothctl` 命令行工具
- `sdptool` SDP 查询工具
- `rfcomm` RFCOMM 工具
- `socat` 数据转发工具

### 安装依赖

```bash
# Ubuntu/Debian
sudo apt-get install bluez bluez-tools socat

# Fedora/RHEL
sudo dnf install bluez bluez-tools socat
```

## 核心功能

### 1. 蓝牙设备扫描

```dart
final devices = await linuxBtService.scanDevices(
  timeout: Duration(seconds: 10)
);

// 返回格式: [{'address': 'AA:BB:CC:DD:EE:FF', 'name': 'Device Name'}, ...]
```

### 2. 服务发现 (SDP)

通过 SDP 协议查询设备支持的服务和 RFCOMM 通道：

```dart
final channel = await linuxBtService.discoverServiceChannel(
  deviceAddress,
  uuid: '00001101-0000-1000-8000-00805F9B34FB', // SPP UUID
);
```

### 3. 连接设备

```dart
final connected = await linuxBtService.connect(
  deviceAddress,
  deviceName: deviceName,
  channel: channel,  // 可选，不指定则自动发现
  uuid: customUuid,  // 可选，默认使用 SPP UUID
);
```

### 4. 发送和接收数据

```dart
// 发送数据
await linuxBtService.sendData(command);

// 发送命令并等待响应
final response = await linuxBtService.sendCommandAndWaitResponse(
  command,
  timeout: Duration(seconds: 5),
);
```

## 工作原理

### 连接流程

1. **扫描设备**: 使用 `bluetoothctl scan on` 扫描附近的蓝牙设备
2. **服务发现**: 使用 `sdptool browse` 查询设备的 SDP 记录
3. **解析 UUID**: 查找匹配的服务 UUID 和对应的 RFCOMM 通道号
4. **绑定通道**: 使用 `rfcomm bind` 将 RFCOMM 通道绑定到 `/dev/rfcomm0`
5. **建立连接**: 使用 `socat` 建立与设备文件的连接
6. **数据通信**: 通过标准输入输出进行数据收发

### RFCOMM 通道绑定

```bash
# 绑定 RFCOMM 通道
rfcomm bind 0 AA:BB:CC:DD:EE:FF 1

# 查看绑定状态
rfcomm show

# 解除绑定
rfcomm release 0
```

### 数据通信

使用 `socat` 建立双向数据流：

```bash
socat - FILE:/dev/rfcomm0,b115200,raw,echo=0
```

## 使用示例

### 基本测试

```dart
// 测试 Linux 蓝牙连接
final success = await testState.testLinuxBluetooth();
```

### 自定义 UUID 测试

```dart
// 使用自定义 UUID
final success = await testState.testLinuxBluetooth(
  uuid: '00001101-0000-1000-8000-00805F9B34FB',
  channel: 1,
);
```

### 指定设备测试

```dart
// 连接指定设备
final success = await testState.testLinuxBluetooth(
  deviceAddress: 'AA:BB:CC:DD:EE:FF',
  deviceName: 'My Device',
);
```

## 整机产测集成

在整机产测流程中，Linux 蓝牙 SPP 用于：

1. **设备识别**: 扫描并识别待测设备
2. **服务发现**: 自动发现设备支持的 SPP 服务
3. **通道绑定**: 自动绑定到正确的 RFCOMM 通道
4. **数据通信**: 发送测试命令并接收响应
5. **结果验证**: 验证设备响应是否符合预期

## 故障排查

### 扫描不到设备

```bash
# 检查蓝牙服务状态
sudo systemctl status bluetooth

# 启动蓝牙服务
sudo systemctl start bluetooth

# 检查蓝牙适配器
hciconfig
```

### 连接失败

```bash
# 检查设备是否已配对
bluetoothctl paired-devices

# 配对设备
bluetoothctl pair AA:BB:CC:DD:EE:FF

# 信任设备
bluetoothctl trust AA:BB:CC:DD:EE:FF
```

### RFCOMM 绑定失败

```bash
# 检查是否已有绑定
rfcomm show

# 释放旧绑定
sudo rfcomm release 0

# 检查设备文件权限
ls -l /dev/rfcomm*
```

## 注意事项

1. **权限要求**: 需要 root 权限或加入 `bluetooth` 用户组
2. **设备配对**: 首次连接需要先配对设备
3. **通道冲突**: 确保 RFCOMM 通道未被占用
4. **超时设置**: 根据设备响应速度调整超时时间
5. **错误处理**: 连接失败后需要清理 RFCOMM 绑定

## 与其他蓝牙方案对比

| 方案 | 平台支持 | UUID 支持 | 通道发现 | 实现方式 |
|------|---------|----------|---------|---------|
| Linux SPP | Linux | ✅ 自定义 | ✅ 自动 | 系统工具 |
| Flutter SPP | Android/Windows | ❌ 标准 | ❌ 固定 | 插件库 |
| Python SPP | 跨平台 | ✅ 自定义 | ✅ 自动 | PyBluez |

## 参考资料

- [BlueZ 官方文档](http://www.bluez.org/)
- [RFCOMM 协议规范](https://www.bluetooth.com/specifications/specs/rfcomm-1-1/)
- [SPP Profile 规范](https://www.bluetooth.com/specifications/specs/serial-port-profile-1-2/)
