# 快速开始 - Linux 一键安装

## 🚀 一键安装所有依赖

本项目的 `install-linux.sh` 脚本会自动安装所有必需的依赖，包括：

### 📦 自动安装的组件

1. **系统依赖**
   - GTK3 图形库
   - BlueZ 蓝牙工具
   - 串口工具

2. **Python 环境**
   - Python3
   - pip3
   - **PyBluez (RFCOMM Socket 支持)**

3. **中文字体**
   - 思源黑体 (Noto Sans CJK)
   - 文泉驿字体

4. **应用程序**
   - JN Production Line 主程序
   - RFCOMM Socket 桥接脚本
   - 启动脚本和桌面快捷方式

## 📥 安装步骤

### 1. 下载构建文件

从 GitHub Actions 下载最新构建：

```bash
# 访问
https://github.com/waywayne/JNProductionLine/actions

# 下载对应架构的构建
- linux-build-x64.tar.gz (x86_64)
- linux-build-arm64.tar.gz (ARM64)
```

### 2. 解压并安装

```bash
# 解压下载的文件
unzip linux-build.zip

# 进入目录
cd linux-build

# 运行一键安装脚本
sudo ./install-linux.sh
```

### 3. 验证安装

```bash
# 测试 PyBluez 安装
sudo bash scripts/test-pybluez.sh

# 运行应用
sudo jn-production-line
```

## ✅ 安装脚本做了什么？

### 自动化流程

```bash
📥 更新软件源
   ↓
📦 安装系统依赖 (GTK, BlueZ, etc.)
   ↓
🐍 安装 Python3 和 PyBluez
   ↓
✅ 验证 PyBluez 安装
   ↓
📁 创建安装目录 (/opt/jn-production-line)
   ↓
📦 解压应用文件
   ↓
🔐 设置执行权限
   ↓
🔗 创建启动脚本 (/usr/local/bin/jn-production-line)
   ↓
🖥️  创建桌面快捷方式
   ↓
🔧 配置串口和 RFCOMM 权限
   ↓
✅ 安装完成！
```

## 🐍 PyBluez 安装详情

### 安装策略

脚本使用智能安装策略：

1. **优先使用系统包**
   ```bash
   apt-get install python3-bluez
   ```

2. **降级使用 pip**（如果系统包不可用）
   ```bash
   pip3 install pybluez
   ```

3. **自动验证**
   ```bash
   python3 -c "import bluetooth"
   ```

### 验证安装

```bash
# 检查 PyBluez 版本
python3 -c "import bluetooth; print(bluetooth.__version__)"

# 运行完整测试
sudo bash scripts/test-pybluez.sh
```

## 🔧 故障排查

### PyBluez 安装失败

**问题：** `ModuleNotFoundError: No module named 'bluetooth'`

**解决：**
```bash
# 方法 1: 使用系统包管理器
sudo apt-get update
sudo apt-get install python3-bluez

# 方法 2: 使用 pip
pip3 install pybluez

# 方法 3: 使用 pip (系统级)
sudo pip3 install pybluez --break-system-packages
```

### 蓝牙权限问题

**问题：** `bluetooth.btcommon.BluetoothError: (13, 'Permission denied')`

**解决：**
```bash
# 使用 sudo 运行
sudo jn-production-line
```

### 中文显示乱码

**问题：** 应用中中文显示为方块

**解决：**
```bash
# 更新字体缓存
sudo fc-cache -fv

# 重启应用
sudo jn-production-line
```

## 📋 系统要求

### 支持的系统

- ✅ Ubuntu 20.04+
- ✅ Debian 11+
- ✅ Linux Mint 20+
- ✅ 其他基于 Debian 的发行版

### 支持的架构

- ✅ x86_64 (AMD64)
- ✅ ARM64 (aarch64)

### 最低要求

- **Python**: 3.6+
- **磁盘空间**: 500 MB
- **内存**: 2 GB
- **蓝牙**: 支持 Bluetooth 2.0+

## 🎯 使用方法

### 启动应用

```bash
# 方法 1: 使用启动脚本（推荐）
sudo jn-production-line

# 方法 2: 直接运行
sudo /opt/jn-production-line/jn_production_line

# 方法 3: 从应用菜单
# 搜索 "JN Production Line"
```

### 蓝牙连接

应用会自动使用 RFCOMM Socket 进行蓝牙通信：

1. 扫描设备
2. 选择设备
3. 自动配对和连接
4. 使用 Python RFCOMM Socket 通信

### 测试功能

- ✅ 自动测试流程
- ✅ 手动测试项目
- ✅ 数据记录和导出
- ✅ 实时日志查看

## 📚 相关文档

- [RFCOMM Socket 实现](RFCOMM_SOCKET.md) - 蓝牙通信架构
- [Linux 构建指南](LINUX_BUILD_GUIDE.md) - 从源码构建
- [蓝牙权限配置](BLUETOOTH_PERMISSIONS.md) - 权限说明
- [中文字体支持](CHINESE_FONTS.md) - 字体配置

## 💡 提示

### 生产环境使用

```bash
# 1. 一键安装
sudo ./install-linux.sh

# 2. 验证安装
sudo bash scripts/test-pybluez.sh

# 3. 运行应用
sudo jn-production-line
```

### 开发环境使用

```bash
# 1. 克隆仓库
git clone https://github.com/waywayne/JNProductionLine.git

# 2. 安装依赖
cd JNProductionLine
sudo apt-get install python3-bluez

# 3. 运行开发版本
flutter run -d linux
```

## 🎉 总结

**一键安装脚本自动完成所有配置，无需手动安装任何依赖！**

只需运行：
```bash
sudo ./install-linux.sh
```

就能获得完整的生产测试环境，包括：
- ✅ 应用程序
- ✅ Python 蓝牙支持
- ✅ 中文字体
- ✅ 所有必需工具

**简单、快速、可靠！** 🚀
