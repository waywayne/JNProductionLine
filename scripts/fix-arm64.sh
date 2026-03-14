#!/bin/bash
# 修复 ARM64 Linux 应用启动问题

echo "🔧 ARM64 Linux 应用修复工具"
echo "================================"
echo ""

# 检查架构
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
    echo "❌ 此脚本仅用于 ARM64 架构"
    echo "   当前架构: $ARCH"
    exit 1
fi

echo "✅ 检测到 ARM64 架构: $ARCH"
echo ""

# 检查是否为 root
if [ "$(id -u)" -ne 0 ]; then 
    echo "⚠️  建议使用 sudo 运行此脚本"
    echo "   示例: sudo ./fix-arm64.sh"
    echo ""
fi

INSTALL_DIR="/opt/jn-production-line"
BINARY_PATH="$INSTALL_DIR/jn_production_line"

# 1. 检查文件是否存在
echo "1️⃣  检查安装..."
if [ ! -f "$BINARY_PATH" ]; then
    echo "   ❌ 应用未安装: $BINARY_PATH"
    echo "   请先运行: sudo ./install-linux.sh"
    exit 1
fi
echo "   ✅ 应用已安装"
echo ""

# 2. 修复执行权限
echo "2️⃣  修复执行权限..."
chmod +x "$BINARY_PATH"
if [ -x "$BINARY_PATH" ]; then
    echo "   ✅ 执行权限已设置"
else
    echo "   ❌ 无法设置执行权限"
    exit 1
fi
echo ""

# 3. 检查文件类型
echo "3️⃣  检查二进制文件..."
FILE_INFO=$(file "$BINARY_PATH")
echo "   $FILE_INFO"

if echo "$FILE_INFO" | grep -q "ARM aarch64\|ARM64"; then
    echo "   ✅ 架构正确 (ARM64)"
elif echo "$FILE_INFO" | grep -q "x86-64\|x86_64"; then
    echo "   ❌ 错误: 这是 x86_64 版本，不能在 ARM64 上运行"
    echo "   请下载正确的 ARM64 版本"
    exit 1
else
    echo "   ⚠️  警告: 无法确定架构"
fi
echo ""

# 4. 检查依赖库
echo "4️⃣  检查依赖库..."
MISSING_LIBS=$(ldd "$BINARY_PATH" 2>&1 | grep "not found")

if [ -z "$MISSING_LIBS" ]; then
    echo "   ✅ 所有依赖库都已安装"
else
    echo "   ❌ 缺少以下库:"
    echo "$MISSING_LIBS" | sed 's/^/      /'
    echo ""
    echo "   正在尝试安装缺失的库..."
    apt-get update -qq
    apt-get install -y libgtk-3-0 libblkid1 liblzma5 2>&1 | grep -v "^Reading\|^Building"
    
    # 重新检查
    MISSING_LIBS=$(ldd "$BINARY_PATH" 2>&1 | grep "not found")
    if [ -z "$MISSING_LIBS" ]; then
        echo "   ✅ 依赖库已修复"
    else
        echo "   ⚠️  仍有缺失的库，可能需要手动安装"
    fi
fi
echo ""

# 5. 检查 GTK
echo "5️⃣  检查 GTK 环境..."

# 先检查 pkg-config 是否安装
if ! command -v pkg-config &> /dev/null; then
    echo "   ⚠️  pkg-config 未安装，正在安装..."
    apt-get update -qq
    apt-get install -y pkg-config 2>&1 | grep -v "^Reading\|^Building" || true
fi

# 检查 GTK3
if command -v pkg-config &> /dev/null && pkg-config --exists gtk+-3.0; then
    GTK_VERSION=$(pkg-config --modversion gtk+-3.0)
    echo "   ✅ GTK3 已安装: $GTK_VERSION"
else
    echo "   ❌ GTK3 未安装，正在安装..."
    apt-get update -qq
    apt-get install -y libgtk-3-0 pkg-config 2>&1 | grep -v "^Reading\|^Building" || true
    
    # 验证安装
    if command -v pkg-config &> /dev/null && pkg-config --exists gtk+-3.0; then
        GTK_VERSION=$(pkg-config --modversion gtk+-3.0)
        echo "   ✅ GTK3 已安装: $GTK_VERSION"
    else
        echo "   ⚠️  GTK3 安装可能失败，但应用可能仍能运行"
    fi
fi
echo ""

# 6. 检查显示环境
echo "6️⃣  检查显示环境..."
if [ -n "$DISPLAY" ]; then
    echo "   ✅ DISPLAY 已设置: $DISPLAY"
elif [ -n "$WAYLAND_DISPLAY" ]; then
    echo "   ✅ Wayland 显示: $WAYLAND_DISPLAY"
else
    echo "   ⚠️  警告: 没有检测到显示环境"
    echo "   如果是 SSH 连接，需要:"
    echo "   - 使用 X11 转发: ssh -X user@host"
    echo "   - 或在本地终端运行"
fi
echo ""

# 7. 测试运行
echo "7️⃣  测试运行..."
echo "   尝试启动应用（5秒超时）..."
echo ""

timeout 5 "$BINARY_PATH" 2>&1 | head -20 &
PID=$!
sleep 1

if ps -p $PID > /dev/null 2>&1; then
    echo ""
    echo "   ✅ 应用进程已启动 (PID: $PID)"
    kill $PID 2>/dev/null || true
    wait $PID 2>/dev/null || true
else
    echo ""
    echo "   ❌ 应用启动失败"
    echo ""
    echo "   尝试直接运行查看错误:"
    echo "   $ sudo $BINARY_PATH"
fi
echo ""

# 8. 创建测试脚本
echo "8️⃣  创建测试脚本..."
cat > /tmp/test-jn-app.sh <<'EOF'
#!/bin/bash
export G_MESSAGES_DEBUG=""
cd /opt/jn-production-line
./jn_production_line "$@"
EOF
chmod +x /tmp/test-jn-app.sh
echo "   ✅ 测试脚本已创建: /tmp/test-jn-app.sh"
echo ""

# 总结
echo "================================"
echo "✅ 修复完成"
echo ""
echo "尝试运行应用:"
echo "  方法 1: sudo jn-production-line"
echo "  方法 2: sudo /tmp/test-jn-app.sh"
echo "  方法 3: sudo $BINARY_PATH"
echo ""
echo "如果仍然无法运行，请运行完整诊断:"
echo "  sudo bash scripts/diagnose-linux.sh"
echo ""
