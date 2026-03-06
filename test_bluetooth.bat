@echo off
REM 蓝牙 SPP 快速测试脚本
REM 使用方法: test_bluetooth.bat [设备地址] [可选: Channel]

echo ========================================
echo 蓝牙 SPP 测试工具
echo ========================================
echo.

REM 检查 Python 是否安装
python --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 Python，请先安装 Python 3.7+
    pause
    exit /b 1
)

REM 检查 PyBluez 是否安装
python -c "import bluetooth" >nul 2>&1
if errorlevel 1 (
    echo [错误] 未安装 PyBluez
    echo 正在安装 PyBluez...
    python -m pip install pybluez
    if errorlevel 1 (
        echo [错误] PyBluez 安装失败
        pause
        exit /b 1
    )
)

echo [OK] Python 环境检查通过
echo.

REM 如果没有提供参数，显示帮助
if "%~1"=="" (
    echo 使用方法:
    echo.
    echo 1. 查看已配对设备:
    echo    test_bluetooth.bat paired
    echo.
    echo 2. 扫描蓝牙设备:
    echo    test_bluetooth.bat scan
    echo.
    echo 3. 查找设备服务:
    echo    test_bluetooth.bat services 00:11:22:33:44:55
    echo.
    echo 4. 连接设备 ^(自动查找服务^):
    echo    test_bluetooth.bat connect 00:11:22:33:44:55
    echo.
    echo 5. 连接设备 ^(指定 Channel^):
    echo    test_bluetooth.bat connect 00:11:22:33:44:55 1
    echo.
    echo 6. 测试读取 MAC 地址:
    echo    test_bluetooth.bat test 00:11:22:33:44:55 1
    echo.
    pause
    exit /b 0
)

REM 执行命令
if /i "%~1"=="paired" (
    echo [执行] 查看已配对设备...
    python scripts/bluetooth_spp_test.py --paired
    goto :end
)

if /i "%~1"=="scan" (
    echo [执行] 扫描蓝牙设备...
    python scripts/bluetooth_spp_test.py --scan
    goto :end
)

if /i "%~1"=="services" (
    if "%~2"=="" (
        echo [错误] 请提供设备地址
        echo 示例: test_bluetooth.bat services 00:11:22:33:44:55
        goto :end
    )
    echo [执行] 查找设备 %~2 的服务...
    python scripts/bluetooth_spp_test.py --services %~2 --uuid 00007033-1000-8000-00805f9b34fb
    goto :end
)

if /i "%~1"=="connect" (
    if "%~2"=="" (
        echo [错误] 请提供设备地址
        echo 示例: test_bluetooth.bat connect 00:11:22:33:44:55
        goto :end
    )
    if "%~3"=="" (
        echo [执行] 连接到设备 %~2 ^(自动查找服务^)...
        python scripts/bluetooth_spp_test.py --connect %~2
    ) else (
        echo [执行] 连接到设备 %~2 ^(Channel %~3^)...
        python scripts/bluetooth_spp_test.py --connect %~2 --channel %~3
    )
    goto :end
)

if /i "%~1"=="test" (
    if "%~2"=="" (
        echo [错误] 请提供设备地址
        echo 示例: test_bluetooth.bat test 00:11:22:33:44:55 1
        goto :end
    )
    if "%~3"=="" (
        echo [错误] 请提供 RFCOMM Channel
        echo 示例: test_bluetooth.bat test 00:11:22:33:44:55 1
        goto :end
    )
    echo [执行] 测试设备 %~2 ^(Channel %~3^)...
    python scripts/bluetooth_spp_test.py --connect %~2 --channel %~3 --test mac
    goto :end
)

echo [错误] 未知命令: %~1
echo 使用 test_bluetooth.bat 查看帮助

:end
echo.
echo ========================================
echo 测试完成
echo ========================================
pause
