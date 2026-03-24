#!/bin/bash

# 通过蓝牙发送 GTP 封装的产测指令
# 用法: sudo ./bt-send-gtp-command.sh <CMD> [OPT] [DATA...]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# GTP 协议常量
PREAMBLE="D0 D2 C5 C2"
MODULE_ID="03 04"
MESSAGE_ID="FE 23 23 06"
SEQUENCE_NUM="00 00"  # 固定序列号
RESERVED="00 00 00 00"
CRC_PLACEHOLDER="40 40"  # 简化，使用固定值

DEVICE_FILE="/dev/rfcomm0"

# 检查设备文件
if [ ! -e "$DEVICE_FILE" ]; then
    echo -e "${RED}❌ 设备文件不存在: $DEVICE_FILE${NC}"
    echo -e "${YELLOW}请先运行 bt-connect-by-sn.sh 建立连接${NC}"
    exit 1
fi

# 检查参数
if [ -z "$1" ]; then
    echo -e "${RED}❌ 错误: 请提供 CMD 字节${NC}"
    echo "用法: sudo $0 <CMD> [OPT] [DATA...]"
    echo ""
    echo "示例:"
    echo "  唤醒设备:     sudo $0 00"
    echo "  产测开始:     sudo $0 01 00"
    echo "  获取电压:     sudo $0 02 00"
    echo "  LED 测试:     sudo $0 03 00 01"
    exit 1
fi

CMD="$1"
OPT="${2:-}"
shift 2 2>/dev/null || shift 1

# 构建 Payload (CMD + OPT + DATA)
PAYLOAD="$CMD"
if [ -n "$OPT" ]; then
    PAYLOAD="$PAYLOAD $OPT"
fi

# 添加额外数据
for byte in "$@"; do
    PAYLOAD="$PAYLOAD $byte"
done

# 计算 Payload 长度
PAYLOAD_BYTES=($PAYLOAD)
PAYLOAD_LEN=${#PAYLOAD_BYTES[@]}

# 计算 GTP Length (little endian, 2 bytes)
# GTP Length = 2(ModuleID) + 4(MessageID) + 1(Version) + 1(Encrypt) + 2(SeqNum) + PayloadLen + 4(Reserved) + 2(CRC)
# = 16 + PayloadLen
GTP_LEN=$((16 + PAYLOAD_LEN))
GTP_LEN_LOW=$((GTP_LEN & 0xFF))
GTP_LEN_HIGH=$(((GTP_LEN >> 8) & 0xFF))
GTP_LEN_HEX=$(printf "%02X %02X" $GTP_LEN_LOW $GTP_LEN_HIGH)

# 固定字段
VERSION="01"
ENCRYPT="FF"

# 构建完整的 GTP 数据包
GTP_PACKET="$PREAMBLE $GTP_LEN_HEX $MODULE_ID $MESSAGE_ID $VERSION $ENCRYPT $SEQUENCE_NUM $PAYLOAD $RESERVED $CRC_PLACEHOLDER"

# 计算实际 CRC（简化版，这里使用固定值）
# 实际应用中需要计算 CRC16
CRC_BYTES=$(echo "$MODULE_ID $MESSAGE_ID $VERSION $ENCRYPT $SEQUENCE_NUM $PAYLOAD $RESERVED" | \
    xxd -r -p | cksum | awk '{print $1}')
CRC_LOW=$((CRC_BYTES & 0xFF))
CRC_HIGH=$(((CRC_BYTES >> 8) & 0xFF))
CRC_HEX=$(printf "%02X %02X" $CRC_LOW $CRC_HIGH)

# 替换 CRC
GTP_PACKET=$(echo "$GTP_PACKET" | sed "s/$CRC_PLACEHOLDER/$CRC_HEX/")

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📤 发送 GTP 指令${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "CMD:      ${GREEN}0x$CMD${NC}"
if [ -n "$OPT" ]; then
    echo -e "OPT:      ${GREEN}0x$OPT${NC}"
fi
echo -e "Payload:  ${GREEN}$PAYLOAD${NC} (${PAYLOAD_LEN} bytes)"
echo -e "GTP Len:  ${GREEN}$GTP_LEN${NC} bytes"
echo ""
echo -e "完整数据包:"
echo -e "${YELLOW}$GTP_PACKET${NC}"
echo ""

# 转换为二进制并发送
echo -e "${BLUE}🔄 发送中...${NC}"
echo "$GTP_PACKET" | xxd -r -p > "$DEVICE_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 指令已发送${NC}"
    echo ""
    
    # 等待响应
    echo -e "${BLUE}⏳ 等待响应 (3秒)...${NC}"
    timeout 3 cat "$DEVICE_FILE" 2>/dev/null | xxd -p -c 32 | head -n 1 | while read -r line; do
        if [ -n "$line" ]; then
            # 格式化输出
            formatted=$(echo "$line" | sed 's/../& /g' | tr '[:lower:]' '[:upper:]')
            echo -e "${GREEN}📥 接收: $formatted${NC}"
        fi
    done || echo -e "${YELLOW}⚠️ 未收到响应或超时${NC}"
else
    echo -e "${RED}❌ 发送失败${NC}"
    exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
