@echo off
REM 安装 Visual C++ Redistributable 运行时库

echo ========================================
echo Visual C++ Redistributable 安装工具
echo ========================================
echo.
echo 本程序需要 Visual C++ 2015-2022 Redistributable (x64)
echo.
echo 正在下载安装程序...
echo.

REM 创建临时目录
set TEMP_DIR=%TEMP%\vc_redist_install
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

REM 下载 VC++ Redistributable
set VC_REDIST_URL=https://aka.ms/vs/17/release/vc_redist.x64.exe
set VC_REDIST_FILE=%TEMP_DIR%\vc_redist.x64.exe

echo 下载地址: %VC_REDIST_URL%
echo 保存到: %VC_REDIST_FILE%
echo.

REM 使用 PowerShell 下载
powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%VC_REDIST_URL%' -OutFile '%VC_REDIST_FILE%'}"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] 下载失败！
    echo.
    echo 请手动下载并安装：
    echo %VC_REDIST_URL%
    echo.
    pause
    exit /b 1
)

echo.
echo [OK] 下载完成
echo.
echo 正在安装...
echo （可能需要管理员权限）
echo.

REM 静默安装
"%VC_REDIST_FILE%" /install /quiet /norestart

if %ERRORLEVEL%==0 (
    echo.
    echo ========================================
    echo [成功] Visual C++ Redistributable 已安装
    echo ========================================
    echo.
    echo 现在可以运行 jn_production_line.exe 了
    echo.
) else (
    echo.
    echo [WARNING] 安装可能需要管理员权限
    echo.
    echo 请尝试：
    echo 1. 右键点击本脚本
    echo 2. 选择"以管理员身份运行"
    echo.
    echo 或手动运行: %VC_REDIST_FILE%
    echo.
)

REM 清理
timeout /t 3 >nul
if exist "%VC_REDIST_FILE%" del "%VC_REDIST_FILE%"

pause
