#!/bin/bash

################################################################################
# 蓝牙 SPP 完整测试脚本
# 功能：从扫描设备到 SPP 通讯的完整流程测试
# 用法：sudo ./test-bluetooth-full.sh [MAC地址] [UUID]
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# 默认参数
MAC_ADDRESS=""
UUID="7033"
CHANNEL=""
AUTO_MODE=false

# 解析参数
while [ $# -gt 0 ]; do
    case $1 in
        -m|--mac)
            MAC_ADDRESS="$2"
            shift 2
            ;;
        -u|--uuid)
            UUID="$2"
            shift 2
            ;;
        -c|--channel)
            CHANNEL="$2"
            shift 2
            ;;
        -a|--auto)
            AUTO_MODE=true
            shift
            ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  -m, --mac <地址>     蓝牙 MAC 地址"
            echo "  -u, --uuid <UUID>    服务 UUID (默认: 7033)"
            echo "  -c, --channel <通道> RFCOMM 通道 (可选，自动查询)"
            echo "  -a, --auto           自动模式，不需要用户确认"
            echo "  -h, --help           显示帮助信息"
            echo ""
            echo "示例:"
            echo "  $0 -m 48:08:EB:60:00:6A -u 7033"
            echo "  $0 --mac 48:08:EB:60:00:6A --channel 5 --auto"
            exit 0
            ;;
        *)
            if [ -z "$MAC_ADDRESS" ]; then
                MAC_ADDRESS="$1"
            fi
            shift
            ;;
    esac
done

# 日志函数
log_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

log_step() {
    echo -e "${CYAN}[$1] $2${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_info() {
    echo -e "${MAGENTA}ℹ️  $1${NC}"
}

# 清理函数
cleanup() {
    log_warning "正在清理..."
    sudo pkill -f "rfcomm" 2>/dev/null || true
    sudo rfcomm release 0 2>/dev/null || true
    echo "scan off" | bluetoothctl > /dev/null 2>&1 || true
    log_success "清理完成"
}

# 设置退出时清理
trap cleanup EXIT INT TERM

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then 
    log_error "请使用 sudo 运行此脚本"
    exit 1
fi

# 显示标题
clear
log_header "🔵 蓝牙 SPP 完整测试脚本"

echo -e "${CYAN}测试流程:${NC}"
echo "  1️⃣  检查系统环境"
echo "  2️⃣  扫描蓝牙设备"
echo "  3️⃣  配对设备（可选）"
echo "  4️⃣  连接蓝牙设备"
echo "  5️⃣  SDP 服务查询"
echo "  6️⃣  建立 RFCOMM 连接"
echo "  7️⃣  测试 SPP 通讯"
echo ""

# ============================================================================
# 步骤 1: 检查系统环境
# ============================================================================
log_step "1/7" "检查系统环境..."

# 检查必要工具
MISSING_TOOLS=""

if ! command -v bluetoothctl > /dev/null 2>&1; then
    MISSING_TOOLS="$MISSING_TOOLS bluetoothctl"
fi

if ! command -v hciconfig > /dev/null 2>&1; then
    MISSING_TOOLS="$MISSING_TOOLS hciconfig"
fi

if ! command -v sdptool > /dev/null 2>&1; then
    MISSING_TOOLS="$MISSING_TOOLS sdptool"
fi

if ! command -v rfcomm > /dev/null 2>&1; then
    MISSING_TOOLS="$MISSING_TOOLS rfcomm"
fi

if [ -n "$MISSING_TOOLS" ]; then
    log_error "缺少必要工具:$MISSING_TOOLS"
    log_info "请安装: sudo apt-get install bluez bluez-tools"
    exit 1
fi

log_success "所有必要工具已安装"

# 检查蓝牙适配器
if ! hciconfig hci0 > /dev/null 2>&1; then
    log_error "未找到蓝牙适配器 hci0"
    exit 1
fi

log_success "蓝牙适配器 hci0 已就绪"

# 开启蓝牙
hciconfig hci0 up 2>/dev/null || true
echo "power on" | bluetoothctl > /dev/null 2>&1
sleep 1

log_success "蓝牙适配器已开启"
echo ""

# ============================================================================
# 步骤 2: 扫描蓝牙设备
# ============================================================================
log_step "2/7" "扫描蓝牙设备..."

if [ -z "$MAC_ADDRESS" ]; then
    log_info "开始扫描附近的蓝牙设备（包括 BLE）..."
    
    # 使用 bluetoothctl 扫描（支持 BLE + 经典蓝牙）
    (
        echo "power on"
        sleep 1
        echo "scan on"
        sleep 10
        echo "scan off"
        echo "devices"
    ) | bluetoothctl > /tmp/bt_scan_full.txt 2>&1
    
    # 显示找到的设备
    DEVICES=$(grep "Device" /tmp/bt_scan_full.txt | grep -v "^#")
    
    if [ -z "$DEVICES" ]; then
        log_error "未找到任何蓝牙设备"
        log_info "扫描输出:"
        cat /tmp/bt_scan_full.txt
        exit 1
    fi
    
    echo -e "${GREEN}找到以下设备:${NC}"
    echo "$DEVICES" | nl
    echo ""
    
    # 让用户选择
    if [ "$AUTO_MODE" = false ]; then
        read -p "请输入设备编号或直接输入 MAC 地址: " SELECTION
        
        if echo "$SELECTION" | grep -qE '^[0-9]+$'; then
            MAC_ADDRESS=$(echo "$DEVICES" | sed -n "${SELECTION}p" | awk '{print $2}')
        else
            MAC_ADDRESS="$SELECTION"
        fi
    else
        # 自动模式：选择第一个设备
        MAC_ADDRESS=$(echo "$DEVICES" | head -1 | awk '{print $2}')
    fi
fi

# 验证 MAC 地址格式
if ! echo "$MAC_ADDRESS" | grep -qE '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$'; then
    log_error "无效的 MAC 地址: $MAC_ADDRESS"
    exit 1
fi

log_success "目标设备: $MAC_ADDRESS"

# 获取设备名称
DEVICE_NAME=$(echo "info $MAC_ADDRESS" | bluetoothctl | grep "Name:" | cut -d':' -f2- | xargs)
if [ -n "$DEVICE_NAME" ]; then
    log_info "设备名称: $DEVICE_NAME"
fi
echo ""

# ============================================================================
# 步骤 3: 配对设备（可选）
# ============================================================================
log_step "3/7" "检查配对状态..."

PAIRED=$(echo "paired-devices" | bluetoothctl | grep -i "$MAC_ADDRESS" || true)

if [ -z "$PAIRED" ]; then
    log_warning "设备未配对"
    
    if [ "$AUTO_MODE" = false ]; then
        read -p "是否尝试配对？(y/N) " -n 1 -r
        echo
        DO_PAIR=$REPLY
    else
        DO_PAIR="y"
    fi
    
    if echo "$DO_PAIR" | grep -qE '^[Yy]$'; then
        log_info "开始配对..."
        
        echo "agent NoInputNoOutput" | bluetoothctl
        echo "default-agent" | bluetoothctl
        echo "pair $MAC_ADDRESS" | bluetoothctl
        sleep 2
        echo "trust $MAC_ADDRESS" | bluetoothctl
        sleep 1
        
        PAIRED=$(echo "paired-devices" | bluetoothctl | grep -i "$MAC_ADDRESS" || true)
        if [ -n "$PAIRED" ]; then
            log_success "配对成功"
        else
            log_warning "配对失败，但将继续尝试连接"
        fi
    else
        log_info "跳过配对，直接连接"
    fi
else
    log_success "设备已配对"
fi
echo ""

# ============================================================================
# 步骤 4: 连接蓝牙设备
# ============================================================================
log_step "4/7" "连接蓝牙设备..."

# 检查是否已连接
BT_INFO=$(echo "info $MAC_ADDRESS" | bluetoothctl)
if echo "$BT_INFO" | grep -q "Connected: yes"; then
    log_success "设备已连接"
else
    log_info "正在连接设备..."
    
    # 尝试连接（最多3次）
    CONNECTED=false
    i=1
    while [ $i -le 3 ]; do
        if [ $i -gt 1 ]; then
            log_info "重试第 $i 次..."
        fi
        
        echo "connect $MAC_ADDRESS" | bluetoothctl
        sleep 3
        
        BT_INFO=$(echo "info $MAC_ADDRESS" | bluetoothctl)
        if echo "$BT_INFO" | grep -q "Connected: yes"; then
            CONNECTED=true
            break
        fi
        
        sleep 1
        i=$((i + 1))
    done
    
    if [ "$CONNECTED" = true ]; then
        log_success "蓝牙设备已连接"
    else
        log_error "蓝牙连接失败"
        log_info "设备信息:"
        echo "$BT_INFO" | grep -E "Name:|Alias:|Connected:|Paired:|Trusted:"
        exit 1
    fi
fi
echo ""

# ============================================================================
# 步骤 5: SDP 服务查询
# ============================================================================
log_step "5/7" "查询 RFCOMM 通道 (SDP)..."

if [ -z "$CHANNEL" ]; then
    log_info "正在查询 UUID: $UUID"
    
    # 执行 SDP 查询
    SDP_OUTPUT=$(sdptool browse "$MAC_ADDRESS" 2>&1)
    
    if [ -z "$SDP_OUTPUT" ]; then
        log_error "SDP 查询失败"
        exit 1
    fi
    
    # 保存完整输出到临时文件
    echo "$SDP_OUTPUT" > /tmp/sdp_output.txt
    log_info "完整 SDP 输出已保存到: /tmp/sdp_output.txt"
    
    # 提取通道号
    CHANNEL=$(echo "$SDP_OUTPUT" | grep -A 10 "$UUID" | grep "Channel:" | head -1 | awk '{print $2}')
    
    if [ -z "$CHANNEL" ]; then
        log_warning "未找到 UUID $UUID 的通道"
        log_info "显示所有可用服务:"
        echo "$SDP_OUTPUT" | grep -E "Service Name:|Channel:" | head -20
        
        if [ "$AUTO_MODE" = false ]; then
            read -p "请手动输入 RFCOMM 通道号: " CHANNEL
        else
            log_error "自动模式下无法确定通道号"
            exit 1
        fi
    fi
fi

log_success "RFCOMM 通道: $CHANNEL"
echo ""

# ============================================================================
# 步骤 6: 建立 RFCOMM 连接
# ============================================================================
log_step "6/7" "建立 RFCOMM 连接..."

# 清理旧连接
sudo pkill -f "rfcomm" 2>/dev/null || true
sudo rfcomm release 0 2>/dev/null || true
sleep 1

DEVICE_PATH="/dev/rfcomm0"

# 方法1: 尝试 rfcomm bind
log_info "尝试 RFCOMM bind 模式..."

if sudo rfcomm bind 0 "$MAC_ADDRESS" "$CHANNEL" 2>&1; then
    log_success "RFCOMM bind 成功"
    
    # 等待设备文件创建
    sleep 1
    
    if [ -e "$DEVICE_PATH" ]; then
        log_success "设备文件已创建: $DEVICE_PATH"
        ls -l "$DEVICE_PATH"
        RFCOMM_MODE="bind"
    else
        log_warning "bind 成功但设备文件未创建"
        sudo rfcomm release 0 2>/dev/null || true
        RFCOMM_MODE=""
    fi
else
    log_warning "RFCOMM bind 失败"
    RFCOMM_MODE=""
fi

# 方法2: 如果 bind 失败，尝试 connect
if [ -z "$RFCOMM_MODE" ]; then
    log_info "尝试 RFCOMM connect 模式..."
    
    # 后台启动 rfcomm connect
    sudo rfcomm connect 0 "$MAC_ADDRESS" "$CHANNEL" &
    RFCOMM_PID=$!
    
    # 等待连接建立
    sleep 3
    
    if [ -e "$DEVICE_PATH" ]; then
        log_success "RFCOMM connect 成功"
        log_success "设备文件已创建: $DEVICE_PATH"
        ls -l "$DEVICE_PATH"
        RFCOMM_MODE="connect"
    else
        log_error "RFCOMM 连接失败"
        kill $RFCOMM_PID 2>/dev/null || true
        exit 1
    fi
fi

log_success "RFCOMM 连接已建立 (模式: $RFCOMM_MODE)"
echo ""

# ============================================================================
# 步骤 7: 测试 SPP 通讯
# ============================================================================
log_step "7/7" "测试 SPP 通讯..."

# 检查读写权限
if [ -r "$DEVICE_PATH" ]; then
    log_success "设备可读"
else
    log_error "设备不可读"
fi

if [ -w "$DEVICE_PATH" ]; then
    log_success "设备可写"
else
    log_error "设备不可写"
fi

echo ""

# 测试发送数据
if [ "$AUTO_MODE" = false ]; then
    read -p "是否测试发送数据？(y/N) " -n 1 -r
    echo
    DO_TEST=$REPLY
else
    DO_TEST="y"
fi

if echo "$DO_TEST" | grep -qE '^[Yy]$'; then
    log_info "测试 1: 发送简单字节序列"
    echo -e "\x01\x02\x03\x04\x05" | sudo tee "$DEVICE_PATH" > /dev/null
    log_success "已发送: 01 02 03 04 05"
    
    log_info "测试 2: 尝试读取响应（5秒超时）"
    timeout 5 sudo cat "$DEVICE_PATH" | xxd -l 100 || log_warning "无响应或超时"
    
    echo ""
    
    log_info "测试 3: 发送 GTP 协议测试包"
    # GTP Preamble: D0 D2 C5 C2
    # Length: 0x0C 0x00 (12 bytes)
    # Module ID: 0x00 0x00
    # Message ID: 0x01 0x00
    # SN: 0x01 0x00
    # Result: 0x00
    # Payload: 0x01 (1 byte test command)
    TEST_PACKET="\xD0\xD2\xC5\xC2\x0C\x00\x00\x00\x01\x00\x01\x00\x00\x01"
    echo -ne "$TEST_PACKET" | sudo tee "$DEVICE_PATH" > /dev/null
    log_success "已发送 GTP 测试包"
    
    log_info "等待响应（5秒）..."
    timeout 5 sudo cat "$DEVICE_PATH" | xxd -l 100 || log_warning "无响应或超时"
fi

echo ""

# ============================================================================
# 测试完成
# ============================================================================
log_header "✅ 测试完成！"

echo -e "${CYAN}连接信息摘要:${NC}"
echo -e "  设备地址:    ${GREEN}$MAC_ADDRESS${NC}"
echo -e "  设备名称:    ${GREEN}${DEVICE_NAME:-未知}${NC}"
echo -e "  服务 UUID:   ${GREEN}$UUID${NC}"
echo -e "  RFCOMM 通道: ${GREEN}$CHANNEL${NC}"
echo -e "  设备路径:    ${GREEN}$DEVICE_PATH${NC}"
echo -e "  连接模式:    ${GREEN}$RFCOMM_MODE${NC}"
echo ""

echo -e "${YELLOW}后续操作:${NC}"
echo -e "  • 保持连接: 设备文件 $DEVICE_PATH 可用于通讯"
echo -e "  • 读取数据: ${CYAN}sudo cat $DEVICE_PATH | xxd${NC}"
echo -e "  • 发送数据: ${CYAN}echo \"data\" | sudo tee $DEVICE_PATH${NC}"
echo -e "  • 断开连接: ${CYAN}sudo rfcomm release 0${NC}"
echo ""

if [ "$AUTO_MODE" = false ]; then
    read -p "按 Enter 键退出并清理连接..."
fi

# cleanup 会在 EXIT 时自动调用
