#!/bin/bash
# 修复 Linux 构建中的插件问题
# 此脚本必须在 flutter pub get 之后、flutter build 之前运行

set -e

echo "🔧 Fixing Linux plugin configuration..."

PLUGINS_CMAKE="linux/flutter/generated_plugins.cmake"

if [ ! -f "$PLUGINS_CMAKE" ]; then
    echo "❌ Error: $PLUGINS_CMAKE not found"
    echo "   Please run 'flutter pub get' first"
    exit 1
fi

echo "📝 Patching $PLUGINS_CMAKE..."

# 创建备份
cp "$PLUGINS_CMAKE" "$PLUGINS_CMAKE.bak"

# 使用 sed 修改 foreach 循环，添加插件检查
cat > "$PLUGINS_CMAKE" << 'EOF'
#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  flutter_libserialport
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
)

set(PLUGIN_BUNDLED_LIBRARIES)

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/flutter/ephemeral/.plugin_symlinks/${plugin}/linux")
    add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/linux plugins/${plugin})
    target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
    list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
    list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
  else()
    message(STATUS "Skipping plugin ${plugin} (directory not found)")
  endif()
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/linux")
    add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/linux plugins/${ffi_plugin})
    list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
  else()
    message(STATUS "Skipping FFI plugin ${ffi_plugin} (directory not found)")
  endif()
endforeach(ffi_plugin)
EOF

echo "✅ Plugin configuration fixed!"
echo "   - Removed flutter_bluetooth_classic_serial from plugin list"
echo "   - Added existence checks for all plugins"
echo ""
echo "📋 Current plugin list:"
grep "FLUTTER_PLUGIN_LIST" -A 3 "$PLUGINS_CMAKE"
