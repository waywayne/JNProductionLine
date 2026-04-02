#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RFCOMM SPP 桥接 — bluetoothctl connect + Python RFCOMM socket 直连

方案（与三方调试工具相同的连接方式）：
  1. bluetoothctl connect 建立 BR/EDR ACL 连接
  2. SDP 查询 UUID 7033 对应的 RFCOMM 通道号
  3. Python bluetooth.BluetoothSocket (RFCOMM) 直接连接（无需 rfcomm 命令）
  4. 双向桥接: stdin → socket, socket → stdout

优势：
  - 不需要 sudo rfcomm connect 命令
  - 不需要 /dev/rfcomm0 设备文件
  - 不需要等待设备文件出现
  - 连接速度与三方工具相同（<1s）
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

# RFCOMM socket constants
AF_BLUETOOTH = 31
BTPROTO_RFCOMM = 3

def log(msg):
    ts = time.strftime('%H:%M:%S')
    print(f"[{ts}] [SPP-BRIDGE] {msg}", file=sys.stderr, flush=True)


# === 全局状态 ===
_alive = threading.Event()
_sock = None  # RFCOMM socket


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

    # 释放残留 rfcomm（以防之前用过 rfcomm connect）
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


def ensure_paired(mac):
    """确保设备已配对和信任（不建立 profile 连接）"""
    log(f"� 检查配对状态: {mac}")

    # 确保蓝牙适配器开启
    try:
        subprocess.run(['sudo', 'hciconfig', 'hci0', 'up'],
                       stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL, timeout=5)
    except Exception:
        pass

    try:
        r = subprocess.run(
            ['bluetoothctl', 'info', mac],
            capture_output=True, text=True, timeout=5
        )
        if 'Paired: yes' in r.stdout:
            log(f"   ✅ 设备已配对")
            return True
        else:
            log(f"   设备未配对，尝试配对...")
            subprocess.run(['bluetoothctl', 'pair', mac],
                           capture_output=True, text=True, timeout=15)
            subprocess.run(['bluetoothctl', 'trust', mac],
                           capture_output=True, text=True, timeout=5)
            return True
    except Exception as e:
        log(f"   检查配对状态异常: {e}")
        return True  # 继续尝试


def ensure_disconnected_profile(mac):
    """确保 bluetoothctl 没有占用 profile 连接。
    bluetoothctl connect 会占用 SPP profile，导致后续 RFCOMM socket 被拒绝。
    """
    try:
        r = subprocess.run(
            ['bluetoothctl', 'info', mac],
            capture_output=True, text=True, timeout=5
        )
        if 'Connected: yes' in r.stdout:
            log(f"   ⚠️ 检测到 bluetoothctl profile 连接，断开以释放 SPP...")
            subprocess.run(['bluetoothctl', 'disconnect', mac],
                           capture_output=True, text=True, timeout=5)
            time.sleep(1)
            log(f"   ✅ 已释放 profile 连接")
    except Exception:
        pass


def ensure_acl(mac):
    """用 hcitool cc 建立纯 ACL 连接（不占用任何 profile）。
    这是关键：bluetoothctl connect 会占用 SPP profile 导致 Connection refused，
    而 hcitool cc 只建立底层 ACL 链路。
    """
    log(f"📶 建立纯 ACL 链路: {mac}")

    # 先断开可能存在的 bluetoothctl profile 连接
    ensure_disconnected_profile(mac)

    # hcitool cc 建立纯 ACL
    try:
        r = subprocess.run(
            ['sudo', 'hcitool', 'cc', mac],
            capture_output=True, text=True, timeout=10
        )
        log(f"   hcitool cc: {(r.stdout + r.stderr).strip()[:200] or '完成'}")
    except subprocess.TimeoutExpired:
        log(f"   ⚠️ hcitool cc 超时")
    except Exception as e:
        log(f"   ⚠️ hcitool cc: {e}")

    time.sleep(0.5)

    # 验证 ACL 是否建立
    try:
        r = subprocess.run(
            ['hcitool', 'con'],
            capture_output=True, text=True, timeout=5
        )
        if mac.upper() in r.stdout.upper() or mac.lower() in r.stdout.lower():
            log(f"   ✅ ACL 链路已建立")
            return True
        else:
            log(f"   ⚠️ ACL 链路状态不确定: {r.stdout.strip()[:200]}")
            # 仍然继续尝试 RFCOMM connect
            return True
    except Exception:
        return True


def sdp_find_spp_channel(mac, target_uuid='7033'):
    """通过 SDP 查询设备上 UUID 包含 target_uuid 的 SPP 服务的 RFCOMM 通道号。
    返回通道号列表，失败返回空列表。
    """
    log(f"🔍 SDP 查询 {mac}，目标 UUID: {target_uuid}")

    channels = []

    try:
        r = subprocess.run(
            ['sdptool', 'browse', mac],
            capture_output=True, text=True, timeout=15
        )
        output = r.stdout
        if output:
            log(f"   sdptool browse 返回 {len(output)} 字节")
            blocks = output.split('Service Name:')
            for block in blocks:
                if target_uuid.lower() in block.lower() or target_uuid.upper() in block.upper():
                    for line in block.split('\n'):
                        if 'Channel:' in line:
                            try:
                                ch = int(line.split('Channel:')[1].strip())
                                if ch not in channels:
                                    log(f"   ✅ SDP 找到: UUID 含 {target_uuid} → CH{ch}")
                                    channels.append(ch)
                            except ValueError:
                                pass
            if not channels:
                for block in blocks:
                    if 'Serial Port' in block or 'serial' in block.lower():
                        for line in block.split('\n'):
                            if 'Channel:' in line:
                                try:
                                    ch = int(line.split('Channel:')[1].strip())
                                    if ch not in channels:
                                        log(f"   📋 SDP Serial Port → CH{ch}")
                                        channels.append(ch)
                                except ValueError:
                                    pass
    except subprocess.TimeoutExpired:
        log(f"   ⚠️ sdptool browse 超时")
    except Exception as e:
        log(f"   ⚠️ sdptool browse 失败: {e}")

    if channels:
        log(f" SDP 发现通道: {channels}")
    else:
        log(f"⚠️ SDP 未发现目标通道")

    return channels


def rfcomm_socket_connect(mac, channel, connect_timeout=10):
    """用 Python RFCOMM socket 直接连接（与三方工具相同的方式）。
    返回 socket 或 None。
    """
    log(f"   🔗 RFCOMM socket 连接 {mac} CH{channel}")

    try:
        s = socket.socket(AF_BLUETOOTH, socket.SOCK_STREAM, BTPROTO_RFCOMM)
        s.settimeout(connect_timeout)

        s.connect((mac, channel))
        s.settimeout(None)

        log(f"   ✅ CH{channel} socket 连接成功！")
        return s

    except socket.timeout:
        log(f"   ⚠️ CH{channel} 连接超时")
        try:
            s.close()
        except Exception:
            pass
        return None
    except OSError as e:
        log(f"   ⚠️ CH{channel} 连接失败: {e}")
        try:
            s.close()
        except Exception:
            pass
        return None
    except Exception as e:
        log(f"   ⚠️ CH{channel} 异常: {e}")
        try:
            s.close()
        except Exception:
            pass
        return None


def connect_spp(mac, channel):
    """完整的 SPP 连接流程：
    1. 确保配对
    2. 释放可能的 bluetoothctl profile 占用
    3. hcitool cc 建立纯 ACL
    4. SDP 查询通道号
    5. RFCOMM socket 直连
    最多 3 轮重试。返回 socket 或 None。
    """
    max_rounds = 3

    # 先确保配对（只需做一次）
    ensure_paired(mac)

    for round_num in range(1, max_rounds + 1):
        log(f"🔗 === 第 {round_num}/{max_rounds} 轮连接 {mac} ===")

        # 步骤1: 建立纯 ACL 链路（不占用 profile）
        ensure_acl(mac)

        # 步骤2: SDP 查询通道号（只在第一轮查，后续复用）
        if round_num == 1:
            sdp_channels = sdp_find_spp_channel(mac)
        
        # 构建候选通道：SDP 结果优先 → 用户指定 → 常见通道
        candidates = []
        for ch in sdp_channels:
            if ch not in candidates:
                candidates.append(ch)
        if channel not in candidates:
            candidates.append(channel)
        for ch in [1, 2, 3, 4, 5, 6]:
            if ch not in candidates:
                candidates.append(ch)

        log(f"📋 候选通道: {candidates}")

        # 步骤3: 尝试每个通道
        for ch in candidates:
            retries = 3 if ch in sdp_channels else 1
            for retry in range(1, retries + 1):
                if retries > 1:
                    log(f"   🔄 CH{ch} 第 {retry}/{retries} 次")
                s = rfcomm_socket_connect(mac, ch)
                if s:
                    log(f"✅ RFCOMM 连接成功 CH{ch}")
                    return s
                if retry < retries:
                    time.sleep(1)

        log(f"⚠️ 第 {round_num} 轮所有通道都失败，等待后重试...")
        time.sleep(2)

    log(f"❌ 连接失败（{max_rounds} 轮尝试）")
    return None


def reader_thread(sock):
    """socket → stdout"""
    n = 0
    total = 0
    log("📡 读取线程启动")

    try:
        while _alive.is_set():
            try:
                rlist, _, _ = select.select([sock], [], [], 0.2)
            except (OSError, ValueError):
                if not _alive.is_set():
                    break
                continue

            if not rlist:
                continue

            try:
                data = sock.recv(4096)
            except socket.timeout:
                continue
            except OSError as e:
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


def writer_thread(sock):
    """stdin → socket"""
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

            try:
                sock.sendall(data)
                log(f"✅ 已发送 {len(data)}B")
            except OSError as e:
                log(f"❌ 发送错误: {e}")
                _alive.clear()
                return

    except Exception as e:
        log(f"❌ 写入线程异常: {e}")
        _alive.clear()
    finally:
        log(f"📊 发送结束: {n}次 {total}B")


def main():
    global _sock

    if len(sys.argv) != 3:
        print("用法: rfcomm_spp_bridge.py <MAC> <通道>", file=sys.stderr)
        sys.exit(1)

    mac = sys.argv[1]
    ch = int(sys.argv[2])

    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    log("SPP 桥接 (RFCOMM socket 直连模式)")
    log(f"  MAC: {mac}")
    log(f"  默认通道: {ch}")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # 信号处理
    def on_signal(signum, _):
        log(f"收到信号 {signum}，准备退出")
        _alive.clear()
    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)

    # 1. 清理旧连接
    cleanup()

    # 2. 连接 SPP（ACL → SDP → socket）
    _sock = connect_spp(mac, ch)
    if _sock is None:
        log("❌ 无法建立 SPP 连接")
        sys.exit(1)

    _alive.set()

    log("✅ 连接已建立，开始双向数据传输")
    log("   连接将保持直到手动断开")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # 3. 启动读写线程
    t_read = threading.Thread(target=reader_thread, args=(_sock,), daemon=True)
    t_write = threading.Thread(target=writer_thread, args=(_sock,), daemon=True)
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
        _sock.close()
    except Exception:
        pass

    t_read.join(timeout=2)
    t_write.join(timeout=2)
    log("✅ 已退出")


if __name__ == "__main__":
    main()
