#!/bin/bash

# 蓝牙产测 - 扬声器测试
# CMD: 0x08, OPT: 0x00, DATA: 扬声器位置

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检查参数
if [ -z "$1" ]; then
    echo "❌ 错误: 请提供扬声器位置"
    echo "用法: $0 <位置>"
    echo ""
    echo "扬声器位置:"
    echo "  0 - 左侧"
    echo "  1 - 右侧"
    exit 1
fi

SPEAKER_POS="$1"

# 转换为十六进制
SPEAKER_HEX=$(printf "%02X" "$SPEAKER_POS")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 产测指令: 扬声器测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "扬声器位置: $([ "$SPEAKER_POS" == "0" ] && echo "左侧" || echo "右侧")"
echo ""

sudo "$SCRIPT_DIR/bt-send-gtp-command.sh" 08 00 "$SPEAKER_HEX"
