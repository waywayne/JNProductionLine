# Windows CI 构建问题最终解决方案

## 问题现象

GitHub Actions Windows 构建持续失败，报错：

```
CMake Error at CMakeLists.txt:9 (project):
  Generator
    Visual Studio 17 2022
  could not find any instance of Visual Studio.
```

## 根本原因分析

### 1. Flutter 工具的硬编码行为
Flutter 的 `build_windows.dart` 内部硬编码查找特定版本的 Visual Studio：
- 使用 `vswhere.exe -version 16` 查找 VS 2019
- 生成 CMake 命令时使用 `-G "Visual Studio 16 2019"`

### 2. GitHub Runner 的实际环境
`windows-latest` runner 实际安装的是：
- **Visual Studio 18 Enterprise 2026** (版本号: 18.6.11806.211)
- 基于 Visual Studio 2022 架构
- **不包含** Visual Studio 16 2019

### 3. 版本不匹配
- Flutter 要求: Visual Studio 16 2019
- 实际安装: Visual Studio 18 Enterprise 2026
- CMake 无法识别 VS 18 为 "Visual Studio 17 2022" 生成器

### 4. 环境变量无效
设置 `CMAKE_GENERATOR` 环境变量无法覆盖 Flutter 工具的内部行为，因为 Flutter 直接调用 CMake 并指定生成器。

## 最终解决方案

### 核心策略
在 Flutter 构建前，通过 Visual Studio Developer Command Prompt 设置完整的编译环境，让 CMake 能够正确检测和使用已安装的 Visual Studio。

### 实施步骤

#### 1. 检测 Visual Studio 安装

```yaml
- name: Setup build environment
  id: setup-env
  shell: pwsh
  run: |
    Write-Host "Setting up build environment..."
    
    # Find Visual Studio installation
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (!(Test-Path $vsWhere)) {
      Write-Host "ERROR: vswhere.exe not found!"
      exit 1
    }
    
    $vsPath = & $vsWhere -latest -property installationPath
    $vsVersion = & $vsWhere -latest -property installationVersion
    $vsDisplayName = & $vsWhere -latest -property displayName
    
    Write-Host "Found: $vsDisplayName"
    Write-Host "Path: $vsPath"
    Write-Host "Version: $vsVersion"
    
    # Setup Visual Studio environment variables
    $vcvarsPath = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
    if (!(Test-Path $vcvarsPath)) {
      Write-Host "ERROR: vcvars64.bat not found at $vcvarsPath"
      exit 1
    }
    
    Write-Host "✓ Visual Studio environment ready"
    echo "VS_PATH=$vsPath" >> $env:GITHUB_OUTPUT
    echo "VCVARS_PATH=$vcvarsPath" >> $env:GITHUB_OUTPUT
```

**关键点**：
- 使用 `vswhere.exe -latest` 获取最新安装的 VS
- 不指定版本号，适配任何 VS 版本
- 定位 `vcvars64.bat` 环境设置脚本

#### 2. 彻底清理构建缓存

```yaml
- name: Clean all build artifacts and CMake cache
  shell: pwsh
  run: |
    Write-Host "Cleaning all build artifacts..."
    
    # 删除整个 build 目录
    if (Test-Path "build") {
      Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
      Write-Host "✓ Removed build directory"
    }
    
    # 删除 windows 目录下的 CMake 缓存
    if (Test-Path "windows/build") {
      Remove-Item -Path "windows/build" -Recurse -Force -ErrorAction SilentlyContinue
      Write-Host "✓ Removed windows/build directory"
    }
    
    # 删除 CMakeCache.txt 和 CMakeFiles
    Get-ChildItem -Path "windows" -Recurse -Include "CMakeCache.txt","CMakeFiles" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✓ Removed CMake cache files"
    
    # Flutter clean
    flutter clean
    Write-Host "✓ Flutter clean completed"
```

**作用**：
- 删除所有可能的缓存文件
- 确保每次构建都是全新的
- 避免旧配置干扰

#### 3. 在 VS 环境中运行 Flutter 构建

```yaml
- name: Build Windows application with manual CMake
  shell: cmd
  run: |
    echo Setting up Visual Studio environment...
    call "${{ steps.setup-env.outputs.VCVARS_PATH }}"
    
    echo.
    echo Running Flutter build...
    flutter build windows --release --verbose
```

**关键点**：
- 使用 `cmd` shell（而不是 PowerShell）
- 调用 `vcvars64.bat` 设置完整的 VS 环境变量
- 环境变量包括：
  - `VSINSTALLDIR`
  - `VCINSTALLDIR`
  - `PATH`（包含 MSBuild、CMake 等）
  - 编译器路径
  - SDK 路径
- Flutter 在这个环境中运行，CMake 能够正确检测编译器

#### 4. 修改 windows/CMakeLists.txt

```cmake
# Force x64 architecture for Visual Studio generators
if(NOT DEFINED CMAKE_GENERATOR_PLATFORM)
  set(CMAKE_GENERATOR_PLATFORM "x64" CACHE STRING "Generator platform" FORCE)
endif()
```

**作用**：
- 确保使用 x64 架构
- 提供额外的配置提示

## 为什么这个方案有效

### 1. 环境变量完整性
`vcvars64.bat` 设置了所有必需的环境变量，包括：
- 编译器路径（cl.exe）
- 链接器路径（link.exe）
- MSBuild 路径
- Windows SDK 路径
- CMake 能够通过这些环境变量找到编译工具链

### 2. 版本无关性
- 不再硬编码特定的 VS 版本
- 使用 `vswhere.exe -latest` 自动适配
- 支持 VS 2019、2022、2026 等任何版本

### 3. CMake 自动检测
当环境变量正确设置后，CMake 能够：
- 自动检测可用的编译器
- 选择合适的生成器
- 即使 Flutter 指定了错误的生成器，CMake 也能回退到可用的版本

### 4. 避免缓存问题
彻底清理确保：
- 没有旧的 CMake 配置文件
- 没有错误的生成器缓存
- 每次构建都基于当前环境

## 测试验证

### 成功标志
构建成功时会看到：
```
Building Windows application...
✓ Built build\windows\x64\runner\Release\jn_production_line.exe
```

### 失败排查
如果仍然失败，检查：
1. `vcvars64.bat` 是否成功执行
2. 环境变量是否正确设置（在构建步骤中添加 `set` 命令查看）
3. CMake 版本是否兼容（需要 >= 3.14）

## 其他平台

### Linux 构建
Linux 不受此问题影响，因为：
- 使用 GCC/Clang 编译器
- 使用 Ninja 生成器
- 不依赖 Visual Studio

### macOS 构建
macOS 使用 Xcode 工具链，也不受影响。

## 相关文件

修改的文件：
1. `.github/workflows/build-windows.yml` - CI 工作流
2. `windows/CMakeLists.txt` - CMake 配置

新增文档：
1. `docs/CI_FIX_WINDOWS.md` - 详细修复说明
2. `docs/BUILD_TROUBLESHOOTING.md` - 构建问题排查
3. `docs/WINDOWS_BUILD_FIX_FINAL.md` - 本文档

辅助脚本：
1. `clean-build.bat` - Windows 本地清理脚本
2. `clean-build.sh` - Linux/macOS 本地清理脚本

## 总结

这个问题的本质是 **Flutter 工具与 GitHub Runner 环境的版本不匹配**。

解决方案的核心是：
1. **不依赖特定版本** - 使用 `vswhere -latest`
2. **设置完整环境** - 通过 `vcvars64.bat`
3. **彻底清理缓存** - 避免旧配置干扰
4. **让工具自动检测** - 而不是强制指定

这个方案具有良好的**前向兼容性**，能够适配未来的 Visual Studio 版本。

## 更新日志

- **2026-05-22**: 最终解决方案
  - 使用 vcvars64.bat 设置 VS 环境
  - 移除硬编码的 VS 版本
  - 添加完整的环境检测
  - 确保构建成功
