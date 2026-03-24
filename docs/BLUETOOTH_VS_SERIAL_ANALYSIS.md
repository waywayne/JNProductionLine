# 蓝牙 vs 串口通信对比分析

## 🔍 核心发现

**串口通信正常，蓝牙通信超时 → 说明设备支持 GTP+CLI 格式，问题不在协议本身！**

---

## 📊 对比分析

### 1. GTP 协议格式（完全相同）

**串口和蓝牙都使用相同的 GTP+CLI 双层格式：**

```
GTP 层：
  Preamble(4)     // 0xD0 0xD2 0xC5 0xC2
  Version(1)      // 0x00
  Length(2)       // little endian
  Type(1)         // 0x03
  FC(1)           // 0x04
  Seq(2)          // 0x00 0x00
  CRC8(1)         // 头部 CRC8
  CLI Message(N)  // CLI 消息
  CRC32(4)        // 整体 CRC32

CLI 层：
  Start(2)        // 0x23 0x23
  ModuleID(2)     // 0x0006 (产测) 或 0x0005 (退出休眠)
  CRC(2)          // CRC16
  MessageID(2)    // 0xFF01 (产测) 或 0x0004 (退出休眠)
  Flags(1)        // 0x00
  Result(1)       // 0x00
  Length(2)       // Payload length
  SN(2)           // Sequence number
  Payload(N)      // 实际数据 (CMD + OPT + DATA)
  Tail(2)         // 0x40 0x40
```

✅ **结论：格式正确，与串口完全一致！**

---

### 2. Module ID 和 Message ID（完全相同）

| 用途 | Module ID | Message ID | 来源 |
|------|-----------|------------|------|
| **产测命令** | 0x0006 | 0xFF01 | `ProductionTestCommands.moduleId/messageId` |
| **退出休眠** | 0x0005 | 0x0004 | `ProductionTestCommands.exitSleepModuleId/messageId` |

✅ **结论：ID 正确，与串口完全一致！**

---

### 3. 数据封装（完全相同）

**串口服务：**
```dart
// lib/services/serial_service.dart
Future<bool> sendGTPCommand(Uint8List cliPayload, {int? moduleId, int? messageId, int? sequenceNumber}) async {
  Uint8List gtpPacket = GTPProtocol.buildGTPPacket(cliPayload, moduleId: moduleId, messageId: messageId, sequenceNumber: sequenceNumber);
  return await sendData(gtpPacket);
}
```

**蓝牙服务：**
```dart
// lib/services/linux_bluetooth_spp_service.dart
Future<Map<String, dynamic>?> sendCommandAndWaitResponse(...) async {
  final gtpPacket = GTPProtocol.buildGTPPacket(
    command,
    moduleId: moduleId,
    messageId: messageId,
    sequenceNumber: seqNum,
  );
  final success = await sendData(gtpPacket);
  ...
}
```

✅ **结论：封装方法完全相同！**

---

## 🐛 那么问题在哪里？

### 关键差异对比

| 对比项 | 串口通信 | 蓝牙通信 | 影响 |
|--------|---------|---------|------|
| **传输方式** | 直接写入 `/dev/ttyUSB0` | Dart → Python stdin → Socket | ⚠️ 多层转发 |
| **进程模型** | 单进程 | 双进程 (Dart + Python) | ⚠️ 可能有同步问题 |
| **缓冲机制** | 串口驱动缓冲 | stdin 缓冲 + Socket 缓冲 | ⚠️ 多层缓冲 |
| **数据完整性** | 硬件保证 | 需要软件保证 | ⚠️ 可能丢失或分片 |
| **超时处理** | 串口超时 | Socket 超时 (0.1s) | ⚠️ 可能过早超时 |

---

## 🔬 深度剖析：可能的问题

### 问题 1：Python stdin 缓冲问题

**现象：** Dart 写入 stdin，但 Python 可能没有立即读取。

**原因：**
```python
# Python 使用 select 等待数据
readable, _, _ = select.select([sys.stdin], [], [], 0.1)

if readable:
    data = sys.stdin.buffer.read(1024)  # 非阻塞读取
```

**可能的问题：**
- Dart 写入后，Python 的 select 可能还在等待
- 0.1 秒的超时可能错过数据
- stdin 缓冲区可能没有立即刷新

---

### 问题 2：Socket 发送时机问题

**现象：** Python 读取到数据，但发送时设备可能还没准备好。

**代码流程：**
```python
# 1. 从 stdin 读取数据
data = sys.stdin.buffer.read(1024)

# 2. 立即发送到 socket
while sent < data_len:
    n = sock.send(data[sent:])
    sent += n

# 3. 发送后延迟 50ms
time.sleep(0.05)
```

**可能的问题：**
- 50ms 延迟可能不够
- 设备可能需要更多时间处理数据
- 连续发送可能导致设备缓冲区溢出

---

### 问题 3：设备响应时间问题

**串口通信：**
- 设备通过物理串口直接连接
- 响应时间通常 < 100ms

**蓝牙通信：**
- 设备通过蓝牙 RFCOMM 连接
- 蓝牙协议栈延迟
- RFCOMM 层延迟
- 响应时间可能 > 500ms

**当前超时设置：** 5 秒

✅ **5 秒应该足够，不是超时设置的问题**

---

### 问题 4：数据分片问题

**可能的情况：**
```
Dart 发送: [41 字节完整数据包]
  ↓
Python stdin 读取: [41 字节]
  ↓
Socket 发送: 
  第一次: [20 字节]
  第二次: [21 字节]
  ↓
设备接收: 
  第一包: [20 字节] - 不完整，等待更多数据
  第二包: [21 字节] - 拼接后完整，开始处理
```

**问题：** 如果两包之间间隔太长，设备可能超时丢弃第一包！

---

## ✅ 解决方案

### 方案 1：增加发送后延迟（已实现，可能不够）

**当前：**
```python
time.sleep(0.05)  # 50ms
```

**建议：**
```python
time.sleep(0.2)  # 200ms，给设备更多处理时间
```

---

### 方案 2：确保数据完整发送

**当前：**
```python
while sent < data_len:
    n = sock.send(data[sent:])
    sent += n
    log(f"已发送 {sent}/{data_len} 字节")
```

**问题：** 如果分多次发送，设备可能认为数据不完整。

**建议：** 使用 `sendall` 的替代方案，确保一次性发送：

```python
def send_complete(sock, data):
    """确保数据完整发送，不分片"""
    sent = 0
    data_len = len(data)
    max_retries = 10
    retry_count = 0
    
    while sent < data_len and retry_count < max_retries:
        try:
            # 尝试发送剩余所有数据
            n = sock.send(data[sent:])
            if n == 0:
                log("Socket 连接已关闭")
                return False
            sent += n
            retry_count = 0  # 成功发送，重置重试计数
        except socket.timeout:
            retry_count += 1
            log(f"发送超时，重试 {retry_count}/{max_retries}")
            time.sleep(0.01)
            continue
        except bluetooth.BluetoothError as e:
            if 'timed out' in str(e).lower():
                retry_count += 1
                log(f"蓝牙超时，重试 {retry_count}/{max_retries}")
                time.sleep(0.01)
                continue
            else:
                log(f"蓝牙发送错误: {e}")
                return False
    
    if sent < data_len:
        log(f"发送失败: 只发送了 {sent}/{data_len} 字节")
        return False
    
    log(f"✅ 数据发送完成: {data_len} 字节")
    return True
```

---

### 方案 3：增加 Dart stdin 刷新

**当前：**
```dart
_socketProcess!.stdin.add(dataToSend);
await _socketProcess!.stdin.flush();
```

**建议：** 确保数据立即写入：

```dart
_socketProcess!.stdin.add(dataToSend);
await _socketProcess!.stdin.flush();
await Future.delayed(Duration(milliseconds: 10));  // 确保写入完成
```

---

### 方案 4：添加发送确认机制

**目标：** 确认 Python 已经收到并发送了数据。

**实现：**

1. **Python 发送确认**
```python
def stdin_to_socket(sock):
    while True:
        readable, _, _ = select.select([sys.stdin], [], [], 0.1)
        
        if readable:
            data = sys.stdin.buffer.read(1024)
            if not data:
                break
            
            # 发送数据
            if send_complete(sock, data):
                # 发送确认到 stderr（Dart 可以读取）
                log(f"SEND_OK:{len(data)}")
            else:
                log(f"SEND_FAIL:{len(data)}")
```

2. **Dart 等待确认**
```dart
Future<bool> sendData(Uint8List data) async {
  // ...
  
  _socketProcess!.stdin.add(data);
  await _socketProcess!.stdin.flush();
  
  // 等待 Python 确认（从 stderr 读取）
  final completer = Completer<bool>();
  final timer = Timer(Duration(seconds: 1), () {
    if (!completer.isCompleted) {
      completer.complete(false);
    }
  });
  
  // 监听 stderr 中的确认消息
  // (需要修改 stderr 监听逻辑)
  
  final confirmed = await completer.future;
  timer.cancel();
  
  return confirmed;
}
```

---

### 方案 5：对比串口和蓝牙的实际数据包

**使用 btmon 和 串口监听工具对比：**

```bash
# 终端 1：监听蓝牙数据包
sudo btmon

# 终端 2：监听串口数据
sudo cat /dev/ttyUSB0 | xxd

# 终端 3：分别测试
# 串口测试
./test_serial.sh

# 蓝牙测试
./test_bluetooth.sh
```

**对比：**
- 数据包是否完全一致
- 发送时机是否不同
- 是否有额外的控制字节

---

## 🎯 立即行动

### 步骤 1：增加发送后延迟

修改 `rfcomm_socket.py`：

```python
log(f"✅ 数据发送完成: {data_len} 字节")
time.sleep(0.2)  # 从 50ms 增加到 200ms
```

### 步骤 2：添加详细的发送日志

确认每次发送的字节数和时机。

### 步骤 3：测试

发送命令，观察：
1. Python 是否收到完整数据
2. Python 是否一次性发送完整数据
3. 设备是否有响应

### 步骤 4：如果仍然超时

使用 btmon 抓包，对比串口和蓝牙的数据包差异。

---

## 📊 预期效果

**如果是延迟问题：**
```
增加延迟到 200ms 后：
📤 发送数据
[Python] ✅ 数据发送完成: 41 字节
[等待 200ms]
📥 接收到响应
✅ 命令响应成功
```

**如果是分片问题：**
```
优化发送逻辑后：
📤 发送数据
[Python] 已发送 41/41 字节 (一次性)
[Python] ✅ 数据发送完成
📥 接收到响应
✅ 命令响应成功
```

---

## 💡 总结

**关键发现：**
1. ✅ GTP 协议格式正确（与串口一致）
2. ✅ Module ID 和 Message ID 正确
3. ✅ 数据封装方法正确
4. ⚠️ 问题可能在数据传输过程中

**最可能的原因：**
1. **发送后延迟不够** - 设备需要更多时间处理
2. **数据分片发送** - 设备可能等待完整数据包
3. **缓冲区同步问题** - Dart → Python → Socket 多层转发

**解决方案：**
1. 增加发送后延迟到 200ms
2. 优化发送逻辑，确保一次性发送
3. 添加发送确认机制
4. 使用 btmon 对比串口和蓝牙数据包
