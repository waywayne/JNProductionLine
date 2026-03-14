#!/bin/bash
# 清理之前错误的蓝牙配置

echo "🧹 清理蓝牙配置文件..."
echo "================================"
echo ""

# 检查是否为 root
if [ "$(id -u)" -ne 0 ]; then 
    echo "❌ 请使用 sudo 运行此脚本"
    echo "   示例: sudo ./cleanup-bluetooth-config.sh"
    exit 1
fi

# 移除 PolicyKit 规则
if [ -f /etc/polkit-1/rules.d/50-bluetooth.rules ]; then
    echo "🗑️  移除 PolicyKit 规则..."
    rm -f /etc/polkit-1/rules.d/50-bluetooth.rules
    echo "   ✅ 已移除 /etc/polkit-1/rules.d/50-bluetooth.rules"
else
    echo "ℹ️  PolicyKit 规则不存在，跳过"
fi
echo ""

# 移除 D-Bus 规则
if [ -f /etc/dbus-1/system.d/bluetooth-group.conf ]; then
    echo "🗑️  移除 D-Bus 规则..."
    rm -f /etc/dbus-1/system.d/bluetooth-group.conf
    echo "   ✅ 已移除 /etc/dbus-1/system.d/bluetooth-group.conf"
else
    echo "ℹ️  D-Bus 规则不存在，跳过"
fi
echo ""

# 重新加载 udev 规则（保留串口配置）
echo "🔄 重新加载 udev 规则..."
udevadm control --reload-rules 2>/dev/null || true
udevadm trigger 2>/dev/null || true
echo "   ✅ udev 规则已重新加载"
echo ""

echo "================================"
echo "✅ 清理完成！"
echo ""
echo "⚠️  注意："
echo "   - 已移除可能导致系统重启的配置"
echo "   - 串口和 RFCOMM 权限配置已保留"
echo "   - 使用蓝牙功能请用 sudo 运行应用"
echo ""
echo "运行应用："
echo "   sudo jn-production-line"
echo ""
