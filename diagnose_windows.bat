@echo off
REM Windows 应用诊断脚本 - 检查为什么程序无法启动

echo ========================================
echo JN Production Line - Windows 诊断工具
echo ========================================
echo.

REM 检查当前目录
echo [1] 检查当前目录...
cd
echo.

REM 检查必要文件
echo [2] 检查必要文件...
set MISSING=0

if exist "jn_production_line.exe" (
    echo [OK] jn_production_line.exe 存在
    for %%A in (jn_production_line.exe) do echo     大小: %%~zA 字节
) else (
    echo [ERROR] jn_production_line.exe 不存在！
    set MISSING=1
)

if exist "flutter_windows.dll" (
    echo [OK] flutter_windows.dll 存在
    for %%A in (flutter_windows.dll) do echo     大小: %%~zA 字节
) else (
    echo [ERROR] flutter_windows.dll 不存在！
    set MISSING=1
)

if exist "data" (
    echo [OK] data 目录存在
) else (
    echo [ERROR] data 目录不存在！
    set MISSING=1
)

if exist "data\icudtl.dat" (
    echo [OK] data\icudtl.dat 存在
) else (
    echo [WARNING] data\icudtl.dat 不存在
)

if exist "data\flutter_assets" (
    echo [OK] data\flutter_assets 目录存在
) else (
    echo [WARNING] data\flutter_assets 目录不存在
)

echo.

if %MISSING%==1 (
    echo [ERROR] 缺少必要文件！请重新解压完整的 ZIP 包。
    echo.
    pause
    exit /b 1
)

REM 检查 Visual C++ 运行时
echo [3] 检查 Visual C++ 运行时库...
set VC_MISSING=0

where vcruntime140.dll >nul 2>&1
if %ERRORLEVEL%==0 (
    echo [OK] vcruntime140.dll 已安装
) else (
    echo [ERROR] vcruntime140.dll 未找到
    set VC_MISSING=1
)

where msvcp140.dll >nul 2>&1
if %ERRORLEVEL%==0 (
    echo [OK] msvcp140.dll 已安装
) else (
    echo [ERROR] msvcp140.dll 未找到
    set VC_MISSING=1
)

echo.

if %VC_MISSING%==1 (
    echo ========================================
    echo [重要] 缺少 Visual C++ 运行时库！
    echo ========================================
    echo.
    echo 这是程序无法启动的最常见原因。
    echo.
    echo 解决方法：
    echo 1. 下载并安装 Visual C++ Redistributable
    echo    下载地址: https://aka.ms/vs/17/release/vc_redist.x64.exe
    echo.
    echo 2. 或者运行本目录中的 install_vc_redist.bat
    echo.
    pause
    exit /b 1
)

REM 检查系统架构
echo [4] 检查系统架构...
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    echo [OK] 64位系统
) else (
    echo [WARNING] 非64位系统，本程序需要64位 Windows
)
echo.

REM 尝试运行程序并捕获错误
echo [5] 尝试启动程序...
echo.
echo 正在启动 jn_production_line.exe...
echo 如果程序没有启动，请查看下方的错误信息。
echo.

start "" "jn_production_line.exe" 2>&1

timeout /t 3 >nul

REM 检查进程是否在运行
tasklist /FI "IMAGENAME eq jn_production_line.exe" 2>NUL | find /I /N "jn_production_line.exe">NUL
if %ERRORLEVEL%==0 (
    echo [OK] 程序已成功启动！
) else (
    echo [ERROR] 程序未能启动
    echo.
    echo 可能的原因：
    echo 1. 缺少 Visual C++ 运行时库（最常见）
    echo 2. 缺少必要的 DLL 文件
    echo 3. 防病毒软件阻止
    echo 4. Windows Defender SmartScreen 阻止
    echo.
    echo 请尝试：
    echo 1. 右键点击 jn_production_line.exe
    echo 2. 选择"属性"
    echo 3. 如果看到"解除锁定"按钮，点击它
    echo 4. 安装 Visual C++ Redistributable
)

echo.
echo ========================================
echo 诊断完成
echo ========================================
pause
