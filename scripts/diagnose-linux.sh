#!/bin/bash
# 诊断 Linux 应用运行问题

echo "🔍 JN Production Line - 诊断工具"
echo "================================"
echo ""

# 检测架构
ARCH=$(uname -m)
echo "1️⃣  系统信息"
echo "   架构: $ARCH"
echo "   内核: $(uname -r)"
echo "   发行版: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo ""

# 检查安装位置
INSTALL_DIR="/opt/jn-production-line"
BINARY_PATH="$INSTALL_DIR/jn_production_line"

echo "2️⃣  检查安装"
if [ -d "$INSTALL_DIR" ]; then
    echo "   ✅ 安装目录存在: $INSTALL_DIR"
    
    if [ -f "$BINARY_PATH" ]; then
        echo "   ✅ 可执行文件存在: $BINARY_PATH"
        
        # 检查文件权限
        PERMS=$(stat -c "%a" "$BINARY_PATH" 2>/dev/null || stat -f "%Lp" "$BINARY_PATH" 2>/dev/null)
        echo "   📋 文件权限: $PERMS"
        
        if [ -x "$BINARY_PATH" ]; then
            echo "   ✅ 文件可执行"
        else
            echo "   ❌ 文件不可执行"
            echo "   修复: sudo chmod +x $BINARY_PATH"
        fi
        
        # 检查文件类型
        echo ""
        echo "   📋 文件类型:"
        file "$BINARY_PATH" | sed 's/^/      /'
        
        # 检查架构匹配
        FILE_ARCH=$(file "$BINARY_PATH" | grep -o "ARM aarch64\|x86-64\|x86_64")
        echo ""
        echo "   📋 二进制架构: $FILE_ARCH"
        
        case "$ARCH" in
            x86_64|amd64)
                if echo "$FILE_ARCH" | grep -q "x86"; then
                    echo "   ✅ 架构匹配"
                else
                    echo "   ❌ 架构不匹配！需要 x86_64 版本"
                fi
                ;;
            aarch64|arm64)
                if echo "$FILE_ARCH" | grep -q "ARM\|aarch64"; then
                    echo "   ✅ 架构匹配"
                else
                    echo "   ❌ 架构不匹配！需要 ARM64 版本"
                fi
                ;;
        esac
        
    else
        echo "   ❌ 可执行文件不存在: $BINARY_PATH"
    fi
else
    echo "   ❌ 安装目录不存在: $INSTALL_DIR"
    echo "   请先运行: sudo ./install-linux.sh"
fi
echo ""

# 检查依赖库
echo "3️⃣  检查依赖库"
if [ -f "$BINARY_PATH" ]; then
    echo "   正在检查共享库依赖..."
    MISSING_LIBS=$(ldd "$BINARY_PATH" 2>&1 | grep "not found" || true)
    
    if [ -z "$MISSING_LIBS" ]; then
        echo "   ✅ 所有依赖库都已安装"
    else
        echo "   ❌ 缺少以下库:"
        echo "$MISSING_LIBS" | sed 's/^/      /'
        echo ""
        echo "   修复: sudo apt-get install -y libgtk-3-0 libblkid1 liblzma5"
    fi
else
    echo "   ⚠️  跳过（可执行文件不存在）"
fi
echo ""

# 检查 GTK 环境
echo "4️⃣  检查 GTK 环境"

# 先检查 pkg-config 是否存在
if ! command -v pkg-config &> /dev/null; then
    echo "   ⚠️  pkg-config 未安装"
    echo "   修复: sudo apt-get install -y pkg-config"
    echo "   注意: pkg-config 是检查 GTK 的工具，但 GTK 可能已安装"
else
    # 检查 GTK3
    if pkg-config --exists gtk+-3.0; then
        GTK_VERSION=$(pkg-config --modversion gtk+-3.0)
        echo "   ✅ GTK3 已安装: $GTK_VERSION"
    else
        echo "   ❌ GTK3 未安装"
        echo "   修复: sudo apt-get install -y libgtk-3-0 pkg-config"
    fi
fi
echo ""

# 检查显示环境
echo "5️⃣  检查显示环境"
if [ -n "$DISPLAY" ]; then
    echo "   ✅ DISPLAY 已设置: $DISPLAY"
else
    echo "   ⚠️  DISPLAY 未设置（可能在 SSH 会话中）"
    echo "   如果是远程连接，需要 X11 转发或使用本地显示"
fi

if [ -n "$WAYLAND_DISPLAY" ]; then
    echo "   ℹ️  Wayland 显示: $WAYLAND_DISPLAY"
fi
echo ""

# 尝试运行并捕获错误
echo "6️⃣  尝试运行应用"
if [ -f "$BINARY_PATH" ] && [ -x "$BINARY_PATH" ]; then
    echo "   正在尝试运行（5秒超时）..."
    echo ""
    
    timeout 5 "$BINARY_PATH" 2>&1 | head -20 || {
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 124 ]; then
            echo ""
            echo "   ✅ 应用启动成功（超时退出）"
        else
            echo ""
            echo "   ❌ 应用启动失败，退出码: $EXIT_CODE"
        fi
    }
else
    echo "   ⚠️  跳过（可执行文件不存在或不可执行）"
fi
echo ""

# 检查日志
echo "7️⃣  检查系统日志"
if command -v journalctl &> /dev/null; then
    echo "   最近的应用相关错误:"
    journalctl -xe --no-pager | grep -i "jn_production\|flutter" | tail -5 || echo "   无相关日志"
else
    echo "   ⚠️  journalctl 不可用"
fi
echo ""

# 总结
echo "================================"
echo "📋 诊断总结"
echo ""
echo "如果应用无法启动，请检查："
echo "  1. 架构是否匹配（ARM64 vs x86_64）"
echo "  2. 文件是否可执行（chmod +x）"
echo "  3. 依赖库是否完整（ldd 检查）"
echo "  4. GTK3 是否安装"
echo "  5. 显示环境是否正确（DISPLAY）"
echo ""
echo "常见修复命令："
echo "  # 修复执行权限"
echo "  sudo chmod +x $BINARY_PATH"
echo ""
echo "  # 安装依赖库"
echo "  sudo apt-get install -y libgtk-3-0 libblkid1 liblzma5 pkg-config"
echo ""
echo "  # 如果缺少 pkg-config"
echo "  sudo bash scripts/install-pkg-config.sh"
echo ""
echo "  # ARM64 专用修复"
echo "  sudo bash scripts/fix-arm64.sh"
echo ""
echo "如需帮助，请将此诊断结果发送给开发者"
echo ""
