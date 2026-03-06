# 蓝牙 SPP 测试工具使用说明

## 安装依赖

### Windows 平台

```bash
# 方法 1: 使用 pip (推荐先安装 Visual Studio Build Tools)
pip install pybluez

# 方法 2: 使用预编译的 wheel (推荐)
# 下载地址: https://www.lfd.uci.edu/~gohlke/pythonlibs/#pybluez
# 选择对应 Python 版本的 whl 文件，例如:
# PyBluez‑0.23‑cp39‑cp39‑win_amd64.whl (Python 3.9, 64位)
pip install PyBluez‑0.23‑cp39‑cp39‑win_amd64.whl

# 方法 3: 使用 conda
conda install -c conda-forge pybluez
```

## 使用方法

### 1. 扫描蓝牙设备

```bash
python bluetooth_spp_test.py --scan
```

输出示例:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 正在扫描蓝牙设备...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

找到 2 个设备:

1. HC-05
   地址: 98:D3:31:FC:2E:7F

2. Kanaan-00LI
   地址: AA:BB:CC:DD:EE:FF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 2. 查找设备服务

```bash
python bluetooth_spp_test.py --services AA:BB:CC:DD:EE:FF
```

输出示例:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 查找设备 AA:BB:CC:DD:EE:FF 的服务...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

找到 2 个服务:

服务 1:
  名称: Serial Port
  RFCOMM Channel: 1
  服务 ID: 00001101-0000-1000-8000-00805F9B34FB
  协议: RFCOMM

服务 2:
  名称: Custom Service
  RFCOMM Channel: 2
  服务 ID: 6E400001-B5A3-F393-E0A9-E50E24DCCA9E
  协议: RFCOMM

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 3. 连接设备（使用标准 SPP UUID）

```bash
python bluetooth_spp_test.py --connect AA:BB:CC:DD:EE:FF
```

### 4. 连接设备（使用自定义 UUID）

```bash
python bluetooth_spp_test.py --connect AA:BB:CC:DD:EE:FF --uuid 6E400001-B5A3-F393-E0A9-E50E24DCCA9E
```

### 5. 连接设备（直接指定 RFCOMM Channel）

```bash
python bluetooth_spp_test.py --connect AA:BB:CC:DD:EE:FF --channel 1
```

### 6. 运行测试（读取蓝牙 MAC 地址）

```bash
python bluetooth_spp_test.py --connect AA:BB:CC:DD:EE:FF --test mac
```

输出示例:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔗 连接到设备: AA:BB:CC:DD:EE:FF
   UUID: 00001101-0000-1000-8000-00805F9B34FB
   正在查找服务...
   找到服务: Serial Port
   RFCOMM Channel: 1
✅ 连接成功!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📖 测试: 读取蓝牙 MAC 地址
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📤 发送 GTP 数据包 (36 字节):
   D0 D2 C5 C2 00 20 00 03 04 00 00 XX 23 23 00 00
   XX XX 00 00 00 00 02 00 00 00 0D 01 0D 0A XX XX
   XX XX
✅ 发送成功

📥 收到数据 (42 字节):
   D0 D2 C5 C2 00 26 00 03 04 00 00 XX 23 23 00 00
   XX XX 00 00 80 00 08 00 00 00 0D AA BB CC DD EE
   FF 00 00 0D 0A XX XX XX XX
✅ 测试完成

🔌 已断开连接
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 常见问题

### Q1: PyBluez 安装失败

**错误信息**:
```
error: Microsoft Visual C++ 14.0 or greater is required
```

**解决方案**:
1. 下载并安装 [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/)
2. 或使用预编译的 wheel 文件
3. 或使用 conda 安装

### Q2: 找不到设备

**可能原因**:
- 设备未开启蓝牙
- 设备未配对
- 设备不在范围内
- Windows 蓝牙服务未启动

**解决方案**:
1. 确保设备已配对（Windows 设置 -> 蓝牙和其他设备）
2. 确保设备在范围内（< 10米）
3. 重启 Windows 蓝牙服务
4. 使用 `--scan` 命令确认设备可见

### Q3: 连接超时

**错误信息**:
```
bluetooth.BluetoothError: (10060, 'A connection attempt failed...')
```

**解决方案**:
1. 确认 RFCOMM channel 正确（使用 `--services` 查看）
2. 确认设备支持 SPP 协议
3. 检查防火墙设置
4. 尝试使用 `--channel` 直接指定通道

### Q4: 未找到服务

**错误信息**:
```
未找到 UUID xxx 的服务
```

**解决方案**:
1. 使用 `--services` 查看设备的所有服务
2. 确认设备支持该 UUID 的服务
3. 尝试使用标准 SPP UUID: `00001101-0000-1000-8000-00805F9B34FB`
4. 或直接使用 `--channel` 指定通道号

## 高级用法

### 自定义测试脚本

编辑 `bluetooth_spp_test.py`，添加自定义测试函数：

```python
def test_custom_command(client: BluetoothSPPClient):
    """自定义测试"""
    print("\n📖 测试: 自定义命令")
    print("━" * 50)
    
    # 构建自定义命令
    # CMD: 0xXX, OPT: 0xYY, DATA: [...]
    cmd_payload = bytes([0xXX, 0xYY, 0x01, 0x02, 0x03])
    
    client.send_gtp_command(cmd_payload, module_id=0x0000, message_id=0x0000)
    response = client.receive_data(timeout=5)
    
    if response:
        # 解析响应
        print("✅ 测试完成")
    else:
        print("❌ 未收到响应")
```

然后在 `main()` 函数中添加测试选项：

```python
parser.add_argument('--test', choices=['mac', 'custom'], help='运行测试')

# ...

if args.test == 'mac':
    test_read_mac(client)
elif args.test == 'custom':
    test_custom_command(client)
```

### 批量测试

创建批处理脚本 `test_all.bat`:

```batch
@echo off
echo 开始批量测试...

echo.
echo 1. 扫描设备
python bluetooth_spp_test.py --scan

echo.
echo 2. 查找服务
python bluetooth_spp_test.py --services AA:BB:CC:DD:EE:FF

echo.
echo 3. 测试标准 UUID
python bluetooth_spp_test.py --connect AA:BB:CC:DD:EE:FF --test mac

echo.
echo 4. 测试自定义 UUID
python bluetooth_spp_test.py --connect AA:BB:CC:DD:EE:FF --uuid 6E400001-B5A3-F393-E0A9-E50E24DCCA9E --test mac

echo.
echo 测试完成!
pause
```

## 与 Flutter 应用集成

### 方案 1: 使用 Python 作为测试工具

在 Flutter 应用开发过程中，使用 Python 脚本进行蓝牙通信测试和调试。

### 方案 2: 通过 Process 调用 Python

在 Flutter 应用中调用 Python 脚本：

```dart
import 'dart:io';

Future<void> testBluetoothViaPython(String deviceAddress) async {
  final result = await Process.run(
    'python',
    [
      'scripts/bluetooth_spp_test.py',
      '--connect', deviceAddress,
      '--test', 'mac'
    ],
  );
  
  print('输出: ${result.stdout}');
  print('错误: ${result.stderr}');
}
```

### 方案 3: 使用 HTTP 服务

创建 Python HTTP 服务，Flutter 通过 HTTP 调用：

```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/bluetooth/connect', methods=['POST'])
def connect():
    data = request.json
    address = data['address']
    uuid = data.get('uuid')
    
    # 连接蓝牙设备
    client = BluetoothSPPClient(address, uuid=uuid)
    client.connect()
    
    return jsonify({'status': 'connected'})

if __name__ == '__main__':
    app.run(port=5000)
```

## 参考资料

- [PyBluez 文档](https://pybluez.github.io/)
- [Windows 蓝牙 API](https://docs.microsoft.com/en-us/windows/uwp/devices-sensors/bluetooth)
- [RFCOMM 协议规范](https://www.bluetooth.com/specifications/specs/rfcomm-1-1/)
- [GTP 协议文档](../docs/CUSTOM_SPP_UUID.md)
