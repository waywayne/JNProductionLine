#!/bin/bash

# 完整的蓝牙产测流程示例
# 演示如何使用脚本进行完整的产测

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔧 完整蓝牙产测流程示例${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 检查参数
if [ -z "$1" ]; then
    echo -e "${RED}❌ 错误: 请提供 SN 码${NC}"
    echo "用法: sudo $0 <SN码>"
    echo "示例: sudo $0 JN001F001L001240324000001"
    exit 1
fi

SN_CODE="$1"

# 步骤 1: 连接设备
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}步骤 1: 连接蓝牙设备${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
"$SCRIPT_DIR/bt-connect-by-sn.sh" "$SN_CODE"
echo ""
sleep 2

# 步骤 2: 唤醒设备
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}步骤 2: 唤醒设备${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
"$SCRIPT_DIR/bt-test-wake-device.sh"
echo ""
sleep 1

# 步骤 3: 产测开始
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}步骤 3: 产测开始${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
"$SCRIPT_DIR/bt-test-production-start.sh"
echo ""
sleep 1

# 步骤 4: 获取电压
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}步骤 4: 获取电压${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
"$SCRIPT_DIR/bt-test-get-voltage.sh"
echo ""
sleep 1

# 步骤 5: LED 测试
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}步骤 5: LED 测试${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
for i in {1..6}; do
    echo -e "${BLUE}测试 LED $i...${NC}"
    "$SCRIPT_DIR/bt-test-led.sh" $i
    sleep 0.5
done
echo ""

# 步骤 6: Touch 测试
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}步骤 6: Touch 测试${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}测试左侧 Touch...${NC}"
"$SCRIPT_DIR/bt-test-touch.sh" 0
sleep 1
echo -e "${BLUE}测试右侧 Touch...${NC}"
"$SCRIPT_DIR/bt-test-touch.sh" 1
echo ""
sleep 1

# 步骤 7: 超声测试
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}步骤 7: 超声测试${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
"$SCRIPT_DIR/bt-test-ultrasonic.sh"
echo ""
sleep 1

# 步骤 8: 马达测试
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}步骤 8: 马达测试${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}测试左侧马达...${NC}"
"$SCRIPT_DIR/bt-test-motor.sh" 0
sleep 1
echo -e "${BLUE}测试右侧马达...${NC}"
"$SCRIPT_DIR/bt-test-motor.sh" 1
echo ""
sleep 1

# 步骤 9: 麦克风测试
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}步骤 9: 麦克风测试${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}测试左侧麦克风...${NC}"
"$SCRIPT_DIR/bt-test-mic.sh" 0
sleep 1
echo -e "${BLUE}测试右侧麦克风...${NC}"
"$SCRIPT_DIR/bt-test-mic.sh" 1
echo ""
sleep 1

# 步骤 10: 扬声器测试
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}步骤 10: 扬声器测试${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}测试左侧扬声器...${NC}"
"$SCRIPT_DIR/bt-test-speaker.sh" 0
sleep 1
echo -e "${BLUE}测试右侧扬声器...${NC}"
"$SCRIPT_DIR/bt-test-speaker.sh" 1
echo ""
sleep 1

# 完成
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ 完整产测流程执行完成！${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}查看接收日志: tail -f /tmp/rfcomm0.log${NC}"
echo -e "${BLUE}断开连接: sudo $SCRIPT_DIR/bt-disconnect.sh${NC}"
echo ""
