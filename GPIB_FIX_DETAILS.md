# GPIB 连接问题修复详情

## 问题分析

从您提供的日志可以看到：

### 成功的部分
1. ✅ Python 环境正常：`Python 3.14.2`
2. ✅ PyVISA 已安装：`1.15.0`
3. ✅ 扫描找到设备：`GPIB0::5::INSTR`
4. ✅ 设备识别成功：`HEWLETT-PACKARD,66311B,US38444369.A,02.02`
5. ✅ Python 脚本成功连接到设备

### 失败的部分
❌ **Python 桥接进程已退出** - 这是核心问题

## 根本原因

Python 脚本在发送 `CONNECTED|OK` 信号后，由于某种原因立即退出了。可能的原因：

1. **stdin 被意外关闭**
   - Dart 端可能在某个时刻关闭了 stdin
   - Python 的 `readline()` 返回空字符串导致脚本退出

2. **缓冲区问题**
   - `sys.stdout.flush()` 后，Dart 端还没来得及读取
   - 进程就继续执行并退出

3. **进程管理问题**
   - Dart 端的进程监听可能有竞态条件

## 修复方案

### 1. 增强日志输出
添加了详细的调试日志，帮助诊断问题：

```dart
// 监听进程退出
_process!.exitCode.then((exitCode) {
  _logState?.warning('Python 桥接进程退出，退出码: $exitCode', type: LogType.gpib);
});

// 详细的 stdout/stderr 日志
_logState?.debug('Python stdout: $line', type: LogType.gpib);
_logState?.info('Python: $line', type: LogType.gpib);
```

### 2. 改进 Python 脚本
添加了更多的状态输出和错误处理：

```python
# 发送连接成功信号
print("CONNECTED|OK")
sys.stdout.flush()

# 等待一小段时间确保信号被接收
time.sleep(0.1)

# 命令处理循环
print("INFO: Entering command loop", file=sys.stderr)
sys.stderr.flush()

while True:
    line = sys.stdin.readline()
    
    # 如果 readline 返回空字符串，说明 stdin 已关闭
    if line == '':
        print("INFO: stdin closed, exiting", file=sys.stderr)
        break
```

### 3. 完善进程监听
添加了 `onError` 和 `onDone` 回调：

```dart
_stdoutSubscription = _process!.stdout
    .transform(utf8.decoder)
    .transform(const LineSplitter())
    .listen(
  (line) { /* ... */ },
  onError: (error) {
    _logState?.error('Python stdout 错误: $error', type: LogType.gpib);
  },
  onDone: () {
    _logState?.debug('Python stdout 流已关闭', type: LogType.gpib);
  },
);
```

## 测试步骤

### 1. 重启应用
完全关闭并重新启动应用，确保使用最新代码。

### 2. 查看详细日志
连接时，在 GPIB 日志窗口中应该看到：

**成功的日志：**
```
开始连接 GPIB 设备: GPIB0::5::INSTR
检查 Python 环境...
找到 Python: Python 3.14.2 (命令: python)
PyVISA 已安装: 1.15.0
使用 Python 命令: python
启动 Python GPIB 桥接进程...
Python 桥接脚本已创建: C:\Users\...\gpib_bridge.py
Python: INFO: Initializing VISA Resource Manager...
Python: INFO: Available resources: ('ASRL1::INSTR', 'GPIB0::5::INSTR')
Python: INFO: Connecting to GPIB0::5::INSTR...
Python: INFO: Device identified: HEWLETT-PACKARD,66311B,US38444369.A,02.02
Python stdout: CONNECTED|OK
收到连接确认信号
Python: INFO: Entering command loop
等待 GPIB 设备响应...
✅ GPIB 设备连接成功: GPIB0::5::INSTR
```

**如果仍然失败，会看到：**
```
Python: INFO: stdin closed, exiting
Python 桥接进程退出，退出码: 0
❌ GPIB 设备连接失败
```

### 3. 手动测试 Python 脚本
如果仍然失败，可以手动测试 Python 脚本：

```bash
# 找到临时脚本
cd %TEMP%

# 手动运行
python gpib_bridge.py GPIB0::5::INSTR
```

应该看到：
```
INFO: Initializing VISA Resource Manager...
INFO: Available resources: ('ASRL1::INSTR', 'GPIB0::5::INSTR')
INFO: Connecting to GPIB0::5::INSTR...
INFO: Device identified: HEWLETT-PACKARD,66311B,US38444369.A,02.02
CONNECTED|OK
INFO: Entering command loop
```

然后输入测试命令：
```
test123|*IDN?
```

应该返回：
```
test123|HEWLETT-PACKARD,66311B,US38444369.A,02.02
```

输入 `EXIT` 退出。

## 可能的额外问题

### 问题 1：Windows 防火墙
如果 Python 进程被防火墙阻止，可能无法正常通信。

**解决方案：**
- 在 Windows 防火墙中允许 Python

### 问题 2：NI-VISA 版本
某些版本的 NI-VISA 可能与 PyVISA 不兼容。

**解决方案：**
- 更新到最新版本的 NI-VISA
- 或尝试使用 `pyvisa-py` 后端（纯 Python 实现）

### 问题 3：设备被占用
如果设备在 NI MAX 中处于打开状态，可能无法被其他程序访问。

**解决方案：**
- 在 NI MAX 中关闭设备连接
- 关闭其他可能使用该设备的程序

## 下一步

如果修复后仍然失败，请提供：
1. 完整的 GPIB 日志（从"开始连接"到失败）
2. Python 桥接进程的退出码
3. 手动运行 Python 脚本的输出

这将帮助我们进一步诊断问题。
