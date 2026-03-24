#!/bin/bash

# BYD MES 系统快速测试脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🧪 BYD MES 系统快速测试${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 检查 Python 脚本
SCRIPT_PATH="$(dirname "$0")/byd_mes_client.py"

if [ ! -f "$SCRIPT_PATH" ]; then
    echo -e "${RED}❌ 错误: 找不到 byd_mes_client.py${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 找到 MES 客户端脚本${NC}"
echo ""

# 检查 Python 依赖
echo -e "${BLUE}🔍 检查 Python 依赖...${NC}"

if ! python3 -c "import requests" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  requests 模块未安装${NC}"
    echo -e "${BLUE}正在安装...${NC}"
    pip3 install requests
fi

if ! python3 -c "import configparser" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  configparser 模块未安装${NC}"
    echo -e "${BLUE}正在安装...${NC}"
    pip3 install configparser
fi

echo -e "${GREEN}✅ Python 依赖检查完成${NC}"
echo ""

# 测试参数
TEST_SN="${1:-TEST_SN_123456}"
MES_IP="${2:-192.168.1.100}"
CLIENT_ID="${3:-DEFAULT_CLIENT}"
STATION="${4:-STATION1}"

echo -e "${BLUE}测试参数:${NC}"
echo -e "  SN: ${GREEN}$TEST_SN${NC}"
echo -e "  MES IP: ${GREEN}$MES_IP${NC}"
echo -e "  Client ID: ${GREEN}$CLIENT_ID${NC}"
echo -e "  工站: ${GREEN}$STATION${NC}"
echo ""

# 测试 1: Start
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📤 测试 1: MES Start${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if python3 "$SCRIPT_PATH" start "$TEST_SN" "$STATION" "$MES_IP" "$CLIENT_ID"; then
    echo -e "${GREEN}✅ Start 测试成功${NC}"
else
    echo -e "${RED}❌ Start 测试失败${NC}"
    exit 1
fi

echo ""

# 测试 2: Complete
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📤 测试 2: MES Complete (良品)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if python3 "$SCRIPT_PATH" complete "$TEST_SN" "$STATION" "$MES_IP" "$CLIENT_ID"; then
    echo -e "${GREEN}✅ Complete 测试成功${NC}"
else
    echo -e "${RED}❌ Complete 测试失败${NC}"
    exit 1
fi

echo ""

# 测试 3: NcComplete
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📤 测试 3: MES NcComplete (不良品)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if python3 "$SCRIPT_PATH" nccomplete "$TEST_SN" "$STATION" "$MES_IP" "$CLIENT_ID" "NC001" "测试不良" "测试项" "失败值"; then
    echo -e "${GREEN}✅ NcComplete 测试成功${NC}"
else
    echo -e "${RED}❌ NcComplete 测试失败${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ 所有测试完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}💡 提示:${NC}"
echo -e "  - 查看日志文件: $(date +%Y-%m-%d)_mes.log"
echo -e "  - 在应用中打开: 菜单栏 -> BYD MES 测试"
echo ""
