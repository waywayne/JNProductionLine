# 蓝牙超时问题修复

## 🐛 问题描述

### 症状
1. **连接后立即断开** - 手动测试时连上蓝牙后就中断
2. **发送数据无响应** - 自动测试发送数据后没有收到响应
3. **Python 进程退出** - 日志显示 `[Python] [RFCOMM] ❌ 蓝牙连接失败: timed out`
4. **缺少详细日志** - 没有看到 "准备发送 X 字节" 等 Python 发送日志

### 日志示例
```
[15:52:22.73] [SUCCESS] ✅ 数据已发送
[15:52:24.85] [DEBUG  ] [Python] [RFCOMM] ❌ 蓝牙连接失败: timed out
[15:52:24.87] [WARNING] ⚠️ Socket 数据流结束
[15:52:24.87] [INFO   ] 🔌 断开 SPP 连接...
[15:52:24.87] [WARNING] ⚠️ RFCOMM Socket 进程已退出 (退出码: 1)
```

---

## 🔍 根本原因

### 问题分析

**PyBluez 的 `BluetoothSocket` 在超时时抛出 `bluetooth.BluetoothError` 而不是 `socket.timeout`！**

#### 代码流程：
1. Socket 设置为 0.1 秒超时：`sock.settimeout(0.1)`
2. `sock.recv(1024)` 在没有数据时等待 0.1 秒
3. **超时后抛出 `bluetooth.BluetoothError: timed out`**（不是 `socket.timeout`）
4. 异常被捕获，但被当作错误处理，导致线程退出
5. 线程退出后，整个 Python 进程也退出
6. Dart 检测到进程退出，断开连接

#### 错误的异常处理（修复前）：
```python
except socket.timeout:
    # 超时是正常的，继续循环
    time.sleep(0.01)
    continue
except bluetooth.BluetoothError as e:
    # ❌ 所有 BluetoothError 都被当作错误
    log(f"蓝牙读取错误: {e}")
    break  # 退出循环
```

**问题：** `bluetooth.BluetoothError: timed out` 被当作错误，导致线程退出！

---

## ✅ 修复方案

### 1. 区分超时和真正的错误

修改异常处理，将超时错误当作正常情况：

```python
except socket.timeout:
    # 超时是正常的，继续循环
    time.sleep(0.01)
    continue
except bluetooth.BluetoothError as e:
    # ✅ 检查是否是超时错误
    error_msg = str(e).lower()
    if 'timed out' in error_msg or 'timeout' in error_msg:
        # 超时是正常的，继续循环
        time.sleep(0.01)
        continue
    else:
        # 其他蓝牙错误，退出
        log(f"蓝牙读取错误: {e}")
        break
```

### 2. 修复位置

需要在两个函数中修复：

#### A. `socket_to_stdout` - 接收数据
```python
def socket_to_stdout(sock):
    """从 socket 读取数据并输出到 stdout（非阻塞）"""
    try:
        while True:
            try:
                data = sock.recv(1024)
                # ... 处理数据 ...
                
            except socket.timeout:
                time.sleep(0.01)
                continue
            except bluetooth.BluetoothError as e:
                # ✅ 区分超时和真正的错误
                error_msg = str(e).lower()
                if 'timed out' in error_msg or 'timeout' in error_msg:
                    time.sleep(0.01)
                    continue
                else:
                    log(f"蓝牙读取错误: {e}")
                    break
```

#### B. `stdin_to_socket` - 发送数据
```python
def stdin_to_socket(sock):
    """从 stdin 读取数据并发送到 socket（非阻塞）"""
    try:
        while True:
            # ... 读取数据 ...
            
            while sent < data_len:
                try:
                    n = sock.send(data[sent:])
                    sent += n
                    
                except socket.timeout:
                    time.sleep(0.01)
                    continue
                except bluetooth.BluetoothError as e:
                    # ✅ 区分超时和真正的错误
                    error_msg = str(e).lower()
                    if 'timed out' in error_msg or 'timeout' in error_msg:
                        time.sleep(0.01)
                        continue
                    else:
                        log(f"蓝牙发送错误: {e}")
                        return
```

---

## 📊 修复效果

### 修复前
```
[Python] [RFCOMM] ✅ RFCOMM Socket 连接成功
[Python] [RFCOMM] 启动双向数据传输...
[Python] [RFCOMM] ❌ 蓝牙连接失败: timed out  ← 0.1秒后就退出
⚠️ Socket 数据流结束
⚠️ RFCOMM Socket 进程已退出 (退出码: 1)
```

### 修复后
```
[Python] [RFCOMM] ✅ RFCOMM Socket 连接成功
[Python] [RFCOMM] 启动双向数据传输...
[Python] [RFCOMM] 准备发送 41 字节数据
[Python] [RFCOMM] 已发送 41/41 字节
[Python] [RFCOMM] ✅ 数据发送完成: 41 字节
[Python] [RFCOMM] 📥 接收到 41 字节: D0 D2 C5 C2 ...
✅ 连接稳定，持续通信
```

---

## 🎯 关键要点

### PyBluez 的超时行为

| 操作 | 超时设置 | 超时后抛出的异常 |
|------|----------|------------------|
| `sock.connect()` | `sock.settimeout(10)` | `bluetooth.BluetoothError: timed out` |
| `sock.recv()` | `sock.settimeout(0.1)` | `bluetooth.BluetoothError: timed out` |
| `sock.send()` | `sock.settimeout(0.1)` | `bluetooth.BluetoothError: timed out` |

**注意：** PyBluez 不抛出标准的 `socket.timeout`，而是抛出 `bluetooth.BluetoothError`！

### 正确的异常处理顺序

```python
try:
    data = sock.recv(1024)
except socket.timeout:
    # 1. 先捕获标准 socket.timeout（虽然 PyBluez 不会抛出）
    pass
except bluetooth.BluetoothError as e:
    # 2. 再捕获 BluetoothError，并区分超时和真正的错误
    if 'timed out' in str(e).lower():
        # 超时，继续
        pass
    else:
        # 真正的错误，退出
        raise
```

---

## 🧪 测试验证

### 测试步骤
1. 连接蓝牙设备
2. 发送测试命令
3. 观察日志输出

### 预期结果
- ✅ 看到 "准备发送 X 字节数据"
- ✅ 看到 "已发送 X/Y 字节"
- ✅ 看到 "✅ 数据发送完成"
- ✅ 看到 "📥 接收到 X 字节"
- ✅ 连接保持稳定，不会因超时退出

### 失败标志
- ❌ 看到 "❌ 蓝牙连接失败: timed out"
- ❌ 看到 "⚠️ Socket 数据流结束"
- ❌ 看到 "⚠️ RFCOMM Socket 进程已退出"

---

## 📝 相关文件

- `scripts/rfcomm_socket.py` - Python RFCOMM Socket 桥接脚本
- `lib/services/linux_bluetooth_spp_service.dart` - Dart 蓝牙服务
- `docs/BLUETOOTH_TROUBLESHOOTING.md` - 故障排查指南

---

## 🔗 相关问题

### 为什么使用 0.1 秒超时？

**目的：** 实现非阻塞 I/O，避免永久阻塞

**原理：**
- `sock.recv()` 在没有数据时会阻塞
- 设置 0.1 秒超时后，最多等待 0.1 秒就返回
- 超时后抛出异常，捕获后继续循环
- 这样可以定期检查其他事件（如 stdin 数据、中断信号等）

**为什么不用更长的超时？**
- 超时越长，响应越慢
- 0.1 秒是一个平衡点：既不会过度占用 CPU，也能快速响应

**为什么不用 `sock.setblocking(False)`？**
- 完全非阻塞模式下，`recv()` 会立即返回，没有数据时抛出 `BlockingIOError`
- 需要不断轮询，CPU 占用高
- 使用短超时更优雅

---

## ✅ 总结

**问题：** PyBluez 的 `BluetoothSocket` 超时抛出 `bluetooth.BluetoothError` 而不是 `socket.timeout`

**修复：** 在异常处理中区分超时错误和真正的错误

**效果：** 连接稳定，不会因为正常的超时而退出

**教训：** 使用第三方库时，要了解其异常行为，不能假设它遵循标准库的行为！
