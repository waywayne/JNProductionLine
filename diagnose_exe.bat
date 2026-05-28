@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo JN Production Line - EXE 诊断工具
echo ========================================
echo.

:: 检查是否以管理员权限运行
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [√] 以管理员权限运行
) else (
    echo [!] 未以管理员权限运行（某些功能可能受限）
)
echo.

:: 查找 EXE 文件
set "EXE_PATH="
if exist "jn_production_line.exe" (
    set "EXE_PATH=jn_production_line.exe"
) else if exist "build\windows\x64\runner\Release\jn_production_line.exe" (
    set "EXE_PATH=build\windows\x64\runner\Release\jn_production_line.exe"
) else if exist "build\windows\runner\Release\jn_production_line.exe" (
    set "EXE_PATH=build\windows\runner\Release\jn_production_line.exe"
)

if "%EXE_PATH%"=="" (
    echo [×] 错误: 找不到 jn_production_line.exe
    echo.
    echo 请确保：
    echo 1. 在正确的目录运行此脚本
    echo 2. 已经构建或下载了应用程序
    pause
    exit /b 1
)

echo [√] 找到 EXE: %EXE_PATH%
echo.

:: 获取 EXE 所在目录
for %%F in ("%EXE_PATH%") do set "EXE_DIR=%%~dpF"

:: 检查文件信息
echo ========================================
echo 文件信息
echo ========================================
for %%F in ("%EXE_PATH%") do (
    echo 文件名: %%~nxF
    echo 大小: %%~zF 字节
    echo 路径: %%~fF
)
echo.

:: 检查依赖的 DLL
echo ========================================
echo 检查依赖文件
echo ========================================

set "MISSING_FILES=0"

:: 检查 flutter_windows.dll
if exist "%EXE_DIR%flutter_windows.dll" (
    echo [√] flutter_windows.dll
) else (
    echo [×] flutter_windows.dll - 缺失！
    set /a MISSING_FILES+=1
)

:: 检查 data 目录
if exist "%EXE_DIR%data\" (
    echo [√] data\ 目录
    
    :: 检查 icudtl.dat
    if exist "%EXE_DIR%data\icudtl.dat" (
        echo   [√] data\icudtl.dat
    ) else (
        echo   [×] data\icudtl.dat - 缺失！
        set /a MISSING_FILES+=1
    )
    
    :: 检查 flutter_assets
    if exist "%EXE_DIR%data\flutter_assets\" (
        echo   [√] data\flutter_assets\
    ) else (
        echo   [×] data\flutter_assets\ - 缺失！
        set /a MISSING_FILES+=1
    )
) else (
    echo [×] data\ 目录 - 缺失！
    set /a MISSING_FILES+=1
)

:: 检查插件 DLL
for %%D in (flutter_bluetooth_classic_serial_plugin.dll flutter_libserialport_plugin.dll serialport.dll) do (
    if exist "%EXE_DIR%%%D" (
        echo [√] %%D
    ) else (
        echo [!] %%D - 可选，但缺失
    )
)

echo.

if %MISSING_FILES% gtr 0 (
    echo [×] 发现 %MISSING_FILES% 个缺失的必需文件！
    echo.
    echo 解决方法：
    echo 1. 重新下载完整的 ZIP 包
    echo 2. 确保解压时包含所有文件
    echo 3. 不要单独复制 EXE 文件
    echo.
    pause
    exit /b 1
)

:: 检查 Visual C++ Runtime
echo ========================================
echo 检查运行时依赖
echo ========================================

:: 检查 VCRUNTIME140.dll
where /q VCRUNTIME140.dll
if %errorLevel% == 0 (
    echo [√] Visual C++ Runtime 已安装
) else (
    echo [!] Visual C++ Runtime 可能未安装
    echo.
    echo 请运行 install_vc_redist.bat 安装
)
echo.

:: 尝试运行 EXE
echo ========================================
echo 尝试启动应用程序
echo ========================================
echo.
echo 正在启动 %EXE_PATH% ...
echo.
echo 如果应用程序无法启动，请查看错误信息。
echo 按任意键继续...
pause >nul

:: 启动 EXE 并捕获错误（使用控制台模式）
echo 使用控制台模式启动以捕获错误...
echo.

:: 创建临时批处理文件来捕获退出代码
echo @echo off > temp_run.bat
echo cd /d "%EXE_DIR%" >> temp_run.bat
echo "%EXE_PATH%" >> temp_run.bat
echo echo. >> temp_run.bat
echo echo 程序已退出，退出代码：%%ERRORLEVEL%% >> temp_run.bat
echo if %%ERRORLEVEL%% NEQ 0 ( >> temp_run.bat
echo   echo. >> temp_run.bat
echo   echo [×] 程序异常退出！ >> temp_run.bat
echo   echo. >> temp_run.bat
echo   echo 可能的原因： >> temp_run.bat
echo   echo 1. 缺少 icudtl.dat 文件 >> temp_run.bat
echo   echo 2. data 目录结构不正确 >> temp_run.bat
echo   echo 3. 缺少 Visual C++ Runtime >> temp_run.bat
echo   echo 4. DLL 文件损坏或版本不匹配 >> temp_run.bat
echo ^) >> temp_run.bat
echo pause >> temp_run.bat

:: 运行临时批处理
call temp_run.bat

:: 删除临时文件
del temp_run.bat 2>nul

:: 等待 2 秒检查进程
timeout /t 2 /nobreak >nul

:: 检查进程是否还在运行
tasklist /FI "IMAGENAME eq jn_production_line.exe" 2>NUL | find /I /N "jn_production_line.exe">NUL
if %errorLevel% == 0 (
    echo.
    echo [√] 应用程序已启动！
    echo.
    echo 如果看到窗口，说明一切正常。
    echo 如果没有看到窗口，可能是以下原因：
    echo 1. 显示驱动问题
    echo 2. 防火墙或杀毒软件阻止
    echo 3. 缺少某些系统组件
) else (
    echo.
    echo [×] 应用程序启动失败或立即退出！
    echo.
    echo 可能的原因：
    echo 1. 缺少 Visual C++ Runtime
    echo 2. 缺少必需的 DLL 文件
    echo 3. data 目录结构不完整
    echo 4. 系统不兼容
    echo.
    echo 请尝试：
    echo 1. 运行 install_vc_redist.bat
    echo 2. 以管理员权限运行
    echo 3. 检查 Windows 事件查看器的错误日志
)

echo.
echo ========================================
echo 诊断完成
echo ========================================
pause
