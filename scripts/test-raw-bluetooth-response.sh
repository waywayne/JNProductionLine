#!/bin/bash

# 测试原始蓝牙响应
# 用于验证设备是否真的会响应

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查参数
if [ -z "$1" ]; then
    echo -e "${RED}❌ 错误: 请提供设备 MAC 地址${NC}"
    echo "用法: $0 <MAC地址> [通道]"
    echo ""
    echo "示例:"
    echo "  $0 48:08:EB:60:00:6A"
    echo "  $0 48:08:EB:60:00:6A 5"
    exit 1
fi

MAC="$1"
CHANNEL="${2:-5}"  # 默认通道 5

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🧪 测试原始蓝牙响应${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "设备地址: ${GREEN}$MAC${NC}"
echo -e "RFCOMM 通道: ${GREEN}$CHANNEL${NC}"
echo ""

# 清理旧连接
echo -e "${YELLOW}🧹 清理旧连接...${NC}"
sudo pkill -9 rfcomm 2>/dev/null || true
sudo rfcomm release 0 2>/dev/null || true
sleep 1

# 建立 RFCOMM 连接
echo -e "${BLUE}🔗 建立 RFCOMM 连接...${NC}"
sudo rfcomm bind 0 "$MAC" "$CHANNEL"

if [ ! -e "/dev/rfcomm0" ]; then
    echo -e "${RED}❌ RFCOMM 设备文件不存在${NC}"
    exit 1
fi

echo -e "${GREEN}✅ RFCOMM 连接已建立: /dev/rfcomm0${NC}"
echo ""

# 构建测试数据包（唤醒命令，CMD=0x00）
# GTP 格式（与测试脚本一致）
PREAMBLE="D0 D2 C5 C2"
LENGTH="10 00"  # 16 bytes
MODULE_ID="03 04"
MESSAGE_ID="FE 23 23 06"
VERSION="01"
ENCRYPT="FF"
SEQUENCE="00 00"
PAYLOAD="00"  # CMD=0x00 (唤醒)
RESERVED="00 00 00 00"
CRC="40 40"  # 简化的 CRC

PACKET="$PREAMBLE $LENGTH $MODULE_ID $MESSAGE_ID $VERSION $ENCRYPT $SEQUENCE $PAYLOAD $RESERVED $CRC"

echo -e "${BLUE}📤 发送测试数据包${NC}"
echo -e "格式: ${YELLOW}测试脚本格式（单层 GTP）${NC}"
echo -e "数据: ${YELLOW}$PACKET${NC}"
echo ""

# 发送数据
echo "$PACKET" | xxd -r -p > /dev/rfcomm0

echo -e "${GREEN}✅ 数据已发送${NC}"
echo ""

# 等待响应（原始数据）
echo -e "${BLUE}⏳ 等待响应 (5秒)...${NC}"
echo -e "${YELLOW}监听原始数据流...${NC}"
echo ""

# 使用 timeout 和 xxd 读取原始数据
timeout 5 cat /dev/rfcomm0 2>/dev/null | xxd -g 1 -c 16 | head -n 10 &
CAT_PID=$!

sleep 5

# 检查是否收到数据
if kill -0 $CAT_PID 2>/dev/null; then
    echo -e "${YELLOW}⚠️ 未收到响应或超时${NC}"
    kill $CAT_PID 2>/dev/null || true
else
    echo -e "${GREEN}✅ 收到响应数据（见上方）${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 清理
echo -e "${YELLOW}🧹 清理连接...${NC}"
sudo rfcomm release 0 2>/dev/null || true

echo -e "${GREEN}✅ 测试完成${NC}"
