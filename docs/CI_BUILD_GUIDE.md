# CI 构建指南

## GitHub Actions 自动构建

### 配置文件
- `.github/workflows/build-linux.yml`: Linux 自动构建配置

### 自动触发
- Push 到 main/master/develop 分支
- 创建 Pull Request
- 手动触发（推荐）

### 手动触发构建

1. **访问 GitHub Actions 页面**
   ```
   https://github.com/waywayne/JNProductionLine/actions
   ```

2. **选择 "Build Linux Application" workflow**

3. **点击 "Run workflow" 按钮**
   - 选择分支（通常是 main）
   - 点击绿色的 "Run workflow" 按钮

4. **等待构建完成**（约 5-10 分钟）
   - 绿色 ✓ = 构建成功
   - 红色 ✗ = 构建失败（查看日志）

### 下载构建产物

#### 方法 1: 从 GitHub Actions 页面下载（推荐）

1. 进入 Actions 页面
2. 点击最新的成功构建（绿色 ✓）
3. 滚动到页面底部 "Artifacts" 部分
4. 下载 `linux-build` 压缩包
5. 解压后得到：
   - `jn-production-line-linux-x64.tar.gz` - 主程序包
   - `*.AppImage` - AppImage 格式（如果构建成功）

#### 方法 2: 使用 GitHub CLI

```bash
# 安装 GitHub CLI
sudo apt install gh

# 登录
gh auth login

# 列出最近的 workflow runs
gh run list --repo waywayne/JNProductionLine --workflow="Build Linux Application"

# 下载最新的构建产物
gh run download --repo waywayne/JNProductionLine

# 或指定特定的 run ID
gh run download <RUN_ID> --repo waywayne/JNProductionLine
```

#### 方法 3: 使用 API 下载

```bash
# 获取最新的 artifact URL
curl -H "Authorization: token YOUR_GITHUB_TOKEN" \
  https://api.github.com/repos/waywayne/JNProductionLine/actions/artifacts

# 下载 artifact
curl -L -H "Authorization: token YOUR_GITHUB_TOKEN" \
  -o linux-build.zip \
  "ARTIFACT_DOWNLOAD_URL"
```

### 构建产物说明

#### jn-production-line-linux-x64.tar.gz
- **格式**: tar.gz 压缩包
- **内容**: 完整的 Linux 应用程序
- **大小**: 约 50-100 MB
- **包含**:
  - `jn_production_line` - 主程序可执行文件
  - `lib/` - 共享库文件
  - `data/` - 资源文件（图标、字体等）

#### *.AppImage（可选）
- **格式**: AppImage 自包含格式
- **优点**: 
  - 无需安装，直接运行
  - 包含所有依赖
  - 适合便携使用
- **使用**:
  ```bash
  chmod +x *.AppImage
  ./*.AppImage
  ```

## 本地构建

### 方法 1: 直接构建

```bash
# 赋予执行权限
chmod +x scripts/build-linux.sh

# 运行构建脚本
./scripts/build-linux.sh
```

### 方法 2: Docker 构建

```bash
# 赋予执行权限
chmod +x scripts/docker-build.sh

# 使用 Docker 构建
./scripts/docker-build.sh
```

### 方法 3: 手动构建

```bash
# 1. 安装系统依赖
sudo apt-get update
sudo apt-get install -y \
    clang cmake ninja-build pkg-config libgtk-3-dev \
    liblzma-dev bluez bluez-tools libbluetooth-dev socat

# 2. 配置 Flutter
flutter config --enable-linux-desktop

# 3. 获取依赖
flutter pub get

# 4. 构建
flutter build linux --release

# 5. 打包
cd build/linux/x64/release/bundle
tar -czf jn-production-line-linux-x64.tar.gz .
```

## 系统要求

### 开发工具
- Flutter SDK 3.24.0+
- Clang/LLVM
- CMake 3.10+
- Ninja build system

### 蓝牙支持
- BlueZ 5.0+
- bluez-tools
- libbluetooth-dev
- socat
- rfkill

### GTK 依赖
- libgtk-3-dev
- pkg-config

## 部署

### 快速安装（推荐）

```bash
# 1. 从 GitHub Actions 下载 linux-build.zip 并解压
unzip linux-build.zip

# 2. 安装系统依赖
sudo apt-get update
sudo apt-get install -y libgtk-3-0 libblkid1 liblzma5 bluez bluez-tools socat

# 3. 创建安装目录
sudo mkdir -p /opt/jn-production-line

# 4. 解压应用到安装目录
sudo tar -xzf jn-production-line-linux-x64.tar.gz -C /opt/jn-production-line

# 5. 设置执行权限
sudo chmod +x /opt/jn-production-line/jn_production_line

# 6. 创建符号链接（可选，方便命令行启动）
sudo ln -s /opt/jn-production-line/jn_production_line /usr/local/bin/jn-production-line

# 7. 运行应用
jn-production-line
# 或
/opt/jn-production-line/jn_production_line
```

### 一键安装脚本

创建 `install.sh`:

```bash
#!/bin/bash
set -e

echo "📦 JN Production Line 安装程序"
echo "================================"

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 请使用 sudo 运行此脚本"
    exit 1
fi

# 检查文件是否存在
if [ ! -f "jn-production-line-linux-x64.tar.gz" ]; then
    echo "❌ 找不到 jn-production-line-linux-x64.tar.gz"
    echo "   请先从 GitHub Actions 下载构建产物"
    exit 1
fi

# 安装系统依赖
echo "📥 安装系统依赖..."
apt-get update
apt-get install -y libgtk-3-0 libblkid1 liblzma5 bluez bluez-tools socat

# 创建安装目录
echo "📁 创建安装目录..."
mkdir -p /opt/jn-production-line

# 解压应用
echo "📦 解压应用..."
tar -xzf jn-production-line-linux-x64.tar.gz -C /opt/jn-production-line

# 设置权限
echo "🔐 设置权限..."
chmod +x /opt/jn-production-line/jn_production_line

# 创建符号链接
echo "🔗 创建符号链接..."
ln -sf /opt/jn-production-line/jn_production_line /usr/local/bin/jn-production-line

# 创建桌面文件
echo "🖥️  创建桌面快捷方式..."
cat > /usr/share/applications/jn-production-line.desktop <<EOF
[Desktop Entry]
Name=JN Production Line
Comment=Flutter production line test application
Exec=/opt/jn-production-line/jn_production_line
Terminal=false
Type=Application
Categories=Utility;Development;
EOF

update-desktop-database 2>/dev/null || true

# 配置蓝牙权限
echo "🔧 配置蓝牙权限..."
usermod -a -G bluetooth $SUDO_USER 2>/dev/null || true

echo ""
echo "✅ 安装完成！"
echo ""
echo "使用方法："
echo "  1. 命令行运行: jn-production-line"
echo "  2. 应用菜单中搜索 'JN Production Line'"
echo ""
echo "⚠️  注意: 如果配置了蓝牙权限，请重新登录以生效"
```

使用方法:

```bash
# 下载并解压 linux-build.zip 后
chmod +x install.sh
sudo ./install.sh
```

### 手动解压并运行

```bash
# 解压
tar -xzf jn-production-line-linux-x64.tar.gz -C /opt/jn-production-line

# 运行
cd /opt/jn-production-line
./jn_production_line
```

### 创建桌面快捷方式

```bash
cat > ~/.local/share/applications/jn-production-line.desktop << EOF
[Desktop Entry]
Name=JN Production Line
Exec=/opt/jn-production-line/jn_production_line
Icon=/opt/jn-production-line/data/flutter_assets/assets/icon.png
Type=Application
Categories=Utility;Development;
Terminal=false
EOF
```

### 系统服务（可选）

```bash
sudo cat > /etc/systemd/system/jn-production-line.service << EOF
[Unit]
Description=JN Production Line Test Service
After=network.target bluetooth.target

[Service]
Type=simple
User=production
WorkingDirectory=/opt/jn-production-line
ExecStart=/opt/jn-production-line/jn_production_line
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable jn-production-line
sudo systemctl start jn-production-line
```

## 蓝牙权限配置

### 添加用户到蓝牙组

```bash
sudo usermod -a -G bluetooth $USER
```

### 配置 udev 规则

```bash
sudo cat > /etc/udev/rules.d/99-bluetooth.rules << EOF
# Bluetooth RFCOMM devices
KERNEL=="rfcomm*", GROUP="bluetooth", MODE="0660"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger
```

### 配置 D-Bus 权限

```bash
sudo cat > /etc/dbus-1/system.d/bluetooth.conf << EOF
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <policy group="bluetooth">
    <allow send_destination="org.bluez"/>
  </policy>
</busconfig>
EOF
```

## 故障排查

### 构建失败

**问题**: Flutter 命令未找到
```bash
# 解决: 安装 Flutter
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"
```

**问题**: GTK 库缺失
```bash
# 解决: 安装 GTK 开发库
sudo apt-get install libgtk-3-dev
```

### 运行时错误

**问题**: 蓝牙权限不足
```bash
# 解决: 添加用户到蓝牙组
sudo usermod -a -G bluetooth $USER
# 重新登录生效
```

**问题**: RFCOMM 设备无法访问
```bash
# 解决: 检查设备权限
ls -l /dev/rfcomm*
sudo chmod 666 /dev/rfcomm*
```

**问题**: bluetoothctl 命令未找到
```bash
# 解决: 安装 bluez
sudo apt-get install bluez bluez-tools
```

## 性能优化

### 编译优化

```bash
# 使用 profile 模式（平衡性能和调试）
flutter build linux --profile

# 使用 release 模式（最佳性能）
flutter build linux --release --split-debug-info=./debug-info
```

### 减小包体积

```bash
# 移除调试符号
strip build/linux/x64/release/bundle/jn_production_line

# 压缩库文件
upx --best build/linux/x64/release/bundle/lib/*.so
```

## CI/CD 集成

### GitLab CI

```yaml
build-linux:
  image: ubuntu:22.04
  script:
    - apt-get update && apt-get install -y git curl
    - git clone https://github.com/flutter/flutter.git -b stable
    - export PATH="$PATH:`pwd`/flutter/bin"
    - ./scripts/build-linux.sh
  artifacts:
    paths:
      - jn-production-line-linux-x64.tar.gz
```

### Jenkins

```groovy
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh './scripts/build-linux.sh'
            }
        }
        stage('Archive') {
            steps {
                archiveArtifacts 'jn-production-line-linux-x64.tar.gz'
            }
        }
    }
}
```

## 参考资料

- [Flutter Linux Desktop](https://docs.flutter.dev/platform-integration/linux/building)
- [BlueZ Documentation](http://www.bluez.org/documentation/)
- [GitHub Actions](https://docs.github.com/en/actions)
