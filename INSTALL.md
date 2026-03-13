# JN Production Line - 安装指南

## 📦 从 GitHub CI 获取构建产物

### 方法 1: 手动下载（推荐）

1. **访问 GitHub Actions 页面**
   ```
   https://github.com/waywayne/JNProductionLine/actions
   ```

2. **触发新构建（可选）**
   - 点击左侧 "Build Linux Application"
   - 点击右侧 "Run workflow" 按钮
   - 选择 `main` 分支
   - 点击绿色 "Run workflow" 按钮
   - 等待 5-10 分钟构建完成

3. **下载构建产物**
   - 点击最新的成功构建（绿色 ✓）
   - 滚动到页面底部 "Artifacts" 部分
   - 点击 `linux-build` 下载（约 50-100 MB）

4. **解压下载的文件**
   ```bash
   unzip linux-build.zip
   ```
   
   解压后得到：
   - `jn-production-line-linux-x64.tar.gz` - 主程序包
   - `install-linux.sh` - 一键安装脚本

### 方法 2: 使用 GitHub CLI

```bash
# 安装 GitHub CLI
sudo apt install gh

# 登录
gh auth login

# 下载最新构建产物
gh run download --repo waywayne/JNProductionLine

# 进入下载目录
cd linux-build
```

## 🚀 快速安装

### 一键安装（推荐）

```bash
# 1. 下载并解压 linux-build.zip
unzip linux-build.zip

# 2. 运行安装脚本
chmod +x install-linux.sh
sudo ./install-linux.sh
```

安装脚本会自动：
- ✅ 安装系统依赖（GTK3, BlueZ, 等）
- ✅ 解压应用到 `/opt/jn-production-line`
- ✅ 创建命令行快捷方式
- ✅ 创建桌面快捷方式
- ✅ 配置蓝牙和串口权限

### 手动安装

```bash
# 1. 安装系统依赖
sudo apt-get update
sudo apt-get install -y libgtk-3-0 libblkid1 liblzma5 bluez bluez-tools socat

# 2. 创建安装目录
sudo mkdir -p /opt/jn-production-line

# 3. 解压应用
sudo tar -xzf jn-production-line-linux-x64.tar.gz -C /opt/jn-production-line

# 4. 设置执行权限
sudo chmod +x /opt/jn-production-line/jn_production_line

# 5. 创建启动脚本（可选）
sudo tee /usr/local/bin/jn-production-line > /dev/null <<'EOF'
#!/bin/bash
cd /opt/jn-production-line
exec ./jn_production_line "$@"
EOF
sudo chmod +x /usr/local/bin/jn-production-line

# 6. 配置蓝牙权限
sudo usermod -a -G bluetooth $USER
```

## 🎮 运行应用

安装完成后，有三种方式运行：

### 方法 1: 命令行
```bash
jn-production-line
```

### 方法 2: 应用菜单
在应用菜单中搜索 "JN Production Line" 并点击

### 方法 3: 直接运行
```bash
/opt/jn-production-line/jn_production_line
```

## ⚙️ 系统要求

### 最低要求
- **操作系统**: Ubuntu 20.04+ / Debian 11+
- **内存**: 2 GB RAM
- **存储**: 200 MB 可用空间

### 推荐配置
- **操作系统**: Ubuntu 22.04 LTS
- **内存**: 4 GB RAM
- **存储**: 500 MB 可用空间

### 必需的系统库
- GTK 3.0
- BlueZ 5.0+（蓝牙功能）
- libserialport（串口功能）

## 🔧 权限配置

### 蓝牙权限

如果使用蓝牙功能，需要配置权限：

```bash
# 添加用户到蓝牙组
sudo usermod -a -G bluetooth $USER

# 重新登录或运行
newgrp bluetooth
```

### 串口权限

如果使用串口功能：

```bash
# 添加用户到 dialout 组
sudo usermod -a -G dialout $USER

# 重新登录生效
```

## 🗑️ 卸载

```bash
# 删除应用文件
sudo rm -rf /opt/jn-production-line

# 删除符号链接
sudo rm /usr/local/bin/jn-production-line

# 删除桌面快捷方式
sudo rm /usr/share/applications/jn-production-line.desktop

# 更新桌面数据库
sudo update-desktop-database
```

## 🐛 故障排查

### 应用无法启动

**错误**: `error while loading shared libraries`
```bash
# 解决: 安装缺失的库
sudo apt-get install -y libgtk-3-0 libblkid1 liblzma5
```

### 蓝牙功能不可用

**错误**: 无法访问蓝牙设备
```bash
# 检查蓝牙服务
sudo systemctl status bluetooth

# 启动蓝牙服务
sudo systemctl start bluetooth

# 检查用户组
groups $USER | grep bluetooth
```

### 串口无法访问

**错误**: Permission denied on /dev/ttyUSB0
```bash
# 添加权限
sudo usermod -a -G dialout $USER

# 或临时授权
sudo chmod 666 /dev/ttyUSB0
```

## 📚 更多信息

- **完整文档**: [docs/CI_BUILD_GUIDE.md](docs/CI_BUILD_GUIDE.md)
- **Linux 构建问题**: [docs/LINUX_BUILD_GUIDE.md](docs/LINUX_BUILD_GUIDE.md)
- **GitHub 仓库**: https://github.com/waywayne/JNProductionLine
- **问题反馈**: https://github.com/waywayne/JNProductionLine/issues

## 📝 版本信息

- **当前版本**: 1.0.0
- **Flutter 版本**: 3.24.0
- **构建平台**: Ubuntu 22.04
- **最后更新**: 2026-03-13
