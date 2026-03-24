#!/bin/bash

# 根据 SN 码连接蓝牙设备
# 用法: sudo ./bt-connect-by-sn.sh <SN码>

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# API 配置
API_URL="http://test.jiananai.com/api/v1/product-sn/fetch-sn"
TOKEN="7f0052b35618d1533f1e235b7d1f5928"
USER_AGENT="com.jnai.glasses/3.0.0(android;12;xiaomimi10@release)"

# 产品配置
PRODUCT_LINE="JN-AI-001"
FACTORY_CODE="F001"
LINE_CODE="L001"
HARDWARE_VERSION="1.0.0"

# 默认通道
DEFAULT_CHANNEL=5

# 检查参数
if [ -z "$1" ]; then
    echo -e "${RED}❌ 错误: 请提供 SN 码${NC}"
    echo "用法: sudo $0 <SN码>"
    echo "示例: sudo $0 JN001F001L001240324000001"
    exit 1
fi

SN_CODE="$1"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📡 根据 SN 码连接蓝牙设备${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "SN 码: ${GREEN}$SN_CODE${NC}"
echo ""

# 步骤 1: 查询设备信息
echo -e "${YELLOW}[1/5]${NC} 查询设备信息..."
RESPONSE=$(curl -s -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -H "Token: $TOKEN" \
    -H "User-Agent: $USER_AGENT" \
    -d "{
        \"sn\": \"$SN_CODE\",
        \"product_line\": \"$PRODUCT_LINE\",
        \"factory_code\": \"$FACTORY_CODE\",
        \"line_code\": \"$LINE_CODE\",
        \"hardware_version\": \"$HARDWARE_VERSION\"
    }")

# 解析响应
ERROR_CODE=$(echo "$RESPONSE" | jq -r '.error_code // 1')
if [ "$ERROR_CODE" != "0" ]; then
    MSG=$(echo "$RESPONSE" | jq -r '.msg // "未知错误"')
    echo -e "${RED}❌ API 错误: $MSG${NC}"
    exit 1
fi

# 提取蓝牙地址
DATA=$(echo "$RESPONSE" | jq -r '.data')
if [ "$DATA" == "null" ]; then
    echo -e "${RED}❌ 未找到设备信息${NC}"
    exit 1
fi

# 检查 data 是否为字符串（需要二次解析）
if echo "$DATA" | jq -e . >/dev/null 2>&1; then
    BT_ADDRESS=$(echo "$DATA" | jq -r '.bluetooth_address // empty')
else
    BT_ADDRESS=$(echo "$RESPONSE" | jq -r '.data.bluetooth_address // empty')
fi

if [ -z "$BT_ADDRESS" ]; then
    echo -e "${RED}❌ 未找到蓝牙地址${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 蓝牙地址: $BT_ADDRESS${NC}"
echo ""

# 步骤 2: 开启蓝牙
echo -e "${YELLOW}[2/5]${NC} 开启蓝牙适配器..."
echo "power on" | bluetoothctl >/dev/null 2>&1 || true
sleep 1
echo -e "${GREEN}✅ 蓝牙已开启${NC}"
echo ""

# 步骤 3: 配对和信任设备
echo -e "${YELLOW}[3/5]${NC} 配对和信任设备..."
(
    echo "pair $BT_ADDRESS"
    sleep 5
    echo "trust $BT_ADDRESS"
    sleep 1
) | bluetoothctl 2>&1 | grep -E "(Pairing successful|trust succeeded|AlreadyExists)" || true
sleep 2
echo -e "${GREEN}✅ 设备已配对和信任${NC}"
echo ""

# 步骤 4: 清理旧连接
echo -e "${YELLOW}[4/5]${NC} 清理旧连接..."
pkill -9 cat 2>/dev/null || true
pkill -9 rfcomm 2>/dev/null || true
sleep 0.2
rfcomm release 0 2>/dev/null || true
sleep 0.2
rm -f /dev/rfcomm0 2>/dev/null || true
sleep 0.3
echo -e "${GREEN}✅ 旧连接已清理${NC}"
echo ""

# 步骤 5: 建立 RFCOMM 连接
echo -e "${YELLOW}[5/5]${NC} 建立 RFCOMM 连接..."
echo -e "   使用通道: ${GREEN}$DEFAULT_CHANNEL${NC}"

rfcomm bind 0 "$BT_ADDRESS" $DEFAULT_CHANNEL
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ RFCOMM 绑定失败${NC}"
    exit 1
fi

sleep 0.5

# 检查设备文件
if [ ! -e "/dev/rfcomm0" ]; then
    echo -e "${RED}❌ 设备文件未创建${NC}"
    rfcomm release 0 2>/dev/null || true
    exit 1
fi

echo -e "${GREEN}✅ RFCOMM 绑定成功${NC}"
echo -e "${GREEN}✅ 设备文件: /dev/rfcomm0${NC}"
echo ""

# 启动后台读取进程（触发连接）
echo -e "${BLUE}🔄 启动后台读取进程...${NC}"
cat /dev/rfcomm0 > /tmp/rfcomm0.log 2>&1 &
CAT_PID=$!
echo -e "${GREEN}✅ 读取进程已启动 (PID: $CAT_PID)${NC}"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ 蓝牙连接成功！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "设备地址: ${GREEN}$BT_ADDRESS${NC}"
echo -e "RFCOMM 通道: ${GREEN}$DEFAULT_CHANNEL${NC}"
echo -e "设备文件: ${GREEN}/dev/rfcomm0${NC}"
echo -e "读取进程 PID: ${GREEN}$CAT_PID${NC}"
echo -e "日志文件: ${GREEN}/tmp/rfcomm0.log${NC}"
echo ""
echo -e "${YELLOW}提示: 连接已保持，可以使用其他脚本发送测试指令${NC}"
echo -e "${YELLOW}断开连接: sudo rfcomm release 0 && kill $CAT_PID${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
