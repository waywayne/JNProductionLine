#!/usr/bin/env python3
"""PCI GPIB 测试脚本 - 专门用于NI PCI-GPIB卡"""

import pyvisa
import sys

class Colors:
    GREEN = '\033[0;32m'
    RED = '\033[0;31m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'

def print_success(msg):
    print(f"{Colors.GREEN}✅ {msg}{Colors.NC}")

def print_error(msg):
    print(f"{Colors.RED}❌ {msg}{Colors.NC}")

def print_warning(msg):
    print(f"{Colors.YELLOW}⚠️  {msg}{Colors.NC}")

def print_info(msg):
    print(f"{Colors.BLUE}ℹ️  {msg}{Colors.NC}")

def test_ni_visa():
    """测试NI-VISA后端（PCI GPIB卡的主要方案）"""
    print("=" * 70)
    print(" " * 20 + "测试 NI-VISA 后端（PCI GPIB卡）")
    print("=" * 70)
    print()
    
    try:
        # 使用NI-VISA
        print_info("初始化 NI-VISA 后端...")
        rm = pyvisa.ResourceManager('@ni')
        print_success("NI-VISA后端初始化成功")
        print()
        
        # 列出资源
        print_info("扫描VISA资源...")
        resources = rm.list_resources()
        print_success(f"找到 {len(resources)} 个资源:")
        for res in resources:
            if 'GPIB' in res:
                print(f"  {Colors.GREEN}★ {res}{Colors.NC}")
            else:
                print(f"    {res}")
        print()
        
        # 连接GPIB设备
        gpib_address = 'GPIB0::5::INSTR'
        if gpib_address in resources:
            print_info(f"连接到 {gpib_address}...")
            inst = rm.open_resource(gpib_address)
            inst.timeout = 30000
            print_success("连接成功")
            print()
            
            # 测试1: 写入命令
            print("【测试1】写入命令 (*CLS)")
            print("-" * 70)
            try:
                inst.write('*CLS')
                print_success("写入成功")
            except Exception as e:
                print_error(f"写入失败: {e}")
            print()
            
            # 测试2: 查询命令
            print("【测试2】查询命令 (*IDN?)")
            print("-" * 70)
            try:
                result = inst.query('*IDN?')
                print_success(f"查询成功: {result.strip()}")
            except Exception as e:
                print_warning(f"查询失败: {e}")
                print_info("设备可能不支持 *IDN? 命令（这是正常的）")
            print()
            
            # 测试3: WFP60H专用命令
            print("【测试3】WFP60H 写入命令")
            print("-" * 70)
            commands = [
                ('*CLS', '清除状态'),
                (':SOURce1:VOLTage 5.0', '设置电压5V'),
                (':SOURce1:CURRent:LIMit 0.1', '设置电流限制0.1A'),
                (':OUTPut1 ON', '打开输出'),
                (':OUTPut1 OFF', '关闭输出'),
            ]
            
            success_count = 0
            for cmd, desc in commands:
                try:
                    inst.write(cmd)
                    print_success(f"{desc:20} {cmd}")
                    success_count += 1
                except Exception as e:
                    print_error(f"{desc:20} {cmd}: {e}")
            
            print()
            print_info(f"成功率: {success_count}/{len(commands)} ({success_count/len(commands)*100:.0f}%)")
            print()
            
            # 测试4: 查询命令（可选）
            print("【测试4】WFP60H 查询命令（可能不支持）")
            print("-" * 70)
            query_commands = [
                (':READ[1]?', '读取电流'),
                (':SOURce1:VOLTage?', '查询电压设置'),
                (':OUTPut1:STATe?', '查询输出状态'),
            ]
            
            for cmd, desc in query_commands:
                try:
                    result = inst.query(cmd)
                    print_success(f"{desc:20} {cmd}: {result.strip()}")
                except Exception as e:
                    print_warning(f"{desc:20} {cmd}: 超时/不支持")
            
            inst.close()
            print()
        else:
            print_error(f"未找到 {gpib_address}")
            print_info("可用的资源:")
            for res in resources:
                print(f"  - {res}")
            rm.close()
            return False
        
        rm.close()
        return True
        
    except Exception as e:
        print_error(f"NI-VISA测试失败: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_pyvisa_py():
    """测试pyvisa-py后端（备选方案）"""
    print()
    print("=" * 70)
    print(" " * 20 + "测试 pyvisa-py 后端（纯Python）")
    print("=" * 70)
    print()
    
    try:
        print_info("初始化 pyvisa-py 后端...")
        rm = pyvisa.ResourceManager('@py')
        print_success("pyvisa-py后端初始化成功")
        print()
        
        print_info("扫描资源...")
        resources = rm.list_resources()
        gpib_resources = [r for r in resources if 'GPIB' in r]
        
        if gpib_resources:
            print_success(f"找到 {len(gpib_resources)} 个GPIB资源:")
            for res in gpib_resources:
                print(f"  ★ {res}")
        else:
            print_warning("未找到GPIB资源")
            print_info("pyvisa-py对PCI GPIB卡的支持有限")
            print_info("建议使用 NI-VISA 后端")
        
        rm.close()
        return len(gpib_resources) > 0
        
    except Exception as e:
        print_error(f"pyvisa-py测试失败: {e}")
        return False

def check_system():
    """检查系统状态"""
    import subprocess
    
    print()
    print("=" * 70)
    print(" " * 25 + "系统状态检查")
    print("=" * 70)
    print()
    
    # 检查PCI设备
    print("【硬件】PCI GPIB卡")
    print("-" * 70)
    try:
        result = subprocess.run(['lspci'], capture_output=True, text=True)
        for line in result.stdout.split('\n'):
            if 'gpib' in line.lower() or 'national instruments' in line.lower():
                print_success(line.strip())
    except:
        print_warning("无法检查PCI设备")
    print()
    
    # 检查设备文件
    print("【设备文件】/dev/gpib*")
    print("-" * 70)
    try:
        result = subprocess.run(['ls', '-l', '/dev/gpib0'], capture_output=True, text=True)
        if result.returncode == 0:
            print_success(result.stdout.strip())
        else:
            print_error("/dev/gpib0 不存在")
    except:
        print_warning("无法检查设备文件")
    print()
    
    # 检查NI-VISA
    print("【软件】NI-VISA")
    print("-" * 70)
    try:
        result = subprocess.run(['visaconf', '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            print_success(f"NI-VISA 已安装")
        else:
            print_warning("NI-VISA 可能未安装")
    except:
        print_warning("visaconf 命令不可用")
    print()
    
    # 检查PyVISA
    print("【Python】PyVISA")
    print("-" * 70)
    try:
        print_success(f"PyVISA 版本: {pyvisa.__version__}")
    except:
        print_error("PyVISA 未安装")
    print()

def main():
    """主函数"""
    print()
    print(f"{Colors.BLUE}{'=' * 70}{Colors.NC}")
    print(f"{Colors.BLUE}{'=' * 70}{Colors.NC}")
    print(f"{Colors.BLUE}          PCI GPIB 综合测试脚本 - NI PCI-GPIB 专用{Colors.NC}")
    print(f"{Colors.BLUE}{'=' * 70}{Colors.NC}")
    print(f"{Colors.BLUE}{'=' * 70}{Colors.NC}")
    
    # 系统检查
    check_system()
    
    # 测试NI-VISA（主要方案）
    ni_ok = test_ni_visa()
    
    # 测试pyvisa-py（备选方案）
    py_ok = test_pyvisa_py()
    
    # 总结
    print()
    print("=" * 70)
    print(" " * 30 + "测试总结")
    print("=" * 70)
    print()
    
    if ni_ok:
        print_success("NI-VISA 后端: 通过")
    else:
        print_error("NI-VISA 后端: 失败")
    
    if py_ok:
        print_success("pyvisa-py 后端: 通过")
    else:
        print_warning("pyvisa-py 后端: 失败（正常，PCI卡不支持）")
    
    print()
    print("=" * 70)
    print(" " * 30 + "建议")
    print("=" * 70)
    print()
    
    if ni_ok:
        print_success("推荐使用 NI-VISA 后端")
        print()
        print("  在代码中使用:")
        print(f"  {Colors.GREEN}rm = pyvisa.ResourceManager('@ni'){Colors.NC}")
        print()
        print("  修改文件:")
        print("  - lib/services/gpib_service.dart")
        print("  - lib/services/gpib_service_v2.dart")
        print("  - lib/services/gpib_diagnostic_service.dart")
        print()
    elif py_ok:
        print_warning("使用 pyvisa-py 后端（备选）")
        print()
        print("  在代码中使用:")
        print(f"  {Colors.YELLOW}rm = pyvisa.ResourceManager('@py'){Colors.NC}")
        print()
    else:
        print_error("所有后端都失败")
        print()
        print("  请检查:")
        print("  1. GPIB设备是否连接")
        print("  2. 设备电源是否打开")
        print("  3. GPIB地址是否设置为5")
        print("  4. /etc/gpib.conf 配置是否正确（应为 ni_pci）")
        print()
        print("  运行修复脚本:")
        print(f"  {Colors.BLUE}./scripts/fix_pci_gpib.sh{Colors.NC}")
        print()
    
    print("=" * 70)
    print()
    
    return 0 if (ni_ok or py_ok) else 1

if __name__ == '__main__':
    sys.exit(main())
