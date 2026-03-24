#!/bin/bash

# 蓝牙产测 - 产测开始
# CMD: 0x01, OPT: 0x00

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 产测指令: 产测开始"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sudo "$SCRIPT_DIR/bt-send-gtp-command.sh" 01 00
