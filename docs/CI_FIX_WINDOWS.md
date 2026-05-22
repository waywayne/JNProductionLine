# GitHub Actions Windows 构建修复

## 问题描述

GitHub Actions 在构建 Windows 应用时报错：

```
CMake Error at CMakeLists.txt:3 (project):
  Generator
    Visual Studio 16 2019
  could not find any instance of Visual Studio.
```

## 根本原因

1. **CMake 缓存问题**：之前的构建可能在 CMake 缓存中保留了 Visual Studio 16 2019 的配置
2. **生成器未指定**：Flutter 构建时 CMake 自动检测生成器，可能选择了错误的版本
3. **windows-latest 使用 VS 2022**：GitHub 的 `windows-latest` runner 现在默认安装 Visual Studio 2022，而不是 2019

## 解决方案

### 修改内容

在 `.github/workflows/build-windows.yml` 中做了以下修改：

#### 1. 增强清理步骤

```yaml
- name: Clean CMake cache
  shell: pwsh
  run: |
    if (Test-Path "build") {
      Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
      Write-Host "Cleaned build directory"
    }
    flutter clean
    Write-Host "Flutter clean completed"
```

**改进点**：
- ✅ 删除整个 `build` 目录，而不仅仅是 `build/windows`
- ✅ 添加 `flutter clean` 确保彻底清理
- ✅ 使用 `-ErrorAction SilentlyContinue` 避免目录不存在时报错

#### 2. 显式指定 CMake 生成器

```yaml
- name: Build Windows application
  shell: pwsh
  env:
    CMAKE_GENERATOR: "Visual Studio 17 2022"
  run: |
    Write-Host "Building with Visual Studio 17 2022"
    flutter build windows --release
```

**关键点**：
- ✅ 设置环境变量 `CMAKE_GENERATOR="Visual Studio 17 2022"`
- ✅ 强制 CMake 使用 Visual Studio 2022
- ✅ 避免自动检测导致的版本错误

## 为什么这样可以解决问题

### Visual Studio 版本映射

| Visual Studio 版本 | CMake Generator 名称 |
|-------------------|---------------------|
| Visual Studio 2019 | Visual Studio 16 2019 |
| Visual Studio 2022 | Visual Studio 17 2022 |

### windows-latest 环境

GitHub Actions 的 `windows-latest` runner 包含：
- ✅ Visual Studio 2022 (默认)
- ✅ Visual Studio 2019 (可能有，但不是默认)
- ✅ CMake 3.x
- ✅ MSBuild

通过显式指定 `CMAKE_GENERATOR`，我们确保 CMake 使用正确的生成器。

## 验证构建成功

构建成功的标志：

```
Building Windows application... ✓
```

输出文件位于：
```
build/windows/x64/runner/Release/
```

## 其他相关修改

### 保留的配置

```yaml
- name: Setup Visual Studio environment
  uses: microsoft/setup-msbuild@v2
```

这一步确保 MSBuild 工具在 PATH 中可用。

### 构建流程

完整的构建流程：
1. Checkout 代码
2. 设置 Visual Studio 环境
3. 设置 Flutter
4. 设置 Python（用于 GPIB 依赖）
5. 安装 Python 依赖
6. 运行 Flutter doctor
7. 获取 Flutter 依赖
8. **清理构建缓存** ← 新增
9. **构建应用（指定 VS 2022）** ← 修改
10. 打包应用
11. 上传 artifact
12. 创建 Release（如果是 tag）

## 本地测试（可选）

如果需要在本地 Windows 机器上测试：

```powershell
# 清理缓存
Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
flutter clean

# 设置生成器并构建
$env:CMAKE_GENERATOR="Visual Studio 17 2022"
flutter build windows --release
```

## 常见问题

### Q: 为什么不直接升级到 VS 2022？
A: GitHub Actions 的 `windows-latest` 已经包含 VS 2022，问题是 CMake 缓存导致它仍然尝试使用 VS 2019。

### Q: 能否使用 VS 2019？
A: 可以，但需要确保 runner 上安装了 VS 2019，并且设置 `CMAKE_GENERATOR="Visual Studio 16 2019"`。

### Q: Linux 构建会受影响吗？
A: 不会，这个修改只影响 Windows 构建。Linux 使用不同的构建系统（Ninja + GCC/Clang）。

## 参考文档

- [CMake Generators](https://cmake.org/cmake/help/latest/manual/cmake-generators.7.html)
- [GitHub Actions Windows Runners](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners#supported-runners-and-hardware-resources)
- [Flutter Desktop Support](https://docs.flutter.dev/desktop)

## 更新日志

- **2026-05-22**: 修复 Windows 构建 CMake 生成器问题
  - 增强清理步骤
  - 显式指定 Visual Studio 17 2022
  - 添加构建日志输出
