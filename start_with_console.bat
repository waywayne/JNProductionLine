@echo off
REM 带控制台启动 - 用于查看错误信息

echo ========================================
echo JN Production Line - 控制台模式启动
echo ========================================
echo.
echo 此模式会保持控制台窗口打开，
echo 可以查看程序的错误信息和日志。
echo.
echo 正在启动...
echo.

REM 检查文件是否存在
if not exist "jn_production_line.exe" (
    echo [ERROR] jn_production_line.exe 不存在！
    echo.
    echo 请确保在正确的目录中运行此脚本。
    echo.
    pause
    exit /b 1
)

REM 启动程序并保持控制台
jn_production_line.exe

REM 如果程序退出，显示退出代码
echo.
echo ========================================
echo 程序已退出
echo 退出代码: %ERRORLEVEL%
echo ========================================
echo.

if %ERRORLEVEL% == 1 (
    echo [ERROR] 程序异常退出（退出代码 1）
    echo.
    echo 最常见原因：
    echo 1. 缺少 data\icudtl.dat 文件
    echo    → 检查 data 目录是否存在
    echo    → 确保 icudtl.dat 在 data\ 目录内
    echo.
    echo 2. icudtl.dat 在错误的位置
    echo    → 不能在根目录，必须在 data\ 目录
    echo.
    echo 3. data\flutter_assets 目录缺失
    echo    → 重新解压完整的 ZIP 包
    echo.
    echo 建议：运行 debug_start.bat 获取详细诊断
    echo.
) else if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] 程序异常退出（退出代码 %ERRORLEVEL%）
    echo.
    echo 可能的原因：
    echo 1. 缺少 Visual C++ 运行时库
    echo    解决：运行 install_vc_redist.bat
    echo.
    echo 2. 缺少必要的 DLL 文件
    echo    解决：运行 diagnose_exe.bat 检查
    echo.
    echo 3. 文件损坏或不完整
    echo    解决：重新下载完整的 ZIP 包
    echo.
) else (
    echo [OK] 程序正常退出
)

pause
