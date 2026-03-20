#!/bin/bash

# 蓝牙连接测试脚本
# 用于诊断 Linux 蓝牙 SPP 连接问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查参数
if [ $# -lt 1 ]; then
    echo -e "${RED}用法: $0 <蓝牙MAC地址> [UUID]${NC}"
    echo "示例: $0 48:08:EB:60:00:6A 7033"
    exit 1
fi

MAC_ADDRESS=$1
UUID=${2:-"00001101-0000-1000-8000-00805F9B34FB"}  # 默认 SPP UUID

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔍 蓝牙连接测试${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "设备地址: ${GREEN}$MAC_ADDRESS${NC}"
echo -e "服务 UUID: ${GREEN}$UUID${NC}"
echo ""

# 步骤 1: 检查蓝牙适配器
echo -e "${YELLOW}[1/7] 检查蓝牙适配器...${NC}"
if ! command -v bluetoothctl &> /dev/null; then
    echo -e "${RED}❌ bluetoothctl 未安装${NC}"
    exit 1
fi

if ! command -v hciconfig &> /dev/null; then
    echo -e "${RED}❌ hciconfig 未安装${NC}"
    exit 1
fi

# 开启蓝牙
echo "power on" | bluetoothctl > /dev/null 2>&1
hciconfig hci0 up 2>/dev/null || true
echo -e "${GREEN}✅ 蓝牙适配器已开启${NC}"
echo ""

# 步骤 2: 扫描设备
echo -e "${YELLOW}[2/7] 扫描蓝牙设备...${NC}"
timeout 5 bash -c "echo 'scan on' | bluetoothctl" > /dev/null 2>&1 &
sleep 3
echo "scan off" | bluetoothctl > /dev/null 2>&1

DEVICES=$(echo "devices" | bluetoothctl | grep -i "$MAC_ADDRESS" || true)
if [ -z "$DEVICES" ]; then
    echo -e "${RED}❌ 未找到设备 $MAC_ADDRESS${NC}"
    echo -e "${YELLOW}提示: 请确保设备已开机且在蓝牙范围内${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 找到设备: $DEVICES${NC}"
echo ""

# 步骤 3: 检查配对状态
echo -e "${YELLOW}[3/7] 检查配对状态...${NC}"
PAIRED=$(echo "paired-devices" | bluetoothctl | grep -i "$MAC_ADDRESS" || true)
if [ -z "$PAIRED" ]; then
    echo -e "${YELLOW}⚠️  设备未配对，开始配对...${NC}"
    
    # 设置代理
    echo "agent NoInputNoOutput" | bluetoothctl
    echo "default-agent" | bluetoothctl
    
    # 配对
    echo "pair $MAC_ADDRESS" | bluetoothctl
    sleep 2
    
    # 信任
    echo "trust $MAC_ADDRESS" | bluetoothctl
    sleep 1
    
    # 再次检查
    PAIRED=$(echo "paired-devices" | bluetoothctl | grep -i "$MAC_ADDRESS" || true)
    if [ -z "$PAIRED" ]; then
        echo -e "${RED}❌ 配对失败${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ 配对成功${NC}"
else
    echo -e "${GREEN}✅ 设备已配对${NC}"
fi
echo ""

# 步骤 4: 连接设备
echo -e "${YELLOW}[4/7] 连接蓝牙设备...${NC}"
echo "connect $MAC_ADDRESS" | bluetoothctl
sleep 3

# 检查连接状态
INFO=$(echo "info $MAC_ADDRESS" | bluetoothctl)
if echo "$INFO" | grep -q "Connected: yes"; then
    echo -e "${GREEN}✅ 蓝牙设备已连接${NC}"
else
    echo -e "${RED}❌ 蓝牙连接失败${NC}"
    echo -e "${YELLOW}设备信息:${NC}"
    echo "$INFO"
    exit 1
fi
echo ""

# 步骤 5: SDP 查询
echo -e "${YELLOW}[5/7] 查询 RFCOMM 通道 (SDP)...${NC}"
if ! command -v sdptool &> /dev/null; then
    echo -e "${RED}❌ sdptool 未安装${NC}"
    exit 1
fi

SDP_OUTPUT=$(sdptool browse "$MAC_ADDRESS" 2>&1 || true)
if [ -z "$SDP_OUTPUT" ]; then
    echo -e "${RED}❌ SDP 查询失败${NC}"
    exit 1
fi

echo -e "${BLUE}SDP 查询结果:${NC}"
echo "$SDP_OUTPUT"
echo ""

# 提取 RFCOMM 通道
CHANNEL=$(echo "$SDP_OUTPUT" | grep -A 10 "$UUID" | grep "Channel:" | head -1 | awk '{print $2}')
if [ -z "$CHANNEL" ]; then
    echo -e "${YELLOW}⚠️  未找到 UUID $UUID 的通道${NC}"
    echo -e "${YELLOW}尝试使用默认通道 1${NC}"
    CHANNEL=1
else
    echo -e "${GREEN}✅ 找到 RFCOMM 通道: $CHANNEL${NC}"
fi
echo ""

# 步骤 6: 建立 RFCOMM 连接
echo -e "${YELLOW}[6/7] 建立 RFCOMM 连接...${NC}"

# 清理旧连接
pkill -f "rfcomm connect" 2>/dev/null || true
rfcomm release 0 2>/dev/null || true
sleep 1

# 尝试连接
echo -e "${BLUE}执行: rfcomm connect 0 $MAC_ADDRESS $CHANNEL${NC}"
timeout 5 rfcomm connect 0 "$MAC_ADDRESS" "$CHANNEL" &
RFCOMM_PID=$!

sleep 3

# 检查设备文件
if [ -e /dev/rfcomm0 ]; then
    echo -e "${GREEN}✅ RFCOMM 设备已创建: /dev/rfcomm0${NC}"
    ls -l /dev/rfcomm0
else
    echo -e "${RED}❌ RFCOMM 设备未创建${NC}"
    kill $RFCOMM_PID 2>/dev/null || true
    exit 1
fi
echo ""

# 步骤 7: 测试读写
echo -e "${YELLOW}[7/7] 测试设备读写...${NC}"
if [ -w /dev/rfcomm0 ]; then
    echo -e "${GREEN}✅ 设备可写${NC}"
else
    echo -e "${RED}❌ 设备不可写（可能需要 sudo）${NC}"
fi

if [ -r /dev/rfcomm0 ]; then
    echo -e "${GREEN}✅ 设备可读${NC}"
else
    echo -e "${RED}❌ 设备不可读（可能需要 sudo）${NC}"
fi
echo ""

# 总结
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ 蓝牙连接测试完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "设备地址: ${GREEN}$MAC_ADDRESS${NC}"
echo -e "RFCOMM 通道: ${GREEN}$CHANNEL${NC}"
echo -e "设备路径: ${GREEN}/dev/rfcomm0${NC}"
echo -e "进程 PID: ${GREEN}$RFCOMM_PID${NC}"
echo ""
echo -e "${YELLOW}提示: 使用 Ctrl+C 断开连接${NC}"
echo -e "${YELLOW}或运行: kill $RFCOMM_PID && rfcomm release 0${NC}"
echo ""

# 保持连接
wait $RFCOMM_PID
