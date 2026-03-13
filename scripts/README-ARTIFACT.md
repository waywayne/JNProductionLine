# JN Production Line - Linux 构建产物

## 📦 包含文件

- `jn-production-line-linux-x64.tar.gz` - Linux 应用程序包（约 50-100 MB）
- `install-linux.sh` - 一键安装脚本

## 🚀 快速安装

### 方法 1: 一键安装（推荐）

```bash
# 运行安装脚本
chmod +x install-linux.sh
sudo ./install-linux.sh
```

安装脚本会自动：
- ✅ 安装系统依赖（GTK3, BlueZ 等）
- ✅ 解压应用到 `/opt/jn-production-line`
- ✅ 创建命令行快捷方式 `jn-production-line`
- ✅ 创建桌面快捷方式
- ✅ 配置蓝牙和串口权限

### 方法 2: 手动安装

```bash
# 1. 安装系统依赖
sudo apt-get update
sudo apt-get install -y libgtk-3-0 libblkid1 liblzma5 bluez bluez-tools socat

# 2. 解压到系统目录
sudo mkdir -p /opt/jn-production-line
sudo tar -xzf jn-production-line-linux-x64.tar.gz -C /opt/jn-production-line

# 3. 设置执行权限
sudo chmod +x /opt/jn-production-line/jn_production_line

# 4. 创建快捷方式（可选）
sudo ln -s /opt/jn-production-line/jn_production_line /usr/local/bin/jn-production-line
```

## 🎮 运行应用

安装完成后：

```bash
# 命令行运行
jn-production-line

# 或从应用菜单启动
# 搜索 "JN Production Line"
```

## ⚙️ 系统要求

- **操作系统**: Ubuntu 20.04+ / Debian 11+
- **内存**: 2 GB RAM
- **存储**: 200 MB 可用空间

## 🔧 权限配置

如果需要使用蓝牙功能，安装后需要重新登录以使权限生效：

```bash
# 重新登录
# 或运行
newgrp bluetooth
```

## 🗑️ 卸载

```bash
sudo rm -rf /opt/jn-production-line
sudo rm /usr/local/bin/jn-production-line
sudo rm /usr/share/applications/jn-production-line.desktop
```

## 📚 更多信息

- **GitHub**: https://github.com/waywayne/JNProductionLine
- **完整文档**: 查看仓库中的 INSTALL.md
- **问题反馈**: https://github.com/waywayne/JNProductionLine/issues
