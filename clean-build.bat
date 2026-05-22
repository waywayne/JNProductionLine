@echo off
REM 清理构建缓存脚本 (Windows)
REM 用于解决 CMake 缓存导致的构建问题

echo 🧹 清理构建缓存...

REM 清理 Windows 构建缓存
if exist "build\windows" (
    echo   删除 build\windows\
    rmdir /s /q "build\windows"
)

REM 清理 Linux 构建缓存
if exist "build\linux" (
    echo   删除 build\linux\
    rmdir /s /q "build\linux"
)

REM 清理 macOS 构建缓存
if exist "build\macos" (
    echo   删除 build\macos\
    rmdir /s /q "build\macos"
)

REM 清理 Flutter 缓存
echo   运行 flutter clean
flutter clean

echo ✅ 清理完成！
echo.
echo 现在可以重新构建：
echo   Windows: flutter build windows --release
echo   Linux:   flutter build linux --release
echo   macOS:   flutter build macos --release
pause
