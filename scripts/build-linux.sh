#!/bin/bash
# Linux 构建脚本

set -e

echo "================================"
echo "JN Production Line - Linux Build"
echo "================================"

# 检查 Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

echo "✅ Flutter version:"
flutter --version

# 安装系统依赖
echo ""
echo "📦 Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y \
    clang cmake ninja-build pkg-config libgtk-3-dev \
    liblzma-dev bluez bluez-tools libbluetooth-dev socat

# 启用 Linux 桌面
echo ""
echo "🔧 Enabling Linux desktop..."
flutter config --enable-linux-desktop

# 移除问题插件
echo ""
echo "🔧 Removing flutter_bluetooth_classic_serial from pubspec.yaml..."
echo "   (Windows-only plugin with broken Linux CMakeLists.txt)"
sed -i.bak '/flutter_bluetooth_classic_serial/d' pubspec.yaml

# 获取依赖
echo ""
echo "📥 Getting Flutter dependencies..."
flutter pub get

# 代码分析
echo ""
echo "🔍 Analyzing code..."
flutter analyze || true

# 构建
echo ""
echo "🔨 Building Linux application..."
flutter build linux --release

# 打包
echo ""
echo "📦 Packaging application..."
cd build/linux/x64/release/bundle
tar -czf ../../../../../jn-production-line-linux-x64.tar.gz .
cd ../../../../../

echo ""
echo "✅ Build completed successfully!"
echo "📦 Package: jn-production-line-linux-x64.tar.gz"
ls -lh jn-production-line-linux-x64.tar.gz
