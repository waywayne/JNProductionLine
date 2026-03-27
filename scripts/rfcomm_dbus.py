#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
方案5: D-Bus BlueZ API 直接连接
使用 D-Bus 与 BlueZ 守护进程通信，无需 sudo 权限
"""

import sys
import os
import time
import threading
import select
import dbus
import dbus.mainloop.glib
from gi.repository import GLib

def log(message):
    """输出日志到 stderr"""
    print(f"[DBUS-SPP] {message}", file=sys.stderr, flush=True)

class BlueZSPP:
    """BlueZ D-Bus SPP 连接器"""
    
    BLUEZ_SERVICE = 'org.bluez'
    ADAPTER_INTERFACE = 'org.bluez.Adapter1'
    DEVICE_INTERFACE = 'org.bluez.Device1'
    PROFILE_MANAGER = 'org.bluez.ProfileManager1'
    
    SPP_UUID = '00001101-0000-1000-8000-00805f9b34fb'
    
    def __init__(self, mac_address, channel=5):
        self.mac_address = mac_address
        self.channel = channel
        self.bus = None
        self.adapter = None
        self.device = None
        self.fd = None
        self.mainloop = None
        self.connected = False
        self.keep_alive = threading.Event()
        self.keep_alive.set()
        
    def init_dbus(self):
        """初始化 D-Bus 连接"""
        try:
            dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
            self.bus = dbus.SystemBus()
            log("✅ D-Bus 系统总线已连接")
            return True
        except Exception as e:
            log(f"❌ D-Bus 初始化失败: {e}")
            return False
    
    def get_adapter(self):
        """获取蓝牙适配器"""
        try:
            manager = dbus.Interface(
                self.bus.get_object(self.BLUEZ_SERVICE, '/'),
                'org.freedesktop.DBus.ObjectManager'
            )
            
            objects = manager.GetManagedObjects()
            
            for path, interfaces in objects.items():
                if self.ADAPTER_INTERFACE in interfaces:
                    self.adapter = dbus.Interface(
                        self.bus.get_object(self.BLUEZ_SERVICE, path),
                        self.ADAPTER_INTERFACE
                    )
                    log(f"✅ 找到蓝牙适配器: {path}")
                    return True
            
            log("❌ 未找到蓝牙适配器")
            return False
        except Exception as e:
            log(f"❌ 获取适配器失败: {e}")
            return False
    
    def get_device(self):
        """获取目标设备"""
        try:
            # 将 MAC 地址转换为 D-Bus 路径格式
            device_path = f"/org/bluez/hci0/dev_{self.mac_address.replace(':', '_')}"
            
            self.device = dbus.Interface(
                self.bus.get_object(self.BLUEZ_SERVICE, device_path),
                self.DEVICE_INTERFACE
            )
            
            # 获取设备属性
            props = dbus.Interface(
                self.bus.get_object(self.BLUEZ_SERVICE, device_path),
                'org.freedesktop.DBus.Properties'
            )
            
            name = props.Get(self.DEVICE_INTERFACE, 'Name')
            paired = props.Get(self.DEVICE_INTERFACE, 'Paired')
            connected = props.Get(self.DEVICE_INTERFACE, 'Connected')
            
            log(f"✅ 找到设备: {name}")
            log(f"   已配对: {paired}")
            log(f"   已连接: {connected}")
            
            return True
        except dbus.exceptions.DBusException as e:
            log(f"❌ 设备不存在或未配对: {e}")
            return False
    
    def connect_device(self):
        """连接设备"""
        try:
            log("🔗 正在连接设备...")
            self.device.Connect()
            time.sleep(2)
            log("✅ 设备已连接")
            return True
        except dbus.exceptions.DBusException as e:
            if 'Already Connected' in str(e):
                log("✅ 设备已经连接")
                return True
            log(f"❌ 连接失败: {e}")
            return False
    
    def connect_serial(self):
        """连接串口服务"""
        try:
            log("🔗 正在连接 SPP 服务...")
            
            # 使用 ConnectProfile 连接 SPP
            self.device.ConnectProfile(self.SPP_UUID)
            time.sleep(1)
            
            log("✅ SPP 服务已连接")
            self.connected = True
            return True
        except dbus.exceptions.DBusException as e:
            log(f"❌ SPP 连接失败: {e}")
            return False
    
    def run(self):
        """运行主循环"""
        if not self.init_dbus():
            return False
        
        if not self.get_adapter():
            return False
        
        if not self.get_device():
            return False
        
        if not self.connect_device():
            return False
        
        if not self.connect_serial():
            return False
        
        log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        log("✅ D-Bus SPP 连接成功")
        log("   注意: D-Bus 方式需要配合 rfcomm 使用")
        log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        # 保持连接
        while self.keep_alive.is_set():
            time.sleep(1)
        
        return True
    
    def disconnect(self):
        """断开连接"""
        self.keep_alive.clear()
        if self.device:
            try:
                self.device.Disconnect()
                log("🔌 设备已断开")
            except:
                pass

def main():
    if len(sys.argv) != 3:
        print("用法: rfcomm_dbus.py <MAC地址> <通道>", file=sys.stderr)
        sys.exit(1)
    
    mac_address = sys.argv[1]
    channel = int(sys.argv[2])
    
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    log("D-Bus BlueZ SPP 连接模式")
    log(f"MAC: {mac_address}")
    log(f"通道: {channel}")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    spp = BlueZSPP(mac_address, channel)
    
    try:
        if spp.run():
            log("连接保持中...")
        else:
            sys.exit(1)
    except KeyboardInterrupt:
        log("收到中断信号")
    finally:
        spp.disconnect()
        log("✅ 清理完成")

if __name__ == "__main__":
    main()
