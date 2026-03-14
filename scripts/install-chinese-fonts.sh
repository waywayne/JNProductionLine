#!/bin/bash
# 安装中文字体支持

echo "🔤 安装中文字体"
echo "================================"
echo ""

# 检查是否为 root
if [ "$(id -u)" -ne 0 ]; then 
    echo "❌ 请使用 sudo 运行此脚本"
    echo "   示例: sudo ./install-chinese-fonts.sh"
    exit 1
fi

echo "📥 更新软件包列表..."
apt-get update -qq

echo "📥 安装中文字体..."
apt-get install -y \
    fonts-noto-cjk \
    fonts-noto-cjk-extra \
    fonts-wqy-microhei \
    fonts-wqy-zenhei

echo ""
echo "🔄 更新字体缓存..."
fc-cache -fv

echo ""
echo "================================"
echo "✅ 中文字体安装完成！"
echo ""
echo "已安装的字体："
echo "  - Noto Sans CJK (思源黑体)"
echo "  - Noto Serif CJK (思源宋体)"
echo "  - WenQuanYi Micro Hei (文泉驿微米黑)"
echo "  - WenQuanYi Zen Hei (文泉驿正黑)"
echo ""
echo "⚠️  重要提示："
echo "   请重启应用以使字体生效"
echo "   如果应用正在运行，请关闭后重新启动"
echo ""
