#!/bin/bash

# 蓝牙产测 - 获取电压
# CMD: 0x02, OPT: 0x00

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 产测指令: 获取电压"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sudo "$SCRIPT_DIR/bt-send-gtp-command.sh" 02 00
