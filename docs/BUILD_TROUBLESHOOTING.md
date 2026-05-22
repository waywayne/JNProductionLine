# 构建问题排查指南

## Windows 构建错误

### 问题：Visual Studio 16 2019 找不到

**错误信息**：
```
CMake Error at CMakeLists.txt:3 (project):
  Generator
    Visual Studio 16 2019
  could not find any instance of Visual Studio.
```

**原因**：
- CMake 缓存中保留了旧的 Visual Studio 版本配置
- 系统已升级到 Visual Studio 2022，但缓存仍指向 VS 2019

**解决方法**：

#### 方法1：使用清理脚本（推荐）

**Windows 系统**：
```cmd
clean-build.bat
```

**macOS/Linux 系统**：
```bash
chmod +x clean-build.sh
./clean-build.sh
```

#### 方法2：手动清理

**Windows (PowerShell)**：
```powershell
# 删除构建缓存
Remove-Item -Path "build\windows" -Recurse -Force -ErrorAction SilentlyContinue

# 清理 Flutter 缓存
flutter clean

# 重新构建
flutter build windows --release
```

**macOS/Linux (Bash)**：
```bash
# 删除构建缓存
rm -rf build/windows

# 清理 Flutter 缓存
flutter clean

# 重新构建
flutter build windows --release  # 如果在 Windows 上
flutter build linux --release    # 如果在 Linux 上
```

#### 方法3：指定 CMake 生成器

如果清理后仍有问题，可以尝试指定 CMake 生成器：

```bash
# 设置环境变量指定使用 Visual Studio 2022
$env:CMAKE_GENERATOR="Visual Studio 17 2022"
flutter build windows --release
```

或在 PowerShell 中：
```powershell
$env:CMAKE_GENERATOR="Visual Studio 17 2022"
flutter build windows --release
```

### 验证 Visual Studio 安装

确保已安装 Visual Studio 2022 或 2019，并包含以下组件：
- Desktop development with C++
- Windows 10 SDK

检查安装：
```cmd
# 查找 Visual Studio 安装路径
where devenv

# 或使用 vswhere 工具
"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -latest
```

## Linux 构建错误

### 问题：file_picker 警告

**警告信息**：
```
Package file_picker:linux references file_picker:linux as the default plugin, 
but it does not provide an inline implementation.
```

**说明**：
- 这是一个警告，不是错误
- 不影响构建，可以忽略
- 是 file_picker 插件的已知问题

**如果需要消除警告**：
可以在 `pubspec.yaml` 中固定 file_picker 版本：
```yaml
dependencies:
  file_picker: ^6.1.1  # 使用稳定版本
```

## 常见构建问题

### 1. 依赖问题

**清理并重新获取依赖**：
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### 2. Flutter 版本问题

**检查 Flutter 版本**：
```bash
flutter --version
flutter doctor -v
```

**升级 Flutter**：
```bash
flutter upgrade
```

### 3. 缓存损坏

**清理所有缓存**：
```bash
flutter clean
flutter pub cache repair
rm -rf build/
```

### 4. 权限问题（Linux）

**确保有执行权限**：
```bash
chmod +x clean-build.sh
chmod +x scripts/*.sh
```

## GitHub Actions 构建

如果 GitHub Actions 构建失败，检查：

1. **工作流文件**：`.github/workflows/build-windows.yml` 和 `build-linux.yml`
2. **CMake 缓存清理步骤**：确保在构建前清理缓存
3. **Visual Studio 版本**：使用 `windows-latest` runner（包含 VS 2022）

## 获取帮助

如果以上方法都无法解决问题：

1. 查看完整错误日志
2. 检查 Flutter doctor 输出
3. 确认系统环境配置
4. 查看 Flutter 官方文档：https://docs.flutter.dev/

## 快速参考

| 问题 | 解决方法 |
|------|---------|
| CMake 缓存错误 | 运行 `clean-build.bat` 或 `clean-build.sh` |
| Visual Studio 找不到 | 安装 VS 2022 或设置 CMAKE_GENERATOR |
| 依赖问题 | `flutter clean && flutter pub get` |
| 权限问题 | `chmod +x` 添加执行权限 |
| file_picker 警告 | 可以忽略，不影响构建 |
