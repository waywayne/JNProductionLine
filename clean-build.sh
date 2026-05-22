#!/bin/bash

# 清理构建缓存脚本
# 用于解决 CMake 缓存导致的构建问题

echo "🧹 清理构建缓存..."

# 清理 Windows 构建缓存
if [ -d "build/windows" ]; then
    echo "  删除 build/windows/"
    rm -rf build/windows
fi

# 清理 Linux 构建缓存
if [ -d "build/linux" ]; then
    echo "  删除 build/linux/"
    rm -rf build/linux
fi

# 清理 macOS 构建缓存
if [ -d "build/macos" ]; then
    echo "  删除 build/macos/"
    rm -rf build/macos
fi

# 清理 Flutter 缓存
echo "  运行 flutter clean"
flutter clean

echo "✅ 清理完成！"
echo ""
echo "现在可以重新构建："
echo "  Windows: flutter build windows --release"
echo "  Linux:   flutter build linux --release"
echo "  macOS:   flutter build macos --release"
