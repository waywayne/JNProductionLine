#!/bin/bash

# 蓝牙产测 - 马达测试
# CMD: 0x06, OPT: 0x00, DATA: 马达位置

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检查参数
if [ -z "$1" ]; then
    echo "❌ 错误: 请提供马达位置"
    echo "用法: $0 <位置>"
    echo ""
    echo "马达位置:"
    echo "  0 - 左侧"
    echo "  1 - 右侧"
    exit 1
fi

MOTOR_POS="$1"

# 转换为十六进制
MOTOR_HEX=$(printf "%02X" "$MOTOR_POS")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 产测指令: 马达测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "马达位置: $([ "$MOTOR_POS" == "0" ] && echo "左侧" || echo "右侧")"
echo ""

sudo "$SCRIPT_DIR/bt-send-gtp-command.sh" 06 00 "$MOTOR_HEX"
