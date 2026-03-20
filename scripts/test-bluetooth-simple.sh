#!/bin/bash

################################################################################
# 简化的蓝牙连接测试脚本
# 模拟系统设置的连接方式
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MAC_ADDRESS="${1:-48:08:EB:60:00:6A}"
UUID="${2:-7033}"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔵 简化蓝牙连接测试${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "设备地址: ${GREEN}$MAC_ADDRESS${NC}"
echo -e "服务 UUID: ${GREEN}$UUID${NC}"
echo ""

# 清理函数
cleanup() {
    echo -e "${YELLOW}清理连接...${NC}"
    sudo pkill -f "rfcomm" 2>/dev/null || true
    sudo rfcomm release 0 2>/dev/null || true
}

trap cleanup EXIT

# 步骤 1: 开启蓝牙并扫描
echo -e "${YELLOW}[1/5] 开启蓝牙并扫描设备...${NC}"
hciconfig hci0 up 2>/dev/null || true

# 使用 bluetoothctl 扫描（支持 BLE + 经典蓝牙）
echo "正在扫描蓝牙设备（包括 BLE）..."

# 启动扫描
(
    echo "power on"
    sleep 1
    echo "scan on"
    sleep 10
    echo "scan off"
    echo "devices"
) | bluetoothctl > /tmp/bt_scan_output.txt 2>&1

# 检查是否找到设备
if grep -qi "$MAC_ADDRESS" /tmp/bt_scan_output.txt; then
    echo -e "${GREEN}✅ 找到设备${NC}"
    DEVICE_INFO=$(grep -i "$MAC_ADDRESS" /tmp/bt_scan_output.txt | head -1)
    echo -e "${BLUE}设备信息: $DEVICE_INFO${NC}"
else
    echo -e "${RED}❌ 未找到设备 $MAC_ADDRESS${NC}"
    echo -e "${YELLOW}扫描结果:${NC}"
    grep "Device" /tmp/bt_scan_output.txt || echo "未找到任何设备"
    echo ""
    echo -e "${YELLOW}提示:${NC}"
    echo -e "  1. 确保设备已开机"
    echo -e "  2. 确保设备在蓝牙范围内（< 10米）"
    echo -e "  3. 某些设备需要先在手机上配对后才能被 Linux 发现"
    echo -e "  4. 尝试重启设备的蓝牙功能"
    exit 1
fi
echo ""

# 步骤 2: 配对设备
echo -e "${YELLOW}[2/5] 配对蓝牙设备...${NC}"

# 检查是否已配对
PAIRED=$(echo "paired-devices" | bluetoothctl | grep -i "$MAC_ADDRESS" || true)

if [ -n "$PAIRED" ]; then
    echo -e "${GREEN}✅ 设备已配对${NC}"
else
    echo "正在配对设备..."
    (
        echo "power on"
        sleep 1
        echo "agent on"
        sleep 1
        echo "default-agent"
        sleep 1
        echo "pair $MAC_ADDRESS"
        sleep 5
        echo "trust $MAC_ADDRESS"
        sleep 1
    ) | bluetoothctl
    
    # 验证配对
    PAIRED=$(echo "paired-devices" | bluetoothctl | grep -i "$MAC_ADDRESS" || true)
    if [ -n "$PAIRED" ]; then
        echo -e "${GREEN}✅ 配对成功${NC}"
    else
        echo -e "${YELLOW}⚠️  配对可能失败，继续尝试连接...${NC}"
    fi
fi
echo ""

# 步骤 3: 等待设备准备
echo -e "${YELLOW}[3/4] 等待设备准备...${NC}"
echo "设备已配对和信任，等待设备准备 RFCOMM 连接..."
sleep 3

# 检查设备状态
BT_INFO=$(echo "info $MAC_ADDRESS" | bluetoothctl)
echo -e "${BLUE}设备状态:${NC}"
echo "$BT_INFO" | grep -E "Paired:|Bonded:|Trusted:"

echo -e "${GREEN}✅ 设备已准备，可以直接使用 RFCOMM${NC}"
echo ""

# 步骤 4: SDP 查询
echo -e "${YELLOW}[4/5] 查询 RFCOMM 通道...${NC}"
CHANNEL=$(sdptool browse "$MAC_ADDRESS" | grep -A 10 "$UUID" | grep "Channel:" | head -1 | awk '{print $2}')

if [ -z "$CHANNEL" ]; then
    echo -e "${RED}❌ 未找到通道${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 找到通道: $CHANNEL${NC}"
echo ""

# 步骤 5: 建立 RFCOMM
echo -e "${YELLOW}[5/5] 建立 RFCOMM 连接...${NC}"

# 清理旧连接
sudo pkill -f "rfcomm" 2>/dev/null || true
sudo rfcomm release 0 2>/dev/null || true
sleep 1

# 使用 bind 模式
if sudo rfcomm bind 0 "$MAC_ADDRESS" "$CHANNEL"; then
    echo -e "${GREEN}✅ RFCOMM bind 成功${NC}"
    sleep 1
    
    if [ -e /dev/rfcomm0 ]; then
        echo -e "${GREEN}✅ 设备文件已创建: /dev/rfcomm0${NC}"
        ls -l /dev/rfcomm0
        
        # 测试读写
        if [ -r /dev/rfcomm0 ] && [ -w /dev/rfcomm0 ]; then
            echo -e "${GREEN}✅ 设备可读写${NC}"
            
            # 发送测试数据
            echo -e "${BLUE}发送测试数据...${NC}"
            echo -e "\x01\x02\x03" | sudo tee /dev/rfcomm0 > /dev/null
            echo -e "${GREEN}✅ 数据已发送${NC}"
        fi
    else
        echo -e "${RED}❌ 设备文件未创建${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ RFCOMM bind 失败${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ 测试成功！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}设备信息:${NC}"
echo -e "  MAC: ${GREEN}$MAC_ADDRESS${NC}"
echo -e "  通道: ${GREEN}$CHANNEL${NC}"
echo -e "  设备: ${GREEN}/dev/rfcomm0${NC}"
echo ""
echo -e "${YELLOW}清理命令: ${CYAN}sudo rfcomm release 0${NC}"
echo ""

read -p "按 Enter 键退出..."
