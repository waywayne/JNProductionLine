#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
稳定 RFCOMM SPP 桥接脚本 — 连上就不断开

设计原则：
  1. 只使用原始 AF_BLUETOOTH socket（不用 PyBluez）
  2. 连接前彻底清理内核 RFCOMM 资源
  3. 读写线程独立运行，互不干扰
  4. stdin 无数据时继续等待，绝不退出
  5. 只有以下情况才断开：
     - 远端设备主动断开
     - 收到 SIGTERM/SIGINT 信号（用户手动断开）
  6. 所有日志输出到 stderr，数据通过 stdout 透传
"""

import sys
import os
import socket
import time
import threading
import select
import signal
import fcntl
import subprocess
import struct
import errno

# === 常量 ===
AF_BLUETOOTH = 31
BTPROTO_RFCOMM = 3
CONNECT_TIMEOUT = 15
MAX_RETRIES = 5

# === 全局状态 ===
_alive = threading.Event()
_sock = None


def log(msg):
    ts = time.strftime('%H:%M:%S')
    print(f"[{ts}] [SPP-STABLE] {msg}", file=sys.stderr, flush=True)


def cleanup_all():
    """彻底清理所有 RFCOMM 资源"""
    my_pid = os.getpid()
    log(f"🧹 清理 RFCOMM 资源 (PID={my_pid})")

    # 杀死所有旧的 rfcomm 相关 Python 进程
    for pattern in ['rfcomm_stable', 'rfcomm_socket_simple', 'rfcomm_bind_bridge']:
        try:
            r = subprocess.run(['pgrep', '-f', pattern],
                               capture_output=True, text=True, timeout=2)
            if r.returncode == 0:
                for line in r.stdout.strip().split('\n'):
                    pid = int(line.strip())
                    if pid != my_pid:
                        os.kill(pid, 9)
                        log(f"   杀死 PID {pid} ({pattern})")
        except Exception:
            pass

    # 杀死 cat 进程
    try:
        subprocess.run(['pkill', '-9', 'cat'],
                       stderr=subprocess.DEVNULL, timeout=2)
    except Exception:
        pass

    # 释放 rfcomm 绑定
    try:
        subprocess.run(['sudo', 'rfcomm', 'release', 'all'],
                       stderr=subprocess.DEVNULL, timeout=2)
    except Exception:
        pass

    # 等待内核释放
    time.sleep(1)
    log("🧹 清理完成")


def create_socket():
    """创建原始 BT socket"""
    s = socket.socket(AF_BLUETOOTH, socket.SOCK_STREAM, BTPROTO_RFCOMM)
    return s


def connect(mac, channel):
    """连接 RFCOMM，带智能重试"""
    last_err = None

    for attempt in range(1, MAX_RETRIES + 1):
        sock = None
        try:
            log(f"🔗 尝试 {attempt}/{MAX_RETRIES}: {mac} CH{channel}")
            sock = create_socket()
            sock.settimeout(CONNECT_TIMEOUT)
            sock.connect((mac, channel))
            # 连接成功，设置为阻塞模式用于稳定通信
            sock.settimeout(None)
            log(f"✅ 连接成功: {mac} CH{channel}")
            return sock
        except Exception as e:
            last_err = e
            log(f"⚠️ 第 {attempt} 次失败: {e}")
            if sock:
                try:
                    sock.close()
                except Exception:
                    pass

            err_str = str(e)
            # Errno 12: 资源不足，重新清理
            if 'Errno 12' in err_str or 'Cannot allocate' in err_str:
                log("🔄 Errno 12 → 重新清理资源")
                cleanup_all()
            else:
                # 普通失败，等待后重试
                wait = min(attempt, 3)
                log(f"   等待 {wait}s 后重试...")
                time.sleep(wait)

    raise ConnectionError(f"连接失败（{MAX_RETRIES}次）: {last_err}")


def reader_thread(sock):
    """BT socket → stdout  —  只有远端断开才退出"""
    n = 0
    total = 0
    log("📡 读取线程启动")

    # 使用 select + 短超时实现非阻塞读取
    try:
        while _alive.is_set():
            try:
                # select 等待最多 200ms
                rlist, _, _ = select.select([sock], [], [], 0.2)
            except (OSError, ValueError):
                if not _alive.is_set():
                    break
                continue

            if not rlist:
                # 超时，没有数据，继续等待
                continue

            try:
                data = sock.recv(4096)
            except socket.timeout:
                continue
            except OSError as e:
                if e.errno == errno.EAGAIN or e.errno == errno.EWOULDBLOCK:
                    continue
                if not _alive.is_set():
                    break
                log(f"❌ 读取错误: {e}")
                _alive.clear()
                break

            if not data:
                # recv 返回空 = 远端关闭
                log("📴 远端设备断开连接")
                _alive.clear()
                break

            n += 1
            total += len(data)
            hex_preview = ' '.join(f'{b:02X}' for b in data[:80])
            log(f"📥 #{n} [{len(data)}B 累计{total}B]: {hex_preview}")

            try:
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
            except BrokenPipeError:
                log("📴 stdout 管道断裂（Dart 退出）")
                _alive.clear()
                break
    except Exception as e:
        log(f"❌ 读取线程异常: {e}")
        _alive.clear()
    finally:
        log(f"📊 读取结束: {n}次 {total}B")


def writer_thread(sock):
    """stdin → BT socket  —  stdin 无数据时继续等待，绝不退出"""
    n = 0
    total = 0
    log("📡 写入线程启动")

    try:
        # 设置 stdin 为非阻塞
        fd = sys.stdin.fileno()
        flags = fcntl.fcntl(fd, fcntl.F_GETFL)
        fcntl.fcntl(fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

        while _alive.is_set():
            try:
                rlist, _, _ = select.select([sys.stdin], [], [], 0.2)
            except (ValueError, OSError):
                if not _alive.is_set():
                    break
                continue

            if not rlist:
                # 无数据，继续等待（不退出）
                continue

            try:
                data = sys.stdin.buffer.read(4096)
            except (OSError, IOError):
                continue

            if not data:
                # stdin 暂时为空，继续等待（不退出）
                continue

            n += 1
            total += len(data)
            hex_preview = ' '.join(f'{b:02X}' for b in data[:80])
            log(f"📨 #{n} [{len(data)}B]: {hex_preview}")

            # 发送数据，处理部分写入
            offset = 0
            while offset < len(data) and _alive.is_set():
                try:
                    sent = sock.send(data[offset:])
                    if sent == 0:
                        log("📴 socket 写入端关闭")
                        _alive.clear()
                        return
                    offset += sent
                except OSError as e:
                    if e.errno == errno.EAGAIN or e.errno == errno.EWOULDBLOCK:
                        time.sleep(0.01)
                        continue
                    em = str(e).lower()
                    if 'timed out' in em or 'timeout' in em:
                        time.sleep(0.01)
                        continue
                    log(f"❌ 发送错误: {e}")
                    _alive.clear()
                    return

            log(f"✅ 已发送 {len(data)}B")

    except Exception as e:
        log(f"❌ 写入线程异常: {e}")
        _alive.clear()
    finally:
        log(f"📊 发送结束: {n}次 {total}B")


def main():
    global _sock

    if len(sys.argv) != 3:
        print("用法: rfcomm_stable.py <MAC> <通道>", file=sys.stderr)
        sys.exit(1)

    mac = sys.argv[1]
    ch = int(sys.argv[2])

    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    log("SPP 稳定连接模式")
    log(f"  MAC: {mac}")
    log(f"  通道: {ch}")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # 信号处理
    def on_signal(signum, _):
        log(f"收到信号 {signum}，准备退出")
        _alive.clear()
    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)

    # 清理资源
    cleanup_all()

    # 连接
    try:
        _sock = connect(mac, ch)
    except Exception as e:
        log(f"❌ {e}")
        sys.exit(1)

    _alive.set()

    log("✅ 连接已建立，开始双向数据传输")
    log("   连接将保持直到：远端断开 / 用户手动断开 / 进程终止")
    log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # 启动读写线程
    t_read = threading.Thread(target=reader_thread, args=(_sock,), name='reader')
    t_write = threading.Thread(target=writer_thread, args=(_sock,), name='writer')
    t_read.daemon = True
    t_write.daemon = True
    t_read.start()
    t_write.start()

    # 主线程等待，直到 _alive 被清除
    try:
        while _alive.is_set():
            # 检查线程是否存活
            if not t_read.is_alive() and not t_write.is_alive():
                break
            time.sleep(0.2)
    except KeyboardInterrupt:
        log("KeyboardInterrupt")

    _alive.clear()
    log("🔌 关闭连接...")

    try:
        _sock.shutdown(socket.SHUT_RDWR)
    except Exception:
        pass
    try:
        _sock.close()
    except Exception:
        pass

    t_read.join(timeout=2)
    t_write.join(timeout=2)
    log("✅ 已退出")


if __name__ == "__main__":
    main()
