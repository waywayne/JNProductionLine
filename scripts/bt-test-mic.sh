#!/bin/bash

# 蓝牙产测 - 麦克风测试
# CMD: 0x07, OPT: 0x00, DATA: 麦克风位置

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检查参数
if [ -z "$1" ]; then
    echo "❌ 错误: 请提供麦克风位置"
    echo "用法: $0 <位置>"
    echo ""
    echo "麦克风位置:"
    echo "  0 - 左侧"
    echo "  1 - 右侧"
    exit 1
fi

MIC_POS="$1"

# 转换为十六进制
MIC_HEX=$(printf "%02X" "$MIC_POS")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 产测指令: 麦克风测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "麦克风位置: $([ "$MIC_POS" == "0" ] && echo "左侧" || echo "右侧")"
echo ""

sudo "$SCRIPT_DIR/bt-send-gtp-command.sh" 07 00 "$MIC_HEX"
