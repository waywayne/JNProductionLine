# Linux 蓝牙权限配置指南

## 问题说明

在 Linux 系统上，默认情况下使用蓝牙功能（如 `bluetoothctl`、`sdptool`、`rfcomm` 等）需要 root 权限。这会导致应用无法正常扫描和连接蓝牙设备。

## 解决方案

### 快速配置（推荐）

运行安装脚本会自动配置所有必要的权限：

```bash
sudo ./scripts/install-linux.sh
```

安装完成后，**必须重新登录**或运行以下命令使权限生效：

```bash
newgrp bluetooth
```

### 验证配置

运行测试脚本检查权限配置：

```bash
chmod +x scripts/test-bluetooth-permissions.sh
./scripts/test-bluetooth-permissions.sh
```

或手动验证：

```bash
# 1. 检查用户组
groups | grep bluetooth

# 2. 测试蓝牙扫描（应该无需 sudo）
bluetoothctl scan on
bluetoothctl scan off

# 3. 测试 SDP 查询（应该无需 sudo）
sdptool browse <设备MAC地址>
```

## 配置详情

安装脚本会自动完成以下配置：

### 1. 用户组配置

将当前用户添加到 `bluetooth` 组：

```bash
sudo usermod -a -G bluetooth $USER
```

### 2. PolicyKit 规则

创建 `/etc/polkit-1/rules.d/50-bluetooth.rules`，允许 `bluetooth` 组用户无需密码使用蓝牙功能。

### 3. D-Bus 规则

创建 `/etc/dbus-1/system.d/bluetooth-group.conf`，允许 `bluetooth` 组访问 BlueZ D-Bus 接口。

### 4. udev 规则

创建 `/etc/udev/rules.d/99-jn-production.rules`，设置蓝牙设备的组和权限：
- RFCOMM 设备：`bluetooth` 组，`0660` 权限
- HCI 设备：`bluetooth` 组，`0660` 权限
- 串口设备：`0666` 权限

### 5. 服务重启

重启 D-Bus 和蓝牙服务以应用新配置：

```bash
sudo systemctl restart dbus
sudo systemctl restart bluetooth
```

## 常见问题

### Q: 为什么配置后仍需要 sudo？

**A**: 用户组更改需要重新登录才能生效。

解决方法：
```bash
# 方法 1: 快速生效（仅当前终端）
newgrp bluetooth

# 方法 2: 注销并重新登录系统（推荐）
```

### Q: 如何确认权限已生效？

**A**: 运行以下命令应该无需 sudo：

```bash
bluetoothctl scan on
```

如果提示权限错误，说明配置未生效。

### Q: 手动配置步骤是什么？

**A**: 详见 [LINUX_BLUETOOTH_SPP.md](LINUX_BLUETOOTH_SPP.md) 的"手动配置"部分。

### Q: 某些发行版不支持 PolicyKit 怎么办？

**A**: 可以使用 sudo 包装器或修改 BlueZ 配置文件。建议使用支持 PolicyKit 的发行版（如 Ubuntu、Fedora、Debian 等）。

## 安全说明

这些配置允许 `bluetooth` 组的用户无需 root 权限使用蓝牙功能。这是安全的，因为：

1. 仅限于蓝牙相关操作
2. 需要明确将用户添加到 `bluetooth` 组
3. 不影响其他系统功能
4. 符合 Linux 最小权限原则

## 支持的系统

已测试的 Linux 发行版：
- ✅ Ubuntu 20.04+
- ✅ Debian 11+
- ✅ Fedora 35+
- ✅ Linux Mint 20+

其他使用 BlueZ 和 PolicyKit 的发行版应该也能正常工作。

## 相关文档

- [LINUX_BLUETOOTH_SPP.md](LINUX_BLUETOOTH_SPP.md) - Linux 蓝牙 SPP 实现详情
- [LINUX_BUILD_GUIDE.md](LINUX_BUILD_GUIDE.md) - Linux 构建指南
- [CI_BUILD_GUIDE.md](CI_BUILD_GUIDE.md) - CI 构建指南

## 技术参考

- [BlueZ Documentation](http://www.bluez.org/)
- [PolicyKit Manual](https://www.freedesktop.org/software/polkit/docs/latest/)
- [D-Bus Specification](https://dbus.freedesktop.org/doc/dbus-specification.html)
- [udev Rules](https://www.freedesktop.org/software/systemd/man/udev.html)
