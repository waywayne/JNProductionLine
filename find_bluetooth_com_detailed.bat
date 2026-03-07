@echo off
REM 详细查找蓝牙 COM 口信息
echo ========================================
echo 查找蓝牙 COM 口（详细信息）
echo ========================================
echo.

echo 方法 1: 使用 PowerShell 查询蓝牙串口设备
echo ----------------------------------------
powershell -Command "Get-PnpDevice -Class Ports | Where-Object {$_.FriendlyName -like '*Bluetooth*' -or $_.FriendlyName -like '*蓝牙*'} | Format-Table FriendlyName, Status, InstanceId -AutoSize"

echo.
echo 方法 2: 查询所有 COM 口及其描述
echo ----------------------------------------
powershell -Command "Get-WmiObject Win32_SerialPort | Format-Table DeviceID, Description, PNPDeviceID -AutoSize"

echo.
echo 方法 3: 使用 WMI 查询蓝牙相关串口
echo ----------------------------------------
powershell -Command "$ports = Get-WmiObject Win32_SerialPort; foreach ($port in $ports) { if ($port.Description -like '*Bluetooth*' -or $port.Description -like '*蓝牙*') { Write-Host ''; Write-Host '端口:' $port.DeviceID -ForegroundColor Green; Write-Host '  描述:' $port.Description; Write-Host '  状态:' $port.Status; Write-Host '  PNP ID:' $port.PNPDeviceID; } }"

echo.
echo ========================================
echo 使用说明
echo ========================================
echo.
echo 如果找到蓝牙 COM 口（如 COM3），可以在应用中使用：
echo.
echo 1. 在 Flutter 应用中：
echo    - 使用 BluetoothComService.findBluetoothComPorts()
echo    - 或直接连接: bluetoothComService.connect('COM3')
echo.
echo 2. 测试连接：
echo    - 在应用中选择找到的 COM 口
echo    - 点击"连接设备"
echo    - 测试读取蓝牙 MAC 地址
echo.
echo 3. 如果没有找到蓝牙 COM 口：
echo    - 确保蓝牙设备已配对
echo    - 确保蓝牙设备已连接（状态显示"已连接"）
echo    - 在 Windows 设置中重新连接设备
echo    - 重启蓝牙适配器
echo.
pause
