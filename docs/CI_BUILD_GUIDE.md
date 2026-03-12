# CI 构建指南

## GitHub Actions 自动构建

### 配置文件
- `.github/workflows/build-linux.yml`: Linux 自动构建配置

### 自动触发
- Push 到 main/master/develop 分支
- 创建 Pull Request
- 手动触发

### 构建产物
构建完成后，可在 GitHub Actions 页面下载：
- `jn-production-line-linux-x64.tar.gz`: Linux 应用程序包
- `*.AppImage`: AppImage 格式（可选）

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

### 解压并运行

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
