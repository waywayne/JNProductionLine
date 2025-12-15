# Windows 应用打包脚本
# 用法: .\scripts\package_windows.ps1

# 设置错误时停止
$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "JN Production Line - Windows 打包工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 读取版本号
Write-Host "[1/6] 读取版本信息..." -ForegroundColor Yellow
$pubspecPath = "pubspec.yaml"
if (-not (Test-Path $pubspecPath)) {
    Write-Host "错误: 未找到 pubspec.yaml 文件" -ForegroundColor Red
    exit 1
}

$versionLine = Get-Content $pubspecPath | Select-String -Pattern 'version:\s*(.+)'
if ($versionLine) {
    $version = $versionLine.Matches.Groups[1].Value.Trim()
    Write-Host "   版本号: $version" -ForegroundColor Green
} else {
    Write-Host "错误: 无法读取版本号" -ForegroundColor Red
    exit 1
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$zipName = "jn_production_line_windows_v${version}_${timestamp}.zip"

# 检查构建产物
Write-Host "[2/6] 检查构建产物..." -ForegroundColor Yellow
$releaseDir = "build/windows/runner/Release"
if (-not (Test-Path $releaseDir)) {
    Write-Host "错误: 未找到构建产物" -ForegroundColor Red
    Write-Host "请先运行: flutter build windows --release" -ForegroundColor Yellow
    exit 1
}
Write-Host "   ✓ 构建产物已找到" -ForegroundColor Green

# 创建临时打包目录
Write-Host "[3/6] 准备打包目录..." -ForegroundColor Yellow
$packageDir = "package_temp"
if (Test-Path $packageDir) {
    Remove-Item -Recurse -Force $packageDir
}
New-Item -ItemType Directory -Force -Path $packageDir | Out-Null
Write-Host "   ✓ 临时目录已创建" -ForegroundColor Green

# 复制文件
Write-Host "[4/6] 复制文件..." -ForegroundColor Yellow

# 复制主程序和依赖
Write-Host "   - 复制主程序..." -ForegroundColor Gray
Copy-Item -Path "$releaseDir/*" -Destination "$packageDir/" -Recurse

# 复制文档
Write-Host "   - 复制文档..." -ForegroundColor Gray
$docs = @(
    "README.md",
    "README_GPIB.md",
    "GPIB_SETUP_WINDOWS.md",
    "GPIB_IMPLEMENTATION_SUMMARY.md",
    "CI_CD_SETUP.md"
)
foreach ($doc in $docs) {
    if (Test-Path $doc) {
        Copy-Item -Path $doc -Destination "$packageDir/" -ErrorAction SilentlyContinue
    }
}

# 复制安装脚本
Write-Host "   - 复制安装脚本..." -ForegroundColor Gray
if (Test-Path "install_gpib_dependencies.bat") {
    Copy-Item -Path "install_gpib_dependencies.bat" -Destination "$packageDir/"
}

# 创建使用说明
Write-Host "   - 生成使用说明..." -ForegroundColor Gray
$buildTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$readmeContent = @"
╔════════════════════════════════════════════════════════════════╗
║          JN Production Line - Windows 版本                     ║
╚════════════════════════════════════════════════════════════════╝

版本: $version
构建时间: $buildTime

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 运行要求

  ✓ Windows 10/11 (64位)
  ✓ 无需安装 Flutter SDK
  ✓ 无需安装 Visual Studio

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔌 GPIB 功能要求（可选）

如需使用 GPIB 电流采集功能，请完成以下步骤:

  1. 安装 Python 3.8 或更高版本
     下载: https://www.python.org/downloads/

  2. 运行 install_gpib_dependencies.bat 安装 Python 依赖

  3. 安装 GPIB 驱动
     - NI GPIB-USB-HS: 下载 NI-488.2 Driver
     - Keysight 82357B: 下载 IO Libraries Suite

详细说明请参考:
  • GPIB_SETUP_WINDOWS.md - 详细安装指南
  • README_GPIB.md - 功能说明和使用手册

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🚀 快速开始

  1. 双击 jn_production_line.exe 启动应用

  2. 连接串口设备进行测试
     - 在界面上选择串口
     - 配置波特率和参数
     - 开始测试

  3. 使用 GPIB 功能（可选）
     - 点击菜单栏 "GPIB Test"
     - 输入 GPIB 地址（如 GPIB0::10::INSTR）
     - 连接设备并开始采集

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 文件说明

  jn_production_line.exe          主程序
  flutter_windows.dll              Flutter 运行时库
  data/                            应用资源文件
  README.md                        项目说明
  README_GPIB.md                   GPIB 功能说明
  GPIB_SETUP_WINDOWS.md            GPIB 安装指南
  install_gpib_dependencies.bat    Python 依赖安装脚本
  使用说明.txt                     本文件

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

❓ 常见问题

Q: 双击程序无反应？
A: 检查是否被杀毒软件拦截，添加到白名单。

Q: 找不到串口设备？
A: 确保设备已连接，并安装了正确的驱动程序。

Q: GPIB 连接失败？
A: 1. 检查 Python 是否安装
   2. 运行 install_gpib_dependencies.bat
   3. 检查 GPIB 驱动是否安装
   4. 确认 GPIB 地址正确

Q: 如何导出日志？
A: 在日志控制台点击 "Export" 按钮。

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🐛 问题反馈

如遇到问题，请提供以下信息:
  • Windows 版本
  • 应用版本: $version
  • 错误截图
  • 日志文件（通过 Export 导出）

提交 Issue:
  Gitee: https://gitee.com/your-repo/JNProductionLine/issues
  GitHub: https://github.com/your-repo/JNProductionLine/issues

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

© 2025 JN Production Line. All rights reserved.
"@

Set-Content -Path "$packageDir/使用说明.txt" -Value $readmeContent -Encoding UTF8
Write-Host "   ✓ 文件复制完成" -ForegroundColor Green

# 打包
Write-Host "[5/6] 创建 ZIP 包..." -ForegroundColor Yellow
Compress-Archive -Path "$packageDir/*" -DestinationPath $zipName -Force
Write-Host "   ✓ ZIP 包已创建" -ForegroundColor Green

# 清理
Write-Host "[6/6] 清理临时文件..." -ForegroundColor Yellow
Remove-Item -Recurse -Force $packageDir
Write-Host "   ✓ 清理完成" -ForegroundColor Green

# 显示结果
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✓ 打包完成!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
$zipSize = (Get-Item $zipName).Length / 1MB
Write-Host "文件名: $zipName" -ForegroundColor White
Write-Host "文件大小: $([math]::Round($zipSize, 2)) MB" -ForegroundColor White
Write-Host "保存位置: $(Get-Location)\$zipName" -ForegroundColor White
Write-Host ""
Write-Host "下一步:" -ForegroundColor Yellow
Write-Host "  1. 在 Windows 上测试 ZIP 包" -ForegroundColor Gray
Write-Host "  2. 上传到 Gitee/GitHub Release" -ForegroundColor Gray
Write-Host "  3. 通知用户下载" -ForegroundColor Gray
Write-Host ""
