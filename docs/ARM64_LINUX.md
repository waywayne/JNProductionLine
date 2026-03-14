# ARM64 Linux 支持

## 概述

应用完全支持 ARM64 (aarch64) Linux 系统，包括：
- ✅ Raspberry Pi 4/5 (64-bit OS)
- ✅ ARM 服务器 (AWS Graviton, Oracle Cloud ARM)
- ✅ ARM 开发板 (NVIDIA Jetson, Rock Pi, etc.)

## 系统要求

### 最低要求
- **架构**: ARM64 (aarch64)
- **操作系统**: Ubuntu 20.04+ / Debian 11+ (64-bit)
- **内存**: 2GB RAM
- **存储**: 500MB 可用空间

### 推荐配置
- **架构**: ARM64 (aarch64)
- **操作系统**: Ubuntu 22.04 LTS / Ubuntu 24.04 LTS
- **内存**: 4GB+ RAM
- **存储**: 1GB+ 可用空间

## 安装

### 自动安装（推荐）

```bash
# 1. 下载 ARM64 构建产物
# 从 GitHub Actions 下载 linux-build-arm64.zip

# 2. 解压
unzip linux-build-arm64.zip

# 3. 运行安装脚本
sudo ./install-linux.sh
```

安装脚本会自动检测 ARM64 架构并安装正确的版本。

### 手动安装

```bash
# 1. 安装依赖
sudo apt-get update
sudo apt-get install -y \
    libgtk-3-0 \
    libblkid1 \
    liblzma5 \
    bluez \
    bluez-tools \
    socat \
    fonts-noto-cjk

# 2. 创建安装目录
sudo mkdir -p /opt/jn-production-line

# 3. 解压应用
sudo tar -xzf jn-production-line-linux-arm64.tar.gz -C /opt/jn-production-line

# 4. 设置权限
sudo chmod +x /opt/jn-production-line/jn_production_line

# 5. 创建符号链接
sudo ln -s /opt/jn-production-line/jn_production_line /usr/local/bin/jn-production-line
```

## 运行

### 命令行运行

```bash
# 使用 sudo（推荐，用于蓝牙功能）
sudo jn-production-line

# 或直接运行
/opt/jn-production-line/jn_production_line
```

### 桌面快捷方式

安装后可以在应用菜单中搜索 "JN Production Line"。

## 故障排查

### 问题 1: 应用无反应

**症状**: 运行 `sudo jn-production-line` 后没有任何输出或窗口

**可能原因**:
1. 架构不匹配（x86_64 vs ARM64）
2. 缺少依赖库
3. 文件权限问题
4. 显示环境问题

**解决方法**:

```bash
# 1. 运行诊断工具
sudo bash scripts/diagnose-linux.sh

# 2. 或运行 ARM64 专用修复工具
sudo bash scripts/fix-arm64.sh

# 3. 检查文件类型
file /opt/jn-production-line/jn_production_line
# 应该显示: ELF 64-bit LSB executable, ARM aarch64

# 4. 检查依赖库
ldd /opt/jn-production-line/jn_production_line | grep "not found"
# 不应该有任何输出

# 5. 手动运行查看错误
sudo /opt/jn-production-line/jn_production_line
```

### 问题 2: 架构不匹配

**症状**: 错误信息 "cannot execute binary file: Exec format error"

**原因**: 下载了错误的架构版本（x86_64 而不是 ARM64）

**解决方法**:

```bash
# 1. 确认系统架构
uname -m
# 应该显示: aarch64 或 arm64

# 2. 检查二进制文件架构
file /opt/jn-production-line/jn_production_line

# 3. 如果不匹配，重新下载正确的版本
# 从 GitHub Actions 下载 linux-build-arm64（不是 linux-build-x64）
```

### 问题 3: 缺少依赖库

**症状**: 错误信息 "error while loading shared libraries: xxx.so"

**解决方法**:

```bash
# 检查缺失的库
ldd /opt/jn-production-line/jn_production_line | grep "not found"

# 安装常见依赖
sudo apt-get install -y \
    libgtk-3-0 \
    libblkid1 \
    liblzma5 \
    libglib2.0-0 \
    libcairo2 \
    libpango-1.0-0
```

### 问题 4: 显示环境问题

**症状**: 错误信息 "cannot open display" 或 "No protocol specified"

**原因**: 
- SSH 连接没有 X11 转发
- 没有显示服务器运行

**解决方法**:

```bash
# 方法 1: 使用 X11 转发（SSH）
ssh -X user@arm-host
sudo -E jn-production-line

# 方法 2: 允许 root 访问 X11
xhost +local:root
sudo jn-production-line

# 方法 3: 在本地终端运行
# 直接在 ARM 设备的图形界面终端中运行
```

### 问题 5: 蓝牙扫描失败

**症状**: 点击"Linux蓝牙"后无法扫描设备

**解决方法**:

```bash
# 1. 检查蓝牙服务
sudo systemctl status bluetooth

# 2. 启动蓝牙服务
sudo systemctl start bluetooth

# 3. 检查蓝牙适配器
hciconfig hci0

# 4. 启用适配器
sudo hciconfig hci0 up

# 5. 测试扫描
sudo hcitool scan

# 6. 如果 hcitool 不可用
sudo apt-get install -y bluez bluez-tools
```

## 性能优化

### Raspberry Pi 优化

```bash
# 1. 增加 GPU 内存（编辑 /boot/config.txt）
gpu_mem=256

# 2. 启用硬件加速
sudo apt-get install -y mesa-utils

# 3. 优化 GTK 性能
export GDK_RENDERING=gl
```

### 低内存设备

```bash
# 减少 Flutter 内存使用
export FLUTTER_LOW_MEMORY=true
```

## 已知限制

### ARM64 特定限制
1. **性能**: ARM 设备性能可能低于 x86_64，UI 可能不够流畅
2. **蓝牙**: 某些 ARM 开发板的蓝牙驱动可能不完整
3. **字体**: 某些 ARM 系统可能需要手动安装中文字体

### 解决方案
```bash
# 安装中文字体
sudo bash scripts/install-chinese-fonts.sh

# 优化性能
export GDK_SCALE=1
export GDK_DPI_SCALE=1
```

## 测试的 ARM64 平台

| 平台 | 状态 | 备注 |
|------|------|------|
| Raspberry Pi 4 (4GB) | ✅ 测试通过 | 推荐 Ubuntu 22.04+ |
| Raspberry Pi 5 (8GB) | ✅ 测试通过 | 性能优秀 |
| AWS Graviton2 | ✅ 测试通过 | 服务器环境 |
| Oracle Cloud ARM | ✅ 测试通过 | 免费层可用 |
| NVIDIA Jetson Nano | ⚠️ 部分支持 | 需要额外配置 |
| Rock Pi 4 | ✅ 测试通过 | Debian 11+ |

## 构建 ARM64 版本

如果需要自己构建 ARM64 版本：

```bash
# 在 ARM64 设备上
git clone https://github.com/waywayne/JNProductionLine.git
cd JNProductionLine
./scripts/build-linux.sh

# 或使用 Docker（在 x86_64 上交叉编译）
docker buildx build --platform linux/arm64 -f Dockerfile.linux .
```

## 相关文档

- [LINUX_BUILD_GUIDE.md](LINUX_BUILD_GUIDE.md) - Linux 构建指南
- [BLUETOOTH_PERMISSIONS.md](BLUETOOTH_PERMISSIONS.md) - 蓝牙权限配置
- [CHINESE_FONTS.md](CHINESE_FONTS.md) - 中文字体支持

## 获取帮助

如果遇到问题：

1. **运行诊断工具**: `sudo bash scripts/diagnose-linux.sh`
2. **查看日志**: `journalctl -xe | grep jn_production`
3. **提交 Issue**: https://github.com/waywayne/JNProductionLine/issues

提交 Issue 时请包含：
- 系统架构: `uname -m`
- 操作系统: `cat /etc/os-release`
- 诊断输出: `sudo bash scripts/diagnose-linux.sh`
