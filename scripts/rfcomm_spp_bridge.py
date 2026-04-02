#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
极简 RFCOMM SPP 桥接 — 使用 rfcomm connect 命令

方案：
  1. sudo rfcomm connect /dev/rfcomm0 <MAC> <CH>  (后台运行，建立真正的 RFCOMM 连接)
  2. 等待 /dev/rfcomm0 设备文件出现并可读写
  3. 双向桥接: stdin → /dev/rfcomm0, /dev/rfcomm0 → stdout
  4. 连接保持直到手动断开

这是 Linux 上最标准的 RFCOMM 连接方式，与三方调试工具使用相同的内核路径。
"""

import sys
import os
import time
import subprocess
import threading
import select
import signal
import fcntl

def log(msg):
    ts = time.strftime('%H:%M:%S')
    print(f"[{ts}] [SPP-BRIDGE] {msg}", file=sys.stderr, flush=True)


# === 全局状态 ===
_alive = threading.Event()
_rfcomm_proc = None  # rfcomm connect 子进程
_device_fd = None


def cleanup():
    """清理旧的 rfcomm 连接和进程"""
    my_pid = os.getpid()
    log("🧹 清理旧连接...")

    # 1. 杀死旧的 Python 桥接进程
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

    # 2. 杀死旧的 rfcomm connect 进程
    try:
        subprocess.run(['pkill', '-9', '-f', 'rfcomm connect'],
                       stderr=subprocess.DEVNULL, timeout=2)
    except Exception:
        pass

    # 3. 释放 rfcomm 设备
    try:
        subprocess.run(['sudo', 'rfcomm', 'release', 'all'],
                       stderr=subprocess.DEVNULL, timeout=2)
    except Exception:
        pass

    time.sleep(0.5)
    log("🧹 清理完成")


def bt_connect(mac, timeout=15):
    """用 bluetoothctl connect 建立 BR/EDR ACL 连接。
    这是三方工具能连上的关键：先建立 ACL，再做 RFCOMM。
    """
    log(f"📶 建立 BT ACL 连接: {mac}")

    # 先确保蓝牙适配器开启
    try:
        subprocess.run(['sudo', 'hciconfig', 'hci0', 'up'],
                       stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL, timeout=5)
    except Exception:
        pass

    # 确保设备已配对（信任）
    try:
        r = subprocess.run(
            ['bluetoothctl', 'info', mac],
            capture_output=True, text=True, timeout=5
        )
        if 'Paired: yes' in r.stdout:
            log(f"   设备已配对")
        else:
            log(f"   设备未配对，尝试配对...")
            subprocess.run(['bluetoothctl', 'pair', mac],
                           capture_output=True, text=True, timeout=15)
            subprocess.run(['bluetoothctl', 'trust', mac],
                           capture_output=True, text=True, timeout=5)
    except Exception as e:
        log(f"   检查配对状态异常: {e}")

    # bluetoothctl connect 建立 ACL
    try:
        r = subprocess.run(
            ['bluetoothctl', 'connect', mac],
            capture_output=True, text=True, timeout=timeout
        )
        output = r.stdout + r.stderr
        log(f"   bluetoothctl connect: {output.strip()[:200]}")
        if 'Connection successful' in output:
            log(f"✅ ACL 连接成功")
            return True
        else:
            log(f"⚠️ ACL 连接结果不确定")
            # 即使输出不含“Connection successful”，可能已经连上，继续尝试
            return True
    except subprocess.TimeoutExpired:
        log(f"⚠️ bluetoothctl connect 超时")
        return False
    except Exception as e:
        log(f"❌ bluetoothctl connect 失败: {e}")
        return False


def sdp_find_spp_channel(mac, target_uuid='7033'):
    """通过 SDP 查询设备上 UUID 包含 target_uuid 的 SPP 服务的 RFCOMM 通道号。
    返回通道号列表（可能有多个），失败返回空列表。
    """
    log(f"🔍 SDP 查询 {mac}，目标 UUID: {target_uuid}")

    channels = []

    # 方法1: sdptool browse
    try:
        r = subprocess.run(
            ['sdptool', 'browse', mac],
            capture_output=True, text=True, timeout=15
        )
        output = r.stdout
        if output:
            log(f"   sdptool browse 返回 {len(output)} 字节")
            # 按 Service 块分割
            blocks = output.split('Service Name:')
            for block in blocks:
                # 查找包含目标 UUID 的块
                if target_uuid.lower() in block.lower() or target_uuid.upper() in block.upper():
                    # 提取 Channel
                    for line in block.split('\n'):
                        if 'Channel:' in line:
                            try:
                                ch = int(line.split('Channel:')[1].strip())
                                log(f"   ✅ SDP 找到: UUID 含 {target_uuid} → CH{ch}")
                                channels.append(ch)
                            except ValueError:
                                pass
            # 如果没找到目标 UUID，尝试查找所有 Serial Port 服务
            if not channels:
                for block in blocks:
                    if 'Serial Port' in block or 'serial' in block.lower():
                        for line in block.split('\n'):
                            if 'Channel:' in line:
                                try:
                                    ch = int(line.split('Channel:')[1].strip())
                                    log(f"   📋 SDP Serial Port → CH{ch}")
                                    channels.append(ch)
                                except ValueError:
                                    pass
            # 如果还是没有，提取所有 RFCOMM 通道
            if not channels:
                for line in output.split('\n'):
                    if 'Channel:' in line:
                        try:
                            ch = int(line.split('Channel:')[1].strip())
                            if ch not in channels:
                                channels.append(ch)
                        except ValueError:
                            pass
                if channels:
                    log(f"   📋 SDP 所有通道: {channels}")
    except subprocess.TimeoutExpired:
        log(f"   ⚠️ sdptool browse 超时")
    except Exception as e:
        log(f"   ⚠️ sdptool browse 失败: {e}")

    # 方法2: sdptool search SP（如果方法1没结果）
    if not channels:
        try:
            r = subprocess.run(
                ['sdptool', 'search', '--bdaddr', mac, 'SP'],
                capture_output=True, text=True, timeout=15
            )
            output = r.stdout
            if output:
                for line in output.split('\n'):
                    if 'Channel:' in line:
                        try:
                            ch = int(line.split('Channel:')[1].strip())
                            if ch not in channels:
                                channels.append(ch)
                                log(f"   📋 sdptool search SP → CH{ch}")
                        except ValueError:
                            pass
        except Exception as e:
            log(f"   ⚠️ sdptool search 失败: {e}")

    if channels:
        log(f"🔍 SDP 发现通道: {channels}")
    else:
        log(f"⚠️ SDP 未发现任何 RFCOMM 通道")

    return channels


def try_rfcomm_connect(mac, channel, dev='/dev/rfcomm0'):
    """尝试用指定通道号做 rfcomm connect。
    成功（进程存活）返回 True，失败返回 False。
    """
    global _rfcomm_proc

    # 释放之前残留的绑定
    try:
        subprocess.run(['sudo', 'rfcomm', 'release', 'all'],
                       stderr=subprocess.DEVNULL, timeout=2)
    except Exception:
        pass
    time.sleep(0.3)

    log(f"   🔗 rfcomm connect {dev} {mac} CH{channel}")
    try:
        _rfcomm_proc = subprocess.Popen(
            ['sudo', 'rfcomm', 'connect', dev, mac, str(channel)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        log(f"      PID: {_rfcomm_proc.pid}")
    except Exception as e:
        log(f"   ❌ 启动失败: {e}")
        return False

    # 等待结果：成功时进程不退出，失败时立即退出
    time.sleep(3)

    if _rfcomm_proc.poll() is not None:
        try:
            stderr_out = _rfcomm_proc.stderr.read().decode('utf-8', errors='replace').strip()
            if stderr_out:
                log(f"      [rfcomm] {stderr_out}")
        except Exception:
            pass
        log(f"   ⚠️ CH{channel} 失败 (退出码: {_rfcomm_proc.returncode})")
        _rfcomm_proc = None
        return False

    # 进程还在 = 连接成功
    log(f"   ✅ CH{channel} 连接成功！")

    # 启动后台线程读取 rfcomm connect 输出
    def read_rfcomm_output():
        try:
            for line in _rfcomm_proc.stderr:
                text = line.decode('utf-8', errors='replace').strip()
                if text:
                    log(f"   [rfcomm] {text}")
        except Exception:
            pass
    threading.Thread(target=read_rfcomm_output, daemon=True).start()

    def read_rfcomm_stdout():
        try:
            for line in _rfcomm_proc.stdout:
                text = line.decode('utf-8', errors='replace').strip()
                if text:
                    log(f"   [rfcomm] {text}")
        except Exception:
            pass
    threading.Thread(target=read_rfcomm_stdout, daemon=True).start()

    return True


def start_rfcomm_connect(mac, channel, dev='/dev/rfcomm0'):
    """
    1. bluetoothctl connect 建立 ACL
    2. SDP 查询 UUID 7033 对应的 RFCOMM 通道号
    3. 尝试 SDP 发现的通道号 + 用户指定的通道号 + 常见通道号
    包含重试逻辑：最多 3 轮。
    """
    max_rounds = 3
    for round_num in range(1, max_rounds + 1):
        log(f"🔗 === 第 {round_num}/{max_rounds} 轮连接 {mac} ===")

        # 步骤1: bluetoothctl connect 建立 ACL
        bt_ok = bt_connect(mac)
        if not bt_ok:
            log(f"   ACL 连接失败，重试...")
            time.sleep(2)
            continue

        time.sleep(1)

        # 步骤2: SDP 查询通道号
        sdp_channels = sdp_find_spp_channel(mac)

        # 构建候选通道列表：SDP 结果优先 → 用户指定 → 常见通道
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

        # 步骤3: 依次尝试每个通道
        for ch in candidates:
            if try_rfcomm_connect(mac, ch, dev):
                log(f"✅ rfcomm connect 运行中，连接已建立 (CH{ch})")
                return True
            time.sleep(1)

        log(f"⚠️ 第 {round_num} 轮所有通道都失败，等待后重试...")
        time.sleep(3)

    log(f"❌ 连接失败（{max_rounds} 轮尝试）")
    return False


def wait_for_device(dev='/dev/rfcomm0', timeout=60):
    """等待设备文件出现并可打开"""
    log(f"⏳ 等待设备文件 {dev} ...")

    start = time.time()
    while time.time() - start < timeout:
        # 检查 rfcomm connect 进程是否还活着
        if _rfcomm_proc and _rfcomm_proc.poll() is not None:
            rc = _rfcomm_proc.returncode
            log(f"❌ rfcomm connect 进程已退出 (退出码: {rc})")
            return None

        if os.path.exists(dev):
            # 设备文件存在，尝试打开
            try:
                fd = os.open(dev, os.O_RDWR | os.O_NONBLOCK)
                log(f"✅ 设备文件已打开: {dev}")
                return fd
            except OSError as e:
                log(f"   设备文件存在但无法打开: {e}，重试...")
                time.sleep(1)
        else:
            time.sleep(0.5)

    log(f"❌ 等待设备文件超时 ({timeout}s)")
    return None


def reader_thread(fd):
    """设备文件 → stdout"""
    n = 0
    total = 0
    log("📡 读取线程启动")

    try:
        while _alive.is_set():
            try:
                rlist, _, _ = select.select([fd], [], [], 0.2)
            except (OSError, ValueError):
                if not _alive.is_set():
                    break
                continue

            if not rlist:
                continue

            try:
                data = os.read(fd, 4096)
            except OSError as e:
                if e.errno == 11:  # EAGAIN
                    continue
                if not _alive.is_set():
                    break
                log(f"❌ 读取错误: {e}")
                _alive.clear()
                break

            if not data:
                continue

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


def writer_thread(fd):
    """stdin → 设备文件"""
    n = 0
    total = 0
    log("📡 写入线程启动")

    try:
        # 设置 stdin 非阻塞
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
                # stdin 暂时为空，继续等待
                continue

            n += 1
            total += len(data)
            hex_preview = ' '.join(f'{b:02X}' for b in data[:64])
            log(f"📨 #{n} [{len(data)}B]: {hex_preview}")

            # 写入设备文件
            offset = 0
            while offset < len(data) and _alive.is_set():
                try:
                    written = os.write(fd, data[offset:])
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
    global _device_fd

    if len(sys.argv) != 3:
        print("用法: rfcomm_spp_bridge.py <MAC> <通道>", file=sys.stderr)
        sys.exit(1)

    mac = sys.argv[1]
    ch = int(sys.argv[2])

    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    log("SPP 桥接 (rfcomm connect 模式)")
    log(f"  MAC: {mac}")
    log(f"  通道: {ch}")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # 信号处理
    def on_signal(signum, _):
        log(f"收到信号 {signum}，准备退出")
        _alive.clear()
    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)

    # 1. 清理旧连接
    cleanup()

    # 2. 启动 rfcomm connect
    if not start_rfcomm_connect(mac, ch):
        sys.exit(1)

    # 3. 等待设备文件
    _device_fd = wait_for_device(timeout=60)
    if _device_fd is None:
        log("❌ 无法建立连接")
        if _rfcomm_proc:
            _rfcomm_proc.kill()
        sys.exit(1)

    _alive.set()

    log("✅ 连接已建立，开始双向数据传输")
    log("   连接将保持直到手动断开")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # 4. 启动读写线程
    t_read = threading.Thread(target=reader_thread, args=(_device_fd,), daemon=True)
    t_write = threading.Thread(target=writer_thread, args=(_device_fd,), daemon=True)
    t_read.start()
    t_write.start()

    # 5. 主线程等待
    try:
        while _alive.is_set():
            # 检查 rfcomm connect 进程
            if _rfcomm_proc and _rfcomm_proc.poll() is not None:
                log("📴 rfcomm connect 进程已退出，连接断开")
                _alive.clear()
                break
            if not t_read.is_alive() and not t_write.is_alive():
                break
            time.sleep(0.2)
    except KeyboardInterrupt:
        log("KeyboardInterrupt")

    _alive.clear()
    log("🔌 关闭连接...")

    # 关闭设备文件
    try:
        os.close(_device_fd)
    except Exception:
        pass

    # 杀死 rfcomm connect 进程
    if _rfcomm_proc:
        try:
            _rfcomm_proc.kill()
            _rfcomm_proc.wait(timeout=2)
        except Exception:
            pass

    # 释放 rfcomm 设备
    try:
        subprocess.run(['sudo', 'rfcomm', 'release', 'all'],
                       stderr=subprocess.DEVNULL, timeout=2)
    except Exception:
        pass

    t_read.join(timeout=2)
    t_write.join(timeout=2)
    log("✅ 已退出")


if __name__ == "__main__":
    main()
