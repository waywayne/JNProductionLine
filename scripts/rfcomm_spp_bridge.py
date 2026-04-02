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


def start_rfcomm_connect(mac, channel, dev='/dev/rfcomm0'):
    """
    启动 rfcomm connect 命令建立 RFCOMM 连接。
    
    rfcomm connect 会:
      1. 自动建立 ACL 连接
      2. 自动建立 RFCOMM 连接
      3. 创建 /dev/rfcomm0 设备文件
      4. 保持连接直到进程被杀死
    
    这是 Linux 内核级别的连接方式，最稳定可靠。
    """
    global _rfcomm_proc

    log(f"🔗 启动 rfcomm connect: {mac} CH{channel}")
    log(f"   命令: sudo rfcomm connect {dev} {mac} {channel}")

    try:
        _rfcomm_proc = subprocess.Popen(
            ['sudo', 'rfcomm', 'connect', dev, mac, str(channel)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        log(f"   rfcomm connect 进程已启动 (PID: {_rfcomm_proc.pid})")
    except Exception as e:
        log(f"❌ 启动 rfcomm connect 失败: {e}")
        return False

    # 启动后台线程读取 rfcomm connect 的输出
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
