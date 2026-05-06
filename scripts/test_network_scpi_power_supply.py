#!/usr/bin/env python3
"""
网络SCPI程控电源测试脚本
通过TCP/IP Socket直接发送SCPI命令控制程控电源

使用前准备：
1. 确保程控电源已连接到局域网
2. 配置台式机静态IP（与程控电源在同一网段）
   sudo ip addr add 192.168.1.100/24 dev <网口名>
   sudo ip link set <网口名> up
3. 安装依赖：pip install pyvisa pyvisa-py

示例：
  python3 test_network_scpi_power_supply.py
"""

import pyvisa
import time
import sys

def test_network_scpi_power_supply():
    """测试网络SCPI程控电源"""
    
    # 配置参数
    power_supply_ip = '192.168.1.13'
    power_supply_port = 5025
    
    print("=" * 60)
    print("网络SCPI程控电源测试")
    print("=" * 60)
    
    try:
        # 1. 初始化资源管理器（使用pyvisa-py后端）
        print("\n📡 初始化 PyVISA 资源管理器 (@py 后端)...")
        rm = pyvisa.ResourceManager('@py')
        print(f"✅ 资源管理器初始化成功: {rm}")
        
        # 2. 列出可用资源（可选）
        print("\n🔍 扫描可用资源...")
        try:
            resources = rm.list_resources()
            print(f"   可用资源: {resources}")
        except Exception as e:
            print(f"   ⚠️ 扫描资源失败: {e}")
            print("   继续使用直接拼接的资源地址...")
        
        # 3. 拼接资源地址
        instrument_address = f'TCPIP0::{power_supply_ip}::{power_supply_port}::SOCKET'
        print(f"\n🔌 连接到程控电源: {instrument_address}")
        
        # 4. 打开资源
        inst = rm.open_resource(instrument_address)
        print("✅ 程控电源连接成功")
        
        # 5. 配置超时和终止符
        inst.timeout = 5000  # 5秒超时
        inst.write_termination = '\n'
        inst.read_termination = '\n'
        print(f"   超时: {inst.timeout}ms")
        print(f"   写终止符: \\n")
        print(f"   读终止符: \\n")
        
        # 6. 查询设备ID
        print("\n📟 查询设备ID...")
        idn = inst.query('*IDN?')
        print(f"✅ 设备ID: {idn}")
        
        # 7. 设置电压和电流
        print("\n⚡ 设置程控电源参数...")
        voltage = 12.5
        current = 1.0
        
        inst.write(f'VOLT {voltage}')
        print(f"   设置电压: {voltage}V")
        
        inst.write(f'CURR {current}')
        print(f"   设置电流限制: {current}A")
        
        # 8. 验证设置
        print("\n🔍 验证设置...")
        actual_voltage = inst.query('VOLT?')
        actual_current = inst.query('CURR?')
        print(f"   实际电压设置: {actual_voltage}V")
        print(f"   实际电流限制: {actual_current}A")
        
        # 9. 打开输出
        print("\n🔛 打开输出...")
        inst.write('OUTP ON')
        time.sleep(0.5)
        
        output_state = inst.query('OUTP?')
        print(f"   输出状态: {'ON' if output_state.strip() in ['1', 'ON'] else 'OFF'}")
        
        # 10. 测量电压和电流
        print("\n📊 测量输出...")
        measured_voltage = inst.query('MEAS:VOLT?')
        measured_current = inst.query('MEAS:CURR?')
        print(f"   测量电压: {float(measured_voltage):.3f}V")
        print(f"   测量电流: {float(measured_current) * 1000:.2f}mA")
        
        # 11. 多次采样测量电流（模拟充电电流测试）
        print("\n📈 多次采样测量电流...")
        sample_count = 10
        sample_rate = 10  # Hz
        samples = []
        
        for i in range(sample_count):
            current_str = inst.query('MEAS:CURR?')
            current_val = float(current_str)
            samples.append(current_val)
            print(f"   样本 {i+1}/{sample_count}: {current_val * 1000:.2f}mA")
            
            if i < sample_count - 1:
                time.sleep(1.0 / sample_rate)
        
        # 计算平均值
        avg_current = sum(samples) / len(samples)
        print(f"\n📊 平均电流: {avg_current * 1000:.2f}mA")
        
        # 12. 关闭输出
        print("\n🔴 关闭输出...")
        inst.write('OUTP OFF')
        time.sleep(0.5)
        
        output_state = inst.query('OUTP?')
        print(f"   输出状态: {'ON' if output_state.strip() in ['1', 'ON'] else 'OFF'}")
        
        # 13. 关闭连接
        print("\n🔌 断开连接...")
        inst.close()
        print("✅ 程控电源已断开")
        
        print("\n" + "=" * 60)
        print("✅ 测试完成！")
        print("=" * 60)
        
        return True
        
    except pyvisa.errors.VisaIOError as e:
        print(f"\n❌ VISA IO 错误: {e}")
        print("\n请检查:")
        print(f"  1. 程控电源IP地址是否正确: {power_supply_ip}")
        print(f"  2. 程控电源端口是否正确: {power_supply_port}")
        print("  3. 网络连接是否正常")
        print("  4. 台式机静态IP是否配置:")
        print("     sudo ip addr add 192.168.1.100/24 dev <网口名>")
        print("     sudo ip link set <网口名> up")
        print("  5. 程控电源是否支持SCPI over TCP/IP")
        return False
        
    except Exception as e:
        print(f"\n❌ 未知错误: {e}")
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
