# 单板产测与整机产测实现总结

## 概述

成功实现了单板产测（Serial Port）和整机产测（SPP Bluetooth）两种测试模式的区分和切换，并为整机产测实现了基于SPP协议的蓝牙通讯基础类。

---

## 新增文件

### 1. **SPP通讯服务** (`lib/services/spp_service.dart`)
- **功能**: 实现SPP（Serial Port Profile）蓝牙通讯协议
- **核心方法**:
  - `getAvailableDevices()`: 扫描可用的蓝牙设备
  - `connect(BluetoothDevice)`: 连接到指定蓝牙设备
  - `disconnect()`: 断开蓝牙连接
  - `sendData(Uint8List)`: 发送数据
  - `sendCommandAndWaitResponse()`: 发送命令并等待响应
  - `_onDataReceived()`: 处理接收到的数据
  - `_processBuffer()`: 解析数据包缓冲区
- **特点**:
  - 自动数据包解析（0xAA 0x55 包头识别）
  - 序列号跟踪机制
  - 超时处理
  - 完整的错误处理和日志记录

### 2. **测试模式枚举** (`lib/models/test_mode.dart`)
- **定义两种测试模式**:
  - `TestMode.singleBoard`: 单板产测（串口通讯）
  - `TestMode.completeDevice`: 整机产测（SPP蓝牙通讯）
- **扩展方法**:
  - `displayName`: 显示名称（中文）
  - `description`: 模式描述
  - `iconName`: 图标名称
  - `usesSerialPort`: 是否使用串口
  - `usesSppBluetooth`: 是否使用SPP蓝牙

### 3. **测试模式选择器** (`lib/widgets/test_mode_selector.dart`)
- **功能**: UI组件，用于选择测试模式
- **特点**:
  - 卡片式设计，清晰展示两种模式
  - 当前模式高亮显示
  - 连接状态下禁止切换
  - 响应式布局

### 4. **连接选择器** (`lib/widgets/connection_selector.dart`)
- **功能**: 根据测试模式自适应显示连接界面
- **单板模式**:
  - 串口下拉选择
  - 连接/断开按钮
  - 连接状态显示
- **整机模式**:
  - 蓝牙设备扫描
  - 设备下拉选择
  - 连接/断开按钮
  - 连接状态显示

---

## 修改文件

### 1. **测试状态管理** (`lib/models/test_state.dart`)

#### 新增属性:
```dart
TestMode _testMode = TestMode.singleBoard;  // 当前测试模式
final SppService _sppService = SppService();  // SPP服务实例
```

#### 新增方法:
- `switchTestMode(TestMode)`: 切换测试模式
- `getAvailableSppDevices()`: 获取可用SPP设备
- `connectToSppDevice(device)`: 连接SPP设备
- 更新 `disconnect()`: 支持两种连接方式的断开
- 更新 `setLogState()`: 同时设置SPP服务的日志状态

#### 更新逻辑:
- `isConnected` getter: 根据测试模式返回相应的连接状态
- 断开连接时自动清理所有测试状态

### 2. **主界面** (`lib/screens/home_screen.dart`)

#### 新增导入:
```dart
import '../widgets/test_mode_selector.dart';
import '../widgets/connection_selector.dart';
```

#### UI布局更新:
```dart
// 替换原来的 SerialPortSection
const TestModeSelector(),        // 测试模式选择器
const SizedBox(height: 16),
const ConnectionSelector(),      // 连接选择器（自适应）
```

### 3. **依赖配置** (`pubspec.yaml`)

#### 新增依赖:
```yaml
flutter_bluetooth_serial: ^0.4.0  # SPP蓝牙通讯库
```

---

## 架构设计

### 通讯层架构
```
┌─────────────────────────────────────┐
│         TestState (状态管理)         │
├─────────────────────────────────────┤
│  - testMode: TestMode               │
│  - serialService: SerialService     │
│  - sppService: SppService           │
└─────────────────┬───────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
┌───────▼────────┐  ┌──────▼──────────┐
│ SerialService  │  │   SppService    │
│  (单板产测)     │  │  (整机产测)      │
├────────────────┤  ├─────────────────┤
│ - 串口通讯      │  │ - SPP蓝牙通讯    │
│ - GTP协议      │  │ - 数据包解析     │
│ - 2000000波特率 │  │ - 序列号跟踪     │
└────────────────┘  └─────────────────┘
```

### UI层架构
```
┌──────────────────────────────────────┐
│          HomeScreen (主界面)          │
├──────────────────────────────────────┤
│  ┌────────────────────────────────┐  │
│  │   TestModeSelector (模式选择)   │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │  ConnectionSelector (连接选择)  │  │
│  │  - 单板: 串口选择               │  │
│  │  - 整机: 蓝牙设备选择           │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │   FactoryTestSection (测试区)   │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

---

## 使用流程

### 单板产测流程:
1. 选择"单板产测"模式
2. 从下拉列表选择串口
3. 点击"连接"按钮
4. 执行各项测试

### 整机产测流程:
1. 选择"整机产测"模式
2. 点击"扫描"按钮搜索蓝牙设备
3. 从下拉列表选择目标设备
4. 点击"连接设备"按钮
5. 执行各项测试

---

## SPP协议数据包格式

### 发送格式:
```
[AA 55] [LEN_H LEN_L] [DATA...] [CHECKSUM]
```

### 接收格式:
```
[AA 55] [LEN_H LEN_L] [PAYLOAD...] [CHECKSUM]
```

### 解析流程:
1. 在缓冲区中查找包头 `0xAA 0x55`
2. 读取包长度（2字节，大端序）
3. 等待完整数据包接收
4. 提取payload并触发回调

---

## 关键特性

### 1. **模式隔离**
- 两种模式完全独立
- 切换模式时自动断开当前连接
- 防止模式混淆

### 2. **状态同步**
- 连接状态实时更新
- UI自动响应状态变化
- 日志统一管理

### 3. **错误处理**
- 完整的异常捕获
- 详细的错误日志
- 用户友好的错误提示

### 4. **扩展性**
- SPP服务独立封装
- 易于添加新的通讯协议
- 测试逻辑与通讯层解耦

---

## 后续开发建议

### 1. **完善整机产测逻辑**
- 基于SPP服务实现整机测试命令
- 定义整机测试序列
- 实现整机测试报告

### 2. **优化SPP通讯**
- 添加重连机制
- 实现心跳检测
- 优化数据包解析性能

### 3. **增强用户体验**
- 添加连接历史记录
- 实现设备自动识别
- 优化扫描速度

### 4. **测试覆盖**
- 单元测试SPP服务
- 集成测试两种模式
- 压力测试数据传输

---

## 技术栈

- **Flutter**: 3.0+
- **Provider**: 状态管理
- **flutter_libserialport**: 串口通讯
- **flutter_bluetooth_serial**: SPP蓝牙通讯
- **Dart**: 异步编程、Stream处理

---

## 注意事项

1. **权限要求**:
   - 单板模式: 串口访问权限
   - 整机模式: 蓝牙权限（需在AndroidManifest.xml/Info.plist配置）

2. **平台兼容性**:
   - 单板模式: macOS, Linux, Windows
   - 整机模式: Android, iOS（需测试验证）

3. **依赖安装**:
   ```bash
   flutter pub get
   ```

4. **蓝牙配对**:
   - 设备需提前配对
   - 扫描仅显示已配对设备

---

## 总结

本次实现成功将单板产测和整机产测进行了清晰的区分，并为整机产测提供了完整的SPP蓝牙通讯基础设施。UI设计直观易用，代码结构清晰，易于维护和扩展。
