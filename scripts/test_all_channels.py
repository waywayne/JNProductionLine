#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
测试蓝牙设备的所有 RFCOMM Channel
"""

import sys
import argparse

# 设置标准输出为 UTF-8 编码（Windows 兼容）
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

try:
    import bluetooth
except ImportError:
    print("❌ 错误: 未安装 PyBluez")
    print("请运行: pip install pybluez")
    sys.exit(1)


def test_all_channels(device_address, start_channel=1, end_channel=30):
    """测试设备的所有 RFCOMM Channel"""
    print("=" * 60)
    print(f"🔍 测试设备: {device_address}")
    print(f"   Channel 范围: {start_channel} - {end_channel}")
    print("=" * 60)
    print()
    
    successful_channels = []
    
    for channel in range(start_channel, end_channel + 1):
        print(f"[{channel:2d}/{end_channel}] 测试 Channel {channel}...", end=" ", flush=True)
        
        try:
            # 创建蓝牙套接字
            sock = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
            
            # 设置超时（3秒）
            sock.settimeout(3)
            
            # 尝试连接
            sock.connect((device_address, channel))
            
            # 连接成功
            print("✅ 成功!")
            successful_channels.append(channel)
            
            # 关闭连接
            sock.close()
            
        except bluetooth.BluetoothError as e:
            error_msg = str(e).lower()
            if "connection refused" in error_msg or "refused" in error_msg:
                print("❌ 拒绝连接")
            elif "timeout" in error_msg or "timed out" in error_msg:
                print("⏱️  超时")
            elif "host is down" in error_msg or "down" in error_msg:
                print("📴 主机未响应")
            else:
                print(f"❌ 失败: {e}")
        except Exception as e:
            print(f"❌ 异常: {e}")
    
    print()
    print("=" * 60)
    print("📊 测试结果")
    print("=" * 60)
    
    if successful_channels:
        print(f"✅ 找到 {len(successful_channels)} 个可用 Channel:")
        print()
        for ch in successful_channels:
            print(f"   Channel {ch}")
        print()
        print("💡 建议使用第一个可用 Channel:")
        print(f"   python scripts/bluetooth_spp_test.py --connect {device_address} --channel {successful_channels[0]} --test mac")
    else:
        print("❌ 没有找到任何可用的 Channel")
        print()
        print("可能的原因:")
        print("   1. 设备未开启或不在范围内")
        print("   2. 设备未启用 SPP 服务")
        print("   3. 设备被其他程序占用")
        print("   4. 蓝牙权限不足")
        print()
        print("建议:")
        print("   1. 确认设备已开启且在范围内")
        print("   2. 在 Windows 设置中断开并重新连接设备")
        print("   3. 查找蓝牙 COM 端口: find_bluetooth_com.bat")
        print("   4. 使用 COM 端口代替蓝牙 SPP")
    
    print("=" * 60)
    
    return successful_channels


def main():
    parser = argparse.ArgumentParser(description='测试蓝牙设备的所有 RFCOMM Channel')
    parser.add_argument('device_address', help='蓝牙设备地址 (如: 48:08:EB:60:00:00)')
    parser.add_argument('--start', type=int, default=1, help='起始 Channel (默认: 1)')
    parser.add_argument('--end', type=int, default=30, help='结束 Channel (默认: 30)')
    
    args = parser.parse_args()
    
    try:
        test_all_channels(args.device_address, args.start, args.end)
    except KeyboardInterrupt:
        print("\n\n⚠️  用户中断")
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
