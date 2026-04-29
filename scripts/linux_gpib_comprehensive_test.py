#!/usr/bin/env python3
"""
Linux GPIB 综合测试脚本
完整验证GPIB通讯的所有方面
"""

import sys
import os
import subprocess
import time
from typing import Dict, List, Tuple, Optional

class Colors:
    """终端颜色"""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    MAGENTA = '\033[0;35m'
    CYAN = '\033[0;36m'
    WHITE = '\033[1;37m'
    NC = '\033[0m'  # No Color
    BOLD = '\033[1m'

def print_header(text: str):
    """打印标题"""
    print(f"\n{Colors.CYAN}{Colors.BOLD}{'='*60}{Colors.NC}")
    print(f"{Colors.CYAN}{Colors.BOLD}{text:^60}{Colors.NC}")
    print(f"{Colors.CYAN}{Colors.BOLD}{'='*60}{Colors.NC}\n")

def print_success(text: str):
    """打印成功信息"""
    print(f"{Colors.GREEN}✅ {text}{Colors.NC}")

def print_error(text: str):
    """打印错误信息"""
    print(f"{Colors.RED}❌ {text}{Colors.NC}")

def print_warning(text: str):
    """打印警告信息"""
    print(f"{Colors.YELLOW}⚠️  {text}{Colors.NC}")

def print_info(text: str):
    """打印信息"""
    print(f"{Colors.BLUE}ℹ️  {text}{Colors.NC}")

def run_command(cmd: str, shell: bool = True) -> Tuple[int, str, str]:
    """运行shell命令"""
    try:
        result = subprocess.run(
            cmd,
            shell=shell,
            capture_output=True,
            text=True,
            timeout=10
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "Command timeout"
    except Exception as e:
        return -1, "", str(e)

class LinuxGPIBTester:
    """Linux GPIB 综合测试器"""
    
    def __init__(self, address: str = "GPIB0::5::INSTR"):
        self.address = address
        self.results = {}
        self.total_tests = 0
        self.passed_tests = 0
        
    def test_system_info(self) -> bool:
        """测试1: 系统信息"""
        print_header("测试1: 系统信息")
        
        # 检查Linux版本
        code, stdout, _ = run_command("uname -a")
        if code == 0:
            print_success(f"系统: {stdout.strip()}")
        
        # 检查发行版
        if os.path.exists("/etc/os-release"):
            with open("/etc/os-release") as f:
                for line in f:
                    if line.startswith("PRETTY_NAME"):
                        print_success(f"发行版: {line.split('=')[1].strip().strip('\"')}")
                        break
        
        # 检查内核版本
        code, stdout, _ = run_command("uname -r")
        if code == 0:
            print_success(f"内核版本: {stdout.strip()}")
        
        return True
    
    def test_hardware_detection(self) -> bool:
        """测试2: 硬件检测"""
        print_header("测试2: GPIB硬件检测")
        
        found = False
        
        # 检查USB设备
        print_info("检查USB GPIB适配器...")
        code, stdout, _ = run_command("lsusb")
        if code == 0:
            for line in stdout.split('\n'):
                if any(keyword in line.lower() for keyword in ['national instruments', 'agilent', 'keysight', 'gpib']):
                    print_success(f"找到USB设备: {line.strip()}")
                    found = True
        
        # 检查PCI设备
        print_info("检查PCI GPIB卡...")
        code, stdout, _ = run_command("lspci")
        if code == 0:
            for line in stdout.split('\n'):
                if any(keyword in line.lower() for keyword in ['gpib', 'national instruments']):
                    print_success(f"找到PCI设备: {line.strip()}")
                    found = True
        
        if not found:
            print_error("未找到GPIB硬件")
            print_warning("请检查:")
            print("  1. USB线缆是否连接")
            print("  2. 设备电源是否打开")
            print("  3. 尝试重新插拔USB")
        
        return found
    
    def test_kernel_modules(self) -> bool:
        """测试3: 内核模块"""
        print_header("测试3: GPIB内核模块")
        
        modules_to_check = [
            'gpib_common',
            'ni_usb_gpib',
            'agilent_82357a',
            'tnt4882',
            'nec7210',
        ]
        
        code, stdout, _ = run_command("lsmod")
        loaded_modules = []
        
        if code == 0:
            for module in modules_to_check:
                if module in stdout:
                    print_success(f"模块已加载: {module}")
                    loaded_modules.append(module)
        
        if not loaded_modules:
            print_error("未加载GPIB内核模块")
            print_warning("尝试加载模块:")
            
            # 尝试加载gpib_common
            print_info("加载 gpib_common...")
            code, _, stderr = run_command("sudo modprobe gpib_common")
            if code == 0:
                print_success("gpib_common 加载成功")
                loaded_modules.append('gpib_common')
            else:
                print_error(f"gpib_common 加载失败: {stderr}")
                print_warning("可能需要安装 linux-gpib 驱动")
                print("  Ubuntu/Debian: sudo apt-get install linux-gpib linux-gpib-user")
            
            # 尝试加载适配器驱动
            for module in ['ni_usb_gpib', 'agilent_82357a']:
                print_info(f"尝试加载 {module}...")
                code, _, _ = run_command(f"sudo modprobe {module}")
                if code == 0:
                    print_success(f"{module} 加载成功")
                    loaded_modules.append(module)
        
        return len(loaded_modules) > 0
    
    def test_device_files(self) -> bool:
        """测试4: 设备文件"""
        print_header("测试4: GPIB设备文件")
        
        device_files = []
        
        # 检查/dev/gpib*
        code, stdout, _ = run_command("ls -l /dev/gpib* 2>/dev/null")
        if code == 0 and stdout:
            print_success("找到GPIB设备文件:")
            for line in stdout.strip().split('\n'):
                print(f"  {line}")
                device_files.append(line)
            
            # 检查权限
            for line in stdout.strip().split('\n'):
                if 'rw-rw-rw-' in line or 'rw-rw----' in line:
                    print_success("设备文件权限正确")
                else:
                    print_warning("设备文件权限可能不足")
                    print_info("修复权限: sudo chmod 666 /dev/gpib*")
        else:
            print_error("未找到 /dev/gpib* 设备文件")
            print_warning("尝试手动创建设备文件:")
            print("  sudo mknod /dev/gpib0 c 160 0")
            print("  sudo chmod 666 /dev/gpib0")
            
            # 尝试创建
            print_info("尝试自动创建...")
            code1, _, _ = run_command("sudo mknod /dev/gpib0 c 160 0")
            code2, _, _ = run_command("sudo chmod 666 /dev/gpib0")
            if code1 == 0 and code2 == 0:
                print_success("设备文件创建成功")
                return True
        
        return len(device_files) > 0
    
    def test_user_permissions(self) -> bool:
        """测试5: 用户权限"""
        print_header("测试5: 用户组权限")
        
        code, stdout, _ = run_command("groups")
        groups = stdout.strip().split()
        
        has_gpib = 'gpib' in groups
        has_dialout = 'dialout' in groups
        
        if has_gpib:
            print_success("用户在 gpib 组中")
        else:
            print_error("用户不在 gpib 组中")
            print_info("添加用户到组: sudo usermod -a -G gpib $USER")
        
        if has_dialout:
            print_success("用户在 dialout 组中")
        else:
            print_error("用户不在 dialout 组中")
            print_info("添加用户到组: sudo usermod -a -G dialout $USER")
        
        if not has_gpib or not has_dialout:
            print_warning("添加用户组后需要重新登录系统！")
        
        return has_gpib and has_dialout
    
    def test_gpib_config(self) -> bool:
        """测试6: GPIB配置"""
        print_header("测试6: GPIB配置文件")
        
        # 检查gpib.conf
        if os.path.exists("/etc/gpib.conf"):
            print_success("/etc/gpib.conf 存在")
            
            with open("/etc/gpib.conf") as f:
                content = f.read()
                print_info("配置内容:")
                for line in content.split('\n'):
                    if line.strip() and not line.strip().startswith('/*') and not line.strip().startswith('*'):
                        print(f"  {line}")
        else:
            print_error("/etc/gpib.conf 不存在")
            print_warning("需要创建配置文件")
            return False
        
        # 检查gpib_config命令
        code, _, _ = run_command("which gpib_config")
        if code == 0:
            print_success("gpib_config 命令可用")
            
            # 运行gpib_config
            print_info("运行 gpib_config...")
            code, stdout, stderr = run_command("sudo gpib_config")
            if code == 0:
                print_success("GPIB配置成功")
            else:
                print_error(f"GPIB配置失败: {stderr}")
        else:
            print_error("gpib_config 命令不存在")
            print_info("安装: sudo apt-get install linux-gpib-user")
            return False
        
        return True
    
    def test_ni_visa(self) -> bool:
        """测试7: NI-VISA"""
        print_header("测试7: NI-VISA驱动")
        
        # 检查visaconf
        code, _, _ = run_command("which visaconf")
        if code == 0:
            print_success("NI-VISA 已安装")
            
            # 检查版本
            code, stdout, _ = run_command("visaconf --version 2>/dev/null")
            if stdout:
                print_info(f"版本: {stdout.strip()}")
            
            # 检查服务
            code, _, _ = run_command("systemctl is-active nivisa")
            if code == 0:
                print_success("NI-VISA 服务正在运行")
            else:
                print_warning("NI-VISA 服务未运行")
                print_info("启动服务: sudo systemctl start nivisa")
        else:
            print_warning("NI-VISA 未安装")
            print_info("可以使用 pyvisa-py 作为替代")
        
        return True
    
    def test_pyvisa(self) -> bool:
        """测试8: PyVISA"""
        print_header("测试8: PyVISA环境")
        
        try:
            import pyvisa
            print_success(f"PyVISA 已安装: {pyvisa.__version__}")
            
            # 检查pyvisa-py
            try:
                import pyvisa_py
                print_success(f"pyvisa-py 已安装 (纯Python后端)")
            except ImportError:
                print_warning("pyvisa-py 未安装")
                print_info("安装: pip3 install pyvisa-py --user")
            
            return True
        except ImportError:
            print_error("PyVISA 未安装")
            print_info("安装: pip3 install pyvisa pyvisa-py --user")
            return False
    
    def test_visa_backends(self) -> bool:
        """测试9: VISA后端"""
        print_header("测试9: VISA后端测试")
        
        try:
            import pyvisa
            
            backends = [
                ('@ni', 'NI-VISA'),
                ('@py', 'PyVISA-py'),
                (None, '默认后端'),
            ]
            
            working_backends = []
            
            for backend, name in backends:
                print_info(f"测试 {name}...")
                try:
                    if backend:
                        rm = pyvisa.ResourceManager(backend)
                    else:
                        rm = pyvisa.ResourceManager()
                    
                    print_success(f"{name} 初始化成功")
                    
                    # 列出资源
                    try:
                        resources = rm.list_resources()
                        print_info(f"  找到 {len(resources)} 个资源")
                        for res in resources:
                            print(f"    - {res}")
                        working_backends.append((backend, name))
                    except Exception as e:
                        print_warning(f"  列出资源失败: {e}")
                    
                    rm.close()
                    
                except Exception as e:
                    print_error(f"{name} 失败: {e}")
            
            return len(working_backends) > 0
            
        except ImportError:
            print_error("PyVISA 未安装，跳过后端测试")
            return False
    
    def test_gpib_connection(self) -> bool:
        """测试10: GPIB连接"""
        print_header(f"测试10: GPIB设备连接 ({self.address})")
        
        try:
            import pyvisa
            
            # 尝试不同的后端
            backends = [
                ('@ni', 'NI-VISA'),
                ('@py', 'PyVISA-py'),
                (None, '默认'),
            ]
            
            for backend, name in backends:
                print_info(f"使用 {name} 后端...")
                try:
                    if backend:
                        rm = pyvisa.ResourceManager(backend)
                    else:
                        rm = pyvisa.ResourceManager()
                    
                    inst = rm.open_resource(self.address)
                    inst.timeout = 30000
                    
                    print_success(f"连接成功 ({name})")
                    
                    # 测试写入
                    try:
                        inst.write('*CLS')
                        print_success("  写入命令成功 (*CLS)")
                    except Exception as e:
                        print_error(f"  写入失败: {e}")
                    
                    # 测试查询
                    try:
                        result = inst.query('*IDN?')
                        print_success(f"  查询成功: {result.strip()}")
                    except Exception as e:
                        print_warning(f"  查询失败: {e}")
                        print_info("  设备可能不支持 *IDN? 命令")
                    
                    inst.close()
                    rm.close()
                    
                    return True
                    
                except Exception as e:
                    print_error(f"{name} 连接失败: {e}")
            
            return False
            
        except ImportError:
            print_error("PyVISA 未安装")
            return False
    
    def test_scpi_commands(self) -> bool:
        """测试11: SCPI命令测试"""
        print_header("测试11: SCPI命令测试")
        
        try:
            import pyvisa
            
            # 使用最佳后端
            try:
                rm = pyvisa.ResourceManager('@py')
                backend_name = 'PyVISA-py'
            except:
                try:
                    rm = pyvisa.ResourceManager('@ni')
                    backend_name = 'NI-VISA'
                except:
                    rm = pyvisa.ResourceManager()
                    backend_name = '默认'
            
            print_info(f"使用后端: {backend_name}")
            
            inst = rm.open_resource(self.address)
            inst.timeout = 30000
            
            # 测试命令列表
            test_commands = [
                ('*CLS', False, '清除状态'),
                ('*RST', False, '复位设备'),
                ('*IDN?', True, '设备识别'),
                ('*OPC?', True, '操作完成'),
                (':SOURce1:VOLTage 5.0', False, '设置电压'),
                (':SOURce1:CURRent:LIMit 0.1', False, '设置电流限制'),
                (':OUTPut1 ON', False, '打开输出'),
                (':OUTPut1 OFF', False, '关闭输出'),
            ]
            
            success_count = 0
            
            for cmd, is_query, desc in test_commands:
                print_info(f"测试: {desc} ({cmd})")
                try:
                    if is_query:
                        result = inst.query(cmd)
                        print_success(f"  成功: {result.strip()}")
                        success_count += 1
                    else:
                        inst.write(cmd)
                        print_success(f"  成功")
                        success_count += 1
                except Exception as e:
                    print_warning(f"  失败: {e}")
            
            inst.close()
            rm.close()
            
            print_info(f"成功率: {success_count}/{len(test_commands)}")
            
            return success_count > 0
            
        except Exception as e:
            print_error(f"SCPI测试失败: {e}")
            return False
    
    def test_system_logs(self) -> bool:
        """测试12: 系统日志"""
        print_header("测试12: 系统日志检查")
        
        # 检查dmesg
        print_info("检查 dmesg 日志...")
        code, stdout, _ = run_command("dmesg | grep -i gpib | tail -20")
        if code == 0 and stdout:
            print_success("找到GPIB相关日志:")
            for line in stdout.strip().split('\n'):
                print(f"  {line}")
        else:
            print_warning("未找到GPIB相关日志")
        
        # 检查journalctl
        print_info("检查 systemd 日志...")
        code, stdout, _ = run_command("journalctl -u nivisa -n 10 --no-pager 2>/dev/null")
        if code == 0 and stdout:
            print_success("NI-VISA服务日志:")
            for line in stdout.strip().split('\n')[-5:]:
                print(f"  {line}")
        
        return True
    
    def run_all_tests(self):
        """运行所有测试"""
        print(f"\n{Colors.BOLD}{Colors.MAGENTA}")
        print("╔════════════════════════════════════════════════════════════╗")
        print("║                                                            ║")
        print("║         Linux GPIB 综合测试系统                            ║")
        print("║         Comprehensive GPIB Testing Suite                  ║")
        print("║                                                            ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print(f"{Colors.NC}\n")
        
        print_info(f"测试设备地址: {self.address}")
        print_info(f"开始时间: {time.strftime('%Y-%m-%d %H:%M:%S')}")
        
        tests = [
            ("系统信息", self.test_system_info),
            ("硬件检测", self.test_hardware_detection),
            ("内核模块", self.test_kernel_modules),
            ("设备文件", self.test_device_files),
            ("用户权限", self.test_user_permissions),
            ("GPIB配置", self.test_gpib_config),
            ("NI-VISA", self.test_ni_visa),
            ("PyVISA", self.test_pyvisa),
            ("VISA后端", self.test_visa_backends),
            ("GPIB连接", self.test_gpib_connection),
            ("SCPI命令", self.test_scpi_commands),
            ("系统日志", self.test_system_logs),
        ]
        
        for name, test_func in tests:
            self.total_tests += 1
            try:
                if test_func():
                    self.passed_tests += 1
                    self.results[name] = "PASS"
                else:
                    self.results[name] = "FAIL"
            except Exception as e:
                print_error(f"测试异常: {e}")
                self.results[name] = "ERROR"
        
        # 打印总结
        self.print_summary()
    
    def print_summary(self):
        """打印测试总结"""
        print_header("测试总结")
        
        print(f"\n{Colors.BOLD}测试结果:{Colors.NC}\n")
        
        for name, result in self.results.items():
            if result == "PASS":
                print(f"  {Colors.GREEN}✅ {name:20} PASS{Colors.NC}")
            elif result == "FAIL":
                print(f"  {Colors.RED}❌ {name:20} FAIL{Colors.NC}")
            else:
                print(f"  {Colors.YELLOW}⚠️  {name:20} ERROR{Colors.NC}")
        
        print(f"\n{Colors.BOLD}统计:{Colors.NC}")
        print(f"  总测试数: {self.total_tests}")
        print(f"  通过: {Colors.GREEN}{self.passed_tests}{Colors.NC}")
        print(f"  失败: {Colors.RED}{self.total_tests - self.passed_tests}{Colors.NC}")
        print(f"  成功率: {Colors.CYAN}{self.passed_tests/self.total_tests*100:.1f}%{Colors.NC}")
        
        # 建议
        print(f"\n{Colors.BOLD}建议:{Colors.NC}\n")
        
        if self.results.get("内核模块") != "PASS":
            print_warning("内核模块未加载")
            print("  1. 安装 linux-gpib: sudo apt-get install linux-gpib linux-gpib-user")
            print("  2. 加载模块: sudo modprobe gpib_common")
            print("  3. 重启系统")
        
        if self.results.get("设备文件") != "PASS":
            print_warning("设备文件不存在")
            print("  1. 运行 gpib_config: sudo gpib_config")
            print("  2. 手动创建: sudo mknod /dev/gpib0 c 160 0")
            print("  3. 设置权限: sudo chmod 666 /dev/gpib0")
        
        if self.results.get("用户权限") != "PASS":
            print_warning("用户权限不足")
            print("  1. 添加到组: sudo usermod -a -G gpib,dialout $USER")
            print("  2. 重新登录系统")
        
        if self.results.get("GPIB连接") != "PASS":
            print_warning("无法连接GPIB设备")
            print("  1. 检查设备地址是否正确")
            print("  2. 检查GPIB线缆连接")
            print("  3. 检查设备电源")
            print("  4. 运行深度修复脚本: ./scripts/linux_gpib_deep_fix.sh")
        
        print(f"\n{Colors.BOLD}完成时间: {time.strftime('%Y-%m-%d %H:%M:%S')}{Colors.NC}\n")

def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Linux GPIB 综合测试')
    parser.add_argument('address', nargs='?', default='GPIB0::5::INSTR',
                       help='GPIB设备地址 (默认: GPIB0::5::INSTR)')
    
    args = parser.parse_args()
    
    # 检查是否为Linux
    if sys.platform != 'linux':
        print_error("此脚本仅适用于Linux系统")
        sys.exit(1)
    
    # 运行测试
    tester = LinuxGPIBTester(args.address)
    tester.run_all_tests()
    
    # 返回状态码
    if tester.passed_tests == tester.total_tests:
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == '__main__':
    main()
