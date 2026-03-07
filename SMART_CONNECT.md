# 🚀 智能蓝牙连接功能

## 问题背景

- ✅ **Android 平台**：可以正常收发数据
- ❌ **Windows 平台**：找不到蓝牙服务（Service Discovery 失败）

## 根本原因

Windows 蓝牙 API 的 Service Discovery Protocol (SDP) 实现与 Android 不同：
- Android 可以正常查询设备的 SDP 服务
- Windows 的 PyBluez 在某些情况下无法查询到 SDP 服务

## 解决方案：智能连接

### 核心思路

**跳过服务查找，直接尝试常用 RFCOMM Channel**

大多数蓝牙 SPP 设备使用固定的 Channel：
- Android 设备通常使用：**Channel 1-6**
- 其他设备可能使用：**Channel 1-10**

### 实现逻辑

```python
def _smart_connect(self):
    """智能连接：尝试常用的 RFCOMM Channel"""
    common_channels = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    
    for channel in common_channels:
        try:
            sock = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
            sock.settimeout(3)  # 3秒超时
            sock.connect((self.device_address, channel))
            
            # 连接成功！
            self.socket = sock
            self.channel = channel
            return
            
        except bluetooth.BluetoothError:
            # 尝试下一个 Channel
            continue
    
    # 所有 Channel 都失败
    raise Exception("无法连接到任何 RFCOMM Channel")
```

### 工作流程

```
1. 用户指定了 Channel？
   ├─ 是 → 直接连接到指定 Channel
   └─ 否 → 继续第 2 步

2. 尝试查找服务 (Service Discovery)
   ├─ 成功 → 使用找到的 Channel
   └─ 失败 → 继续第 3 步

3. 启动智能连接
   ├─ 尝试 Channel 1 → 失败
   ├─ 尝试 Channel 2 → 失败
   ├─ 尝试 Channel 3 → 成功！✅
   └─ 使用 Channel 3 连接
```

---

## 使用方法

### 方法 1: 自动智能连接（推荐）

```bash
# 不指定 Channel，让脚本自动尝试
python scripts/bluetooth_spp_test.py --connect 48:08:EB:60:00:00 --test mac
```

**输出示例**：
```
🔗 连接到设备: 48:08:EB:60:00:00
   UUID: 00007033-0000-1000-8000-00805f9b34fb
   正在查找服务...
   ⚠️  未找到服务，启动智能连接...

   🔄 尝试常用 Channel: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
   (Android 设备通常使用 Channel 1-6)

   [ 1] 尝试 Channel 1... ❌ 拒绝
   [ 2] 尝试 Channel 2... ❌ 拒绝
   [ 3] 尝试 Channel 3... ✅

   ✅ 成功连接到 Channel 3
✅ 连接成功!
```

### 方法 2: 指定 Channel（最快）

如果已知设备使用的 Channel：

```bash
# 直接指定 Channel 3
python scripts/bluetooth_spp_test.py --connect 48:08:EB:60:00:00 --channel 3 --test mac
```

---

## Flutter 应用中使用

### 自动智能连接

```dart
// 不指定 Channel，让 Python 脚本自动尝试
await testState.testPythonBluetooth(
  deviceAddress: '48:08:EB:60:00:00',
);
```

**日志输出**：
```
[INFO] 🔗 连接到设备: 48:08:EB:60:00:00
[INFO]    未指定 Channel，将自动尝试常用 Channel
[DEBUG]    [ 1] 尝试 Channel 1... ❌ 拒绝
[DEBUG]    [ 2] 尝试 Channel 2... ❌ 拒绝
[DEBUG]    [ 3] 尝试 Channel 3... ✅
[SUCCESS] ✅ 成功连接到 Channel 3
```

### 指定 Channel

```dart
// 如果已知 Channel，直接指定
await testState.testPythonBluetooth(
  deviceAddress: '48:08:EB:60:00:00',
  channel: 3,  // 直接使用 Channel 3
);
```

---

## 优势

| 特性 | 传统方式 | 智能连接 |
|------|----------|----------|
| Service Discovery | 必需 | 可选 |
| Windows 兼容性 | ❌ 差 | ✅ 优秀 |
| 连接速度 | 慢 | 快 |
| 容错性 | 低 | 高 |
| 用户体验 | 需要手动排查 | 自动尝试 |

---

## 性能

### 最坏情况

- 尝试 10 个 Channel
- 每个 Channel 超时 3 秒
- 总时间：**最多 30 秒**

### 最佳情况

- 第一个 Channel 就成功
- 总时间：**< 1 秒**

### 实际情况

- Android 设备通常使用 Channel 1-3
- 平均时间：**3-9 秒**

---

## 常见问题

### Q1: 为什么不直接使用 Channel 1？

**A**: 不同设备使用不同的 Channel：
- 有些设备使用 Channel 1
- 有些设备使用 Channel 3
- 有些设备使用 Channel 5

智能连接会自动找到正确的 Channel。

### Q2: 如何加快连接速度？

**A**: 如果已知设备的 Channel，直接指定：

```bash
python scripts/bluetooth_spp_test.py --connect 48:08:EB:60:00:00 --channel 3
```

或在 Flutter 中：

```dart
await testState.testPythonBluetooth(
  deviceAddress: '48:08:EB:60:00:00',
  channel: 3,
);
```

### Q3: 智能连接会影响 Android 吗？

**A**: 不会！
- Android 上 Service Discovery 正常工作
- 智能连接只在 Service Discovery 失败时启动
- Android 会直接使用找到的服务，不会触发智能连接

### Q4: 如何知道设备使用哪个 Channel？

**方法 1**: 让智能连接自动找到，查看日志：
```
✅ 成功连接到 Channel 3  ← 记住这个 Channel
```

**方法 2**: 使用测试脚本：
```bash
python scripts/test_all_channels.py 48:08:EB:60:00:00
```

---

## 技术细节

### UUID 修正

修正了 UUID 格式（第 3 段应该是 `0000` 而不是 `1000`）：

**之前**：
```
00007033-1000-8000-00805f9b34fb  ❌
```

**现在**：
```
00007033-0000-1000-8000-00805f9b34fb  ✅
```

### 超时设置

- **Service Discovery**: 无超时（可能很慢）
- **智能连接**: 每个 Channel 3 秒超时
- **总超时**: 最多 30 秒（10 个 Channel × 3 秒）

### 错误处理

智能连接会识别不同的错误类型：
- `Connection refused` → ❌ 拒绝（Channel 不可用）
- `Timeout` → ⏱️  超时（设备响应慢）
- `Host is down` → 📴 无响应（设备未开启）

---

## 测试建议

### 第一次使用

```bash
# 1. 让智能连接找到正确的 Channel
python scripts/bluetooth_spp_test.py --connect 48:08:EB:60:00:00 --test mac

# 2. 记录成功的 Channel（如 Channel 3）

# 3. 后续使用直接指定 Channel
python scripts/bluetooth_spp_test.py --connect 48:08:EB:60:00:00 --channel 3 --test mac
```

### Flutter 应用

```dart
// 第一次测试：自动查找
await testState.testPythonBluetooth(
  deviceAddress: '48:08:EB:60:00:00',
);

// 查看日志，找到成功的 Channel（如 3）

// 后续使用：直接指定
await testState.testPythonBluetooth(
  deviceAddress: '48:08:EB:60:00:00',
  channel: 3,  // 使用找到的 Channel
);
```

---

## 总结

### ✅ 优点

1. **自动容错**：Service Discovery 失败时自动尝试常用 Channel
2. **跨平台**：Android 和 Windows 都能正常工作
3. **用户友好**：无需手动排查 Channel
4. **性能优化**：支持直接指定 Channel 跳过尝试

### 🎯 最佳实践

1. **首次连接**：使用智能连接，让脚本自动找到 Channel
2. **记录 Channel**：在日志中记录成功的 Channel
3. **后续连接**：直接指定 Channel，提升速度
4. **生产环境**：在配置文件中保存设备的 Channel

### 📊 预期效果

- **Windows 平台**：从"无法连接"到"自动连接成功" ✅
- **Android 平台**：保持原有功能，无影响 ✅
- **用户体验**：从"需要手动排查"到"自动工作" ✅
