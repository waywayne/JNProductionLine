#!/bin/bash

# RFCOMM Bind 模式测试脚本
# 测试是否可以使用 rfcomm bind 而不是 rfcomm connect

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查参数
if [ $# -lt 2 ]; then
    echo -e "${RED}用法: $0 <蓝牙MAC地址> <通道号>${NC}"
    echo "示例: $0 48:08:EB:60:00:6A 5"
    exit 1
fi

MAC_ADDRESS=$1
CHANNEL=$2

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔧 RFCOMM Bind 模式测试${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "设备地址: ${GREEN}$MAC_ADDRESS${NC}"
echo -e "RFCOMM 通道: ${GREEN}$CHANNEL${NC}"
echo ""

# 步骤 1: 清理旧连接
echo -e "${YELLOW}[1/5] 清理旧连接...${NC}"
sudo pkill -f "rfcomm" 2>/dev/null || true
sudo rfcomm release 0 2>/dev/null || true
sleep 1
echo -e "${GREEN}✅ 清理完成${NC}"
echo ""

# 步骤 2: 确保蓝牙已连接
echo -e "${YELLOW}[2/5] 检查蓝牙连接状态...${NC}"
BT_INFO=$(echo "info $MAC_ADDRESS" | bluetoothctl)
if echo "$BT_INFO" | grep -q "Connected: yes"; then
    echo -e "${GREEN}✅ 蓝牙设备已连接${NC}"
else
    echo -e "${YELLOW}⚠️  设备未连接，尝试连接...${NC}"
    echo "connect $MAC_ADDRESS" | bluetoothctl
    sleep 3
    
    BT_INFO=$(echo "info $MAC_ADDRESS" | bluetoothctl)
    if echo "$BT_INFO" | grep -q "Connected: yes"; then
        echo -e "${GREEN}✅ 蓝牙连接成功${NC}"
    else
        echo -e "${RED}❌ 蓝牙连接失败${NC}"
        echo "$BT_INFO"
        exit 1
    fi
fi
echo ""

# 步骤 3: 使用 rfcomm bind
echo -e "${YELLOW}[3/5] 执行 rfcomm bind...${NC}"
echo -e "${BLUE}命令: sudo rfcomm bind 0 $MAC_ADDRESS $CHANNEL${NC}"

if sudo rfcomm bind 0 "$MAC_ADDRESS" "$CHANNEL"; then
    echo -e "${GREEN}✅ RFCOMM bind 成功${NC}"
else
    echo -e "${RED}❌ RFCOMM bind 失败${NC}"
    exit 1
fi
echo ""

# 步骤 4: 等待并检查设备文件
echo -e "${YELLOW}[4/5] 检查设备文件...${NC}"
sleep 1

if [ -e /dev/rfcomm0 ]; then
    echo -e "${GREEN}✅ 设备文件已创建: /dev/rfcomm0${NC}"
    ls -l /dev/rfcomm0
else
    echo -e "${RED}❌ 设备文件未创建${NC}"
    sudo rfcomm release 0
    exit 1
fi
echo ""

# 步骤 5: 测试读写权限
echo -e "${YELLOW}[5/5] 测试设备读写...${NC}"

if [ -w /dev/rfcomm0 ]; then
    echo -e "${GREEN}✅ 设备可写${NC}"
else
    echo -e "${RED}❌ 设备不可写${NC}"
fi

if [ -r /dev/rfcomm0 ]; then
    echo -e "${GREEN}✅ 设备可读${NC}"
else
    echo -e "${RED}❌ 设备不可读${NC}"
fi
echo ""

# 总结
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ RFCOMM Bind 模式测试成功！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}说明:${NC}"
echo -e "  • ${GREEN}rfcomm bind${NC} 模式不需要保持前台进程"
echo -e "  • 设备文件 ${GREEN}/dev/rfcomm0${NC} 可以直接读写"
echo -e "  • 这种方式比 ${YELLOW}rfcomm connect${NC} 更稳定"
echo ""
echo -e "${YELLOW}清理命令:${NC}"
echo -e "  sudo rfcomm release 0"
echo ""

# 可选：测试简单通讯
read -p "是否测试发送数据？(y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}发送测试数据...${NC}"
    echo -e "\x01\x02\x03" | sudo tee /dev/rfcomm0 > /dev/null
    echo -e "${GREEN}✅ 数据已发送${NC}"
    
    echo -e "${BLUE}尝试读取响应（5秒超时）...${NC}"
    timeout 5 sudo cat /dev/rfcomm0 | xxd || echo -e "${YELLOW}⚠️  无响应或超时${NC}"
fi

echo ""
echo -e "${YELLOW}提示: 使用完毕后请运行: sudo rfcomm release 0${NC}"
