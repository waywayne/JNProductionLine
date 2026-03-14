#!/bin/bash
# 测试蓝牙权限配置脚本

echo "🔍 检查蓝牙权限配置"
echo "================================"
echo ""

# 检查用户组
echo "1️⃣  检查用户组..."
if groups | grep -q bluetooth; then
    echo "   ✅ 用户在 bluetooth 组中"
else
    echo "   ❌ 用户不在 bluetooth 组中"
    echo "   请运行: sudo usermod -a -G bluetooth $USER"
    echo "   然后重新登录"
    exit 1
fi
echo ""

# 检查 PolicyKit 规则
echo "2️⃣  检查 PolicyKit 规则..."
if [ -f /etc/polkit-1/rules.d/50-bluetooth.rules ]; then
    echo "   ✅ PolicyKit 规则已配置"
else
    echo "   ⚠️  PolicyKit 规则未找到"
    echo "   文件: /etc/polkit-1/rules.d/50-bluetooth.rules"
fi
echo ""

# 检查 D-Bus 规则
echo "3️⃣  检查 D-Bus 规则..."
if [ -f /etc/dbus-1/system.d/bluetooth-group.conf ]; then
    echo "   ✅ D-Bus 规则已配置"
else
    echo "   ⚠️  D-Bus 规则未找到"
    echo "   文件: /etc/dbus-1/system.d/bluetooth-group.conf"
fi
echo ""

# 检查 udev 规则
echo "4️⃣  检查 udev 规则..."
if [ -f /etc/udev/rules.d/99-jn-production.rules ]; then
    echo "   ✅ udev 规则已配置"
else
    echo "   ⚠️  udev 规则未找到"
    echo "   文件: /etc/udev/rules.d/99-jn-production.rules"
fi
echo ""

# 检查蓝牙服务
echo "5️⃣  检查蓝牙服务..."
if systemctl is-active --quiet bluetooth; then
    echo "   ✅ 蓝牙服务正在运行"
else
    echo "   ❌ 蓝牙服务未运行"
    echo "   请运行: sudo systemctl start bluetooth"
    exit 1
fi
echo ""

# 测试 bluetoothctl 命令
echo "6️⃣  测试 bluetoothctl 命令（无需 sudo）..."
if timeout 2 bluetoothctl scan on 2>/dev/null; then
    bluetoothctl scan off 2>/dev/null
    echo "   ✅ bluetoothctl 可以无需 sudo 运行"
else
    echo "   ❌ bluetoothctl 需要 sudo"
    echo "   可能需要："
    echo "   - 重新登录系统"
    echo "   - 或运行: newgrp bluetooth"
fi
echo ""

# 检查 rfcomm 模块
echo "7️⃣  检查 rfcomm 模块..."
if lsmod | grep -q rfcomm; then
    echo "   ✅ rfcomm 模块已加载"
else
    echo "   ⚠️  rfcomm 模块未加载"
    echo "   运行: sudo modprobe rfcomm"
fi
echo ""

echo "================================"
echo "✅ 权限检查完成"
echo ""
echo "如果有任何 ❌ 或 ⚠️  标记，请："
echo "1. 运行安装脚本: sudo ./scripts/install-linux.sh"
echo "2. 重新登录系统或运行: newgrp bluetooth"
echo "3. 再次运行此测试脚本"
echo ""
