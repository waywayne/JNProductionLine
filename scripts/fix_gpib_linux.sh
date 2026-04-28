#!/bin/bash

# GPIB Linux 问题修复脚本
# 用于解决Linux系统上的GPIB权限和驱动问题

echo "========================================="
echo "GPIB Linux 问题修复脚本"
echo "========================================="
echo ""

# 检查是否为root
if [ "$EUID" -eq 0 ]; then
  echo "⚠️  警告: 请不要以root身份运行此脚本"
  echo "正确用法: ./fix_gpib_linux.sh"
  exit 1
fi

# 1. 检查并添加用户到gpib组
echo "1. 检查用户组权限..."
if groups | grep -q "gpib"; then
    echo "✅ 用户已在gpib组中"
else
    echo "⚠️  用户不在gpib组中，正在添加..."
    sudo usermod -a -G gpib $USER
    echo "✅ 已添加到gpib组 (需要重新登录生效)"
fi

if groups | grep -q "dialout"; then
    echo "✅ 用户已在dialout组中"
else
    echo "⚠️  用户不在dialout组中，正在添加..."
    sudo usermod -a -G dialout $USER
    echo "✅ 已添加到dialout组 (需要重新登录生效)"
fi

echo ""

# 2. 检查GPIB内核模块
echo "2. 检查GPIB内核模块..."
if lsmod | grep -q "gpib"; then
    echo "✅ GPIB内核模块已加载"
else
    echo "⚠️  GPIB内核模块未加载，尝试加载..."
    if sudo modprobe gpib_common 2>/dev/null; then
        echo "✅ gpib_common模块加载成功"
    else
        echo "❌ 无法加载gpib_common模块"
        echo "   可能需要安装linux-gpib驱动"
    fi
fi

echo ""

# 3. 检查GPIB设备文件
echo "3. 检查GPIB设备文件..."
if ls /dev/gpib* 2>/dev/null; then
    echo "✅ 找到GPIB设备文件:"
    ls -l /dev/gpib* 2>/dev/null
else
    echo "❌ 未找到/dev/gpib*设备文件"
    echo "   可能需要配置GPIB硬件"
fi

echo ""

# 4. 检查NI-VISA安装
echo "4. 检查NI-VISA安装..."
if command -v visaconf &> /dev/null; then
    echo "✅ NI-VISA已安装"
    visaconf --version 2>/dev/null || echo "   (版本信息不可用)"
else
    echo "⚠️  NI-VISA未安装"
    echo "   下载地址: https://www.ni.com/en-us/support/downloads/drivers/download.ni-visa.html"
fi

echo ""

# 5. 检查Python和PyVISA
echo "5. 检查Python环境..."
if command -v python3 &> /dev/null; then
    echo "✅ Python3已安装: $(python3 --version)"
    
    if python3 -c "import pyvisa" 2>/dev/null; then
        echo "✅ PyVISA已安装: $(python3 -c 'import pyvisa; print(pyvisa.__version__)')"
    else
        echo "⚠️  PyVISA未安装，正在安装..."
        pip3 install pyvisa pyvisa-py --user
    fi
else
    echo "❌ Python3未安装"
fi

echo ""
echo "========================================="
echo "修复完成!"
echo "========================================="
echo ""
echo "重要提示:"
echo "1. 如果添加了用户组，请重新登录系统使其生效"
echo "2. 运行 'groups' 命令确认用户组"
echo "3. 运行 'lsmod | grep gpib' 确认内核模块"
echo "4. 如果问题仍然存在，请检查GPIB硬件连接"
echo ""
