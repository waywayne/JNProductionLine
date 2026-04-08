#!/bin/bash
# 将 libimage_test.a 和 OpenCV 静态库链接为 libimage_test.so 共享库
# 需要在目标 Linux 机器上运行此脚本（静态库需要与目标架构匹配）
# 前提条件: 安装 g++ 编译器
#
# 注意: 静态库(.a)编译时可能未使用 -fPIC，
# 如果链接失败，需要联系库提供方重新编译时加上 -fPIC 选项。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_SO="$SCRIPT_DIR/libimage_test.so"
OPENCV_LIB_DIR="$SCRIPT_DIR/opencv/lib"

echo "========================================="
echo "  构建 libimage_test.so 共享库"
echo "========================================="
echo "脚本目录: $SCRIPT_DIR"
echo "输出文件: $OUTPUT_SO"
echo ""

# 检查静态库是否存在
if [ ! -f "$SCRIPT_DIR/libimage_test.a" ]; then
    echo "❌ 错误: 找不到 $SCRIPT_DIR/libimage_test.a"
    exit 1
fi

# 收集所有 OpenCV 静态库
OPENCV_LIBS=""
if [ -d "$OPENCV_LIB_DIR" ]; then
    for lib in "$OPENCV_LIB_DIR"/libopencv_*.a; do
        if [ -f "$lib" ]; then
            OPENCV_LIBS="$OPENCV_LIBS $lib"
        fi
    done
    echo "找到 OpenCV 静态库:"
    for lib in $OPENCV_LIBS; do
        echo "  - $(basename $lib)"
    done
else
    echo "⚠️  未找到 OpenCV 库目录，尝试不链接 OpenCV"
fi

echo ""
echo "🔨 开始编译..."

# 链接为共享库
g++ -shared -fPIC -o "$OUTPUT_SO" \
    -Wl,--whole-archive \
    "$SCRIPT_DIR/libimage_test.a" \
    $OPENCV_LIBS \
    -Wl,--no-whole-archive \
    -lstdc++ -lm -lpthread -ldl -lz \
    2>&1

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 编译成功: $OUTPUT_SO"
    echo "   文件大小: $(du -h "$OUTPUT_SO" | cut -f1)"
    echo ""
    echo "部署方式 (选择其一):"
    echo "  1. 放在此目录下，Flutter build 会自动打包到 bundle/lib/"
    echo "  2. cp $OUTPUT_SO /opt/jn-production-line/lib/"
    echo "  3. cp $OUTPUT_SO /usr/local/lib/ && sudo ldconfig"
else
    echo ""
    echo "❌ 编译失败"
    echo ""
    echo "常见问题:"
    echo "  1. 'relocation ... can not be used when making a shared object'"
    echo "     → 静态库编译时未使用 -fPIC，需联系库提供方重新编译"
    echo "  2. 'undefined reference' 错误"
    echo "     → 可能需要安装: sudo apt-get install -y libstdc++-dev zlib1g-dev"
    exit 1
fi
