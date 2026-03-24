# 蓝牙产测脚本使用指南

## 📋 脚本列表

### 连接管理
- `bt-connect-by-sn.sh` - 根据 SN 码连接蓝牙设备
- `bt-disconnect.sh` - 断开蓝牙连接

### 通用指令发送
- `bt-send-gtp-command.sh` - 发送自定义 GTP 封装指令

### 产测指令
- `bt-test-wake-device.sh` - 唤醒设备 (CMD: 0x00)
- `bt-test-production-start.sh` - 产测开始 (CMD: 0x01)
- `bt-test-get-voltage.sh` - 获取电压 (CMD: 0x02)
- `bt-test-led.sh` - LED 测试 (CMD: 0x03)
- `bt-test-touch.sh` - Touch 测试 (CMD: 0x04)
- `bt-test-ultrasonic.sh` - 超声测试 (CMD: 0x05)
- `bt-test-motor.sh` - 马达测试 (CMD: 0x06)
- `bt-test-mic.sh` - 麦克风测试 (CMD: 0x07)
- `bt-test-speaker.sh` - 扬声器测试 (CMD: 0x08)

## 🚀 快速开始

### 1. 添加执行权限
```bash
cd scripts
chmod +x bt-*.sh
```

### 2. 连接设备
```bash
# 使用 SN 码连接
sudo ./bt-connect-by-sn.sh JN001F001L001240324000001
```

**连接流程：**
1. 查询设备信息（从 API 获取蓝牙地址）
2. 开启蓝牙适配器
3. 配对和信任设备
4. 清理旧连接
5. 建立 RFCOMM 连接（使用默认通道 5）
6. 启动后台读取进程

**连接成功后会显示：**
```
✅ 蓝牙连接成功！
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
设备地址: 48:08:EB:60:00:6A
RFCOMM 通道: 5
设备文件: /dev/rfcomm0
读取进程 PID: 12345
日志文件: /tmp/rfcomm0.log
```

### 3. 执行产测指令

#### 唤醒设备
```bash
sudo ./bt-test-wake-device.sh
```

#### 产测开始
```bash
sudo ./bt-test-production-start.sh
```

#### 获取电压
```bash
sudo ./bt-test-get-voltage.sh
```

#### LED 测试
```bash
# 测试 LED 1
sudo ./bt-test-led.sh 1

# 测试 LED 2
sudo ./bt-test-led.sh 2
```

#### Touch 测试
```bash
# 测试左侧 Touch
sudo ./bt-test-touch.sh 0

# 测试右侧 Touch
sudo ./bt-test-touch.sh 1
```

#### 超声测试
```bash
sudo ./bt-test-ultrasonic.sh
```

#### 马达测试
```bash
# 测试左侧马达
sudo ./bt-test-motor.sh 0

# 测试右侧马达
sudo ./bt-test-motor.sh 1
```

#### 麦克风测试
```bash
# 测试左侧麦克风
sudo ./bt-test-mic.sh 0

# 测试右侧麦克风
sudo ./bt-test-mic.sh 1
```

#### 扬声器测试
```bash
# 测试左侧扬声器
sudo ./bt-test-speaker.sh 0

# 测试右侧扬声器
sudo ./bt-test-speaker.sh 1
```

### 4. 断开连接
```bash
sudo ./bt-disconnect.sh
```

## 🔧 高级用法

### 发送自定义指令
```bash
# 格式: sudo ./bt-send-gtp-command.sh <CMD> [OPT] [DATA...]

# 示例 1: 只有 CMD
sudo ./bt-send-gtp-command.sh 00

# 示例 2: CMD + OPT
sudo ./bt-send-gtp-command.sh 01 00

# 示例 3: CMD + OPT + DATA
sudo ./bt-send-gtp-command.sh 03 00 01

# 示例 4: CMD + OPT + 多个 DATA
sudo ./bt-send-gtp-command.sh 0A 00 01 02 03
```

### 查看接收日志
```bash
# 实时查看
tail -f /tmp/rfcomm0.log

# 查看十六进制
tail -f /tmp/rfcomm0.log | xxd
```

### 手动读取响应
```bash
# 读取 3 秒
timeout 3 cat /dev/rfcomm0 | xxd

# 持续读取
cat /dev/rfcomm0 | xxd
```

## 📊 GTP 协议格式

```
┌─────────────┬──────────┬───────────┬────────────┬─────────┬─────────┬────────┬─────────┬──────────┬─────┐
│  Preamble   │  Length  │ Module ID │ Message ID │ Version │ Encrypt │ Seq No │ Payload │ Reserved │ CRC │
├─────────────┼──────────┼───────────┼────────────┼─────────┼─────────┼────────┼─────────┼──────────┼─────┤
│ D0 D2 C5 C2 │ 2 bytes  │  03 04    │ FE 23 23 06│   01    │   FF    │ 2 bytes│ N bytes │ 00 00 00 │2 byt│
│  (4 bytes)  │  (LE)    │ (2 bytes) │  (4 bytes) │(1 byte) │(1 byte) │(2 byt) │         │  00 (4B) │es   │
└─────────────┴──────────┴───────────┴────────────┴─────────┴─────────┴────────┴─────────┴──────────┴─────┘
```

**Payload 格式：**
```
┌─────┬─────┬──────────┐
│ CMD │ OPT │   DATA   │
├─────┼─────┼──────────┤
│1 byt│1 byt│ N bytes  │
└─────┴─────┴──────────┘
```

## 🔍 故障排查

### 连接失败
```bash
# 检查蓝牙适配器
hciconfig

# 检查设备配对状态
echo "info 48:08:EB:60:00:6A" | bluetoothctl

# 手动配对
echo "pair 48:08:EB:60:00:6A" | bluetoothctl
echo "trust 48:08:EB:60:00:6A" | bluetoothctl
```

### 设备文件不存在
```bash
# 检查 RFCOMM 绑定
rfcomm show

# 手动绑定
sudo rfcomm bind 0 48:08:EB:60:00:6A 5

# 检查设备文件
ls -l /dev/rfcomm0
```

### 发送失败
```bash
# 检查设备文件权限
ls -l /dev/rfcomm0

# 检查连接状态
cat /dev/rfcomm0 &
echo "test" > /dev/rfcomm0
```

### 无响应
```bash
# 检查读取进程
ps aux | grep cat

# 重启读取进程
sudo pkill cat
cat /dev/rfcomm0 > /tmp/rfcomm0.log 2>&1 &
```

## 📝 注意事项

1. **所有脚本都需要 sudo 权限**
2. **连接前确保设备已开机**
3. **默认使用通道 5**（SDP 查询失败时的后备方案）
4. **连接成功后会启动后台读取进程**
5. **断开连接前会自动停止读取进程**
6. **接收日志保存在 `/tmp/rfcomm0.log`**
7. **CRC 计算使用简化版本**（实际应用中需要完整 CRC16）

## 🔗 相关文档

- [Linux 蓝牙 SPP 开发指南](../docs/LINUX_BLUETOOTH_SPP.md)
- [GTP 协议规范](../docs/GTP_PROTOCOL.md)
- [产测指令规范](../docs/PRODUCTION_TEST_COMMANDS.md)

## 📞 技术支持

如有问题，请联系开发团队。
