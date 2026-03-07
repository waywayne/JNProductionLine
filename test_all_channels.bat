@echo off
REM 测试所有 RFCOMM Channel
echo ========================================
echo 测试所有蓝牙 RFCOMM Channel
echo ========================================
echo.

if "%~1"=="" (
    echo 使用方法: test_all_channels.bat [设备地址]
    echo 示例: test_all_channels.bat 48:08:EB:60:00:00
    echo.
    pause
    exit /b 1
)

set DEVICE_ADDR=%~1

echo 设备地址: %DEVICE_ADDR%
echo.
echo 正在测试 Channel 1-30...
echo 这可能需要几分钟时间，请耐心等待...
echo.

python scripts/test_all_channels.py %DEVICE_ADDR%

echo.
pause
