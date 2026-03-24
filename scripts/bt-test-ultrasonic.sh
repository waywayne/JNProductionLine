#!/bin/bash

# 蓝牙产测 - 超声测试
# CMD: 0x05, OPT: 0x00

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 产测指令: 超声测试"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sudo "$SCRIPT_DIR/bt-send-gtp-command.sh" 05 00
