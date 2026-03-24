#!/bin/bash

# 蓝牙产测 - 唤醒设备
# CMD: 0x00

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 产测指令: 唤醒设备"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

sudo "$SCRIPT_DIR/bt-send-gtp-command.sh" 00
