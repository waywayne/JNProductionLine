# Linux 蓝牙权限配置指南

## 问题说明

在 Linux 系统上，使用蓝牙功能（如 `bluetoothctl`、`sdptool`、`rfcomm` 等）需要特定权限。

## 推荐方案：使用 sudo 运行

**最简单、最安全的方法是使用 sudo 运行应用：**

```bash
sudo jn-production-line
```

这样可以确保蓝牙功能正常工作，不会影响系统稳定性。

## 安装

运行安装脚本会自动配置串口和 RFCOMM 设备权限：

```bash
sudo ./scripts/install-linux.sh
```

安装脚本会配置：
- ✅ 串口设备权限（`/dev/ttyUSB*`, `/dev/ttyACM*`）
- ✅ RFCOMM 设备权限（`/dev/rfcomm*`）
- ❌ **不会**配置可能导致系统重启的 D-Bus 规则

### 清理旧配置

如果之前运行过旧版本的安装脚本，请清理可能导致问题的配置：

```bash
sudo ./scripts/cleanup-bluetooth-config.sh
```

这会移除可能导致 GNOME 桌面重启的 PolicyKit 和 D-Bus 配置文件。

### 验证蓝牙功能

使用 sudo 测试蓝牙扫描：

```bash
# 测试蓝牙扫描
sudo bash -c 'echo "scan on" | bluetoothctl'
sleep 5
sudo bash -c 'echo "scan off" | bluetoothctl'
sudo bash -c 'echo "devices" | bluetoothctl'
```

## 配置详情

安装脚本会自动配置 udev 规则：

### udev 规则

创建 `/etc/udev/rules.d/99-jn-production.rules`：

```
# Serial ports
KERNEL=="ttyUSB[0-9]*", MODE="0666"
KERNEL=="ttyACM[0-9]*", MODE="0666"

# Bluetooth RFCOMM devices
KERNEL=="rfcomm[0-9]*", MODE="0666"
```

这样配置后：
- 所有用户都可以访问串口设备
- 所有用户都可以访问 RFCOMM 设备
- 不需要重启系统服务
- 不会影响桌面环境

## 常见问题

### Q: 为什么推荐使用 sudo 运行？

**A**: 蓝牙操作（`bluetoothctl`、`sdptool`）需要访问系统 D-Bus 和蓝牙服务，这些默认需要 root 权限。虽然可以通过复杂的 PolicyKit 和 D-Bus 配置来允许普通用户访问，但这可能：
- 导致系统服务重启（如 D-Bus），进而导致桌面环境重启
- 引入安全风险
- 在不同发行版上行为不一致

使用 sudo 是最简单、最可靠的方案。

### Q: 之前的安装脚本导致桌面重启怎么办？

**A**: 运行清理脚本移除问题配置：

```bash
sudo ./scripts/cleanup-bluetooth-config.sh
```

然后重新运行安装脚本：

```bash
sudo ./scripts/install-linux.sh
```

### Q: 使用 sudo 运行应用安全吗？

**A**: 对于生产测试工具来说是可以接受的，因为：
- 生产测试环境通常是受控环境
- 应用需要访问硬件设备（串口、蓝牙）
- 使用 sudo 比配置复杂的权限规则更安全可靠

### Q: 能否不使用 sudo？

**A**: 理论上可以，但需要复杂的配置，且可能导致系统不稳定。不推荐在生产环境中尝试。

## 安全说明

当前配置仅设置了设备文件权限（串口和 RFCOMM），不涉及系统服务配置：

1. ✅ 串口设备（`/dev/ttyUSB*`, `/dev/ttyACM*`）设置为 `0666`
2. ✅ RFCOMM 设备（`/dev/rfcomm*`）设置为 `0666`
3. ❌ 不修改 PolicyKit 规则
4. ❌ 不修改 D-Bus 配置
5. ❌ 不重启系统服务

这样可以确保：
- 不会导致桌面环境重启
- 不会影响系统稳定性
- 配置简单可靠

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
