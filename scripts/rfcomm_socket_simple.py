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
    """彻底清理 RFCOMM 资源，避免 Errno 12 (Cannot allocate memory)
    
    步骤：
      1. pkill 所有旧的桥接进程（排除自己）
      2. pkill 所有 cat 进程
      3. rfcomm release all（释放所有绑定）
      4. 关闭所有 /dev/rfcomm* 设备文件
      5. 等待 1 秒让内核完全释放资源
    """
    my_pid = os.getpid()
    log(f"🧹 彻底清理 RFCOMM 资源 (本进程 PID: {my_pid})")
    
    # 1. 强杀所有旧的 Python 桥接进程（排除自己）
    try:
        result = subprocess.run(['pgrep', '-f', 'rfcomm'],
                              capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            for pid_str in result.stdout.strip().split('\n'):
                if pid_str and pid_str.strip():
                    try:
                        pid = int(pid_str.strip())
                        if pid != my_pid:
                            subprocess.run(['kill', '-9', str(pid)], timeout=1)
                            log(f"   已杀死旧进程 PID: {pid}")
                    except:
                        pass
    except:
        pass
    
    # 2. 强杀所有 cat 进程
    try:
        subprocess.run(['pkill', '-9', 'cat'], stderr=subprocess.DEVNULL, timeout=2)
    except:
        pass
    
    # 3. 释放所有 rfcomm 绑定
    try:
        subprocess.run(['sudo', 'rfcomm', 'release', 'all'], 
                      stderr=subprocess.DEVNULL, timeout=2)
        log("   已释放所有 rfcomm 绑定")
    except:
        pass
    
    # 4. 关闭所有打开的 /dev/rfcomm* 设备文件
    try:
        result = subprocess.run(['lsof', '/dev/rfcomm*'], 
                              capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            for line in result.stdout.split('\n')[1:]:  # 跳过标题行
                parts = line.split()
                if len(parts) > 1:
                    try:
                        pid = int(parts[1])
                        if pid != my_pid:
                            subprocess.run(['kill', '-9', str(pid)], timeout=1)
                            log(f"   已杀死占用 /dev/rfcomm 的进程 PID: {pid}")
                    except:
                        pass
    except:
        pass
    
    # 5. 等待内核完全释放资源
    time.sleep(1)
    log("🧹 清理完成")


def connect_rfcomm(mac, channel, timeout=10, max_retries=5):
    """连接 RFCOMM — 只使用原始 AF_BLUETOOTH socket（更稳定，避免 PyBluez 的 Errno 77）"""
    last_error = None
    
    log(f"使用原始 AF_BLUETOOTH socket 连接（不使用 PyBluez）")
    
    for attempt in range(1, max_retries + 1):
        try:
            log(f"[尝试 {attempt}/{max_retries}] 连接 {mac} CH{channel} (超时 {timeout}s)")
            
            # 直接使用原始 socket
            AF_BLUETOOTH = 31
            BTPROTO_RFCOMM = 3
            sock = socket.socket(AF_BLUETOOTH, socket.SOCK_STREAM, BTPROTO_RFCOMM)
            sock.settimeout(timeout)
            
            # 连接前等待一下，避免资源竞争
            if attempt > 1:
                wait_time = min(attempt * 0.5, 2)  # 最多等 2 秒
                log(f"   等待 {wait_time}s 后重试...")
                time.sleep(wait_time)
            
            sock.connect((mac, channel))
            log(f"✅ 连接成功: {mac} CH{channel}")
            return sock
            
        except Exception as e:
            last_error = e
            log(f"⚠️ 第 {attempt} 次失败: {e}")
            try:
                sock.close()
            except:
                pass
            
            # 如果是 Errno 12 (Cannot allocate memory)，需要更彻底的清理
            if 'Errno 12' in str(e) or 'Cannot allocate memory' in str(e):
                log("🔄 检测到 Errno 12，重新清理 RFCOMM 资源...")
                cleanup_rfcomm_resources()
    
    # 所有尝试失败
    raise Exception(f"连接失败（{max_retries} 次尝试）: {last_error}")


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
