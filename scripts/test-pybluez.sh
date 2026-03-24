#!/bin/bash
# 测试 PyBluez 安装和 RFCOMM Socket 功能

echo "🔍 测试 PyBluez 安装"
echo "===================="
echo ""

# 检查 Python3
echo "1️⃣ 检查 Python3..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo "   ✅ $PYTHON_VERSION"
else
    echo "   ❌ Python3 未安装"
    exit 1
fi
echo ""

# 检查 PyBluez 模块
echo "2️⃣ 检查 PyBluez 模块..."
if python3 -c "import bluetooth" 2>/dev/null; then
    PYBLUEZ_VERSION=$(python3 -c "import bluetooth; print(bluetooth.__version__)" 2>/dev/null || echo "未知版本")
    echo "   ✅ PyBluez 已安装 (版本: $PYBLUEZ_VERSION)"
else
    echo "   ❌ PyBluez 未安装"
    echo ""
    echo "   安装方法："
    echo "   sudo apt-get install python3-bluez"
    echo "   或"
    echo "   pip3 install pybluez"
    exit 1
fi
echo ""

# 检查蓝牙适配器
echo "3️⃣ 检查蓝牙适配器..."
if command -v hciconfig &> /dev/null; then
    HCI_OUTPUT=$(hciconfig 2>&1)
    if echo "$HCI_OUTPUT" | grep -q "hci0"; then
        echo "   ✅ 蓝牙适配器已找到"
        hciconfig hci0 | head -3 | sed 's/^/   /'
    else
        echo "   ⚠️  未找到蓝牙适配器"
    fi
else
    echo "   ⚠️  hciconfig 命令不可用"
fi
echo ""

# 测试 RFCOMM Socket 脚本
echo "4️⃣ 检查 RFCOMM Socket 脚本..."
SCRIPT_PATH="scripts/rfcomm_socket.py"
if [ -f "$SCRIPT_PATH" ]; then
    echo "   ✅ 脚本存在: $SCRIPT_PATH"
    
    # 检查脚本权限
    if [ -x "$SCRIPT_PATH" ]; then
        echo "   ✅ 脚本可执行"
    else
        echo "   ⚠️  脚本不可执行，设置权限..."
        chmod +x "$SCRIPT_PATH"
        echo "   ✅ 权限已设置"
    fi
    
    # 测试脚本语法
    if python3 -m py_compile "$SCRIPT_PATH" 2>/dev/null; then
        echo "   ✅ 脚本语法正确"
    else
        echo "   ❌ 脚本语法错误"
    fi
else
    echo "   ❌ 脚本不存在: $SCRIPT_PATH"
fi
echo ""

# 显示 Python 蓝牙功能
echo "5️⃣ 测试 Python 蓝牙功能..."
python3 << 'EOF'
import sys
try:
    import bluetooth
    
    print("   ✅ 可以导入 bluetooth 模块")
    
    # 测试基本功能
    try:
        # 尝试获取本地蓝牙设备
        devices = bluetooth.discover_devices(duration=1, lookup_names=False)
        print(f"   ✅ 蓝牙扫描功能正常")
    except Exception as e:
        print(f"   ⚠️  蓝牙扫描测试: {e}")
    
    # 检查 RFCOMM 支持
    if hasattr(bluetooth, 'RFCOMM'):
        print(f"   ✅ RFCOMM 常量可用: {bluetooth.RFCOMM}")
    
    if hasattr(bluetooth, 'BluetoothSocket'):
        print(f"   ✅ BluetoothSocket 类可用")
    
except ImportError as e:
    print(f"   ❌ 导入失败: {e}")
    sys.exit(1)
except Exception as e:
    print(f"   ⚠️  测试异常: {e}")
EOF

echo ""
echo "✅ PyBluez 测试完成！"
echo ""
echo "💡 提示："
echo "   - 如果所有测试通过，RFCOMM Socket 功能可用"
echo "   - 使用蓝牙功能需要 sudo 权限"
echo "   - 测试连接: sudo python3 scripts/rfcomm_socket.py <MAC> <CHANNEL>"
echo ""
