# SPP 超时问题调试指南

## 问题描述

基于 SPP 发送命令后，总是超时没有响应。

## 可能的原因

### 1. **数据包格式不匹配**
- 设备返回的数据包不是 `AA 55` 开头
- 数据包长度字段解析错误
- 数据包被分片接收

### 2. **缓冲区处理问题**
- 起始标志未找到，数据被丢弃
- 数据包不完整，一直等待
- 垃圾数据干扰

### 3. **响应匹配问题**
- 没有待处理的响应队列
- Completer 已经完成
- 响应超时时间太短

### 4. **连接问题**
- RFCOMM 连接不稳定
- socat 进程异常
- 设备端未响应

## 调试步骤

### 步骤 1: 检查是否收到数据

查看日志中是否有 `📥 接收` 消息：

```
📥 接收: AA 55 00 04 01 03 00 01 AB CD (ASCII: .U..........)
```

**如果没有接收日志：**
- 检查设备是否真的发送了数据
- 检查 RFCOMM 连接是否正常
- 检查 socat 进程是否运行

**如果有接收日志：**
- 继续下一步

### 步骤 2: 检查数据包格式

查看接收到的数据是否以 `AA 55` 开头：

```
📥 接收: AA 55 ...  ✅ 正确
📥 接收: FF 00 ...  ❌ 错误格式
```

**如果不是 AA 55 开头：**
- 设备可能使用不同的协议格式
- 需要修改 `_processBuffer()` 方法以支持该格式

**如果是 AA 55 开头：**
- 继续下一步

### 步骤 3: 检查缓冲区处理

查看日志中的缓冲区处理信息：

```
🔍 处理缓冲区，当前长度: 10 字节
   数据包长度: 6, 总长度: 10
   提取完整数据包，剩余缓冲区: 0 字节
```

**常见问题：**

#### 3.1 未找到起始标志
```
⚠️ 缓冲区中未找到起始标志 (AA 55)
   缓冲区内容: FF 00 11 22 33
```
**原因**: 接收到的数据不是标准格式
**解决**: 检查设备发送的数据格式

#### 3.2 数据不足
```
   数据不足，等待更多数据 (当前: 6, 需要: 8)
```
**原因**: 数据包被分片接收
**解决**: 这是正常的，等待更多数据到达

#### 3.3 数据不完整
```
   数据不完整，等待更多数据 (当前: 8, 需要: 14)
```
**原因**: 根据长度字段，还需要更多数据
**解决**: 等待剩余数据，如果长时间不到达，可能是设备端问题

### 步骤 4: 检查数据包解析

查看完整数据包的解析信息：

```
📦 完整数据包 #6:
   长度: 10 字节
   HEX: AA 55 00 04 01 03 00 01 AB CD
   头部: AA 55 (起始标志)
   长度: 4
   模块ID: 0x01
   消息ID: 0x03
   数据: 00 01
   校验和: 0xABCD
```

**检查项：**
- 长度字段是否正确（第 3-4 字节）
- 模块ID 和消息ID 是否符合预期
- 校验和是否正确

### 步骤 5: 检查响应匹配

查看响应匹配日志：

```
✅ 响应数据包 #6 匹配序列号: 5
   Completer 已完成
```

**如果看到 "没有待处理的响应"：**
```
⚠️ 收到数据包但没有待处理的响应
```
**原因**: 
- 响应来得太晚，已经超时
- 发送命令时没有创建待处理响应

**如果看到 "Completer 已经完成"：**
```
   ⚠️ Completer 已经完成
```
**原因**: 同一个响应被处理了两次

### 步骤 6: 检查超时设置

查看命令发送日志：

```
🔄 序列号: 6, 等待响应 (超时: 5秒)
```

**如果超时时间太短：**
- 增加超时时间
- 检查设备响应速度

## 常见问题和解决方案

### 问题 1: 总是超时，但有接收数据

**症状：**
```
📥 接收: AA 55 00 04 01 03 00 01 AB CD
⚠️ 命令超时 (5秒)
```

**可能原因：**
1. 数据包格式不匹配，无法解析
2. 缓冲区处理逻辑有问题
3. 响应队列管理有问题

**解决方法：**
```dart
// 检查日志中是否有 "📦 完整数据包" 消息
// 如果没有，说明数据包解析失败

// 检查是否有 "✅ 响应数据包匹配序列号" 消息
// 如果没有，说明响应匹配失败
```

### 问题 2: 没有接收到任何数据

**症状：**
```
📤 发送: AA 55 00 06 01 02 FF FF 12 34
⚠️ 命令超时 (5秒)
```
没有 `📥 接收` 日志

**可能原因：**
1. 设备未响应
2. RFCOMM 连接断开
3. socat 进程异常

**解决方法：**
```bash
# 检查 RFCOMM 连接
rfcomm show

# 检查 socat 进程
ps aux | grep socat

# 手动测试设备响应
echo -ne '\xAA\x55\x00\x06\x01\x02\xFF\xFF\x12\x34' > /dev/rfcomm0
cat /dev/rfcomm0
```

### 问题 3: 数据包格式不是 AA 55

**症状：**
```
📥 接收: FF 00 11 22 33 44
⚠️ 缓冲区中未找到起始标志 (AA 55)
```

**解决方法：**

修改 `_processBuffer()` 方法以支持不同的数据包格式：

```dart
// 如果设备使用不同的起始标志，例如 0xFF 0x00
if (_buffer[i] == 0xFF && _buffer[i + 1] == 0x00) {
  startIndex = i;
  break;
}

// 或者如果没有起始标志，直接按长度解析
// 需要根据具体协议调整
```

### 问题 4: 数据包长度解析错误

**症状：**
```
🔍 处理缓冲区，当前长度: 10 字节
   数据包长度: 65535, 总长度: 65539
   数据不完整，等待更多数据
```

**原因：** 长度字段字节序错误（大端 vs 小端）

**解决方法：**

```dart
// 当前是大端序（Big Endian）
final packetLength = (_buffer[2] << 8) | _buffer[3];

// 如果设备使用小端序（Little Endian），改为：
final packetLength = _buffer[2] | (_buffer[3] << 8);
```

## 调试技巧

### 1. 启用详细日志

确保日志级别设置为 DEBUG：

```dart
// 在测试代码中
_logState?.debug('...');  // 会显示
```

### 2. 使用十六进制查看器

```bash
# 监控 RFCOMM 设备
sudo cat /dev/rfcomm0 | xxd

# 或使用 socat 调试模式
socat -d -d -d - FILE:/dev/rfcomm0,b115200,raw,echo=0
```

### 3. 抓包分析

```bash
# 使用 hcidump 抓取蓝牙数据包
sudo hcidump -X -i hci0

# 或使用 btmon
sudo btmon
```

### 4. 简化测试

创建最小测试用例：

```dart
// 只发送一个简单命令
final testCommand = Uint8List.fromList([0xAA, 0x55, 0x00, 0x02, 0x01, 0x02, 0x00, 0x00]);
final response = await sppService.sendCommandAndWaitResponse(testCommand);
```

## 修改建议

### 如果设备不使用 AA 55 协议

修改 `lib/services/linux_bluetooth_spp_service.dart`:

```dart
// 方案 1: 支持多种起始标志
void _processBuffer() {
  while (_buffer.length >= 4) {
    int startIndex = -1;
    
    // 查找 AA 55 或其他起始标志
    for (int i = 0; i < _buffer.length - 1; i++) {
      if ((_buffer[i] == 0xAA && _buffer[i + 1] == 0x55) ||
          (_buffer[i] == 0xFF && _buffer[i + 1] == 0x00)) {
        startIndex = i;
        break;
      }
    }
    // ... 其余代码
  }
}

// 方案 2: 使用固定长度数据包
void _processBuffer() {
  const packetSize = 10;  // 固定长度
  
  while (_buffer.length >= packetSize) {
    final packet = _buffer.sublist(0, packetSize);
    _buffer = _buffer.sublist(packetSize);
    _processPacket(packet);
  }
}

// 方案 3: 使用分隔符
void _processBuffer() {
  // 查找换行符或其他分隔符
  final delimiterIndex = _buffer.indexOf(0x0A);  // \n
  if (delimiterIndex != -1) {
    final packet = _buffer.sublist(0, delimiterIndex);
    _buffer = _buffer.sublist(delimiterIndex + 1);
    _processPacket(packet);
  }
}
```

### 增加超时时间

如果设备响应较慢：

```dart
// 在测试配置中增加超时
static const defaultTimeout = Duration(seconds: 10);  // 从 5 秒改为 10 秒
```

## 下一步

1. **运行应用并查看详细日志**
2. **确认是否收到数据** (`📥 接收` 消息)
3. **确认数据包格式** (是否 `AA 55` 开头)
4. **确认数据包解析** (是否有 `📦 完整数据包` 消息)
5. **确认响应匹配** (是否有 `✅ 响应数据包匹配` 消息)

根据日志输出，可以精确定位问题所在。
