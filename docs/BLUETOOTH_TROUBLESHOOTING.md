# 蓝牙 SPP 通信故障排查指南

## 🔍 问题诊断流程

### 1. 连接问题

#### 症状：连接后立即断开
```
✅ RFCOMM Socket 连接成功
⚠️ Socket 数据流结束
⚠️ RFCOMM Socket 进程已退出 (退出码: 1)
```

**可能原因：**
- Python 脚本 I/O 阻塞
- Dart 监听顺序错误
- Socket 超时设置不当

**解决方案：**
1. ✅ 使用非阻塞 I/O（`sock.settimeout(0.1)`）
2. ✅ 立即监听 stdout/stderr
3. ✅ 使用 `select` 等待数据

---

### 2. 发送问题

#### 症状：提示"未连接，无法发送数据"
```
❌ 未连接，无法发送数据
```

**可能原因：**
- `_isConnected` 状态被误设置为 `false`
- `onDone` 回调提前触发
- 进程意外退出

**解决方案：**
1. ✅ 在 `onDone` 中检查 `_isConnected` 状态
2. ✅ 添加 `cancelOnError: false`
3. ✅ 保存进程引用后再监听

---

### 3. 超时问题

#### 症状：发送成功但无响应
```
📤 发送数据: [FF FF FF FF FF FF FF FF 00]
✅ 数据已发送
⚠️ 命令超时 (5秒)
⚠️ 第 1 次重试...
⚠️ 第 2 次重试...
❌ 所有重试均失败
```

**可能原因：**
- 设备未正确接收数据
- 数据发送不完整
- 设备需要时间处理

**解决方案：**
1. ✅ 使用循环发送确保完整性
2. ✅ 发送后添加 50ms 延迟
3. ✅ 增加详细的发送日志

---

## 🛠️ 修复历史

### 修复 1：非阻塞 I/O

**问题：** `sys.stdin.buffer.read()` 阻塞导致超时

**修复：**
```python
# 设置非阻塞模式
fcntl.fcntl(sys.stdin.fileno(), fcntl.F_SETFL, flags | os.O_NONBLOCK)

# 使用 select 等待数据
readable, _, _ = select.select([sys.stdin], [], [], 0.1)
if readable:
    data = sys.stdin.buffer.read(1024)
```

---

### 修复 2：Socket 超时设置

**问题：** `sock.settimeout(None)` 导致永久阻塞

**修复：**
```python
# 连接时使用 10 秒超时
sock.settimeout(10)
sock.connect((mac_address, channel))

# 连接后使用 0.1 秒超时（非阻塞）
sock.settimeout(0.1)
```

---

### 修复 3：完整数据发送

**问题：** `sock.sendall()` 在非阻塞模式下可能失败

**修复：**
```python
sent = 0
while sent < len(data):
    try:
        n = sock.send(data[sent:])
        sent += n
    except socket.timeout:
        time.sleep(0.01)
        continue

# 发送后延迟
time.sleep(0.05)
```

---

### 修复 4：Dart 监听顺序

**问题：** 先等待 2 秒，后监听 stdout

**修复：**
```dart
final process = await Process.start(...);
_socketProcess = process;  // ✅ 立即保存

// ✅ 立即监听
_subscription = process.stdout.listen(...);
process.stderr.listen(...);

// ✅ 最后等待
await Future.delayed(Duration(seconds: 2));
```

---

### 修复 5：去掉 SDP 发现

**问题：** SDP 查询慢且容易失败

**修复：**
```dart
// 直接使用默认通道 5
int targetChannel = channel ?? 5;
_logState?.info('✅ 使用默认 SPP 通道: 5');
_logState?.debug('   跳过 SDP 服务发现，直接连接');
```

**优势：**
- ⚡ 速度提升 50%+（省去 2-5 秒）
- ✅ 更可靠（避免 SDP 失败）
- ✅ 兼容性好（大多数设备使用通道 5）

---

## 📊 日志分析

### 正常连接日志

```
🔗 开始连接蓝牙设备 (Linux SPP)
   地址: 48:08:EB:60:00:6A
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 设备已配对和信任
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 使用默认 SPP 通道: 5
   跳过 SDP 服务发现，直接连接
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏳ 建立 RFCOMM Socket 连接...
   方法: Python RFCOMM Socket
   找到脚本: /opt/jn-production-line/scripts/rfcomm_socket.py
   启动命令: python3 ... 48:08:EB:60:00:6A 5
   ✅ RFCOMM Socket 进程已启动
[Python] [RFCOMM] 正在连接到 48:08:EB:60:00:6A 通道 5...
[Python] [RFCOMM] ✅ RFCOMM Socket 连接成功
[Python] [RFCOMM] 启动双向数据传输...
✅ RFCOMM Socket 连接已建立
✅ SPP 连接成功
```

### 正常发送日志

```
📤 发送 Payload: [FF FF FF FF FF FF FF FF 00] (9 字节)
📦 完整数据包: [D0 D2 C5 C2 00 25 00 03 04 00 00 B2 23 23 05 00 1D F7 04 00 00 00 09 00 01 00 FF FF FF FF FF FF FF FF 00 40 1A B1 FD 9D]
   总长度: 41 字节
✅ 数据已发送
[Python] [RFCOMM] 准备发送 41 字节数据
[Python] [RFCOMM] 已发送 41/41 字节
[Python] [RFCOMM] ✅ 数据发送完成: 41 字节
```

### 正常接收日志

```
[Python] [RFCOMM] 📥 接收到 41 字节: D0 D2 C5 C2 00 25 00 03 04 00 00 B2 23 23 05 00 1D F7 04 00 00 00 09 00 02 00 FF FF FF FF FF FF FF FF 00 FF FF FF FF FF FF FF FF 00 9F 68 40 37
📥 收到数据: [41 字节]
📦 完整数据包: [D0 D2 C5 C2 00 25 00 03 04 00 00 B2 23 23 05 00 1D F7 04 00 00 00 09 00 02 00 FF FF FF FF FF FF FF FF 00 FF FF FF FF FF FF FF FF 00 9F 68 40 37]
✅ 总长度: 41 字节
✅ 命令响应成功
```

---

## 🔧 调试技巧

### 1. 查看 Python 日志

Python 脚本的日志输出到 stderr，在 Dart 中会显示为：
```
[Python] [RFCOMM] <消息>
```

### 2. 检查进程状态

```bash
# 查看 Python 进程
ps aux | grep rfcomm_socket.py

# 查看蓝牙连接
hcitool con

# 查看 RFCOMM 设备
ls -l /dev/rfcomm*
```

### 3. 手动测试 Python 脚本

```bash
# 直接运行脚本
sudo python3 scripts/rfcomm_socket.py 48:08:EB:60:00:6A 5

# 发送测试数据（另一个终端）
echo -n "test" | sudo python3 scripts/rfcomm_socket.py 48:08:EB:60:00:6A 5
```

### 4. 抓包分析

```bash
# 使用 btmon 抓取蓝牙数据包
sudo btmon

# 或使用 hcidump
sudo hcidump -X
```

---

## ✅ 检查清单

连接前检查：
- [ ] 蓝牙适配器已开启
- [ ] 设备已配对和信任
- [ ] Python 和 PyBluez 已安装
- [ ] 脚本文件存在且可执行

连接时检查：
- [ ] 看到 "✅ RFCOMM Socket 连接成功"
- [ ] 看到 "启动双向数据传输"
- [ ] 没有 "Socket 数据流结束"
- [ ] 没有 "进程已退出"

发送时检查：
- [ ] 看到 "✅ 数据已发送"
- [ ] 看到 Python 日志 "准备发送 X 字节"
- [ ] 看到 Python 日志 "✅ 数据发送完成"
- [ ] 没有 "未连接，无法发送数据"

接收时检查：
- [ ] 看到 Python 日志 "📥 接收到 X 字节"
- [ ] 看到 Dart 日志 "📥 收到数据"
- [ ] 看到 "✅ 命令响应成功"
- [ ] 没有 "⚠️ 命令超时"

---

## 🚨 常见错误

### 错误 1：timed out

```
[Python] [RFCOMM] ❌ 蓝牙连接失败: timed out
```

**原因：** Socket 操作超时

**解决：**
- 检查设备是否在范围内
- 检查设备是否已配对
- 增加连接超时时间

---

### 错误 2：Connection refused

```
[Python] [RFCOMM] ❌ 蓝牙连接失败: Connection refused
```

**原因：** 设备拒绝连接

**解决：**
- 确保设备已配对
- 确保通道号正确（通常是 5）
- 重启设备和蓝牙适配器

---

### 错误 3：Permission denied

```
[Python] [RFCOMM] ❌ 蓝牙连接失败: Permission denied
```

**原因：** 权限不足

**解决：**
```bash
# 使用 sudo 运行应用
sudo jn-production-line
```

---

## 📚 相关文档

- [RFCOMM Socket 实现](RFCOMM_SOCKET.md)
- [快速开始指南](QUICK_START.md)
- [蓝牙权限配置](BLUETOOTH_PERMISSIONS.md)
- [Linux 构建指南](LINUX_BUILD_GUIDE.md)
