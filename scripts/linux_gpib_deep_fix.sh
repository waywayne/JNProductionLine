#!/bin/bash

# Linux GPIB 深度修复脚本
# 解决Linux下GPIB驱动和设备识别问题

echo "========================================="
echo "Linux GPIB 深度诊断和修复"
echo "========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为Linux
if [ "$(uname)" != "Linux" ]; then
    echo -e "${RED}❌ 此脚本仅适用于Linux系统${NC}"
    exit 1
fi

# 检查是否为root
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  警告: 请不要以root身份运行此脚本${NC}"
    echo "正确用法: ./linux_gpib_deep_fix.sh"
    exit 1
fi

echo "========================================="
echo "第一步: 检查GPIB适配器硬件"
echo "========================================="
echo ""

# 检查USB设备
echo "1. 检查USB GPIB适配器..."
if lsusb | grep -i "National Instruments\|Agilent\|Keysight"; then
    echo -e "${GREEN}✅ 找到GPIB USB适配器:${NC}"
    lsusb | grep -i "National Instruments\|Agilent\|Keysight"
else
    echo -e "${RED}❌ 未找到GPIB USB适配器${NC}"
    echo "请检查:"
    echo "  1. USB线缆是否连接"
    echo "  2. 适配器是否有电源指示灯"
    echo "  3. 尝试重新插拔USB"
    echo ""
    echo "所有USB设备:"
    lsusb
fi

echo ""

# 检查PCI设备
echo "2. 检查PCI GPIB卡..."
if lspci | grep -i "GPIB\|National Instruments"; then
    echo -e "${GREEN}✅ 找到GPIB PCI卡:${NC}"
    lspci | grep -i "GPIB\|National Instruments"
else
    echo -e "${YELLOW}⚠️  未找到GPIB PCI卡（如果使用USB适配器，这是正常的）${NC}"
fi

echo ""
echo "========================================="
echo "第二步: 检查并安装GPIB驱动"
echo "========================================="
echo ""

# 检查NI-VISA
echo "3. 检查NI-VISA..."
if command -v visaconf &> /dev/null; then
    echo -e "${GREEN}✅ NI-VISA已安装${NC}"
    visaconf --version 2>/dev/null || echo "  (版本信息不可用)"
    
    # 检查NI-VISA服务
    if systemctl is-active --quiet nivisa || service nivisa status &> /dev/null; then
        echo -e "${GREEN}✅ NI-VISA服务正在运行${NC}"
    else
        echo -e "${YELLOW}⚠️  NI-VISA服务未运行，尝试启动...${NC}"
        sudo systemctl start nivisa 2>/dev/null || sudo service nivisa start 2>/dev/null
    fi
else
    echo -e "${RED}❌ NI-VISA未安装${NC}"
    echo ""
    echo "安装NI-VISA:"
    echo "  Ubuntu/Debian:"
    echo "    wget https://download.ni.com/support/softlib/visa/NI-VISA/21.5/NI-VISA_21.5.0_Linux_x64.deb"
    echo "    sudo dpkg -i NI-VISA_21.5.0_Linux_x64.deb"
    echo "    sudo apt-get install -f"
    echo ""
    echo "  或访问: https://www.ni.com/en-us/support/downloads/drivers/download.ni-visa.html"
fi

echo ""

# 检查linux-gpib
echo "4. 检查linux-gpib驱动..."
if dpkg -l | grep -q linux-gpib; then
    echo -e "${GREEN}✅ linux-gpib已安装${NC}"
    dpkg -l | grep linux-gpib
else
    echo -e "${YELLOW}⚠️  linux-gpib未安装，正在尝试安装...${NC}"
    
    # 检测发行版
    if [ -f /etc/debian_version ]; then
        echo "检测到Debian/Ubuntu系统"
        sudo apt-get update
        sudo apt-get install -y linux-gpib linux-gpib-user linux-gpib-modules-dkms
    elif [ -f /etc/redhat-release ]; then
        echo "检测到RedHat/CentOS系统"
        sudo yum install -y linux-gpib linux-gpib-user
    else
        echo -e "${RED}❌ 无法自动安装，请手动安装linux-gpib${NC}"
    fi
fi

echo ""
echo "========================================="
echo "第三步: 加载GPIB内核模块"
echo "========================================="
echo ""

# 尝试加载gpib_common
echo "5. 加载gpib_common模块..."
if lsmod | grep -q gpib_common; then
    echo -e "${GREEN}✅ gpib_common模块已加载${NC}"
else
    echo -e "${YELLOW}⚠️  gpib_common模块未加载，尝试加载...${NC}"
    if sudo modprobe gpib_common 2>/dev/null; then
        echo -e "${GREEN}✅ gpib_common模块加载成功${NC}"
    else
        echo -e "${RED}❌ 无法加载gpib_common模块${NC}"
        echo "可能原因:"
        echo "  1. linux-gpib未正确安装"
        echo "  2. 内核模块未编译"
        echo "  3. 内核版本不兼容"
        echo ""
        echo "尝试重新编译GPIB模块:"
        echo "  sudo dpkg-reconfigure linux-gpib-modules-dkms"
    fi
fi

echo ""

# 尝试加载特定适配器驱动
echo "6. 加载GPIB适配器驱动..."

# NI USB-GPIB
if lsusb | grep -q "National Instruments"; then
    echo "检测到NI USB-GPIB适配器，加载ni_usb_gpib..."
    if sudo modprobe ni_usb_gpib 2>/dev/null; then
        echo -e "${GREEN}✅ ni_usb_gpib模块加载成功${NC}"
    else
        echo -e "${RED}❌ 无法加载ni_usb_gpib模块${NC}"
    fi
fi

# Agilent/Keysight
if lsusb | grep -q "Agilent\|Keysight"; then
    echo "检测到Agilent/Keysight适配器，加载agilent_82357a..."
    if sudo modprobe agilent_82357a 2>/dev/null; then
        echo -e "${GREEN}✅ agilent_82357a模块加载成功${NC}"
    else
        echo -e "${RED}❌ 无法加载agilent_82357a模块${NC}"
    fi
fi

echo ""

# 显示已加载的GPIB模块
echo "已加载的GPIB相关模块:"
lsmod | grep gpib || echo -e "${RED}  无GPIB模块${NC}"

echo ""
echo "========================================="
echo "第四步: 配置GPIB设备"
echo "========================================="
echo ""

# 检查gpib.conf
echo "7. 检查GPIB配置文件..."
if [ -f /etc/gpib.conf ]; then
    echo -e "${GREEN}✅ /etc/gpib.conf 存在${NC}"
    echo "当前配置:"
    cat /etc/gpib.conf | grep -v "^#" | grep -v "^$"
else
    echo -e "${YELLOW}⚠️  /etc/gpib.conf 不存在，创建默认配置...${NC}"
    sudo tee /etc/gpib.conf > /dev/null <<EOF
/* GPIB配置文件 */

interface {
    minor = 0           /* board index, minor = 0 uses /dev/gpib0 */
    board_type = "ni_usb_b"  /* NI USB-GPIB适配器 */
    name = "gpib0"
    pad = 0             /* primary address of interface */
    sad = 0             /* secondary address of interface */
    timeout = T30s      /* timeout for commands */
    eos = 0x0a          /* EOS Byte (LF) */
    set-reos = yes      /* Terminate read if EOS */
    set-bin = no        /* Compare EOS 8-bit */
    set-xeos = no       /* Assert EOI whenever EOS byte is sent */
    set-eot = yes       /* Assert EOI with last byte on writes */
}

/* 如果使用Agilent/Keysight适配器，将board_type改为 "agilent_82357a" */
EOF
    echo -e "${GREEN}✅ 已创建默认配置${NC}"
fi

echo ""

# 运行gpib_config
echo "8. 配置GPIB板卡..."
if command -v gpib_config &> /dev/null; then
    echo "运行 gpib_config..."
    if sudo gpib_config 2>&1; then
        echo -e "${GREEN}✅ GPIB配置成功${NC}"
    else
        echo -e "${RED}❌ GPIB配置失败${NC}"
        echo "请检查:"
        echo "  1. /etc/gpib.conf 配置是否正确"
        echo "  2. 适配器类型是否匹配"
        echo "  3. 内核模块是否正确加载"
    fi
else
    echo -e "${RED}❌ gpib_config命令不存在${NC}"
    echo "请安装linux-gpib-user包"
fi

echo ""
echo "========================================="
echo "第五步: 检查设备文件"
echo "========================================="
echo ""

echo "9. 检查/dev/gpib*设备文件..."
if ls /dev/gpib* 2>/dev/null; then
    echo -e "${GREEN}✅ 找到GPIB设备文件:${NC}"
    ls -l /dev/gpib*
    
    # 检查权限
    echo ""
    echo "检查设备文件权限..."
    for dev in /dev/gpib*; do
        if [ -r "$dev" ] && [ -w "$dev" ]; then
            echo -e "${GREEN}✅ $dev 可读写${NC}"
        else
            echo -e "${YELLOW}⚠️  $dev 权限不足${NC}"
            echo "  当前权限: $(ls -l $dev)"
            echo "  尝试修复权限..."
            sudo chmod 666 $dev
        fi
    done
else
    echo -e "${RED}❌ 未找到/dev/gpib*设备文件${NC}"
    echo ""
    echo "可能原因:"
    echo "  1. GPIB内核模块未加载"
    echo "  2. gpib_config未成功运行"
    echo "  3. 硬件未正确连接"
    echo ""
    echo "尝试手动创建设备文件:"
    echo "  sudo mknod /dev/gpib0 c 160 0"
    echo "  sudo chmod 666 /dev/gpib0"
fi

echo ""
echo "========================================="
echo "第六步: 用户组权限"
echo "========================================="
echo ""

echo "10. 检查用户组..."
if groups | grep -q "gpib"; then
    echo -e "${GREEN}✅ 用户已在gpib组中${NC}"
else
    echo -e "${YELLOW}⚠️  用户不在gpib组中，正在添加...${NC}"
    sudo usermod -a -G gpib $USER
    echo -e "${GREEN}✅ 已添加到gpib组 (需要重新登录生效)${NC}"
fi

if groups | grep -q "dialout"; then
    echo -e "${GREEN}✅ 用户已在dialout组中${NC}"
else
    echo -e "${YELLOW}⚠️  用户不在dialout组中，正在添加...${NC}"
    sudo usermod -a -G dialout $USER
    echo -e "${GREEN}✅ 已添加到dialout组 (需要重新登录生效)${NC}"
fi

echo ""
echo "当前用户组: $(groups)"

echo ""
echo "========================================="
echo "第七步: 测试GPIB通讯"
echo "========================================="
echo ""

echo "11. 使用Python测试GPIB..."
python3 << 'PYTHON_TEST'
import sys

try:
    import pyvisa
    print("✅ PyVISA已安装")
    
    # 尝试列出资源
    try:
        rm = pyvisa.ResourceManager('@ni')
        print(f"✅ NI-VISA后端可用")
        resources = rm.list_resources()
        print(f"找到 {len(resources)} 个资源:")
        for res in resources:
            print(f"  - {res}")
        rm.close()
    except Exception as e:
        print(f"❌ NI-VISA后端失败: {e}")
        
        # 尝试默认后端
        try:
            rm = pyvisa.ResourceManager()
            print(f"✅ 默认VISA后端可用")
            resources = rm.list_resources()
            print(f"找到 {len(resources)} 个资源:")
            for res in resources:
                print(f"  - {res}")
            rm.close()
        except Exception as e2:
            print(f"❌ 默认VISA后端也失败: {e2}")
            
except ImportError:
    print("❌ PyVISA未安装")
    print("安装: pip3 install pyvisa pyvisa-py")
    sys.exit(1)
PYTHON_TEST

echo ""
echo ""
echo "========================================="
echo "第八步: 应急解决方案"
echo "========================================="
echo ""

# 如果设备文件仍然不存在，手动创建
if ! ls /dev/gpib* 2>/dev/null; then
    echo -e "${YELLOW}⚠️  设备文件仍不存在，尝试手动创建...${NC}"
    
    # 创建设备文件
    sudo mknod /dev/gpib0 c 160 0 2>/dev/null
    sudo chmod 666 /dev/gpib0
    
    if [ -e /dev/gpib0 ]; then
        echo -e "${GREEN}✅ 已手动创建 /dev/gpib0${NC}"
    else
        echo -e "${RED}❌ 无法创建设备文件${NC}"
    fi
fi

echo ""

# 如果NI-VISA后端不工作，尝试使用pyvisa-py
echo "12. 配置PyVISA后端..."
python3 << 'PYTHON_BACKEND'
import sys

try:
    import pyvisa
    
    # 检查pyvisa-py
    try:
        import pyvisa_py
        print("✅ pyvisa-py已安装（纯Python后端）")
    except ImportError:
        print("⚠️  pyvisa-py未安装，正在安装...")
        import subprocess
        subprocess.run([sys.executable, "-m", "pip", "install", "pyvisa-py", "--user"], check=True)
        print("✅ pyvisa-py安装成功")
    
    # 测试@py后端
    try:
        rm = pyvisa.ResourceManager('@py')
        print("✅ @py后端可用（不依赖NI-VISA）")
        resources = rm.list_resources()
        if resources:
            print(f"  找到 {len(resources)} 个资源:")
            for res in resources:
                print(f"    - {res}")
        else:
            print("  未找到资源（这可能是正常的，如果设备未连接）")
        rm.close()
    except Exception as e:
        print(f"❌ @py后端失败: {e}")
        
except Exception as e:
    print(f"❌ PyVISA配置失败: {e}")
PYTHON_BACKEND

echo ""
echo "========================================="
echo "第九步: 创建快速测试脚本"
echo "========================================="
echo ""

# 创建测试脚本
TEST_SCRIPT="/tmp/test_gpib.py"
cat > "$TEST_SCRIPT" << 'PYTHON_TEST_SCRIPT'
#!/usr/bin/env python3
"""GPIB快速测试脚本"""

import sys

def test_gpib(address='GPIB0::5::INSTR'):
    """测试GPIB连接"""
    import pyvisa
    
    print(f"测试地址: {address}")
    print("=" * 50)
    
    # 测试不同的后端
    backends = [
        ('@ni', 'NI-VISA'),
        ('@py', 'PyVISA-py (纯Python)'),
        (None, '默认后端'),
    ]
    
    for backend, name in backends:
        print(f"\n尝试后端: {name}")
        try:
            if backend:
                rm = pyvisa.ResourceManager(backend)
            else:
                rm = pyvisa.ResourceManager()
            
            print(f"  ✅ {name} 初始化成功")
            
            # 列出资源
            resources = rm.list_resources()
            print(f"  找到 {len(resources)} 个资源")
            
            # 尝试连接
            try:
                inst = rm.open_resource(address)
                inst.timeout = 30000
                print(f"  ✅ 连接成功")
                
                # 测试写入
                try:
                    inst.write('*CLS')
                    print(f"  ✅ 写入命令成功 (*CLS)")
                except Exception as e:
                    print(f"  ❌ 写入失败: {e}")
                
                # 测试查询
                try:
                    result = inst.query('*IDN?')
                    print(f"  ✅ 查询成功: {result.strip()}")
                except Exception as e:
                    print(f"  ⚠️  查询失败: {e}")
                    print(f"     (设备可能不支持查询命令)")
                
                inst.close()
                
            except Exception as e:
                print(f"  ❌ 连接失败: {e}")
            
            rm.close()
            
        except Exception as e:
            print(f"  ❌ {name} 失败: {e}")

if __name__ == '__main__':
    address = sys.argv[1] if len(sys.argv) > 1 else 'GPIB0::5::INSTR'
    test_gpib(address)
PYTHON_TEST_SCRIPT

chmod +x "$TEST_SCRIPT"
echo -e "${GREEN}✅ 已创建测试脚本: $TEST_SCRIPT${NC}"
echo "使用方法: python3 $TEST_SCRIPT GPIB0::5::INSTR"

echo ""
echo "========================================="
echo "第十步: 设置开机自动加载"
echo "========================================="
echo ""

# 创建systemd服务自动加载GPIB模块
echo "13. 配置开机自动加载GPIB模块..."

SYSTEMD_SERVICE="/etc/systemd/system/gpib-setup.service"
if [ ! -f "$SYSTEMD_SERVICE" ]; then
    echo "创建systemd服务..."
    sudo tee "$SYSTEMD_SERVICE" > /dev/null << 'EOF'
[Unit]
Description=GPIB Setup Service
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'modprobe gpib_common && modprobe ni_usb_gpib && gpib_config && chmod 666 /dev/gpib*'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable gpib-setup.service
    echo -e "${GREEN}✅ 已配置开机自动加载${NC}"
else
    echo -e "${GREEN}✅ systemd服务已存在${NC}"
fi

echo ""
echo "========================================="
echo "诊断和修复完成"
echo "========================================="
echo ""

# 最终状态检查
echo -e "${GREEN}最终状态检查:${NC}"
echo ""

# 1. 用户组
echo "1. 用户组:"
if groups | grep -q "gpib" && groups | grep -q "dialout"; then
    echo -e "   ${GREEN}✅ 用户组正确${NC}"
else
    echo -e "   ${YELLOW}⚠️  需要重新登录生效${NC}"
fi

# 2. 内核模块
echo "2. 内核模块:"
if lsmod | grep -q gpib; then
    echo -e "   ${GREEN}✅ GPIB模块已加载${NC}"
    lsmod | grep gpib | awk '{print "      " $1}'
else
    echo -e "   ${RED}❌ GPIB模块未加载${NC}"
fi

# 3. 设备文件
echo "3. 设备文件:"
if ls /dev/gpib* 2>/dev/null; then
    echo -e "   ${GREEN}✅ 设备文件存在${NC}"
    ls -l /dev/gpib* | awk '{print "      " $0}'
else
    echo -e "   ${RED}❌ 设备文件不存在${NC}"
fi

# 4. NI-VISA
echo "4. NI-VISA:"
if command -v visaconf &> /dev/null; then
    echo -e "   ${GREEN}✅ NI-VISA已安装${NC}"
else
    echo -e "   ${YELLOW}⚠️  NI-VISA未安装${NC}"
fi

# 5. PyVISA
echo "5. PyVISA:"
if python3 -c "import pyvisa" 2>/dev/null; then
    echo -e "   ${GREEN}✅ PyVISA已安装${NC}"
else
    echo -e "   ${RED}❌ PyVISA未安装${NC}"
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}下一步操作:${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

if ! groups | grep -q "gpib" || ! groups | grep -q "dialout"; then
    echo -e "${YELLOW}⚠️  重要: 必须重新登录系统使用户组生效！${NC}"
    echo ""
    echo "方法1: 注销并重新登录"
    echo "方法2: 重启系统"
    echo ""
fi

if ! lsmod | grep -q gpib || ! ls /dev/gpib* 2>/dev/null; then
    echo -e "${YELLOW}⚠️  GPIB驱动未完全配置${NC}"
    echo ""
    echo "建议操作:"
    echo "1. 重启系统"
    echo "2. 重新运行此脚本"
    echo "3. 运行测试脚本: python3 /tmp/test_gpib.py"
    echo ""
fi

echo "测试GPIB连接:"
echo "  python3 /tmp/test_gpib.py GPIB0::5::INSTR"
echo ""

echo "查看详细日志:"
echo "  sudo dmesg | grep -i gpib"
echo "  sudo journalctl -u gpib-setup.service"
echo ""

echo -e "${GREEN}=========================================${NC}"
