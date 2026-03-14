#!/bin/bash
# 抑制 GLib/GTK 警告的快速修复脚本

echo "🔧 抑制 GLib/GTK 警告"
echo "================================"
echo ""

APP_NAME="jn-production-line"
INSTALL_DIR="/opt/$APP_NAME"
BINARY_NAME="jn_production_line"

# 检查是否为 root
if [ "$(id -u)" -ne 0 ]; then 
    echo "❌ 请使用 sudo 运行此脚本"
    echo "   示例: sudo ./suppress-glib-warnings.sh"
    exit 1
fi

# 检查应用是否已安装
if [ ! -f "$INSTALL_DIR/$BINARY_NAME" ]; then
    echo "❌ 应用未安装: $INSTALL_DIR/$BINARY_NAME"
    exit 1
fi

echo "✅ 找到应用: $INSTALL_DIR/$BINARY_NAME"
echo ""

# 更新启动脚本
echo "📝 更新启动脚本..."
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

echo "   ✅ 启动脚本已更新"
echo ""

# 更新桌面文件
echo "🖥️  更新桌面快捷方式..."
if [ -f "/usr/share/applications/$APP_NAME.desktop" ]; then
    sed -i "s|Exec=.*|Exec=/usr/local/bin/$APP_NAME|g" /usr/share/applications/$APP_NAME.desktop
    echo "   ✅ 桌面快捷方式已更新"
else
    echo "   ⚠️  桌面快捷方式不存在，跳过"
fi
echo ""

# 创建环境配置文件
echo "⚙️  创建环境配置..."
cat > "$INSTALL_DIR/env.sh" <<'EOF'
#!/bin/bash
# 环境变量配置

# 抑制 GLib/GTK 警告
export G_MESSAGES_DEBUG=""
export G_ENABLE_DIAGNOSTIC=0
export G_DEBUG=""

# 抑制 GTK 主题警告
export GTK_THEME=""

# 禁用 GTK 调试
export GTK_DEBUG=""
EOF

chmod +x "$INSTALL_DIR/env.sh"
echo "   ✅ 环境配置已创建: $INSTALL_DIR/env.sh"
echo ""

echo "================================"
echo "✅ 修复完成！"
echo ""
echo "现在运行应用应该不会再看到 GLib 警告："
echo "  $ sudo jn-production-line"
echo ""
echo "如果仍然看到警告，可以手动设置环境变量："
echo "  $ export G_MESSAGES_DEBUG=\"\""
echo "  $ sudo -E jn-production-line"
echo ""
echo "或者直接使用环境配置："
echo "  $ source $INSTALL_DIR/env.sh"
echo "  $ sudo -E jn-production-line"
echo ""
