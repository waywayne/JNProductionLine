@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo JN Production Line - 调试启动
echo ========================================
echo.

:: 设置调试环境变量
set FLUTTER_ENGINE_SWITCH_LOG_LEVEL=info
set FLUTTER_ENGINE_SWITCH_ENABLE_IMPELLER=false

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
    pause
    exit /b 1
)

echo [√] 找到 EXE: %EXE_PATH%
echo.

:: 获取 EXE 所在目录
for %%F in ("%EXE_PATH%") do set "EXE_DIR=%%~dpF"

:: 切换到 EXE 目录
cd /d "%EXE_DIR%"

echo ========================================
echo 检查必需文件
echo ========================================

set "ERRORS=0"

:: 检查 flutter_windows.dll
if exist "flutter_windows.dll" (
    echo [√] flutter_windows.dll
) else (
    echo [×] flutter_windows.dll - 缺失！
    set /a ERRORS+=1
)

:: 检查 data\icudtl.dat
if exist "data\icudtl.dat" (
    echo [√] data\icudtl.dat
    for %%F in ("data\icudtl.dat") do (
        echo     大小: %%~zF 字节
    )
) else (
    echo [×] data\icudtl.dat - 缺失！
    set /a ERRORS+=1
)

:: 检查 data\flutter_assets
if exist "data\flutter_assets\" (
    echo [√] data\flutter_assets\
) else (
    echo [×] data\flutter_assets\ - 缺失！
    set /a ERRORS+=1
)

:: 检查根目录是否有错误的 icudtl.dat
if exist "icudtl.dat" (
    echo [!] 警告: 根目录存在 icudtl.dat（应该只在 data\ 目录）
    echo     这会导致程序崩溃！
    set /a ERRORS+=1
)

echo.

if %ERRORS% gtr 0 (
    echo [×] 发现 %ERRORS% 个问题！
    echo.
    echo 请先解决这些问题再启动程序。
    echo.
    pause
    exit /b 1
)

echo ========================================
echo 启动应用程序（调试模式）
echo ========================================
echo.
echo 工作目录: %CD%
echo 可执行文件: %EXE_PATH%
echo.
echo 正在启动...
echo.

:: 启动程序并等待
"%EXE_PATH%"

:: 捕获退出代码
set EXIT_CODE=%ERRORLEVEL%

echo.
echo ========================================
echo 程序已退出
echo ========================================
echo 退出代码: %EXIT_CODE%
echo.

if %EXIT_CODE% == 0 (
    echo [√] 程序正常退出
) else if %EXIT_CODE% == 1 (
    echo [×] 程序异常退出（退出代码 1）
    echo.
    echo 常见原因：
    echo 1. 缺少 icudtl.dat 文件
    echo    → 确保 data\icudtl.dat 存在
    echo.
    echo 2. icudtl.dat 在错误的位置
    echo    → 必须在 data\ 目录，不能在根目录
    echo.
    echo 3. data 目录结构不完整
    echo    → 确保 data\flutter_assets\ 存在
    echo.
    echo 4. DLL 文件损坏
    echo    → 重新下载完整的 ZIP 包
    echo.
    echo 5. 缺少 Visual C++ Runtime
    echo    → 运行 install_vc_redist.bat
) else if %EXIT_CODE% == -1073741515 (
    echo [×] 缺少 DLL 依赖（错误代码 0xC0000135）
    echo.
    echo 解决方法：
    echo 1. 运行 install_vc_redist.bat
    echo 2. 确保 flutter_windows.dll 存在
    echo 3. 确保所有插件 DLL 存在
) else if %EXIT_CODE% == -1073740791 (
    echo [×] 访问冲突（错误代码 0xC0000409）
    echo.
    echo 可能原因：
    echo 1. icudtl.dat 文件损坏
    echo 2. 内存访问错误
    echo 3. DLL 版本不匹配
) else (
    echo [×] 程序异常退出
    echo.
    echo 请查看 Windows 事件查看器获取详细信息：
    echo 1. 按 Win+R
    echo 2. 输入 eventvwr.msc
    echo 3. 查看 "Windows 日志" → "应用程序"
)

echo.
echo ========================================
echo 调试信息
echo ========================================
echo.

:: 显示目录结构
echo 当前目录结构:
tree /F /A | findstr /V "flutter_assets"

echo.
echo ========================================
pause
