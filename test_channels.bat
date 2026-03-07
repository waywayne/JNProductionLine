@echo off
REM 测试不同的 RFCOMM Channel
echo ========================================
echo 测试蓝牙 RFCOMM Channel
echo ========================================
echo.

if "%~1"=="" (
    echo 使用方法: test_channels.bat [设备地址]
    echo 示例: test_channels.bat 48:08:EB:60:00:00
    pause
    exit /b 1
)

set DEVICE_ADDR=%~1

echo 设备地址: %DEVICE_ADDR%
echo.
echo 正在测试 Channel 1-10...
echo.

for /L %%i in (1,1,10) do (
    echo ----------------------------------------
    echo 测试 Channel %%i
    echo ----------------------------------------
    python scripts/bluetooth_spp_test.py --connect %DEVICE_ADDR% --channel %%i
    if errorlevel 0 (
        echo.
        echo ✅ Channel %%i 可以连接！
        echo.
        pause
        exit /b 0
    )
    echo.
)

echo.
echo ========================================
echo 所有 Channel (1-10) 都无法连接
echo ========================================
echo.
echo 建议:
echo 1. 确认设备已开启且在范围内
echo 2. 使用以下命令查找正确的 Channel:
echo    python scripts/bluetooth_spp_test.py --services %DEVICE_ADDR%
echo 3. 检查设备是否被其他程序占用
echo.
pause
