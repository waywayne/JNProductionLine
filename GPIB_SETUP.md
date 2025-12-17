# GPIB 连接问题解决方案

## 问题原因

Windows 系统没有安装 Python 环境，导致 GPIB 连接失败。

## 解决步骤

### 1. 检查环境
点击"检查环境"按钮，查看 Python 和 PyVISA 状态。

### 2. 安装 Python
如果 Python 未安装：
- 下载：https://www.python.org/downloads/
- 安装时勾选 "Add Python to PATH"
- 重启应用

### 3. 安装依赖
点击"安装依赖"按钮，自动安装 PyVISA。

### 4. 连接设备
输入 GPIB 地址（如 GPIB0::10::INSTR），点击"连接"。

## 新增功能

1. **检查环境按钮** - 检测 Python 和 PyVISA
2. **安装依赖按钮** - 一键安装 PyVISA
3. **智能连接** - 自动检查环境并提示

## 注意事项

- 必须先安装 Python 才能安装 PyVISA
- 需要 NI-VISA 驱动支持
- 支持 python/python3/py 命令
