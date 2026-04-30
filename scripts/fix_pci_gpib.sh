#!/bin/bash
# 修复PCI GPIB卡配置

echo "修复PCI GPIB配置..."

# 1. 修正gpib.conf配置
sudo tee /etc/gpib.conf > /dev/null << 'EOF'
/* PCI-GPIB配置 */
interface {
    minor = 0
    board_type = "ni_pci"  /* PCI卡，不是USB */
    name = "gpib0"
    pad = 0
    sad = 0
    timeout = T30s
    eos = 0x0a
    set-reos = yes
    set-bin = no
    set-xeos = no
    set-eot = yes
}
EOF

echo "✅ 配置已更新为PCI模式"

# 2. 尝试加载PCI驱动
echo "加载PCI GPIB驱动..."
sudo modprobe tnt4882 2>/dev/null || sudo modprobe nec7210 2>/dev/null

# 3. 测试
echo ""
echo "测试连接:"
python3 /tmp/test_gpib.py GPIB0::5::INSTR
