#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PyBluez 自动安装和环境检测脚本
用于自动化测试环境准备
"""

import sys
import subprocess
import platform
import os


def check_python_version():
    """检查 Python 版本"""
    version = sys.version_info
    print(f"Python 版本: {version.major}.{version.minor}.{version.micro}")
    
    if version.major < 3 or (version.major == 3 and version.minor < 7):
        print("❌ Python 版本过低，需要 Python 3.7+")
        return False
    
    print("✅ Python 版本符合要求")
    return True


def check_pybluez():
    """检查 PyBluez 是否已安装"""
    try:
        import bluetooth
        print("✅ PyBluez 已安装")
        
        # 尝试获取版本信息
        try:
            version = bluetooth.__version__
            print(f"   版本: {version}")
        except:
            print("   版本: 未知")
        
        return True
    except ImportError:
        print("❌ PyBluez 未安装")
        return False


def install_pybluez_pip():
    """使用 pip 安装 PyBluez"""
    print("\n尝试使用 pip 安装 PyBluez...")
    
    try:
        subprocess.check_call([
            sys.executable,
            '-m', 'pip', 'install',
            'pybluez',
            '--user'
        ])
        print("✅ PyBluez 安装成功")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ pip 安装失败: {e}")
        return False


def install_pybluez_conda():
    """使用 conda 安装 PyBluez"""
    print("\n尝试使用 conda 安装 PyBluez...")
    
    # 检查 conda 是否可用
    try:
        subprocess.check_call(['conda', '--version'], 
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("❌ conda 不可用")
        return False
    
    try:
        subprocess.check_call([
            'conda', 'install',
            '-c', 'conda-forge',
            'pybluez',
            '-y'
        ])
        print("✅ PyBluez 安装成功")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ conda 安装失败: {e}")
        return False


def download_wheel():
    """下载预编译的 wheel 文件"""
    print("\n提供预编译 wheel 下载链接...")
    
    system = platform.system()
    machine = platform.machine()
    py_version = f"{sys.version_info.major}{sys.version_info.minor}"
    
    print(f"系统: {system}")
    print(f"架构: {machine}")
    print(f"Python: {sys.version_info.major}.{sys.version_info.minor}")
    
    if system == "Windows":
        if machine == "AMD64":
            wheel_name = f"PyBluez-0.23-cp{py_version}-cp{py_version}-win_amd64.whl"
        else:
            wheel_name = f"PyBluez-0.23-cp{py_version}-cp{py_version}-win32.whl"
        
        print(f"\n推荐下载: {wheel_name}")
        print("下载地址: https://www.lfd.uci.edu/~gohlke/pythonlibs/#pybluez")
        print("\n下载后使用以下命令安装:")
        print(f"  pip install {wheel_name}")
        
        return False
    else:
        print("⚠️  非 Windows 系统，请使用 pip 或 conda 安装")
        return False


def check_bluetooth_adapter():
    """检查蓝牙适配器"""
    print("\n检查蓝牙适配器...")
    
    try:
        import bluetooth
        
        # 尝试查找本地蓝牙适配器
        try:
            devices = bluetooth.discover_devices(duration=1, lookup_names=False)
            print("✅ 蓝牙适配器工作正常")
            return True
        except Exception as e:
            print(f"⚠️  蓝牙适配器可能有问题: {e}")
            print("   请确保:")
            print("   1. 蓝牙适配器已启用")
            print("   2. 蓝牙驱动已安装")
            print("   3. Windows 蓝牙服务正在运行")
            return False
    except ImportError:
        print("⚠️  PyBluez 未安装，无法检查蓝牙适配器")
        return False


def auto_install():
    """自动安装 PyBluez"""
    print("=" * 60)
    print("PyBluez 自动安装程序")
    print("=" * 60)
    
    # 1. 检查 Python 版本
    if not check_python_version():
        return False
    
    # 2. 检查是否已安装
    if check_pybluez():
        # 已安装，检查蓝牙适配器
        check_bluetooth_adapter()
        return True
    
    # 3. 尝试安装
    print("\n开始安装 PyBluez...")
    
    # 方法 1: 尝试使用 conda
    if install_pybluez_conda():
        if check_pybluez():
            check_bluetooth_adapter()
            return True
    
    # 方法 2: 尝试使用 pip
    if install_pybluez_pip():
        if check_pybluez():
            check_bluetooth_adapter()
            return True
    
    # 方法 3: 提供 wheel 下载链接
    print("\n自动安装失败，请手动安装:")
    download_wheel()
    
    return False


def create_install_script():
    """创建 Windows 批处理安装脚本"""
    script_content = """@echo off
echo ========================================
echo PyBluez 安装脚本
echo ========================================
echo.

REM 检查 Python
python --version >nul 2>&1
if errorlevel 1 (
    echo 错误: 未找到 Python
    echo 请先安装 Python 3.7+
    pause
    exit /b 1
)

echo 检测到 Python 环境
echo.

REM 尝试使用 pip 安装
echo 尝试使用 pip 安装 PyBluez...
python -m pip install pybluez --user

if errorlevel 1 (
    echo.
    echo pip 安装失败，可能需要:
    echo 1. 安装 Visual Studio Build Tools
    echo 2. 或下载预编译的 wheel 文件
    echo.
    echo 预编译 wheel 下载地址:
    echo https://www.lfd.uci.edu/~gohlke/pythonlibs/#pybluez
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo 安装完成！
echo ========================================
echo.

REM 验证安装
python -c "import bluetooth; print('PyBluez 版本:', bluetooth.__version__)" 2>nul
if errorlevel 1 (
    python -c "import bluetooth; print('PyBluez 已安装')"
)

echo.
pause
"""
    
    script_path = os.path.join(os.path.dirname(__file__), 'install_pybluez.bat')
    
    try:
        with open(script_path, 'w', encoding='utf-8') as f:
            f.write(script_content)
        print(f"\n✅ 已创建安装脚本: {script_path}")
        print("   可以双击运行此脚本进行安装")
        return True
    except Exception as e:
        print(f"❌ 创建安装脚本失败: {e}")
        return False


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='PyBluez 环境检测和安装')
    parser.add_argument('--check', action='store_true', help='仅检查环境')
    parser.add_argument('--install', action='store_true', help='自动安装')
    parser.add_argument('--create-script', action='store_true', help='创建安装脚本')
    
    args = parser.parse_args()
    
    if args.check:
        # 仅检查
        check_python_version()
        installed = check_pybluez()
        if installed:
            check_bluetooth_adapter()
        sys.exit(0 if installed else 1)
    
    elif args.create_script:
        # 创建安装脚本
        create_install_script()
        sys.exit(0)
    
    elif args.install:
        # 自动安装
        success = auto_install()
        sys.exit(0 if success else 1)
    
    else:
        # 默认：检查并提示
        print("=" * 60)
        print("PyBluez 环境检测")
        print("=" * 60)
        
        check_python_version()
        installed = check_pybluez()
        
        if installed:
            check_bluetooth_adapter()
            print("\n✅ 环境就绪")
        else:
            print("\n❌ 环境未就绪")
            print("\n请选择:")
            print("  1. 运行: python setup_bluetooth.py --install")
            print("  2. 或手动安装 PyBluez")
            
            create_install_script()


if __name__ == "__main__":
    main()
