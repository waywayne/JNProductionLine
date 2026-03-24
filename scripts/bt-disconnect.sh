#!/bin/bash

# 断开蓝牙 RFCOMM 连接

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔌 断开蓝牙连接${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 停止 cat 进程
echo -e "${YELLOW}[1/3]${NC} 停止读取进程..."
pkill -9 cat 2>/dev/null && echo -e "${GREEN}✅ 读取进程已停止${NC}" || echo -e "${YELLOW}⚠️ 无读取进程${NC}"
echo ""

# 释放 RFCOMM
echo -e "${YELLOW}[2/3]${NC} 释放 RFCOMM..."
rfcomm release 0 2>/dev/null && echo -e "${GREEN}✅ RFCOMM 已释放${NC}" || echo -e "${YELLOW}⚠️ RFCOMM 未绑定${NC}"
echo ""

# 删除设备文件
echo -e "${YELLOW}[3/3]${NC} 清理设备文件..."
rm -f /dev/rfcomm0 2>/dev/null && echo -e "${GREEN}✅ 设备文件已删除${NC}" || echo -e "${YELLOW}⚠️ 设备文件不存在${NC}"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ 蓝牙连接已断开${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
