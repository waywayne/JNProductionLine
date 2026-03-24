#!/bin/bash

# 蓝牙产测 - Touch 测试
# CMD: 0x04, OPT: 0x00, DATA: Touch位置

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检查参数
if [ -z "$1" ]; then
    echo "❌ 错误: 请提供 Touch 位置"
    echo "用法: $0 <位置>"
    echo ""
    echo "Touch 位置:"
    echo "  0 - 左侧"
    echo "  1 - 右侧"
    exit 1
fi

TOUCH_POS="$1"

# 转换为十六进制
TOUCH_HEX=$(printf "%02X" "$TOUCH_POS")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 产测指令: Touch 测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Touch 位置: $([ "$TOUCH_POS" == "0" ] && echo "左侧" || echo "右侧")"
echo ""

sudo "$SCRIPT_DIR/bt-send-gtp-command.sh" 04 00 "$TOUCH_HEX"
