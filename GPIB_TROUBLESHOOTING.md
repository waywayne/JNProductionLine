# GPIB 连接问题排查指南

## 问题：连接时提示"GPIB设备未连接"，但 NI MAX 能看到设备

### 解决步骤

#### 1. 检查 Python 环境
点击 **"检查环境"** 按钮，确认：
- ✅ Python 已安装
- ✅ PyVISA 已安装

如果有问题，点击 **"安装依赖"** 按钮。

#### 2. 扫描 GPIB 设备
点击 **"扫描 GPIB 设备"** 按钮，查看：
- 是否能找到设备
- 设备地址是否正确（如 `GPIB0::10::INSTR`）

#### 3. 检查日志输出
在右侧 GPIB 日志窗口中查看详细信息：

**正常连接日志：**
```
开始连接 GPIB 设备: GPIB0::10::INSTR
检查 Python 环境...
找到 Python: Python 3.11.0 (命令: python)
PyVISA 已安装: 1.13.0
使用 Python 命令: python
启动 Python GPIB 桥接进程...
Python: INFO: Initializing VISA Resource Manager...
Python: INFO: Available resources: ('GPIB0::10::INSTR',)
Python: INFO: Connecting to GPIB0::10::INSTR...
Python: INFO: Device identified: Keysight Technologies,66319D,...
等待 GPIB 设备响应...
✅ GPIB 设备连接成功: GPIB0::10::INSTR
```

**连接失败日志：**
```
Python: ERROR: Failed to connect to GPIB0::10::INSTR: ...
Python: ERROR: Make sure NI-VISA is installed and the device is accessible
❌ Python 桥接进程已退出
```

### 常见问题

#### 问题 1：找不到设备
**症状：** 扫描设备返回空列表

**解决方案：**
1. 确认设备已开机
2. 检查 GPIB 线缆连接
3. 在 NI MAX 中测试设备通信
4. 重启 NI-VISA 服务

#### 问题 2：连接超时
**症状：** 日志显示"连接超时：设备未响应"

**解决方案：**
1. 检查设备地址是否正确
2. 确认设备没有被其他程序占用
3. 在 NI MAX 中关闭设备连接
4. 重启应用程序

#### 问题 3：Python 桥接进程退出
**症状：** 日志显示"Python 桥接进程已退出"

**解决方案：**
1. 查看 Python 错误信息（日志中的 "Python: ERROR" 行）
2. 确认 NI-VISA 驱动已正确安装
3. 尝试重新安装 PyVISA：
   ```bash
   python -m pip uninstall pyvisa pyvisa-py
   python -m pip install pyvisa pyvisa-py
   ```

#### 问题 4：设备地址错误
**症状：** 连接失败，但扫描能找到设备

**解决方案：**
1. 点击"扫描 GPIB 设备"查看正确地址
2. 复制正确的地址到输入框
3. 常见格式：`GPIB0::10::INSTR`（10 是设备地址）

### 改进内容

#### 1. 增强的 Python 桥接脚本
- ✅ 列出所有可用资源
- ✅ 测试设备连接（发送 *IDN? 查询）
- ✅ 发送连接成功信号
- ✅ 详细的错误信息

#### 2. 改进的连接逻辑
- ✅ 等待 Python 脚本的连接确认
- ✅ 10 秒超时保护
- ✅ 检查进程状态
- ✅ 详细的日志输出

#### 3. 新增功能
- ✅ **扫描 GPIB 设备** - 列出所有可用设备
- ✅ **实时日志** - 显示 Python 脚本输出
- ✅ **连接状态验证** - 确保设备真正连接

### 调试技巧

#### 1. 手动测试 Python 脚本
创建测试脚本 `test_gpib.py`：
```python
import pyvisa

# 列出所有资源
rm = pyvisa.ResourceManager()
print("Available resources:")
print(rm.list_resources())

# 连接设备
address = "GPIB0::10::INSTR"
inst = rm.open_resource(address)
print(f"Connected to: {address}")

# 查询设备
idn = inst.query("*IDN?")
print(f"Device: {idn}")

inst.close()
rm.close()
```

运行：
```bash
python test_gpib.py
```

#### 2. 检查 NI-VISA 安装
在 Windows 命令行中：
```bash
# 检查 VISA 版本
visa32.dll

# 或在 Python 中
python -c "import pyvisa; print(pyvisa.__version__)"
```

#### 3. 查看临时脚本
临时脚本位置：`%TEMP%\gpib_bridge.py`

可以手动运行查看详细输出：
```bash
python %TEMP%\gpib_bridge.py GPIB0::10::INSTR
```

### 联系支持

如果以上方法都无法解决问题，请提供：
1. "检查环境"按钮的输出
2. "扫描 GPIB 设备"的结果
3. 连接失败时的完整日志
4. NI MAX 中的设备信息截图
