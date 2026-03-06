# 如何查看 RFCOMM 通道号

## 问题说明

`flutter_bluetooth_serial` 的 `BluetoothConnection` 类**不提供**获取 RFCOMM 通道号的 API。

通道号是在底层 Android 系统中通过 SDP 协议自动协商的，对应用层是透明的。

## 查看方法

### Android 平台

#### 方法 1: 使用 adb logcat (推荐)

**步骤：**

1. **连接设备到电脑**
   ```bash
   adb devices
   ```

2. **开启日志监控**
   ```bash
   adb logcat | grep -i "rfcomm\|bluetoothsocket"
   ```

3. **运行应用并建立 SPP 连接**

4. **查看日志输出**
   
   你会看到类似以下的日志：
   ```
   BluetoothSocket: connect(), SocketState: INIT, mPfd: {ParcelFileDescriptor: java.io.FileDescriptor@...}
   BluetoothSocket: connect to RFCOMM channel 1
   BluetoothSocket: connect(), SocketState: CONNECTED, mPfd: {ParcelFileDescriptor: java.io.FileDescriptor@...}
   ```

   **通道号就是 "channel X" 中的 X**

**完整命令示例：**
```bash
# 清除之前的日志
adb logcat -c

# 实时查看蓝牙相关日志
adb logcat | grep -E "RFCOMM|BluetoothSocket|SPP"

# 或者保存到文件
adb logcat > bluetooth_log.txt
```

#### 方法 2: 使用 Android Studio Logcat

1. 在 Android Studio 中打开 **Logcat** 面板
2. 在过滤器中输入: `RFCOMM` 或 `BluetoothSocket`
3. 运行应用并建立连接
4. 查看日志中的通道信息

**过滤器设置：**
```
package:com.yourapp  tag:BluetoothSocket|RFCOMM
```

#### 方法 3: 使用 SDP 工具查询设备

**使用 `sdptool` (需要 root 权限):**

```bash
# 在 Android 设备上执行 (需要 root)
su
sdptool browse <DEVICE_MAC_ADDRESS>
```

**输出示例：**
```
Service Name: Serial Port
Service RecHandle: 0x10001
Service Class ID List:
  "Serial Port" (0x1101)
Protocol Descriptor List:
  "L2CAP" (0x0100)
  "RFCOMM" (0x0003)
    Channel: 1        <-- 这就是 RFCOMM 通道号
```

### Windows 平台

Windows 平台使用系统蓝牙服务，通道信息由系统管理，应用层无法直接获取。

**查看方法：**

1. **使用 Bluetooth LE Explorer (Microsoft Store)**
   - 下载并安装 "Bluetooth LE Explorer"
   - 连接到设备
   - 查看设备的服务列表
   - 找到 SPP 服务 (UUID: 00001101-...)

2. **使用 Windows 事件查看器**
   - 打开 "事件查看器"
   - 导航到: Windows 日志 → 系统
   - 筛选来源: Bluetooth
   - 查找连接相关的事件

3. **使用第三方工具**
   - nRF Connect for Desktop
   - Bluetooth Command Line Tools

## 常见 RFCOMM 通道号

不同设备和服务可能使用不同的通道号：

| 设备类型 | 常见通道号 | 说明 |
|---------|-----------|------|
| HC-05/HC-06 | 1 | 经典蓝牙串口模块 |
| Arduino BT | 1 | Arduino 蓝牙板 |
| 手机 SPP | 1-10 | 取决于系统和应用 |
| 自定义设备 | 1-30 | 由设备 SDP 服务器分配 |

## 为什么需要知道通道号？

### 通常情况下**不需要**知道通道号

- `BluetoothConnection.toAddress()` 会自动处理
- SDP 协议会自动查询和连接
- 应用层无需关心底层细节

### 可能需要知道的情况

1. **调试连接问题**
   - 确认设备是否正确发布了 SPP 服务
   - 验证通道号是否在有效范围内 (1-30)

2. **开发自定义蓝牙设备**
   - 需要在设备端配置 SDP 记录
   - 需要分配合适的 RFCOMM 通道

3. **性能优化**
   - 了解通道使用情况
   - 避免通道冲突

4. **兼容性测试**
   - 测试不同通道号的连接
   - 验证多连接场景

## 代码示例

### 在连接时打印日志

```dart
try {
  print('正在连接到设备: ${device.address}');
  
  final connection = await BluetoothConnection.toAddress(device.address);
  
  print('连接成功！');
  print('设备名称: ${device.name}');
  print('设备地址: ${device.address}');
  print('连接状态: ${connection.isConnected}');
  print('提示: 使用 adb logcat 查看 RFCOMM 通道号');
  
} catch (e) {
  print('连接失败: $e');
}
```

### 使用 adb 命令监控

```bash
#!/bin/bash
# monitor_bluetooth.sh

echo "开始监控蓝牙连接..."
echo "按 Ctrl+C 停止"
echo ""

adb logcat -c  # 清除旧日志

adb logcat | while read line; do
  if echo "$line" | grep -qi "rfcomm\|bluetoothsocket"; then
    # 高亮显示通道号
    echo "$line" | grep --color=always -E "channel [0-9]+|$"
  fi
done
```

## 故障排查

### 问题 1: 看不到 RFCOMM 日志

**可能原因：**
- 日志级别过滤
- 设备未启用蓝牙调试

**解决方案：**
```bash
# 设置日志级别为 VERBOSE
adb shell setprop log.tag.BluetoothSocket VERBOSE
adb shell setprop log.tag.RFCOMM VERBOSE

# 重启蓝牙服务
adb shell svc bluetooth disable
adb shell svc bluetooth enable
```

### 问题 2: 连接成功但没有通道信息

**可能原因：**
- 使用了缓存的连接
- 系统优化了日志输出

**解决方案：**
- 完全断开设备后重新连接
- 清除应用数据后重试
- 重启设备

### 问题 3: 通道号显示为 0 或 -1

**可能原因：**
- SDP 查询失败
- 设备未正确发布服务

**解决方案：**
- 检查设备的 SPP 服务配置
- 使用 SDP 工具验证服务记录
- 重新配对设备

## 参考资料

- [Android BluetoothSocket 文档](https://developer.android.com/reference/android/bluetooth/BluetoothSocket)
- [RFCOMM 协议规范](https://www.bluetooth.com/specifications/specs/rfcomm-1-1/)
- [SDP 协议规范](https://www.bluetooth.com/specifications/specs/service-discovery-protocol-1-2/)
- [flutter_bluetooth_serial GitHub](https://github.com/edufolly/flutter_bluetooth_serial)

## 总结

- ✅ 应用层**不需要**手动指定或获取通道号
- ✅ 通道号由 SDP 协议**自动协商**
- ✅ 可以通过 **adb logcat** 查看实际使用的通道号
- ⚠️ 通道号主要用于**调试和故障排查**
- ⚠️ 不同设备和连接可能使用**不同的通道号**
