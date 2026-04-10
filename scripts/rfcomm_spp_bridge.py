#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RFCOMM SPP 桥接 — 直接 Bluetooth Socket 连接

连接方式（与三方工具一致）：
  1. socket(AF_BLUETOOTH, SOCK_STREAM, BTPROTO_RFCOMM)
  2. socket.connect((MAC, Channel))
  3. 双向桥接: stdin → socket, socket → stdout

简单、直接、可靠。不需要 rfcomm 命令、不需要 /dev/rfcomm0、不需要 D-Bus。
"""

import socket
import time
import sys
import os
import select
import signal
import threading
import fcntl

# --- 常量 ---
AF_BLUETOOTH = 31
BTPROTO_RFCOMM = 3

def log(msg):
    ts = time.strftime('%H:%M:%S')
    print(f"[{ts}] [SPP-BRIDGE] {msg}", file=sys.stderr, flush=True)


def cleanup_old_processes():
    """清理旧的桥接进程"""
    import subprocess
    my_pid = os.getpid()
    my_ppid = os.getppid()
    # 排除自身PID和父进程PID（sudo wrapper），避免误杀新启动的进程
    exclude_pids = {my_pid, my_ppid}

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
                        if pid not in exclude_pids:
                            os.kill(pid, 9)
                            log(f"   杀死旧进程 PID {pid}")
                    except Exception:
                        pass
        except Exception:
            pass

    # 释放 rfcomm 绑定
    try:
        subprocess.run(['sudo', 'rfcomm', 'release', 'all'],
                       stderr=subprocess.DEVNULL, timeout=2)
    except Exception:
        pass

    time.sleep(0.3)


def connect_spp(mac, channel, timeout=10):
    """
    直接用 Bluetooth RFCOMM socket 连接设备。
    这一步会触发系统的连接请求（自动建立 ACL）。
    """
    log(f"🔗 正在连接设备: {mac} (Channel {channel})...")

    client_sock = socket.socket(AF_BLUETOOTH, socket.SOCK_STREAM, BTPROTO_RFCOMM)
    client_sock.settimeout(timeout)

    try:
        client_sock.connect((mac, channel))
        client_sock.settimeout(None)  # 连接后切回阻塞模式
        log(f"✅ 连接已建立！")
        return client_sock
    except Exception as e:
        log(f"❌ 连接失败 (CH{channel}): {e}")
        try:
            client_sock.close()
        except Exception:
            pass
        return None


def reader_thread(sock, alive_event):
    """socket → stdout"""
    n = 0
    total = 0
    log("📡 读取线程启动")

    try:
        while alive_event.is_set():
            try:
                rlist, _, _ = select.select([sock], [], [], 0.2)
            except (OSError, ValueError):
                if not alive_event.is_set():
                    break
                continue

            if not rlist:
                continue

            try:
                data = sock.recv(4096)
            except socket.timeout:
                continue
            except OSError as e:
                if not alive_event.is_set():
                    break
                log(f"❌ 读取错误: {e}")
                alive_event.clear()
                break

            if not data:
                log("📴 远端关闭连接")
                alive_event.clear()
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
                alive_event.clear()
                break
    except Exception as e:
        log(f"❌ 读取线程异常: {e}")
        alive_event.clear()
    finally:
        log(f"📊 读取结束: {n}次 {total}B")


def writer_thread(sock, alive_event):
    """stdin → socket"""
    n = 0
    total = 0
    log("📡 写入线程启动")

    try:
        stdin_fd = sys.stdin.fileno()
        flags = fcntl.fcntl(stdin_fd, fcntl.F_GETFL)
        fcntl.fcntl(stdin_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

        while alive_event.is_set():
            try:
                rlist, _, _ = select.select([sys.stdin], [], [], 0.2)
            except (ValueError, OSError):
                if not alive_event.is_set():
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
                alive_event.clear()
                return

    except Exception as e:
        log(f"❌ 写入线程异常: {e}")
        alive_event.clear()
    finally:
        log(f"📊 发送结束: {n}次 {total}B")


def main():
    if len(sys.argv) != 3:
        print("用法: rfcomm_spp_bridge.py <MAC> <通道>", file=sys.stderr)
        sys.exit(1)

    mac = sys.argv[1]
    channel = int(sys.argv[2])

    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    log("SPP 桥接 (直接 Bluetooth Socket)")
    log(f"  MAC: {mac}")
    log(f"  Channel: {channel}")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # 信号处理
    alive = threading.Event()
    alive.set()

    def on_signal(signum, _):
        log(f"收到信号 {signum}，准备退出")
        alive.clear()
    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)

    # 1. 清理旧进程（已移到 Dart 端在启动前执行，避免 Python 误杀自身 sudo 父进程）
    # cleanup_old_processes()

    # 2. 连接（带重试，尝试指定通道 + 常见通道）
    client_sock = None
    candidates = [channel]
    for ch in [1, 2, 3, 4, 5, 6]:
        if ch not in candidates:
            candidates.append(ch)

    for attempt in range(1, 4):
        log(f"🔗 第 {attempt}/3 轮连接尝试")
        for ch in candidates:
            client_sock = connect_spp(mac, ch, timeout=10)
            if client_sock:
                log(f"✅ 成功连接到 Channel {ch}")
                break
        if client_sock:
            break
        if attempt < 3:
            log(f"⏳ 等待 2 秒后重试...")
            time.sleep(2)

    if not client_sock:
        log("❌ 所有通道连接均失败")
        log("提示：请检查设备是否进入配对模式或被其他设备占用。")
        sys.exit(1)

    log("✅ 连接已建立，开始双向数据传输")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # 3. 启动双向桥接
    t_read = threading.Thread(target=reader_thread, args=(client_sock, alive), daemon=True)
    t_write = threading.Thread(target=writer_thread, args=(client_sock, alive), daemon=True)
    t_read.start()
    t_write.start()

    # 4. 主线程等待
    try:
        while alive.is_set():
            if not t_read.is_alive() and not t_write.is_alive():
                break
            time.sleep(0.2)
    except KeyboardInterrupt:
        log("KeyboardInterrupt")

    alive.clear()
    log("🔌 关闭连接...")

    try:
        client_sock.close()
    except Exception:
        pass

    t_read.join(timeout=2)
    t_write.join(timeout=2)
    log("✅ 已退出")


if __name__ == "__main__":
    main()
