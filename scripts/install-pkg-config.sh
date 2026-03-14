#!/bin/bash
# 快速安装 pkg-config

echo "📦 安装 pkg-config"
echo "================================"
echo ""

# 检查是否为 root
if [ "$(id -u)" -ne 0 ]; then 
    echo "❌ 请使用 sudo 运行此脚本"
    echo "   示例: sudo ./install-pkg-config.sh"
    exit 1
fi

# 检查是否已安装
if command -v pkg-config &> /dev/null; then
    PKG_VERSION=$(pkg-config --version)
    echo "✅ pkg-config 已安装: $PKG_VERSION"
    echo ""
    exit 0
fi

echo "📥 正在安装 pkg-config..."
apt-get update -qq
apt-get install -y pkg-config

# 验证安装
if command -v pkg-config &> /dev/null; then
    PKG_VERSION=$(pkg-config --version)
    echo ""
    echo "✅ pkg-config 安装成功: $PKG_VERSION"
    echo ""
    echo "现在可以运行诊断工具:"
    echo "  sudo bash scripts/diagnose-linux.sh"
else
    echo ""
    echo "❌ pkg-config 安装失败"
    echo ""
    echo "请手动安装:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install -y pkg-config"
fi
echo ""
