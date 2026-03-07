@echo off
REM 查找蓝牙 COM 端口
echo ========================================
echo 查找蓝牙 COM 端口
echo ========================================
echo.

echo 方法 1: 使用 PowerShell 查询
echo ----------------------------------------
powershell -Command "Get-WmiObject Win32_SerialPort | Where-Object {$_.Description -like '*Bluetooth*' -or $_.Description -like '*蓝牙*'} | Format-Table DeviceID, Description, PNPDeviceID -AutoSize"

echo.
echo 方法 2: 查询所有 COM 端口
echo ----------------------------------------
powershell -Command "Get-WmiObject Win32_SerialPort | Format-Table DeviceID, Description -AutoSize"

echo.
echo ========================================
echo 使用说明
echo ========================================
echo.
echo 如果找到蓝牙 COM 端口（如 COM3），可以直接在应用中使用：
echo.
echo 1. 在 Flutter 应用中选择该 COM 端口
echo 2. 点击"连接设备"
echo 3. 无需使用 Python 蓝牙功能
echo.
echo 这种方式比蓝牙 SPP 更可靠！
echo.
pause
