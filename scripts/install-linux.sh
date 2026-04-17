#!/bin/bash
# JN Production Line - Linux 安装脚本
# 用于在 Ubuntu/Debian 系统上安装从 CI 构建的应用

set -e

APP_NAME="jn-production-line"
INSTALL_DIR="/opt/$APP_NAME"
BINARY_NAME="jn_production_line"

# 检测系统架构
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)
        ARCHIVE_NAME="jn-production-line-linux-x64.tar.gz"
        ARCH_NAME="x64"
        ;;
    aarch64|arm64)
        ARCHIVE_NAME="jn-production-line-linux-arm64.tar.gz"
        ARCH_NAME="ARM64"
        ;;
    *)
        echo "❌ 不支持的架构: $ARCH"
        echo "   仅支持 x86_64 和 ARM64"
        exit 1
        ;;
esac

echo "📦 JN Production Line 安装程序"
echo "================================"
echo "🖥️  检测到架构: $ARCH_NAME"
echo ""

# 检查是否为 root
if [ "$(id -u)" -ne 0 ]; then 
    echo "❌ 请使用 sudo 运行此脚本"
    echo "   示例: sudo ./install-linux.sh"
    exit 1
fi

# 检查文件是否存在
if [ ! -f "$ARCHIVE_NAME" ]; then
    echo "❌ 找不到 $ARCHIVE_NAME"
    echo ""
    echo "请按以下步骤操作："
    echo "1. 访问 https://github.com/waywayne/JNProductionLine/actions"
    echo "2. 选择最新的成功构建"
    echo "3. 下载 'linux-build' artifact"
    echo "4. 解压 linux-build.zip"
    echo "5. 将此脚本放在解压后的目录中"
    echo "6. 重新运行: sudo ./install-linux.sh"
    exit 1
fi

# 安装系统依赖
echo "📥 安装系统依赖..."
apt-get update -qq
apt-get install -y \
    libgtk-3-0 \
    libblkid1 \
    liblzma5 \
    bluez \
    bluez-tools \
    curl \
    iperf3 \
    socat \
    pkg-config \
    fonts-noto-cjk \
    fonts-noto-cjk-extra \
    fonts-wqy-microhei \
    fonts-wqy-zenhei \
    python3 \
    python3-pip \
    python3-bluez

echo "   ✅ 已安装系统依赖和中文字体"

# 安装 Python 蓝牙库（RFCOMM Socket 支持）
echo "🐍 安装 Python 蓝牙库..."
if ! python3 -c "import bluetooth" 2>/dev/null; then
    echo "   正在安装 PyBluez..."
    
    # 优先使用系统包
    if apt-cache show python3-bluez >/dev/null 2>&1; then
        apt-get install -y python3-bluez
        echo "   ✅ 已通过 apt 安装 python3-bluez"
    else
        # 降级使用 pip
        pip3 install pybluez --break-system-packages 2>/dev/null || pip3 install pybluez
        echo "   ✅ 已通过 pip 安装 PyBluez"
    fi
else
    echo "   ✅ PyBluez 已安装"
fi

# 验证 Python 蓝牙库
if python3 -c "import bluetooth" 2>/dev/null; then
    PYBLUEZ_VERSION=$(python3 -c "import bluetooth; print(bluetooth.__version__)" 2>/dev/null || echo "未知版本")
    echo "   ✅ PyBluez 验证成功 (版本: $PYBLUEZ_VERSION)"
else
    echo "   ⚠️  警告: PyBluez 安装可能失败，RFCOMM Socket 功能可能不可用"
fi

# 创建安装目录
echo "📁 创建安装目录..."
mkdir -p "$INSTALL_DIR"

# 备份旧版本（如果存在）
if [ -f "$INSTALL_DIR/$BINARY_NAME" ]; then
    echo "🔄 备份旧版本..."
    mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$INSTALL_DIR"
fi

# 解压应用
echo "📦 解压应用..."
tar -xzf "$ARCHIVE_NAME" -C "$INSTALL_DIR"

# 验证解压
if [ ! -f "$INSTALL_DIR/$BINARY_NAME" ]; then
    echo "❌ 解压失败：找不到 $BINARY_NAME"
    echo "   检查压缩包内容:"
    tar -tzf "$ARCHIVE_NAME" | head -10
    exit 1
fi

# 设置权限
echo "🔐 设置权限..."
chmod +x "$INSTALL_DIR/$BINARY_NAME"

# 设置 Python 脚本权限（如果存在）
if [ -f "$INSTALL_DIR/scripts/rfcomm_socket.py" ]; then
    chmod +x "$INSTALL_DIR/scripts/rfcomm_socket.py"
    echo "   ✅ 已设置 RFCOMM Socket 脚本权限"
fi

# 验证文件
echo "🔍 验证安装..."
FILE_TYPE=$(file "$INSTALL_DIR/$BINARY_NAME")
echo "   文件类型: $FILE_TYPE"

# 检查架构匹配
case "$ARCH" in
    x86_64|amd64)
        if ! echo "$FILE_TYPE" | grep -q "x86-64\|x86_64"; then
            echo "   ⚠️  警告: 二进制文件架构可能不匹配"
        fi
        ;;
    aarch64|arm64)
        if ! echo "$FILE_TYPE" | grep -q "ARM aarch64\|ARM64"; then
            echo "   ⚠️  警告: 二进制文件架构可能不匹配"
        fi
        ;;
esac

# 检查依赖库
echo "   检查依赖库..."
MISSING_LIBS=$(ldd "$INSTALL_DIR/$BINARY_NAME" 2>&1 | grep "not found" || true)
if [ -n "$MISSING_LIBS" ]; then
    echo "   ⚠️  警告: 缺少以下依赖库:"
    echo "$MISSING_LIBS" | sed 's/^/      /'
fi

# 创建启动脚本
echo "🔗 创建启动脚本..."
cat > /usr/local/bin/$APP_NAME <<EOF
#!/bin/bash
# JN Production Line 启动脚本

# 抑制非关键的 GLib/GTK 警告
export G_MESSAGES_DEBUG=""
export G_ENABLE_DIAGNOSTIC=0
export G_DEBUG=""

# 切换到安装目录并运行
cd "$INSTALL_DIR"
exec "./$BINARY_NAME" "\$@"
EOF

chmod +x /usr/local/bin/$APP_NAME

# 创建桌面文件
echo "🖥️  创建桌面快捷方式..."
cat > /usr/share/applications/$APP_NAME.desktop <<EOF
[Desktop Entry]
Name=JN Production Line
Comment=Flutter production line test application
Exec=/usr/local/bin/$APP_NAME
Terminal=false
Type=Application
Categories=Utility;Development;
StartupNotify=true
EOF

# 更新桌面数据库
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database /usr/share/applications 2>/dev/null || true
fi

# 配置串口权限
echo "🔧 配置串口权限..."
cat > /etc/udev/rules.d/99-jn-production.rules <<EOF
# Serial ports
KERNEL=="ttyUSB[0-9]*", MODE="0666"
KERNEL=="ttyACM[0-9]*", MODE="0666"

# Bluetooth RFCOMM devices
KERNEL=="rfcomm[0-9]*", MODE="0666"
EOF

udevadm control --reload-rules 2>/dev/null || true
udevadm trigger 2>/dev/null || true

echo "   ✅ 串口和 RFCOMM 权限已配置"

# 显示安装信息
echo ""
echo "✅ 安装完成！"
echo ""
echo "安装位置: $INSTALL_DIR"
echo "可执行文件: $INSTALL_DIR/$BINARY_NAME"
echo ""
echo "使用方法："
echo "  方法 1: 命令行运行"
echo "    $ $APP_NAME"
echo ""
echo "  方法 2: 从应用菜单启动"
echo "    在应用菜单中搜索 'JN Production Line'"
echo ""
echo "  方法 3: 直接运行"
echo "    $ $INSTALL_DIR/$BINARY_NAME"
echo ""

echo "⚠️  重要提示:"
echo "   1. Linux 蓝牙功能需要使用 sudo 运行应用："
echo "      $ sudo $APP_NAME"
echo ""
echo "   2. 已安装以下依赖："
echo "      ✅ Python3 和 PyBluez (RFCOMM Socket 支持)"
echo "      ✅ BlueZ 蓝牙工具"
echo "      ✅ 中文字体支持"
echo ""
echo "   3. 如果中文显示异常："
echo "      - 重启应用"
echo "      - 或运行: sudo fc-cache -fv"
echo ""

echo "📚 更多信息请查看:"
echo "   - 构建指南: docs/LINUX_BUILD_GUIDE.md"
echo "   - 蓝牙权限: docs/BLUETOOTH_PERMISSIONS.md"
echo "   - RFCOMM Socket: docs/RFCOMM_SOCKET.md"
echo "   - 中文字体: docs/CHINESE_FONTS.md"
echo "   - GitHub: https://github.com/waywayne/JNProductionLine"
echo ""
echo "🔧 故障排查:"
echo "   如果应用无法启动，运行诊断工具:"
echo "   $ sudo bash scripts/diagnose-linux.sh"
echo ""
