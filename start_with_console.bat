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

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] 程序异常退出
    echo.
    echo 可能的原因：
    echo 1. 缺少 Visual C++ 运行时库
    echo    解决：运行 install_vc_redist.bat
    echo.
    echo 2. 缺少必要的 DLL 文件
    echo    解决：运行 diagnose_windows.bat 检查
    echo.
    echo 3. 配置文件错误
    echo    解决：删除配置文件重新启动
    echo.
) else (
    echo [OK] 程序正常退出
)

pause
