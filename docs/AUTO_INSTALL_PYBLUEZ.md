# PyBluez 自动安装集成

## 概述

已将 PyBluez 的自动检测和安装功能集成到 Flutter 应用中，实现零配置的蓝牙测试环境。

## 工作流程

```
应用启动
    ↓
初始化 Python 蓝牙服务
    ↓
检查 Python 环境 ✓
    ↓
检查 PyBluez 安装状态
    ↓
┌─────────────┐
│ 已安装？    │
└─────────────┘
    ↓ 否
自动安装 PyBluez
    ↓
方法 1: pip install pybluez --user
    ↓ 失败
方法 2: python setup_bluetooth.py --install
    ↓
验证安装
    ↓
✅ 环境就绪
```

## 自动安装功能

### 1. 自动检测

应用启动时自动检测：
- ✅ Python 环境（python/python3/py）
- ✅ Python 版本（需要 3.7+）
- ✅ PyBluez 安装状态
- ✅ 蓝牙适配器状态

### 2. 自动安装

如果 PyBluez 未安装，自动尝试：

**方法 1: 使用 pip**
```bash
python -m pip install pybluez --user
```

**方法 2: 使用安装脚本**
```bash
python scripts/setup_bluetooth.py --install
```

### 3. 安装验证

安装后自动验证：
```python
import bluetooth
print("OK")
```

## 使用方法

### 自动模式（推荐）

应用会在启动时自动处理所有环境配置：

1. **启动应用**
2. **查看日志**
   ```
   🔧 初始化 Python 蓝牙服务...
   ✅ 找到 Python: python
   ✅ 找到脚本: scripts/bluetooth_spp_test.py
   ⚠️  PyBluez 未安装
   🔧 尝试自动安装 PyBluez...
      方法 1: 尝试使用 pip 安装...
      ✅ pip 安装成功
   ✅ PyBluez 自动安装成功
   ✅ Python 蓝牙服务初始化成功
   ```

3. **开始测试**
   - 点击"Python蓝牙测试"按钮
   - 自动扫描设备并测试

### 手动模式

如果自动安装失败，可以手动安装：

#### 方法 1: 使用安装脚本

```bash
# 检查环境
python scripts/setup_bluetooth.py --check

# 自动安装
python scripts/setup_bluetooth.py --install

# 创建批处理脚本
python scripts/setup_bluetooth.py --create-script
```

#### 方法 2: 使用 pip

```bash
# 直接安装
pip install pybluez --user

# 或使用预编译 wheel
pip install PyBluez-0.23-cp39-cp39-win_amd64.whl
```

#### 方法 3: 使用 conda

```bash
conda install -c conda-forge pybluez
```

## 文件说明

### 1. setup_bluetooth.py

自动安装和环境检测脚本。

**功能**:
- 检查 Python 版本
- 检查 PyBluez 安装状态
- 自动安装 PyBluez（pip/conda）
- 检查蓝牙适配器
- 创建 Windows 批处理安装脚本

**命令**:
```bash
# 仅检查环境
python setup_bluetooth.py --check

# 自动安装
python setup_bluetooth.py --install

# 创建安装脚本
python setup_bluetooth.py --create-script
```

### 2. install_pybluez.bat

Windows 批处理安装脚本（自动生成）。

**使用**:
```bash
# 双击运行
install_pybluez.bat

# 或命令行运行
.\install_pybluez.bat
```

### 3. PythonBluetoothService

Flutter 服务类，集成自动安装功能。

**方法**:
- `initialize()` - 初始化并自动安装
- `_checkPyBluez()` - 检查安装状态
- `_autoInstallPyBluez()` - 自动安装
- `_findSetupScript()` - 查找安装脚本

## 日志输出

### 成功安装

```
🔧 初始化 Python 蓝牙服务...
✅ 找到 Python: python
   版本: Python 3.9.7
✅ 找到脚本: C:\...\scripts\bluetooth_spp_test.py
⚠️  PyBluez 未安装
🔧 尝试自动安装 PyBluez...
   方法 1: 尝试使用 pip 安装...
   ✅ pip 安装成功
✅ PyBluez 自动安装成功
✅ Python 蓝牙服务初始化成功
```

### 安装失败

```
🔧 初始化 Python 蓝牙服务...
✅ 找到 Python: python
✅ 找到脚本: C:\...\scripts\bluetooth_spp_test.py
⚠️  PyBluez 未安装
🔧 尝试自动安装 PyBluez...
   方法 1: 尝试使用 pip 安装...
   ⚠️  pip 安装失败
   方法 2: 尝试使用安装脚本...
   ⚠️  脚本安装失败
❌ 自动安装失败
   请手动安装:
   1. pip install pybluez
   2. 或运行: python scripts/setup_bluetooth.py --install
```

## 故障排查

### 问题 1: pip 安装失败

**错误**:
```
error: Microsoft Visual C++ 14.0 or greater is required
```

**解决方案**:
1. 安装 [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/)
2. 或使用预编译 wheel:
   ```bash
   # 下载 wheel 文件
   # https://www.lfd.uci.edu/~gohlke/pythonlibs/#pybluez
   
   # 安装
   pip install PyBluez-0.23-cp39-cp39-win_amd64.whl
   ```

### 问题 2: 权限不足

**错误**:
```
ERROR: Could not install packages due to an EnvironmentError
```

**解决方案**:
```bash
# 使用 --user 参数
pip install pybluez --user

# 或以管理员身份运行
```

### 问题 3: Python 未找到

**错误**:
```
❌ 未找到 Python 环境
```

**解决方案**:
1. 安装 Python 3.7+
2. 添加 Python 到 PATH
3. 重启应用

### 问题 4: 脚本未找到

**错误**:
```
❌ 未找到蓝牙测试脚本
```

**解决方案**:
1. 确认 `scripts/bluetooth_spp_test.py` 存在
2. 确认 `scripts/setup_bluetooth.py` 存在
3. 检查文件权限

## 部署建议

### 开发环境

- ✅ 使用自动安装功能
- ✅ 开发时自动配置环境
- ✅ 无需手动干预

### 生产环境

**方案 1: 预安装（推荐）**
```bash
# 在部署前预安装 PyBluez
pip install pybluez --user
```

**方案 2: 打包依赖**
```bash
# 将 PyBluez 打包到应用中
# 使用 PyInstaller 或类似工具
```

**方案 3: 使用安装脚本**
```bash
# 提供安装脚本给用户
python setup_bluetooth.py --create-script
# 用户双击 install_pybluez.bat 安装
```

## 性能考虑

### 初始化时间

- **首次启动（需安装）**: 30-60 秒
- **后续启动（已安装）**: < 1 秒

### 优化建议

1. **缓存检测结果**
   ```dart
   // 保存安装状态到本地
   SharedPreferences prefs = await SharedPreferences.getInstance();
   await prefs.setBool('pybluez_installed', true);
   ```

2. **异步初始化**
   ```dart
   // 不阻塞主线程
   _initializePythonBluetoothService();  // 已实现
   ```

3. **跳过重复检查**
   ```dart
   // 如果已初始化，跳过检查
   if (_pythonBtService.isAvailable) return;
   ```

## 安全考虑

### 自动安装风险

- ⚠️ 自动从 PyPI 下载包
- ⚠️ 需要网络连接
- ⚠️ 可能需要管理员权限

### 缓解措施

1. **使用 --user 参数**
   - 安装到用户目录
   - 不需要管理员权限

2. **验证安装**
   - 安装后验证导入
   - 检查版本信息

3. **提供手动选项**
   - 允许用户手动安装
   - 提供详细说明

## 更新日志

- **2026-03-06**: 添加自动安装功能
- **2026-03-06**: 创建 setup_bluetooth.py 脚本
- **2026-03-06**: 集成到 PythonBluetoothService
- **2026-03-06**: 添加批处理脚本生成功能
