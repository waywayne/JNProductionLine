#!/bin/bash
# 测试应用是否能运行

echo "🧪 测试应用运行"
echo "================================"
echo ""

INSTALL_DIR="/opt/jn-production-line"
BINARY_PATH="$INSTALL_DIR/jn_production_line"

# 检查文件是否存在
if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ 应用未安装: $BINARY_PATH"
    echo "   请先运行: sudo ./install-linux.sh"
    exit 1
fi

echo "✅ 找到应用: $BINARY_PATH"
echo ""

# 检查权限
if [ ! -x "$BINARY_PATH" ]; then
    echo "❌ 文件不可执行"
    echo "   修复: sudo chmod +x $BINARY_PATH"
    exit 1
fi

echo "✅ 文件可执行"
echo ""

# 设置环境变量抑制警告
export G_MESSAGES_DEBUG=""
export G_ENABLE_DIAGNOSTIC=0
export G_DEBUG=""

echo "🚀 启动应用..."
echo "   (按 Ctrl+C 停止)"
echo ""

# 切换到安装目录并运行
cd "$INSTALL_DIR"

# 如果是 root 用户直接运行，否则提示使用 sudo
if [ "$(id -u)" -eq 0 ]; then
    exec "./$BINARY_PATH" "$@"
else
    echo "💡 提示: 蓝牙功能需要 sudo 权限"
    echo "   建议使用: sudo bash $0"
    echo ""
    exec "./$BINARY_PATH" "$@"
fi
