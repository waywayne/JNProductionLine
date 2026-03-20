#!/bin/bash

# 测试 SPP 发送脚本
# 用于验证数据是否真正发送到设备

echo "=== SPP 发送测试 ==="
echo ""

# 检查 rfcomm0 是否存在
if [ ! -e /dev/rfcomm0 ]; then
    echo "❌ /dev/rfcomm0 不存在，请先连接蓝牙设备"
    exit 1
fi

echo "✅ /dev/rfcomm0 存在"
echo ""

# 测试数据包（产测开始命令）
# D0 D2 C5 C2 00 1D 00 03 04 00 00 FE 23 23 06 00 8D EF 01 FF 00 00 01 00 00 00 00 40 40 C9 D9 4D 45
TEST_DATA="\xD0\xD2\xC5\xC2\x00\x1D\x00\x03\x04\x00\x00\xFE\x23\x23\x06\x00\x8D\xEF\x01\xFF\x00\x00\x01\x00\x00\x00\x00\x40\x40\xC9\xD9\x4D\x45"

echo "测试方法1: 使用 socat (与代码相同)"
echo "命令: echo -ne '\xD0\xD2...' | socat - FILE:/dev/rfcomm0,b115200,raw,echo=0"
echo -ne "$TEST_DATA" | socat - FILE:/dev/rfcomm0,b115200,raw,echo=0 &
SOCAT_PID=$!
sleep 2
kill $SOCAT_PID 2>/dev/null
echo "✅ socat 方式发送完成"
echo ""

echo "测试方法2: 直接写入设备文件"
echo "命令: echo -ne '\xD0\xD2...' > /dev/rfcomm0"
echo -ne "$TEST_DATA" > /dev/rfcomm0
echo "✅ 直接写入方式发送完成"
echo ""

echo "测试方法3: 使用 stty 配置后写入"
echo "命令: stty -F /dev/rfcomm0 115200 raw -echo && echo -ne '\xD0\xD2...' > /dev/rfcomm0"
stty -F /dev/rfcomm0 115200 raw -echo 2>/dev/null
echo -ne "$TEST_DATA" > /dev/rfcomm0
echo "✅ stty 配置后发送完成"
echo ""

echo "测试方法4: 使用 cat 持续监听（后台）"
echo "命令: cat /dev/rfcomm0 &"
cat /dev/rfcomm0 > /tmp/spp_response.log 2>&1 &
CAT_PID=$!
echo "   监听进程 PID: $CAT_PID"
sleep 1
echo -ne "$TEST_DATA" > /dev/rfcomm0
sleep 2
kill $CAT_PID 2>/dev/null
if [ -s /tmp/spp_response.log ]; then
    echo "✅ 收到响应:"
    hexdump -C /tmp/spp_response.log | head -20
else
    echo "❌ 未收到响应"
fi
echo ""

echo "=== 测试完成 ==="
echo "请检查嵌入式端是否收到数据"
