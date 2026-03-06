# Python 蓝牙测试使用指南

## 快速开始

### 1. 启动应用

应用启动后，Python 蓝牙服务处于未初始化状态，不会占用资源。

### 2. 点击"Python蓝牙测试"按钮

首次点击时，会自动进行以下步骤：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔧 初始化 Python 蓝牙服务...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 步骤 1/3: 检查 Python 环境
   ✅ Python: python

📋 步骤 2/3: 查找蓝牙测试脚本
   ✅ 脚本: C:\...\scripts\bluetooth_spp_test.py

📋 步骤 3/3: 检查 PyBluez 安装状态
   ⚠️  PyBluez 未安装

🔧 开始自动安装 PyBluez...
   这可能需要 30-60 秒，请稍候...
   方法 1: 尝试使用 pip 安装...
   ✅ pip 安装成功

✅ PyBluez 自动安装成功

🎉 Python 蓝牙服务初始化完成
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 3. 自动测试

初始化成功后，自动执行蓝牙测试：

```
🐍 开始 Python 蓝牙测试
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔍 扫描蓝牙设备...
✅ 选择设备: Kanaan-00LI (AA:BB:CC:DD:EE:FF)

🔍 查找设备服务...
✅ 找到服务: Serial Port

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📖 测试: 读取蓝牙 MAC 地址

📤 发送 GTP 数据包 (36 字节):
   D0 D2 C5 C2 00 20 00 03 04 00 00 XX ...

✅ 发送成功

📥 收到数据 (42 字节):
   D0 D2 C5 C2 00 26 00 03 04 00 00 XX ...

✅ Python 蓝牙测试成功
   设备 MAC: AA:BB:CC:DD:EE:FF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 工作流程

```
点击"Python蓝牙测试"
    ↓
检查服务是否已初始化
    ↓ 否
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
初始化流程
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ↓
步骤 1: 查找 Python (python/python3/py)
    ↓ 成功
步骤 2: 查找脚本 (scripts/bluetooth_spp_test.py)
    ↓ 成功
步骤 3: 检查 PyBluez
    ↓ 未安装
自动安装 PyBluez
    ├─ 方法 1: pip install pybluez --user
    └─ 方法 2: python setup_bluetooth.py --install
    ↓ 成功
验证安装
    ↓ 成功
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
测试流程
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ↓
扫描蓝牙设备
    ↓
选择设备
    ↓
查找 SPP 服务
    ↓
发送 GTP 命令
    ↓
接收响应
    ↓
显示结果
```

## 常见问题

### Q1: 初始化失败 - 未找到 Python

**日志**:
```
📋 步骤 1/3: 检查 Python 环境
   ❌ 未找到 Python 环境
   请安装 Python 3.7+ 并添加到 PATH
```

**解决方案**:
1. 安装 Python 3.7+
   - 下载: https://www.python.org/downloads/
   - 安装时勾选"Add Python to PATH"

2. 验证安装
   ```bash
   python --version
   # 或
   python3 --version
   ```

3. 重启应用

### Q2: 初始化失败 - 未找到脚本

**日志**:
```
📋 步骤 2/3: 查找蓝牙测试脚本
   ❌ 未找到蓝牙测试脚本
   脚本路径: scripts/bluetooth_spp_test.py
```

**解决方案**:
1. 确认文件存在
   ```
   项目根目录/
   └── scripts/
       ├── bluetooth_spp_test.py
       └── setup_bluetooth.py
   ```

2. 检查文件权限

3. 重新部署应用

### Q3: PyBluez 自动安装失败

**日志**:
```
🔧 开始自动安装 PyBluez...
   方法 1: 尝试使用 pip 安装...
   ⚠️  pip 安装失败
   方法 2: 尝试使用安装脚本...
   ⚠️  脚本安装失败

❌ 自动安装失败
```

**解决方案**:

#### 方法 1: 使用预编译 wheel（推荐）

```bash
# 1. 下载对应版本的 wheel 文件
# https://www.lfd.uci.edu/~gohlke/pythonlibs/#pybluez
# 例如: PyBluez-0.23-cp39-cp39-win_amd64.whl

# 2. 安装
pip install PyBluez-0.23-cp39-cp39-win_amd64.whl
```

#### 方法 2: 安装 Visual Studio Build Tools

```bash
# 1. 下载并安装 Visual Studio Build Tools
# https://visualstudio.microsoft.com/downloads/

# 2. 选择"使用 C++ 的桌面开发"

# 3. 重新尝试安装
pip install pybluez --user
```

#### 方法 3: 使用 conda

```bash
# 1. 安装 Anaconda 或 Miniconda

# 2. 安装 PyBluez
conda install -c conda-forge pybluez
```

### Q4: 扫描不到设备

**日志**:
```
🔍 扫描蓝牙设备...
❌ 未找到任何蓝牙设备
```

**解决方案**:
1. 确保蓝牙设备已开启
2. 确保设备已配对（Windows 设置 -> 蓝牙）
3. 确保设备在范围内（< 10米）
4. 重启 Windows 蓝牙服务
5. 检查蓝牙适配器是否正常

### Q5: 连接超时

**日志**:
```
📖 测试: 读取蓝牙 MAC 地址
⚠️  接收超时或错误: timeout
```

**解决方案**:
1. 确认设备支持 SPP 协议
2. 确认 RFCOMM channel 正确
3. 检查防火墙设置
4. 尝试重新配对设备

## 高级用法

### 指定设备地址

```dart
await state.testPythonBluetooth(
  deviceAddress: 'AA:BB:CC:DD:EE:FF',
);
```

### 使用自定义 UUID

```dart
await state.testPythonBluetooth(
  deviceAddress: 'AA:BB:CC:DD:EE:FF',
  uuid: '6E400001-B5A3-F393-E0A9-E50E24DCCA9E',
);
```

### 指定 RFCOMM Channel

```dart
await state.testPythonBluetooth(
  deviceAddress: 'AA:BB:CC:DD:EE:FF',
  channel: 1,
);
```

## 性能优化

### 首次使用

- **初始化时间**: 1-3 秒（已安装 PyBluez）
- **安装时间**: 30-60 秒（首次安装）
- **扫描时间**: 5-10 秒
- **测试时间**: 2-5 秒

### 后续使用

- **初始化时间**: < 1 秒（已初始化）
- **测试时间**: 2-5 秒

### 优化建议

1. **预安装 PyBluez**
   ```bash
   pip install pybluez --user
   ```

2. **使用设备地址**
   - 跳过扫描步骤
   - 直接连接设备

3. **指定 UUID/Channel**
   - 跳过服务发现
   - 加快连接速度

## 故障排查清单

- [ ] Python 已安装（python --version）
- [ ] Python 在 PATH 中
- [ ] PyBluez 已安装（python -c "import bluetooth"）
- [ ] 脚本文件存在（scripts/bluetooth_spp_test.py）
- [ ] 蓝牙适配器已启用
- [ ] 设备已配对
- [ ] 设备在范围内
- [ ] 防火墙允许蓝牙连接

## 日志级别

应用使用不同的日志级别：

- **info** - 一般信息
- **success** - 成功操作
- **warning** - 警告信息
- **error** - 错误信息
- **debug** - 调试信息

所有 Python 蓝牙相关日志都使用 `LogType.debug`，可以在日志面板中查看。

## 技术支持

如果遇到问题：

1. 查看详细日志
2. 检查故障排查清单
3. 参考常见问题
4. 查阅文档:
   - `/docs/WINDOWS_SPP_PYTHON.md`
   - `/docs/AUTO_INSTALL_PYBLUEZ.md`
   - `/scripts/README_BLUETOOTH.md`
