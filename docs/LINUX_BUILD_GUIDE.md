# Linux 构建指南

## 问题说明

### flutter_bluetooth_classic_serial 插件问题

`flutter_bluetooth_classic_serial` 插件仅支持 Windows 平台，但其 Linux 目录下的 CMakeLists.txt 文件存在严重问题：

1. **重复定义 Flutter 目标**：尝试创建已存在的 `flutter` 和 `flutter_assemble` 目标
2. **错误的路径引用**：引用了不存在的文件路径
3. **递归包含问题**：在自己的 CMakeLists.txt 中包含 generated_plugins.cmake，导致循环依赖

### 错误信息

```
CMake Error: add_library cannot create target "flutter" because another target with the same name already exists
CMake Error: add_custom_target cannot create target "flutter_assemble" because another target with the same name already exists
```

## 解决方案

### 方案概述

在 Linux 构建时，我们需要：
1. 从 `linux/flutter/generated_plugins.cmake` 中移除该插件
2. 删除插件的符号链接目录，防止 CMake 找到它

### 自动化修复

所有构建脚本已经包含了自动修复步骤：

#### GitHub CI (.github/workflows/build-linux.yml)
```yaml
- name: Fix plugin configuration for Linux
  run: |
    sed -i '/flutter_bluetooth_classic_serial/d' linux/flutter/generated_plugins.cmake
    rm -rf linux/flutter/ephemeral/.plugin_symlinks/flutter_bluetooth_classic_serial
```

#### 本地构建脚本 (scripts/build-linux.sh)
```bash
sed -i '/flutter_bluetooth_classic_serial/d' linux/flutter/generated_plugins.cmake
rm -rf linux/flutter/ephemeral/.plugin_symlinks/flutter_bluetooth_classic_serial
```

#### Docker 构建 (Dockerfile.linux)
```dockerfile
RUN sed -i '/flutter_bluetooth_classic_serial/d' linux/flutter/generated_plugins.cmake && \
    rm -rf linux/flutter/ephemeral/.plugin_symlinks/flutter_bluetooth_classic_serial
```

## 构建方法

### 方法 1: 使用构建脚本（推荐）

```bash
# 在 Linux 系统上
./scripts/build-linux.sh
```

### 方法 2: 使用 Docker

```bash
# 在任何系统上（需要 Docker）
./scripts/docker-build.sh
```

### 方法 3: 手动构建

```bash
# 1. 获取依赖
flutter pub get

# 2. 修复插件配置
sed -i '/flutter_bluetooth_classic_serial/d' linux/flutter/generated_plugins.cmake
rm -rf linux/flutter/ephemeral/.plugin_symlinks/flutter_bluetooth_classic_serial

# 3. 构建
flutter build linux --release
```

## 平台支持说明

### 蓝牙功能

- **Android**: 使用 `flutter_bluetooth_serial` - ✅ 完全支持
- **Windows**: 使用 `flutter_bluetooth_classic_serial` - ✅ 完全支持
- **Linux**: 使用 `flutter_libserialport` - ✅ 串口通信支持

### 为什么 Linux 不需要 flutter_bluetooth_classic_serial？

1. Linux 上主要使用串口通信（`flutter_libserialport`）
2. 该插件的 Linux 实现不完整且有 CMake 错误
3. 代码中已经有平台检查，Linux 不会调用该插件的功能

参考 `lib/services/spp_service.dart`:
```dart
bool _isPlatformSupported() {
  // Android: flutter_bluetooth_serial
  // Windows: flutter_bluetooth_classic_serial
  return Platform.isAndroid || Platform.isWindows;
}
```

## 故障排除

### 问题：构建时仍然报 flutter_bluetooth_classic_serial 错误

**解决方案**：
```bash
# 清理构建缓存
flutter clean

# 重新获取依赖
flutter pub get

# 再次应用修复
sed -i '/flutter_bluetooth_classic_serial/d' linux/flutter/generated_plugins.cmake
rm -rf linux/flutter/ephemeral/.plugin_symlinks/flutter_bluetooth_classic_serial

# 重新构建
flutter build linux --release
```

### 问题：macOS 上无法构建 Linux 版本

**原因**：Flutter 的 Linux 构建只能在 Linux 主机上运行

**解决方案**：
- 使用 Docker: `./scripts/docker-build.sh`
- 使用 Linux 虚拟机
- 使用 GitHub Actions CI

## 相关文件

- `.github/workflows/build-linux.yml` - GitHub CI 配置
- `scripts/build-linux.sh` - Linux 构建脚本
- `Dockerfile.linux` - Docker 构建配置
- `linux/flutter/generated_plugins.cmake` - 插件配置（自动生成）

## 注意事项

⚠️ **重要**：`linux/flutter/generated_plugins.cmake` 是自动生成的文件，每次运行 `flutter pub get` 后都会被重新生成，因此需要在每次构建前重新应用修复。

这就是为什么所有构建脚本都在 `flutter pub get` **之后**、`flutter build` **之前**执行修复步骤。
