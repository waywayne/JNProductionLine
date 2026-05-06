#!/usr/bin/env python3
"""
网络SCPI程控电源测试脚本
通过 lxi 命令行工具发送SCPI命令控制程控电源

使用前准备：
1. 确保程控电源已连接到局域网
2. 配置台式机静态IP（与程控电源在同一网段）
   sudo ip addr add 192.168.1.100/24 dev <网口名>
   sudo ip link set <网口名> up
3. 安装 lxi-tools：
   sudo apt-get install lxi-tools  (Ubuntu/Debian)
   或从源码编译: https://github.com/lxi-tools/lxi-tools

示例：
  python3 test_network_scpi_power_supply.py
"""

import subprocess
import shlex
import time
import sys

def run_scpi_command(ip, command):
    """通过调用 lxi 工具执行 SCPI 命令"""
    # 使用 shlex.quote 来安全地转义命令参数，防止注入风险
    full_command = f'lxi scpi --address {ip} {shlex.quote(command)}'
    try:
        # 执行命令，捕获输出，text=True 直接返回字符串
        result = subprocess.run(full_command, shell=True, capture_output=True, text=True, timeout=10)
        # 检查执行是否成功
        if result.returncode == 0:
            return result.stdout.strip()
        else:
            raise Exception(f"Command failed: {result.stderr}")
    except subprocess.TimeoutExpired:
        raise Exception("SCPI command timed out")
    except Exception as e:
        raise Exception(f"Error executing command: {e}")

def test_network_scpi_power_supply():
    """测试网络SCPI程控电源"""
    
    # 配置参数
    power_supply_ip = '192.168.1.13'
    
    print("=" * 60)
    print("网络SCPI程控电源测试 (使用 lxi 工具)")
    print("=" * 60)
    
    try:
        # 1. 检查 lxi 工具是否安装
        print("\n🔍 检查 lxi 工具...")
        try:
            result = subprocess.run(['which', 'lxi'], capture_output=True, text=True)
            if result.returncode == 0:
                lxi_path = result.stdout.strip()
                print(f"✅ lxi 工具已安装: {lxi_path}")
            else:
                print("❌ lxi 工具未安装")
                print("   请安装: sudo apt-get install lxi-tools")
                return False
        except Exception as e:
            print(f"❌ 检查 lxi 工具失败: {e}")
            return False
        
        # 2. 查询设备ID
        print(f"\n🔌 连接到程控电源: {power_supply_ip}")
        print("\n📟 查询设备ID...")
        idn = run_scpi_command(power_supply_ip, '*IDN?')
        print(f"✅ 设备ID: {idn}")
        
        # 3. 设置电压和电流
        print("\n⚡ 设置程控电源参数...")
        voltage = 12.5
        current = 1.0
        
        run_scpi_command(power_supply_ip, f'VOLT {voltage}')
        print(f"   设置电压: {voltage}V")
        
        run_scpi_command(power_supply_ip, f'CURR {current}')
        print(f"   设置电流限制: {current}A")
        
        # 4. 验证设置
        print("\n🔍 验证设置...")
        actual_voltage = run_scpi_command(power_supply_ip, 'VOLT?')
        actual_current = run_scpi_command(power_supply_ip, 'CURR?')
        print(f"   实际电压设置: {actual_voltage}V")
        print(f"   实际电流限制: {actual_current}A")
        
        # 5. 打开输出
        print("\n🔛 打开输出...")
        run_scpi_command(power_supply_ip, 'OUTP ON')
        time.sleep(0.5)
        
        output_state = run_scpi_command(power_supply_ip, 'OUTP?')
        print(f"   输出状态: {'ON' if output_state.strip() in ['1', 'ON'] else 'OFF'}")
        
        # 6. 测量电压和电流
        print("\n📊 测量输出...")
        measured_voltage = run_scpi_command(power_supply_ip, 'MEAS:VOLT?')
        measured_current = run_scpi_command(power_supply_ip, 'MEAS:CURR?')
        print(f"   测量电压: {float(measured_voltage):.3f}V")
        print(f"   测量电流: {float(measured_current) * 1000:.2f}mA")
        
        # 7. 多次采样测量电流（模拟充电电流测试）
        print("\n📈 多次采样测量电流...")
        sample_count = 10
        sample_rate = 10  # Hz
        samples = []
        
        for i in range(sample_count):
            current_str = run_scpi_command(power_supply_ip, 'MEAS:CURR?')
            current_val = float(current_str)
            samples.append(current_val)
            print(f"   样本 {i+1}/{sample_count}: {current_val * 1000:.2f}mA")
            
            if i < sample_count - 1:
                time.sleep(1.0 / sample_rate)
        
        # 计算平均值
        avg_current = sum(samples) / len(samples)
        print(f"\n📊 平均电流: {avg_current * 1000:.2f}mA")
        
        # 8. 关闭输出
        print("\n🔴 关闭输出...")
        run_scpi_command(power_supply_ip, 'OUTP OFF')
        time.sleep(0.5)
        
        output_state = run_scpi_command(power_supply_ip, 'OUTP?')
        print(f"   输出状态: {'ON' if output_state.strip() in ['1', 'ON'] else 'OFF'}")
        
        print("\n" + "=" * 60)
        print("✅ 测试完成！")
        print("=" * 60)
        
        return True
        
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        print("\n请检查:")
        print(f"  1. 程控电源IP地址是否正确: {power_supply_ip}")
        print("  2. 网络连接是否正常")
        print("  3. 台式机静态IP是否配置:")
        print("     sudo ip addr add 192.168.1.100/24 dev <网口名>")
        print("     sudo ip link set <网口名> up")
        print("  4. lxi-tools 是否正确安装:")
        print("     sudo apt-get install lxi-tools")
        print("  5. 程控电源是否支持SCPI over TCP/IP (VXI-11)")
        import traceback
        traceback.print_exc()
        return False

def show_network_config_guide():
    """显示网络配置指南"""
    print("\n" + "=" * 60)
    print("网络配置指南")
    print("=" * 60)
    print("\n1. 查看网口名称:")
    print("   ip link show")
    print("   或")
    print("   ifconfig")
    print("\n2. 配置静态IP（临时）:")
    print("   sudo ip addr add 192.168.1.100/24 dev <网口名>")
    print("   sudo ip link set <网口名> up")
    print("\n3. 验证配置:")
    print("   ip addr show <网口名>")
    print("\n4. 测试连通性:")
    print("   ping 192.168.1.13")
    print("\n5. 删除静态IP（如需要）:")
    print("   sudo ip addr del 192.168.1.100/24 dev <网口名>")
    print("\n" + "=" * 60)

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == '--help':
        show_network_config_guide()
    else:
        success = test_network_scpi_power_supply()
        sys.exit(0 if success else 1)
