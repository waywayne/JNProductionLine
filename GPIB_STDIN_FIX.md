# GPIB stdin 关闭问题修复

## 问题现象

从最新的日志可以看到：
1. ✅ Python 脚本成功连接到设备
2. ✅ 发送了 `CONNECTED|OK` 信号
3. ✅ Dart 端收到连接确认信号
4. ✅ Python 进入命令循环
5. ❌ **Python 进程立即退出**

## 根本原因

Python 脚本在进入命令循环后，`stdin.readline()` 立即返回空字符串（EOF），表示 stdin 已被关闭。

可能的原因：
1. **Dart Process.stdin 自动关闭**
   - 在某些情况下，Dart 可能会自动关闭未使用的 stdin
   - 特别是在 Windows 上

2. **进程启动模式问题**
   - `ProcessStartMode.normal` 可能不适合需要长期 stdin 通信的场景

3. **Shell 环境问题**
   - Windows 上可能需要在 shell 中运行才能正确处理 stdin

## 修复方案

### 1. 添加 runInShell 参数
```dart
_process = await Process.start(
  pythonCmd,
  [scriptPath, address],
  mode: ProcessStartMode.normal,
  runInShell: Platform.isWindows, // Windows 需要在 shell 中运行
);
```

### 2. 改进 Python 脚本的 stdin 处理
```python
# 更健壮的 readline 处理
try:
    line = sys.stdin.readline()
except Exception as e:
    print(f"ERROR: Failed to read from stdin: {e}", file=sys.stderr)
    break

# 明确检测 EOF
if line == '':
    print("INFO: stdin closed (EOF received), exiting", file=sys.stderr)
    break
```

### 3. 连接成功后发送测试命令
```dart
// 发送一个测试命令确保通信正常
_logState?.debug('测试 GPIB 通信...', type: LogType.gpib);
try {
  final testId = 'test_${DateTime.now().millisecondsSinceEpoch}';
  _process!.stdin.writeln('$testId|*IDN?');
  await _process!.stdin.flush();
  _logState?.debug('测试命令已发送', type: LogType.gpib);
} catch (e) {
  _logState?.warning('测试命令发送失败: $e', type: LogType.gpib);
}
```

## 预期日志

### 成功的情况
```
Python: INFO: Initializing VISA Resource Manager...
Python: INFO: Available resources: ('GPIB0::5::INSTR', ...)
Python: INFO: Connecting to GPIB0::5::INSTR...
Python: INFO: Device identified: HEWLETT-PACKARD,66311B,...
Python stdout: CONNECTED|OK
收到连接确认信号
Python: INFO: Entering command loop
✅ GPIB 设备连接成功: GPIB0::5::INSTR
测试 GPIB 通信...
测试命令已发送
Python stdout: test_1234567890|HEWLETT-PACKARD,66311B,...
```

### 如果 stdin 仍然关闭
```
Python: INFO: Entering command loop
Python: INFO: stdin closed (EOF received), exiting
Python 桥接进程退出，退出码: 0
测试命令发送失败: Bad file descriptor
```

## 测试步骤

1. **完全重启应用**
   - 确保使用最新代码
   - 关闭所有之前的进程

2. **点击"连接"**
   - 观察日志中是否出现"测试命令已发送"
   - 观察是否收到测试命令的响应

3. **如果仍然失败**
   - 查看是否有"stdin closed (EOF received)"消息
   - 查看测试命令发送是否失败

## 备选方案

如果上述修复仍然无效，可以考虑：

### 方案 A：使用 Socket 通信
改用 TCP socket 代替 stdin/stdout：
- Python 脚本监听本地端口
- Dart 通过 socket 发送命令
- 更稳定，但需要处理端口占用

### 方案 B：使用临时文件
- Python 脚本轮询读取命令文件
- Dart 写入命令到文件
- 简单但效率较低

### 方案 C：使用 HTTP 服务
- Python 脚本启动简单的 HTTP 服务器
- Dart 通过 HTTP 请求发送命令
- 最稳定，但启动较慢

## 下一步

请重启应用并测试连接，然后告诉我：
1. 是否看到"测试命令已发送"
2. 是否收到测试命令的响应
3. Python 进程是否仍然退出
4. 完整的日志输出

这将帮助我们确定是否需要切换到备选方案。
