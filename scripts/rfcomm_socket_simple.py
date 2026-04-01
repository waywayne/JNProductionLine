#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RFCOMM Socket 桥接脚本

数据流：
  Dart stdin  →  Python  →  BT socket (发送到设备)
  BT socket   →  Python  →  Dart stdout (接收设备数据)

关键原则：
  - 连接前清理僵尸 RFCOMM 资源（pkill 旧 python 桥接、rfcomm release all）
  - 绝不 bluetoothctl disconnect（会拆 ACL 链路 → Errno 112）
  - 绝不 bluetoothctl connect（会冲突 → Errno 52）
  - socket 关闭时自动释放内核资源
"""

import sys
import os
import socket
import time
import threading
import select
import signal
import atexit
import subprocess

try:
    import bluetooth
    HAS_PYBLUEZ = True
except ImportError:
    HAS_PYBLUEZ = False


def log(msg):
    """日志输出到 stderr（不影响 stdout 二进制数据通道）"""
    ts = time.strftime('%H:%M:%S')
    print(f"[{ts}] [RFCOMM-BRIDGE] {msg}", file=sys.stderr, flush=True)


def cleanup_rfcomm_resources():
    """清理 RFCOMM 资源（与产测一致：只 pkill + rfcomm release）
    
    步骤：
      1. pkill 旧的桥接进程和 cat 进程
      2. rfcomm release all
      3. 等待 500ms
    绝不 bluetoothctl disconnect/connect
    绝不 hciconfig reset（产测不用）
    """
    my_pid = os.getpid()
    log(f"🧹 清理 RFCOMM 资源 (本进程 PID: {my_pid})...")
    
    # 1. 杀掉旧的桥接进程（排除自己）
    try:
        result = subprocess.run(
            ['pgrep', '-f', 'rfcomm_socket_simple.py'],
            capture_output=True, text=True, timeout=3
        )
        if result.stdout.strip():
            for pid_str in result.stdout.strip().split('\n'):
                try:
                    pid = int(pid_str.strip())
                    if pid != my_pid:
                        log(f"   杀掉旧桥接进程 PID={pid}")
                        os.kill(pid, signal.SIGKILL)
                except (ProcessLookupError, ValueError):
                    pass
    except Exception as e:
        log(f"   pgrep 失败: {e}")

    # 2. 杀掉残留 cat 进程
    try:
        subprocess.run(['pkill', '-9', 'cat'], capture_output=True, timeout=3)
    except Exception:
        pass

    # 3. 释放所有 rfcomm 绑定
    try:
        subprocess.run(['rfcomm', 'release', 'all'], capture_output=True, timeout=3)
        log("   rfcomm release all 完成")
    except Exception:
        pass

    # 4. 等待资源释放
    time.sleep(0.5)
    log("🧹 清理完成")


def connect_raw_socket(mac, channel, timeout=5):
    """使用原始 AF_BLUETOOTH socket 连接（不依赖 PyBluez）"""
    AF_BLUETOOTH = 31
    BTPROTO_RFCOMM = 3
    log(f"使用原始 AF_BLUETOOTH socket 连接 {mac} CH{channel} (超时 {timeout}s)")
    sock = socket.socket(AF_BLUETOOTH, socket.SOCK_STREAM, BTPROTO_RFCOMM)
    sock.settimeout(timeout)
    sock.connect((mac, channel))
    log(f"✅ 原始 socket 连接成功: {mac} CH{channel}")
    return sock


def connect_rfcomm(mac, channel, timeout=5, max_retries=3):
    """连接 RFCOMM — 先尝试 PyBluez，失败则回退到原始 AF_BLUETOOTH socket"""
    last_error = None

    for attempt in range(1, max_retries + 1):
        # 尝试 PyBluez
        if HAS_PYBLUEZ:
            try:
                log(f"[尝试 {attempt}/{max_retries}] PyBluez 连接 {mac} CH{channel} (超时 {timeout}s)")
                sock = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
                sock.settimeout(timeout)
                sock.connect((mac, channel))
                log(f"✅ PyBluez 连接成功: {mac} CH{channel}")
                return sock
            except Exception as e:
                last_error = e
                log(f"⚠️ PyBluez 第 {attempt} 次失败: {e}")
                try:
                    sock.close()
                except:
                    pass
                # Errno 77 (EBADFD) — PyBluez fd 异常，直接回退到原始 socket
                if 'Errno 77' in str(e) or 'bad state' in str(e).lower():
                    log("🔄 检测到 Errno 77 (EBADFD)，回退到原始 AF_BLUETOOTH socket")
                    break
                time.sleep(0.5)

        # 尝试原始 AF_BLUETOOTH socket
        try:
            return connect_raw_socket(mac, channel, timeout)
        except Exception as e2:
            last_error = e2
            log(f"⚠️ 原始 socket 第 {attempt} 次失败: {e2}")
            time.sleep(0.5)

    # 所有尝试失败，最后再试一次原始 socket
    if last_error:
        log(f"🔄 所有 PyBluez 尝试失败，最终回退原始 socket")
        return connect_raw_socket(mac, channel, timeout)


def bt_to_stdout(sock, alive):
    """BT socket → stdout（完全透传二进制数据）"""
    n = 0
    total = 0
    # 设为 0.1s 超时用于非阻塞读
    sock.settimeout(0.1)
    try:
        while alive.is_set():
            try:
                data = sock.recv(4096)
                if not data:
                    log("BT socket 关闭（远端断开）")
                    alive.clear()
                    break
                n += 1
                total += len(data)
                log(f"📥 #{n} [{len(data)}B 累计{total}B]: {' '.join(f'{b:02X}' for b in data[:60])}")
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
            except socket.timeout:
                continue
            except Exception as e:
                em = str(e).lower()
                if 'timed out' in em or 'timeout' in em or 'temporarily unavailable' in em:
                    continue
                log(f"❌ 读取错误: {e}")
                alive.clear()
                break
    except Exception as e:
        log(f"❌ 读取线程异常: {e}")
        alive.clear()
    finally:
        log(f"📊 读取结束: {n}次 {total}B")


def stdin_to_bt(sock, alive):
    """stdin → BT socket（完全透传二进制数据）"""
    n = 0
    total = 0
    try:
        import fcntl
        flags = fcntl.fcntl(sys.stdin.fileno(), fcntl.F_GETFL)
        fcntl.fcntl(sys.stdin.fileno(), fcntl.F_SETFL, flags | os.O_NONBLOCK)

        while alive.is_set():
            try:
                rd, _, _ = select.select([sys.stdin], [], [], 0.05)
            except (ValueError, OSError):
                break
            if not rd:
                continue
            try:
                data = sys.stdin.buffer.read(4096)
            except (OSError, IOError):
                continue
            if not data:
                # stdin 暂时无数据，继续等待（不退出）
                continue

            n += 1
            total += len(data)
            log(f"📨 #{n} [{len(data)}B]: {' '.join(f'{b:02X}' for b in data[:60])}")

            off = 0
            while off < len(data) and alive.is_set():
                try:
                    w = sock.send(data[off:])
                    if w == 0:
                        log("BT socket 关闭（写入端）")
                        alive.clear()
                        return
                    off += w
                except Exception as e:
                    em = str(e).lower()
                    if 'timed out' in em or 'timeout' in em or 'temporarily unavailable' in em:
                        time.sleep(0.01)
                        continue
                    log(f"❌ 发送错误: {e}")
                    alive.clear()
                    return
    except Exception as e:
        log(f"❌ 写入线程异常: {e}")
        alive.clear()
    finally:
        log(f"📊 发送结束: {n}次 {total}B")


def main():
    if len(sys.argv) != 3:
        print("用法: rfcomm_socket_simple.py <MAC> <通道>", file=sys.stderr)
        sys.exit(1)

    mac = sys.argv[1]
    ch = int(sys.argv[2])

    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    log(f"RFCOMM 桥接: {mac} CH{ch}")
    log(f"PyBluez: {'可用' if HAS_PYBLUEZ else '不可用'}")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # 连接前清理僵尸 RFCOMM 资源（释放内核内存）
    cleanup_rfcomm_resources()

    try:
        sock = connect_rfcomm(mac, ch)
    except Exception as e:
        log(f"❌ 连接失败: {e}")
        log("   请确认：1.设备已配对 2.设备在范围内 3.通道正确")
        sys.exit(1)

    # atexit 保证 socket 总会关闭
    def cleanup():
        try:
            sock.close()
            log("🧹 socket 已关闭")
        except:
            pass
    atexit.register(cleanup)

    alive = threading.Event()
    alive.set()

    def on_signal(signum, _):
        log(f"信号 {signum}")
        alive.clear()
    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)

    log("✅ 连接已建立，开始双向透传")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    t_read = threading.Thread(target=bt_to_stdout, args=(sock, alive), daemon=True)
    t_write = threading.Thread(target=stdin_to_bt, args=(sock, alive), daemon=True)
    t_read.start()
    t_write.start()

    try:
        while alive.is_set():
            if not t_read.is_alive() and not t_write.is_alive():
                break
            time.sleep(0.1)
    except KeyboardInterrupt:
        pass

    alive.clear()
    log("清理...")
    try:
        sock.close()
    except:
        pass
    t_read.join(timeout=2)
    t_write.join(timeout=2)
    log("✅ 退出")


if __name__ == "__main__":
    main()
