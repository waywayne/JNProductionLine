#!/bin/bash
# 测试蓝牙扫描功能

echo "🔍 测试蓝牙扫描功能"
echo "================================"
echo ""

# 检查是否为 root
if [ "$(id -u)" -ne 0 ]; then 
    echo "⚠️  建议使用 sudo 运行此脚本以获得完整权限"
    echo "   示例: sudo ./test-bluetooth-scan.sh"
    echo ""
fi

# 检查蓝牙服务
echo "1️⃣  检查蓝牙服务..."
if systemctl is-active --quiet bluetooth; then
    echo "   ✅ 蓝牙服务正在运行"
else
    echo "   ❌ 蓝牙服务未运行"
    echo "   启动服务: sudo systemctl start bluetooth"
    exit 1
fi
echo ""

# 检查蓝牙适配器
echo "2️⃣  检查蓝牙适配器..."
if hciconfig hci0 2>/dev/null | grep -q "UP RUNNING"; then
    echo "   ✅ 蓝牙适配器已启用"
else
    echo "   ⚠️  蓝牙适配器未启用，尝试启用..."
    hciconfig hci0 up 2>/dev/null || true
    if hciconfig hci0 2>/dev/null | grep -q "UP RUNNING"; then
        echo "   ✅ 蓝牙适配器已启用"
    else
        echo "   ❌ 无法启用蓝牙适配器"
        exit 1
    fi
fi
echo ""

# 测试 hcitool 扫描
echo "3️⃣  测试 hcitool 扫描（主要方法）..."
echo "   正在扫描（约 10 秒）..."
HCITOOL_RESULT=$(hcitool scan --flush 2>/dev/null || hcitool scan 2>/dev/null)
if [ -n "$HCITOOL_RESULT" ]; then
    echo "   ✅ hcitool 扫描成功"
    echo ""
    echo "   发现的设备："
    echo "$HCITOOL_RESULT" | grep -v "Scanning" | while read line; do
        if [ -n "$line" ]; then
            echo "   📱 $line"
        fi
    done
else
    echo "   ⚠️  hcitool 未找到设备"
fi
echo ""

# 测试 bluetoothctl 扫描
echo "4️⃣  测试 bluetoothctl 扫描（备用方法）..."
echo "   正在扫描（约 3 秒）..."
bluetoothctl << EOF > /dev/null 2>&1
scan on
EOF
sleep 3
BTCTL_RESULT=$(bluetoothctl << EOF 2>/dev/null
scan off
devices
EOF
)
if echo "$BTCTL_RESULT" | grep -q "Device"; then
    echo "   ✅ bluetoothctl 扫描成功"
    echo ""
    echo "   发现的设备："
    echo "$BTCTL_RESULT" | grep "Device" | while read line; do
        echo "   📱 $line"
    done
else
    echo "   ⚠️  bluetoothctl 未找到设备"
fi
echo ""

# 总结
echo "================================"
echo "✅ 扫描测试完成"
echo ""
echo "💡 提示："
echo "   - 如果两种方法都未找到设备，请确保："
echo "     1. 目标蓝牙设备已开启并可被发现"
echo "     2. 目标设备在扫描范围内（通常 10 米内）"
echo "     3. 蓝牙适配器工作正常"
echo ""
echo "   - hcitool 是主要扫描方法，更可靠"
echo "   - bluetoothctl 是备用方法，某些情况下更详细"
echo ""
