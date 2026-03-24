# 设备无响应诊断

## 🔍 当前状态

**现象：** Python 脚本成功发送数据，但**从未收到任何响应**。

### 日志证据

```
📤 发送 Payload: [00] (1 字节)
📦 完整数据包: [D0 D2 C5 C2 00 1D 00 03 04 00 00 FE 23 23 06 00 8D EF 01 FF 00 00 01 00 00 00 40 40 79 F0 2D 78]
✅ 数据已发送
[SUCCESS] 数据已发送
⚠️ 命令超时 (5秒)
```

**关键问题：没有看到 `[Python] 📥 接收到 XX 字节` 的日志！**

---

## 🎯 可能的原因

### 原因 1：设备真的不响应（最可能 60%）

**可能性：**
- 设备不支持我们发送的 GTP+CLI 格式
- 设备期望不同的协议格式
- 设备需要特定的握手流程

**验证方法：**
```bash
# 使用测试脚本验证设备是否响应
sudo ./scripts/test-raw-bluetooth-response.sh <MAC地址>
```

**如果测试脚本有响应：**
- 说明设备支持某种格式
- 需要对比测试脚本和我们的格式差异

**如果测试脚本也无响应：**
- 设备可能需要特定的初始化流程
- 设备可能处于休眠状态
- 设备固件可能有问题

---

### 原因 2：Socket 读取有问题（可能 20%）

**可能性：**
- Socket 超时设置不对
- 接收缓冲区问题
- 蓝牙协议栈问题

**当前设置：**
```python
sock.settimeout(0.1)  # 100ms 超时
```

**验证方法：**
```python
# 增加超时时间
sock.settimeout(1.0)  # 1 秒超时

# 或者使用阻塞模式
sock.settimeout(None)  # 无超时，阻塞等待
```

---

### 原因 3：数据格式问题（可能 15%）

**对比：测试脚本 vs 我们的应用**

#### 测试脚本格式（单层 GTP）：
```
D0 D2 C5 C2    # Preamble
10 00          # Length = 16
03 04          # Module ID
FE 23 23 06    # Message ID
01             # Version
FF             # Encrypt
00 00          # Sequence
00             # Payload (CMD)
00 00 00 00    # Reserved
40 40          # CRC

总长度：23 字节
```

#### 我们的格式（双层 GTP+CLI）：
```
D0 D2 C5 C2    # Preamble
00             # Version
1D 00          # Length = 29
03             # Type
04             # FC
00 00          # Seq
FE             # CRC8
23 23          # CLI Start
06 00          # CLI Module ID
8D EF          # CLI CRC
01 FF          # CLI Message ID
00             # CLI Flags
00             # CLI Result
01 00          # CLI Length
00 00          # CLI SN
00             # Payload (CMD)
40 40          # CLI Tail
79 F0 2D 78    # CRC32

总长度：33 字节
```

**关键差异：**
- 测试脚本：单层 GTP，Module ID 和 Message ID 在 GTP 头部
- 我们应用：双层 GTP+CLI，Module ID 和 Message ID 在 CLI 内部

**问题：** 设备可能只支持测试脚本的格式！

---

### 原因 4：连接状态问题（可能 5%）

**可能性：**
- Socket 已断开但未检测到
- 设备端连接异常
- 蓝牙链路不稳定

**验证方法：**
```python
# 检查 Socket 状态
try:
    sock.getpeername()  # 如果连接断开会抛出异常
    log("Socket 连接正常")
except:
    log("Socket 连接已断开")
```

---

## 🔬 诊断步骤

### 步骤 1：验证设备是否真的会响应

**使用测试脚本：**
```bash
sudo ./scripts/test-raw-bluetooth-response.sh <MAC地址>
```

**预期结果：**
- 如果有响应 → 设备支持某种格式，继续步骤 2
- 如果无响应 → 设备可能需要特殊初始化，继续步骤 3

---

### 步骤 2：对比数据格式

**如果测试脚本有响应：**

1. **使用 btmon 抓包**
   ```bash
   # 终端 1
   sudo btmon
   
   # 终端 2
   sudo ./scripts/test-raw-bluetooth-response.sh <MAC地址>
   ```

2. **对比数据包**
   - 测试脚本发送的数据
   - 我们应用发送的数据
   - 找出差异

3. **修改为测试脚本的格式**
   - 使用单层 GTP 格式
   - Module ID 和 Message ID 放在 GTP 头部

---

### 步骤 3：检查设备状态

**如果测试脚本也无响应：**

1. **检查设备是否需要唤醒**
   ```bash
   # 尝试发送唤醒命令
   echo "00" | xxd -r -p > /dev/rfcomm0
   sleep 1
   # 再发送测试命令
   ```

2. **检查设备固件版本**
   - 设备可能需要特定固件版本
   - 联系硬件团队确认

3. **使用第三方工具测试**
   - Serial Bluetooth Terminal
   - 观察是否有响应

---

## ✅ 修复方案

### 方案 A：使用测试脚本的格式（如果步骤 1 有响应）

**修改 GTP 协议实现：**

```dart
// lib/services/gtp_protocol.dart

/// Build GTP packet (Test Script Format)
/// 使用测试脚本的单层 GTP 格式
static Uint8List buildTestScriptGTPPacket(
  Uint8List payload, {
  int? moduleId,
  int? messageId,
  int? sequenceNumber,
}) {
  // 固定值
  final preamble = [0xD0, 0xD2, 0xC5, 0xC2];
  final defaultModuleId = moduleId ?? 0x0403;      // 0x03 0x04
  final defaultMessageId = messageId ?? 0x062323FE; // 0xFE 0x23 0x23 0x06
  final version = 0x01;
  final encrypt = 0xFF;
  final seq = sequenceNumber ?? 0x0000;
  final reserved = [0x00, 0x00, 0x00, 0x00];
  
  // 计算 GTP Length
  // Length = ModuleID(2) + MessageID(4) + Version(1) + Encrypt(1) + Seq(2) + Payload(N) + Reserved(4) + CRC(2)
  final gtpLength = 2 + 4 + 1 + 1 + 2 + payload.length + 4 + 2;
  
  // 构建数据包
  final buffer = BytesBuilder();
  
  // 1. Preamble (4 bytes)
  buffer.add(preamble);
  
  // 2. Length (2 bytes, little endian)
  buffer.addByte(gtpLength & 0xFF);
  buffer.addByte((gtpLength >> 8) & 0xFF);
  
  // 3. Module ID (2 bytes, little endian)
  buffer.addByte(defaultModuleId & 0xFF);
  buffer.addByte((defaultModuleId >> 8) & 0xFF);
  
  // 4. Message ID (4 bytes, little endian)
  buffer.addByte(defaultMessageId & 0xFF);
  buffer.addByte((defaultMessageId >> 8) & 0xFF);
  buffer.addByte((defaultMessageId >> 16) & 0xFF);
  buffer.addByte((defaultMessageID >> 24) & 0xFF);
  
  // 5. Version (1 byte)
  buffer.addByte(version);
  
  // 6. Encrypt (1 byte)
  buffer.addByte(encrypt);
  
  // 7. Sequence (2 bytes, little endian)
  buffer.addByte(seq & 0xFF);
  buffer.addByte((seq >> 8) & 0xFF);
  
  // 8. Payload (N bytes)
  buffer.add(payload);
  
  // 9. Reserved (4 bytes)
  buffer.add(reserved);
  
  // 10. CRC (2 bytes) - 简化版
  buffer.addByte(0x40);
  buffer.addByte(0x40);
  
  return buffer.toBytes();
}
```

---

### 方案 B：增加 Socket 超时（如果是读取问题）

```python
# scripts/rfcomm_socket.py

# 连接成功后设置更长的超时
sock.settimeout(1.0)  # 从 0.1s 增加到 1s
```

---

### 方案 C：使用阻塞模式（备选）

```python
# scripts/rfcomm_socket.py

# 使用阻塞模式，等待数据
sock.settimeout(None)

# 使用 select 检查是否有数据
import select
readable, _, _ = select.select([sock], [], [], 5.0)  # 5秒超时
if readable:
    data = sock.recv(1024)
```

---

## 🧪 立即测试

### 测试 1：验证设备响应

```bash
# 运行测试脚本
sudo ./scripts/test-raw-bluetooth-response.sh <MAC地址>

# 观察是否有响应数据
```

### 测试 2：增加 Python 日志

修改后的 Python 脚本会每 100 次超时打印一次状态：
```
⏳ 持续监听中... (超时次数: 100, 已接收: 0 次)
⏳ 持续监听中... (超时次数: 200, 已接收: 0 次)
...
```

**如果一直是 "已接收: 0 次"，说明设备真的没有响应！**

---

## 📊 预期结果

### 场景 1：测试脚本有响应

```bash
$ sudo ./scripts/test-raw-bluetooth-response.sh 48:08:EB:60:00:6A
✅ RFCOMM 连接已建立
📤 发送测试数据包
✅ 数据已发送
⏳ 等待响应 (5秒)...
00000000: d0 d2 c5 c2 00 10 00 03 04 00 00 ...  ← 收到响应！
✅ 收到响应数据
```

**结论：设备支持测试脚本的格式，需要修改我们的格式！**

---

### 场景 2：测试脚本无响应

```bash
$ sudo ./scripts/test-raw-bluetooth-response.sh 48:08:EB:60:00:6A
✅ RFCOMM 连接已建立
📤 发送测试数据包
✅ 数据已发送
⏳ 等待响应 (5秒)...
⚠️ 未收到响应或超时
```

**结论：设备可能需要特殊初始化，或者固件有问题！**

---

## 💡 总结

**关键问题：设备没有响应任何数据！**

**可能原因：**
1. **数据格式不对** - 设备期望测试脚本的格式（单层 GTP）
2. **设备需要初始化** - 需要先发送特定命令
3. **设备固件问题** - 需要联系硬件团队

**立即行动：**
1. 运行测试脚本验证设备是否响应
2. 根据结果选择修复方案
3. 如果测试脚本有响应，修改为单层 GTP 格式
4. 如果测试脚本无响应，联系硬件团队

---

## 🔧 快速修复（如果是格式问题）

**临时方案：** 在 `linux_bluetooth_spp_service.dart` 中添加格式选择

```dart
// 添加一个标志
bool _useTestScriptFormat = true;  // 使用测试脚本格式

Future<Map<String, dynamic>?> sendCommandAndWaitResponse(...) async {
  Uint8List gtpPacket;
  
  if (_useTestScriptFormat) {
    // 使用测试脚本格式（单层 GTP）
    gtpPacket = GTPProtocol.buildTestScriptGTPPacket(
      command,
      moduleId: 0x0403,
      messageId: 0x062323FE,
      sequenceNumber: seqNum,
    );
  } else {
    // 使用原有格式（双层 GTP+CLI）
    gtpPacket = GTPProtocol.buildGTPPacket(
      command,
      moduleId: moduleId,
      messageId: messageId,
      sequenceNumber: seqNum,
    );
  }
  
  // ...
}
```
