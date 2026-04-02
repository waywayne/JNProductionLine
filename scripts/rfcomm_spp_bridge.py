#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RFCOMM SPP 桥接 — BlueZ D-Bus Profile API

方案（BlueZ 5 推荐方式，与 Android createRfcommSocketToServiceRecord 等效）：
  1. 通过 D-Bus 向 BlueZ 注册 SPP Profile（UUID 包含 7033）
  2. bluetoothctl connect 建立连接
  3. BlueZ 自动协商 RFCOMM，通过 D-Bus NewConnection 回调给我们 fd
  4. 双向桥接: stdin → fd, fd → stdout

优势：
  - BlueZ 自动处理 SDP 和 RFCOMM 通道协商
  - 不需要手动 rfcomm connect 或 socket connect
  - 不需要 /dev/rfcomm0 设备文件
  - 与三方工具使用相同的 BlueZ Profile 连接路径
"""

import sys
import os
import time
import subprocess
import threading
import select
import signal
import fcntl
import socket
import struct

# 尝试导入 dbus，如果失败则回退到 socket 方案
try:
    import dbus
    import dbus.service
    import dbus.mainloop.glib
    from gi.repository import GLib
    HAS_DBUS = True
except ImportError:
    HAS_DBUS = False

# RFCOMM socket constants (回退方案用)
AF_BLUETOOTH = 31
BTPROTO_RFCOMM = 3
SOL_BLUETOOTH = 274
BT_SECURITY = 4
BT_SECURITY_LOW = 1

def log(msg):
    ts = time.strftime('%H:%M:%S')
    print(f"[{ts}] [SPP-BRIDGE] {msg}", file=sys.stderr, flush=True)


# === 全局状态 ===
_alive = threading.Event()
_fd = None  # RFCOMM 文件描述符 (D-Bus 方案) 或 socket (回退方案)
_fd_ready = threading.Event()  # D-Bus 回调时设置
_fd_is_socket = False  # 标记是 socket 还是 fd
_mainloop = None


# =============================================
# 方案 A: BlueZ D-Bus Profile API
# =============================================

PROFILE_PATH = "/org/bluez/spp_profile"
SPP_UUID = "00007033-0000-1000-8000-00805f9b34fb"  # 设备自定义 SPP UUID (7033)

if HAS_DBUS:
    class SppProfile(dbus.service.Object):
        """BlueZ Profile1 接口实现"""

        @dbus.service.method("org.bluez.Profile1",
                             in_signature="", out_signature="")
        def Release(self):
            log("📴 Profile Released")

        @dbus.service.method("org.bluez.Profile1",
                             in_signature="oha{sv}", out_signature="")
        def NewConnection(self, path, fd, properties):
            global _fd
            _fd = fd.take()
            log(f"✅ NewConnection! device={path} fd={_fd}")

            # 设置非阻塞
            flags = fcntl.fcntl(_fd, fcntl.F_GETFL)
            fcntl.fcntl(_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

            _fd_ready.set()

        @dbus.service.method("org.bluez.Profile1",
                             in_signature="o", out_signature="")
        def RequestDisconnection(self, path):
            log(f"📴 RequestDisconnection: {path}")
            _alive.clear()


def register_spp_profile():
    """在 BlueZ 中注册 SPP Profile"""
    if not HAS_DBUS:
        return None
    try:
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
        bus = dbus.SystemBus()

        manager = dbus.Interface(
            bus.get_object("org.bluez", "/org/bluez"),
            "org.bluez.ProfileManager1"
        )

        profile = SppProfile(bus, PROFILE_PATH)

        opts = {
            "Name": dbus.String("SPP Bridge"),
            "Role": dbus.String("client"),
            "RequireAuthentication": dbus.Boolean(False),
            "RequireAuthorization": dbus.Boolean(False),
            "AutoConnect": dbus.Boolean(True),
        }

        # 注册标准 SPP UUID
        manager.RegisterProfile(PROFILE_PATH, SPP_UUID, opts)
        log(f"✅ SPP Profile 已注册 (UUID: {SPP_UUID})")
        return bus
    except Exception as e:
        log(f"⚠️ 注册 Profile 失败: {e}")
        return None


def dbus_connect(mac, timeout=30):
    """用 D-Bus Profile 方式连接"""
    global _mainloop, _fd_is_socket

    if not HAS_DBUS:
        return False

    log("📡 使用 BlueZ D-Bus Profile API 连接")

    bus = register_spp_profile()
    if bus is None:
        return False

    _fd_is_socket = False

    # 在后台线程运行 GLib MainLoop
    _mainloop = GLib.MainLoop()
    loop_thread = threading.Thread(target=_mainloop.run, daemon=True)
    loop_thread.start()

    # 确保蓝牙适配器开启
    try:
        subprocess.run(['sudo', 'hciconfig', 'hci0', 'up'],
                       stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL, timeout=5)
    except Exception:
        pass

    # 确保设备已配对
    try:
        r = subprocess.run(['bluetoothctl', 'info', mac],
                           capture_output=True, text=True, timeout=5)
        if 'Paired: yes' not in r.stdout:
            log("   设备未配对，尝试配对...")
            subprocess.run(['bluetoothctl', 'pair', mac],
                           capture_output=True, text=True, timeout=15)
            subprocess.run(['bluetoothctl', 'trust', mac],
                           capture_output=True, text=True, timeout=5)
    except Exception:
        pass

    # 获取设备的 D-Bus 对象路径
    mac_path = mac.replace(":", "_").upper()
    device_path = f"/org/bluez/hci0/dev_{mac_path}"
    log(f"   设备路径: {device_path}")

    for attempt in range(1, 4):
        log(f"🔗 第 {attempt}/3 次连接 {mac}")

        # 方法1: D-Bus ConnectProfile(uuid) — 强制 BR/EDR RFCOMM 连接
        try:
            device = dbus.Interface(
                bus.get_object("org.bluez", device_path),
                "org.bluez.Device1"
            )

            # 先确保通用连接（建立 ACL）
            try:
                log(f"   📶 D-Bus Device1.Connect() ...")
                device.Connect()
                time.sleep(1)
            except dbus.exceptions.DBusException as e:
                err_name = e.get_dbus_name() if hasattr(e, 'get_dbus_name') else str(e)
                log(f"   Connect(): {err_name}")
                # Already connected 不是错误
                if 'AlreadyConnected' not in str(err_name):
                    pass

            # 用 ConnectProfile 指定 UUID — 强制走 BR/EDR RFCOMM
            log(f"   📡 D-Bus ConnectProfile({SPP_UUID}) ...")
            device.ConnectProfile(SPP_UUID)
            log(f"   ConnectProfile 调用成功，等待 NewConnection ...")

        except dbus.exceptions.DBusException as e:
            err_msg = str(e)
            log(f"   ⚠️ D-Bus 调用失败: {err_msg[:200]}")
            # 尝试 bluetoothctl connect 作为备选
            try:
                r = subprocess.run(
                    ['bluetoothctl', 'connect', mac],
                    capture_output=True, text=True, timeout=15
                )
                log(f"   bluetoothctl: {(r.stdout + r.stderr).strip()[:200]}")
            except Exception:
                pass
        except Exception as e:
            log(f"   ⚠️ 异常: {e}")

        # 等待 D-Bus NewConnection 回调
        log(f"   ⏳ 等待 Profile NewConnection 回调 ({timeout}s)...")
        if _fd_ready.wait(timeout=timeout):
            log(f"✅ D-Bus Profile 连接成功! fd={_fd}")
            return True

        log(f"   ⚠️ 未收到 NewConnection 回调")
        time.sleep(2)

    # 停止 mainloop
    if _mainloop and _mainloop.is_running():
        _mainloop.quit()

    return False


# =============================================
# 方案 B: 回退方案 - bluetoothctl connect + RFCOMM socket
# 设置 BT_SECURITY_LOW 尝试绕过安全限制
# =============================================

def socket_connect(mac, channel, timeout=10):
    """用 RFCOMM socket 连接，设置 BT_SECURITY_LOW"""
    log(f"   🔗 RFCOMM socket CH{channel} (SECURITY_LOW)")

    try:
        s = socket.socket(AF_BLUETOOTH, socket.SOCK_STREAM, BTPROTO_RFCOMM)

        # 设置安全级别为 LOW（不要求加密/认证）
        try:
            s.setsockopt(SOL_BLUETOOTH, BT_SECURITY,
                         struct.pack('I', BT_SECURITY_LOW))
            log(f"      BT_SECURITY_LOW 已设置")
        except Exception as e:
            log(f"      ⚠️ 设置 BT_SECURITY_LOW 失败: {e}")

        s.settimeout(timeout)
        s.connect((mac, channel))
        s.settimeout(None)

        log(f"   ✅ CH{channel} 连接成功！")
        return s
    except Exception as e:
        log(f"   ⚠️ CH{channel} 失败: {e}")
        try:
            s.close()
        except Exception:
            pass
        return None


def fallback_connect(mac, channel):
    """回退方案：bluetoothctl connect + RFCOMM socket + BT_SECURITY_LOW"""
    global _fd, _fd_is_socket

    log("📡 回退方案: bluetoothctl connect + RFCOMM socket (BT_SECURITY_LOW)")

    # 确保蓝牙适配器开启
    try:
        subprocess.run(['sudo', 'hciconfig', 'hci0', 'up'],
                       stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL, timeout=5)
    except Exception:
        pass

    # 确保配对
    try:
        r = subprocess.run(['bluetoothctl', 'info', mac],
                           capture_output=True, text=True, timeout=5)
        if 'Paired: yes' not in r.stdout:
            subprocess.run(['bluetoothctl', 'pair', mac],
                           capture_output=True, text=True, timeout=15)
            subprocess.run(['bluetoothctl', 'trust', mac],
                           capture_output=True, text=True, timeout=5)
    except Exception:
        pass

    for attempt in range(1, 4):
        log(f"🔗 === 第 {attempt}/3 轮连接 {mac} ===")

        # bluetoothctl connect 建立 ACL
        try:
            r = subprocess.run(
                ['bluetoothctl', 'connect', mac],
                capture_output=True, text=True, timeout=15
            )
            output = r.stdout + r.stderr
            log(f"   bluetoothctl: {output.strip()[:200]}")
        except Exception as e:
            log(f"   ⚠️ bluetoothctl connect: {e}")
            time.sleep(2)
            continue

        # SDP 查询通道
        sdp_channels = []
        try:
            r = subprocess.run(
                ['sdptool', 'browse', mac],
                capture_output=True, text=True, timeout=15
            )
            if r.stdout:
                blocks = r.stdout.split('Service Name:')
                for block in blocks:
                    if '7033' in block.lower() or '7033' in block.upper():
                        for line in block.split('\n'):
                            if 'Channel:' in line:
                                try:
                                    ch = int(line.split('Channel:')[1].strip())
                                    if ch not in sdp_channels:
                                        sdp_channels.append(ch)
                                        log(f"   SDP: UUID 7033 → CH{ch}")
                                except ValueError:
                                    pass
                if not sdp_channels:
                    for block in blocks:
                        if 'Serial Port' in block:
                            for line in block.split('\n'):
                                if 'Channel:' in line:
                                    try:
                                        ch = int(line.split('Channel:')[1].strip())
                                        if ch not in sdp_channels:
                                            sdp_channels.append(ch)
                                    except ValueError:
                                        pass
        except Exception:
            pass

        # 候选通道
        candidates = list(sdp_channels)
        if channel not in candidates:
            candidates.append(channel)
        for ch in [1, 2, 3, 4, 5, 6]:
            if ch not in candidates:
                candidates.append(ch)

        log(f"📋 候选通道: {candidates}")

        for ch in candidates:
            retries = 3 if ch in sdp_channels else 1
            for retry in range(1, retries + 1):
                if retries > 1:
                    log(f"   � CH{ch} 第 {retry}/{retries} 次")
                s = socket_connect(mac, ch)
                if s:
                    _fd = s
                    _fd_is_socket = True
                    _fd_ready.set()
                    return True
                if retry < retries:
                    time.sleep(1)

        time.sleep(2)

    return False


# =============================================
# 通用读写线程
# =============================================

def cleanup():
    """清理旧的桥接进程"""
    my_pid = os.getpid()
    log("🧹 清理旧连接...")

    for pattern in ['rfcomm_spp_bridge.py', 'rfcomm_stable.py',
                    'rfcomm_socket_simple.py', 'rfcomm_bind_bridge.py']:
        try:
            r = subprocess.run(['pgrep', '-f', pattern],
                               capture_output=True, text=True, timeout=2)
            if r.returncode == 0:
                for line in r.stdout.strip().split('\n'):
                    if not line.strip():
                        continue
                    try:
                        pid = int(line.strip())
                        if pid != my_pid:
                            os.kill(pid, 9)
                            log(f"   杀死旧桥接 PID {pid}")
                    except Exception:
                        pass
        except Exception:
            pass

    try:
        subprocess.run(['sudo', 'pkill', '-9', '-f', 'rfcomm connect'],
                       stderr=subprocess.DEVNULL, timeout=2)
    except Exception:
        pass
    try:
        subprocess.run(['sudo', 'rfcomm', 'release', 'all'],
                       stderr=subprocess.DEVNULL, timeout=2)
    except Exception:
        pass

    time.sleep(0.3)
    log("🧹 清理完成")


def reader_thread():
    """fd/socket → stdout"""
    global _fd
    n = 0
    total = 0
    log("📡 读取线程启动")

    try:
        while _alive.is_set():
            if _fd_is_socket:
                # socket 方式
                try:
                    rlist, _, _ = select.select([_fd], [], [], 0.2)
                except (OSError, ValueError):
                    if not _alive.is_set():
                        break
                    continue
                if not rlist:
                    continue
                try:
                    data = _fd.recv(4096)
                except socket.timeout:
                    continue
                except OSError as e:
                    if not _alive.is_set():
                        break
                    log(f"❌ 读取错误: {e}")
                    _alive.clear()
                    break
            else:
                # fd 方式
                try:
                    rlist, _, _ = select.select([_fd], [], [], 0.2)
                except (OSError, ValueError):
                    if not _alive.is_set():
                        break
                    continue
                if not rlist:
                    continue
                try:
                    data = os.read(_fd, 4096)
                except OSError as e:
                    if e.errno == 11:  # EAGAIN
                        continue
                    if not _alive.is_set():
                        break
                    log(f"❌ 读取错误: {e}")
                    _alive.clear()
                    break

            if not data:
                log("📴 远端关闭连接")
                _alive.clear()
                break

            n += 1
            total += len(data)
            hex_preview = ' '.join(f'{b:02X}' for b in data[:64])
            log(f"📥 #{n} [{len(data)}B 累计{total}B]: {hex_preview}")

            try:
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
            except BrokenPipeError:
                log("📴 stdout 管道断裂")
                _alive.clear()
                break
    except Exception as e:
        log(f"❌ 读取线程异常: {e}")
        _alive.clear()
    finally:
        log(f"📊 读取结束: {n}次 {total}B")


def writer_thread():
    """stdin → fd/socket"""
    global _fd
    n = 0
    total = 0
    log("📡 写入线程启动")

    try:
        stdin_fd = sys.stdin.fileno()
        flags = fcntl.fcntl(stdin_fd, fcntl.F_GETFL)
        fcntl.fcntl(stdin_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

        while _alive.is_set():
            try:
                rlist, _, _ = select.select([sys.stdin], [], [], 0.2)
            except (ValueError, OSError):
                if not _alive.is_set():
                    break
                continue

            if not rlist:
                continue

            try:
                data = sys.stdin.buffer.read(4096)
            except (OSError, IOError):
                continue

            if not data:
                continue

            n += 1
            total += len(data)
            hex_preview = ' '.join(f'{b:02X}' for b in data[:64])
            log(f"📨 #{n} [{len(data)}B]: {hex_preview}")

            if _fd_is_socket:
                try:
                    _fd.sendall(data)
                    log(f"✅ 已发送 {len(data)}B")
                except OSError as e:
                    log(f"❌ 发送错误: {e}")
                    _alive.clear()
                    return
            else:
                offset = 0
                while offset < len(data) and _alive.is_set():
                    try:
                        written = os.write(_fd, data[offset:])
                        offset += written
                    except OSError as e:
                        if e.errno == 11:  # EAGAIN
                            time.sleep(0.01)
                            continue
                        log(f"❌ 写入错误: {e}")
                        _alive.clear()
                        return
                log(f"✅ 已发送 {len(data)}B")

    except Exception as e:
        log(f"❌ 写入线程异常: {e}")
        _alive.clear()
    finally:
        log(f"📊 发送结束: {n}次 {total}B")


def main():
    global _fd

    if len(sys.argv) != 3:
        print("用法: rfcomm_spp_bridge.py <MAC> <通道>", file=sys.stderr)
        sys.exit(1)

    mac = sys.argv[1]
    ch = int(sys.argv[2])

    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    log("SPP 桥接 (BlueZ D-Bus Profile + 回退)")
    log(f"  MAC: {mac}")
    log(f"  默认通道: {ch}")
    log(f"  D-Bus 可用: {HAS_DBUS}")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # 信号处理
    def on_signal(signum, _):
        log(f"收到信号 {signum}，准备退出")
        _alive.clear()
    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)

    # 1. 清理旧连接
    cleanup()

    # 2. 尝试连接
    connected = False

    # 方案 A: D-Bus Profile
    if HAS_DBUS:
        log("📡 尝试方案 A: BlueZ D-Bus Profile API")
        connected = dbus_connect(mac, timeout=15)

    # 方案 B: 回退到 bluetoothctl connect + RFCOMM socket (BT_SECURITY_LOW)
    if not connected:
        if HAS_DBUS:
            log("⚠️ D-Bus Profile 未成功，回退到方案 B")
        log("📡 尝试方案 B: bluetoothctl + RFCOMM socket (BT_SECURITY_LOW)")
        connected = fallback_connect(mac, ch)

    if not connected:
        log("❌ 无法建立 SPP 连接")
        sys.exit(1)

    _alive.set()

    log("✅ 连接已建立，开始双向数据传输")
    log("   连接将保持直到手动断开")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # 3. 启动读写线程
    t_read = threading.Thread(target=reader_thread, daemon=True)
    t_write = threading.Thread(target=writer_thread, daemon=True)
    t_read.start()
    t_write.start()

    # 4. 主线程等待
    try:
        while _alive.is_set():
            if not t_read.is_alive() and not t_write.is_alive():
                break
            time.sleep(0.2)
    except KeyboardInterrupt:
        log("KeyboardInterrupt")

    _alive.clear()
    log("🔌 关闭连接...")

    try:
        if _fd_is_socket:
            _fd.close()
        else:
            os.close(_fd)
    except Exception:
        pass

    if _mainloop and _mainloop.is_running():
        _mainloop.quit()

    t_read.join(timeout=2)
    t_write.join(timeout=2)
    log("✅ 已退出")


if __name__ == "__main__":
    main()
