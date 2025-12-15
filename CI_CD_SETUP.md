# CI/CD 自动构建配置说明

## 概述

本项目配置了自动化构建流程，可在 Gitee 或 GitHub 上自动构建 Windows 版本。

## 配置文件

### 1. GitHub Actions（推荐）

**文件**: `.github/workflows/build-windows.yml`

**功能**:
- ✅ 自动构建 Windows Release 版本
- ✅ 自动打包为 ZIP 文件
- ✅ 包含 GPIB 相关文档和安装脚本
- ✅ 保存构建产物 90 天
- ✅ 支持 Tag 自动发布 Release

**触发条件**:
- Push 到 `main` 或 `master` 分支
- 创建 Tag（如 `v1.0.3`）
- Pull Request
- 手动触发

### 2. Gitee Go CI/CD

**文件**: `.workflow/build-windows.yml`

**说明**: Gitee 原生 CI/CD 配置（如果 Gitee 支持）

### 3. 通用 CI 配置

**文件**: `.gitee-ci.yml`

**说明**: 通用 CI 配置，兼容多个平台

## 使用方法

### 在 GitHub 上使用

1. **推送代码到 GitHub**:
   ```bash
   git remote add github https://github.com/your-username/JNProductionLine.git
   git push github main
   ```

2. **查看构建状态**:
   - 访问仓库的 "Actions" 标签页
   - 查看 "Build Windows Release" 工作流

3. **下载构建产物**:
   - 在 Actions 页面点击具体的运行记录
   - 在 "Artifacts" 部分下载 `windows-release`

4. **创建 Release**:
   ```bash
   git tag v1.0.3
   git push github v1.0.3
   ```
   - 自动创建 Release 并附加 ZIP 文件

### 在 Gitee 上使用

#### 方案 A: 使用 Gitee Go（如果支持）

1. **启用 Gitee Go**:
   - 进入仓库设置
   - 找到 "Gitee Go" 或 "流水线" 选项
   - 启用 CI/CD 功能

2. **配置流水线**:
   - Gitee 会自动检测 `.workflow/build-windows.yml`
   - 或手动导入配置文件

3. **触发构建**:
   - Push 代码到 `master` 分支
   - 在 Gitee Go 页面查看构建状态

#### 方案 B: 使用 Gitee Actions（导入 GitHub Actions）

1. **启用 Gitee Actions**:
   - 进入仓库设置
   - 找到 "Actions" 选项
   - 启用功能

2. **导入配置**:
   - Gitee 会自动识别 `.github/workflows/` 目录
   - 或手动配置

#### 方案 C: 本地构建 + 手动上传（推荐）

如果 Gitee 不支持 Windows 构建环境：

1. **在 Windows 电脑上构建**:
   ```bash
   flutter build windows --release
   ```

2. **打包**:
   ```powershell
   # 使用提供的脚本
   .\scripts\package_windows.ps1
   ```

3. **上传到 Gitee Release**:
   - 在 Gitee 仓库创建 Release
   - 手动上传 ZIP 文件

## 构建产物说明

### 文件命名格式

```
jn_production_line_windows_v{version}_{timestamp}.zip
```

示例:
```
jn_production_line_windows_v1.0.2_20251215_173000.zip
```

### ZIP 包内容

```
jn_production_line_windows_v1.0.2.zip
├── jn_production_line.exe          # 主程序
├── flutter_windows.dll              # Flutter 运行时
├── data/                            # 资源文件
│   ├── icudtl.dat
│   └── flutter_assets/
├── README.md                        # 项目说明
├── README_GPIB.md                   # GPIB 功能说明
├── GPIB_SETUP_WINDOWS.md            # GPIB 安装指南
└── install_gpib_dependencies.bat    # Python 依赖安装脚本
```

## 手动打包脚本

为方便本地打包，提供了 PowerShell 脚本。

### 创建打包脚本

文件: `scripts/package_windows.ps1`

```powershell
# 读取版本号
$version = (Get-Content pubspec.yaml | Select-String -Pattern 'version:\s*(.+)').Matches.Groups[1].Value
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$zipName = "jn_production_line_windows_v${version}_${timestamp}.zip"

Write-Host "开始打包 Windows 应用..."
Write-Host "版本: $version"

# 检查构建产物
if (-not (Test-Path "build/windows/runner/Release")) {
    Write-Host "错误: 未找到构建产物，请先运行 'flutter build windows --release'"
    exit 1
}

# 创建临时打包目录
$packageDir = "package_temp"
if (Test-Path $packageDir) {
    Remove-Item -Recurse -Force $packageDir
}
New-Item -ItemType Directory -Force -Path $packageDir | Out-Null

# 复制文件
Write-Host "复制文件..."
Copy-Item -Path "build/windows/runner/Release/*" -Destination "$packageDir/" -Recurse
Copy-Item -Path "README*.md" -Destination "$packageDir/" -ErrorAction SilentlyContinue
Copy-Item -Path "GPIB*.md" -Destination "$packageDir/" -ErrorAction SilentlyContinue
Copy-Item -Path "install_gpib_dependencies.bat" -Destination "$packageDir/" -ErrorAction SilentlyContinue

# 创建使用说明
$readmeContent = @"
# JN Production Line - Windows 版本

版本: $version
构建时间: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## 运行要求

- Windows 10/11 (64位)
- 无需安装 Flutter SDK

## GPIB 功能要求

如需使用 GPIB 电流采集功能:
1. 安装 Python 3.8+
2. 运行 install_gpib_dependencies.bat 安装依赖
3. 安装 GPIB 驱动（NI-VISA 或 Keysight IO Libraries）

详细说明请参考:
- GPIB_SETUP_WINDOWS.md - 安装指南
- README_GPIB.md - 功能说明

## 快速开始

1. 双击 jn_production_line.exe 启动应用
2. 连接串口设备进行测试
3. 如需 GPIB 功能，点击菜单栏 "GPIB Test"

## 问题反馈

如遇到问题，请提供:
- Windows 版本
- 错误截图
- 日志文件
"@

Set-Content -Path "$packageDir/使用说明.txt" -Value $readmeContent -Encoding UTF8

# 打包
Write-Host "创建 ZIP 包..."
Compress-Archive -Path "$packageDir/*" -DestinationPath $zipName -Force

# 清理
Remove-Item -Recurse -Force $packageDir

# 显示结果
$zipSize = (Get-Item $zipName).Length / 1MB
Write-Host "✓ 打包完成!"
Write-Host "文件: $zipName"
Write-Host "大小: $([math]::Round($zipSize, 2)) MB"
```

### 使用打包脚本

```powershell
# 1. 构建
flutter build windows --release

# 2. 打包
.\scripts\package_windows.ps1
```

## 环境变量配置

如果需要在 CI/CD 中使用敏感信息（如 API Key），可配置环境变量：

### GitHub Secrets

1. 进入仓库 Settings → Secrets and variables → Actions
2. 添加 Secret:
   - `GPIB_LICENSE_KEY` (如果需要)
   - `SIGNING_KEY` (代码签名密钥)

### 在工作流中使用

```yaml
- name: Build with secrets
  env:
    GPIB_LICENSE_KEY: ${{ secrets.GPIB_LICENSE_KEY }}
  run: flutter build windows --release
```

## 构建优化

### 加速构建

1. **启用缓存**:
   ```yaml
   - uses: subosito/flutter-action@v2
     with:
       cache: true
   ```

2. **并行构建**（如果有多个平台）:
   ```yaml
   strategy:
     matrix:
       os: [windows-latest, macos-latest]
   ```

### 减小包体积

1. **启用混淆**:
   ```bash
   flutter build windows --release --obfuscate --split-debug-info=./debug-info
   ```

2. **压缩资源**:
   - 优化图片资源
   - 移除未使用的依赖

## 故障排查

### 构建失败

1. **检查 Flutter 版本**:
   - 确保 CI 环境的 Flutter 版本与本地一致

2. **检查依赖**:
   ```bash
   flutter pub get
   flutter doctor -v
   ```

3. **查看日志**:
   - 在 Actions 页面查看详细日志
   - 检查每个步骤的输出

### Python 依赖问题

如果 Python 依赖安装失败:

```yaml
- name: Install Python dependencies with retry
  run: |
    for i in {1..3}; do
      pip install pyvisa pyvisa-py pandas openpyxl && break
      sleep 5
    done
```

## 最佳实践

1. **版本管理**:
   - 使用语义化版本号（如 v1.0.3）
   - 每次发布前更新 `pubspec.yaml` 中的版本号

2. **Tag 命名**:
   ```bash
   git tag -a v1.0.3 -m "Release version 1.0.3 with GPIB support"
   git push origin v1.0.3
   ```

3. **Release Notes**:
   - 在 Tag 描述中说明更新内容
   - GitHub 可自动生成 Release Notes

4. **测试**:
   - 下载构建产物后在 Windows 上测试
   - 验证 GPIB 功能是否正常

## 参考资料

- [GitHub Actions 文档](https://docs.github.com/actions)
- [Gitee Go 文档](https://gitee.com/help/articles/4378)
- [Flutter CI/CD 最佳实践](https://docs.flutter.dev/deployment/cd)

## 更新日志

- 2025-12-15: 初始 CI/CD 配置
  - 添加 Windows 自动构建
  - 配置 GitHub Actions
  - 添加 Gitee Go 支持
