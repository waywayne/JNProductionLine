# Linux 蓝牙连接完整解决方案总结

## 🎯 问题回顾

### 遇到的错误

1. **"Connection refused"** - RFCOMM 连接被拒绝
2. **"Invalid exchange"** - 无效的数据交换
3. **"br-connection-profile-unavailable"** - BR/EDR 连接配置文件不可用
4. **"Device not available"** - 设备不可用

### 根本原因

**Linux BlueZ 蓝牙栈要求完整的连接流程：**
1. 扫描设备
2. **配对设备** ← 关键步骤，之前缺失！
3. 信任设备
4. 连接设备
5. 建立 RFCOMM

## ✅ 完整解决方案

### 1. 扫描设备（支持 BLE）

**问题**：`hcitool scan` 只支持经典蓝牙，手机能搜到但 Linux 搜不到

**解决**：使用 `bluetoothctl scan`

```bash
(
  echo "power on"
  sleep 1
  echo "scan on"
  sleep 10
  echo "scan off"
  echo "devices"
) | bluetoothctl
```

**优点**：
- ✅ 支持 BLE 设备
- ✅ 支持现代蓝牙设备
- ✅ 与手机扫描方式一致

### 2. 配对设备（必须步骤）

**问题**：直接连接导致 "br-connection-profile-unavailable"

**解决**：先配对再连接

```bash
(
  echo "power on"
  sleep 1
  echo "agent on"
  sleep 1
  echo "default-agent"
  sleep 1
  echo "pair 48:08:EB:60:00:6A"
  sleep 5
  echo "trust 48:08:EB:60:00:6A"
  sleep 1
) | bluetoothctl
```

**关键点**：
- ✅ 使用 `agent on`（不是 `NoInputNoOutput`）
- ✅ 等待 5 秒让配对完成
- ✅ 配对后立即信任设备

### 3. 连接设备

```bash
echo "connect 48:08:EB:60:00:6A" | bluetoothctl
```

### 4. 验证连接

```bash
echo "info 48:08:EB:60:00:6A" | bluetoothctl | grep "Connected: yes"
```

### 5. SDP 查询通道

```bash
sdptool browse 48:08:EB:60:00:6A | grep -A 10 "7033"
```

### 6. 建立 RFCOMM（使用 bind 模式）

```bash
sudo rfcomm bind 0 48:08:EB:60:00:6A 5
```

## 📋 完整流程对比

### ❌ 之前的错误流程

```
扫描 (hcitool) → 连接 (bluetoothctl) → RFCOMM
                    ↓
                  失败！
```

### ✅ 正确的完整流程

```
扫描 (bluetoothctl) → 配对 (pair) → 信任 (trust) → 连接 (connect) → RFCOMM (bind)
                                                          ↓
                                                        成功！
```

## 🔍 关键发现

### 从日志中学到的

```
[CHG] Device 48:08:EB:60:00:6A Connected: yes
[CHG] Device 48:08:EB:60:00:6A UUIDs: 00007033-0000-1000-8000-00805f9b34fb
[CHG] Device 48:08:EB:60:00:6A ServicesResolved: yes
Failed to connect: org.bluez.Error.Failed br-connection-profile-unavailable
```

**分析**：
- ✅ 设备已发现
- ✅ UUID 已识别
- ✅ 服务已解析
- ❌ **但缺少 BR/EDR 连接配置文件** ← 因为没有配对！

### 为什么需要配对？

1. **安全性**：BR/EDR 连接需要建立信任关系
2. **配置文件**：配对过程会协商连接配置文件
3. **BlueZ 要求**：Linux BlueZ 栈强制要求配对

## 🚀 已实现的改进

### 1. 测试脚本

- ✅ `scripts/test-bluetooth-simple.sh` - 简化版（6步）
- ✅ `scripts/test-bluetooth-full.sh` - 完整版（7步）
- ✅ `scripts/test-rfcomm-bind.sh` - RFCOMM 专项测试

### 2. 应用代码

- ✅ `lib/services/linux_bluetooth_spp_service.dart`
  - 改用 `bluetoothctl scan`（支持 BLE）
  - 添加配对步骤
  - 使用 `rfcomm bind` 优先

### 3. 文档

- ✅ `docs/BLUETOOTH_PAIRING.md` - 配对详细说明
- ✅ `docs/BLUETOOTH_MANUAL_CONNECT.md` - 手动连接指南
- ✅ `docs/BLUETOOTH_CONNECTION_SUMMARY.md` - 本文档

## 📝 使用指南

### 测试脚本使用

```bash
# 简化版（推荐）
sudo ./scripts/test-bluetooth-simple.sh 48:08:EB:60:00:6A 7033

# 完整版
sudo ./scripts/test-bluetooth-full.sh -m 48:08:EB:60:00:6A -u 7033

# 自动模式
sudo ./scripts/test-bluetooth-full.sh -m 48:08:EB:60:00:6A -u 7033 --auto
```

### 应用集成

```dart
// 1. 扫描设备（支持 BLE）
final devices = await bluetoothService.scanDevices();

// 2. 连接设备（自动配对）
final connected = await bluetoothService.connect(
  deviceAddress,
  deviceName: deviceName,
  uuid: '7033',
);

// 3. 发送数据
await bluetoothService.sendCommandAndWaitResponse(command);
```

## ⚠️ 常见问题

### Q1: 为什么手机能搜到但 Linux 搜不到？

**A**: `hcitool scan` 只支持经典蓝牙，现代设备多使用 BLE。
**解决**: 使用 `bluetoothctl scan`

### Q2: 为什么连接时报 "br-connection-profile-unavailable"？

**A**: 设备未配对，缺少 BR/EDR 连接配置文件。
**解决**: 先执行 `pair` 命令

### Q3: 配对时需要 PIN 码怎么办？

**A**: 使用 `agent on` 而不是 `agent NoInputNoOutput`
**解决**: 系统会提示输入 PIN 码

### Q4: RFCOMM 连接后设备文件不存在？

**A**: 使用 `rfcomm connect` 需要保持进程运行
**解决**: 使用 `rfcomm bind` 模式

## 🎉 成功标志

运行测试脚本后，应该看到：

```
[1/6] 开启蓝牙并扫描设备...
✅ 找到设备

[2/6] 配对蓝牙设备...
✅ 设备已配对

[3/6] 连接蓝牙设备...
✅ 蓝牙已连接

[4/6] 验证蓝牙连接...
✅ 蓝牙已连接

[5/6] 查询 RFCOMM 通道...
✅ 找到通道: 5

[6/6] 建立 RFCOMM 连接...
✅ RFCOMM bind 成功
✅ 设备文件已创建: /dev/rfcomm0
✅ 设备可读写

✅ 测试成功！
```

## 📚 参考资料

- [BlueZ Documentation](http://www.bluez.org/documentation/)
- [Linux Bluetooth Wiki](https://wiki.archlinux.org/title/Bluetooth)
- [RFCOMM Protocol](https://www.bluetooth.com/specifications/specs/rfcomm-1-1/)
- [bluetoothctl Manual](https://manpages.debian.org/testing/bluez/bluetoothctl.1.en.html)

## 🔄 版本历史

- **v1.0** - 初始版本，使用 hcitool + rfcomm connect
- **v2.0** - 改用 bluetoothctl + rfcomm bind
- **v3.0** - 添加配对步骤，支持 BLE 设备（当前版本）

---

**最后更新**: 2026-03-20
**状态**: ✅ 已验证可用
