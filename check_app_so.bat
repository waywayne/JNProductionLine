@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo 检查 app.so 文件
echo ========================================
echo.

REM 查找可能的构建目录
set "FOUND=0"

if exist "build\windows\x64\runner\Release\data\app.so" (
    echo ✓ 找到 app.so: build\windows\x64\runner\Release\data\app.so
    for %%A in ("build\windows\x64\runner\Release\data\app.so") do (
        set "SIZE=%%~zA"
        set /a "SIZE_MB=!SIZE! / 1048576"
        echo   大小: !SIZE_MB! MB
    )
    set "FOUND=1"
)

if exist "build\windows\runner\Release\data\app.so" (
    echo ✓ 找到 app.so: build\windows\runner\Release\data\app.so
    for %%A in ("build\windows\runner\Release\data\app.so") do (
        set "SIZE=%%~zA"
        set /a "SIZE_MB=!SIZE! / 1048576"
        echo   大小: !SIZE_MB! MB
    )
    set "FOUND=1"
)

echo.
if "%FOUND%"=="0" (
    echo ✗ 未找到 app.so 文件！
    echo.
    echo 这会导致 EXE 无法启动（退出代码 1）
    echo.
    echo 可能的原因：
    echo 1. Flutter build 没有生成 AOT 编译代码
    echo 2. 使用了错误的构建模式（Debug 而不是 Release）
    echo 3. Flutter 版本问题
    echo.
    echo 解决方法：
    echo 1. 清理构建：flutter clean
    echo 2. 重新构建：flutter build windows --release
    echo 3. 检查 Flutter 版本：flutter --version
) else (
    echo ✓ app.so 文件存在，应该可以正常运行
)

echo.
echo ========================================
echo 检查完整的 data 目录结构
echo ========================================
echo.

for %%D in ("build\windows\x64\runner\Release" "build\windows\runner\Release") do (
    if exist "%%~D\data" (
        echo 目录: %%~D\data
        dir /b "%%~D\data"
        echo.
    )
)

pause
