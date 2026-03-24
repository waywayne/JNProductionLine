#!/bin/bash

# 蓝牙产测 - LED 测试
# CMD: 0x03, OPT: 0x00, DATA: LED编号

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检查参数
if [ -z "$1" ]; then
    echo "❌ 错误: 请提供 LED 编号"
    echo "用法: $0 <LED编号>"
    echo ""
    echo "LED 编号:"
    echo "  1 - LED 1"
    echo "  2 - LED 2"
    echo "  3 - LED 3"
    echo "  4 - LED 4"
    echo "  5 - LED 5"
    echo "  6 - LED 6"
    exit 1
fi

LED_NUM="$1"

# 转换为十六进制
LED_HEX=$(printf "%02X" "$LED_NUM")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 产测指令: LED 测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "LED 编号: $LED_NUM"
echo ""

sudo "$SCRIPT_DIR/bt-send-gtp-command.sh" 03 00 "$LED_HEX"
