import 'dart:async';
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../models/log_state.dart';
import '../config/test_config.dart';

// Conditional imports for platform-specific Bluetooth plugins
// Android: flutter_bluetooth_serial
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
    if (dart.library.io) 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
// Windows: flutter_bluetooth_classic_serial
import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart'
    as classic;

/// SPP (Serial Port Profile) Bluetooth communication service for complete device testing
/// 整机产测使用SPP协议进行蓝牙通讯
class SppService {
  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _subscription;
  final StreamController<Uint8List> _dataController = StreamController<Uint8List>.broadcast();
  
  BluetoothDevice? _currentDevice;
  bool _isConnected = false;
  LogState? _logState;
  
  // 数据包缓冲区
  Uint8List _buffer = Uint8List(0);
  int _packetCount = 0;
  
  // 序列号跟踪
  int _sequenceNumber = 0;
  final Map<int, Completer<Map<String, dynamic>?>> _pendingResponses = {};
  
  void setLogState(LogState logState) {
    _logState = logState;
  }
  
  /// Get available Bluetooth devices
  Future<List<BluetoothDevice>> getAvailableDevices() async {
    try {
      _logState?.info('🔍 开始扫描蓝牙设备...');
      _logState?.info('   当前平台: ${Platform.operatingSystem}');
      
      // Check platform support
      if (!_isPlatformSupported()) {
        _logState?.warning('⚠️ 当前平台 (${Platform.operatingSystem}) 不支持SPP蓝牙');
        _logState?.info('   支持的平台: Android, Windows');
        _logState?.info('   macOS/iOS 请使用BLE或其他通信方式');
        return [];
      }
      
      // Platform-specific implementation
      if (Platform.isAndroid) {
        return await _getAvailableDevicesAndroid();
      } else if (Platform.isWindows) {
        return await _getAvailableDevicesWindows();
      }
      
      _logState?.warning('⚠️ 当前平台不支持SPP蓝牙');
      return [];
    } catch (e) {
      _logState?.error('❌ 扫描蓝牙设备失败: $e');
      return [];
    }
  }
  
  /// Get available Bluetooth devices on Android
  Future<List<BluetoothDevice>> _getAvailableDevicesAndroid() async {
    try {
      // Check if Bluetooth is available
      final isAvailable = await FlutterBluetoothSerial.instance.isAvailable ?? false;
      if (!isAvailable) {
        _logState?.error('❌ 蓝牙不可用');
        _logState?.info('   请检查系统蓝牙是否已启用');
        return [];
      }
      
      // Check if Bluetooth is enabled
      final isEnabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
      if (!isEnabled) {
        _logState?.warning('⚠️ 蓝牙未启用，尝试启用...');
        final enabled = await FlutterBluetoothSerial.instance.requestEnable();
        if (enabled != true) {
          _logState?.error('❌ 无法启用蓝牙');
          return [];
        }
      }
      
      // Get bonded devices
      final bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      _logState?.success('✅ 找到 ${bondedDevices.length} 个已配对设备');
      
      for (var device in bondedDevices) {
        _logState?.info('  📱 ${device.name ?? "未知设备"} (${device.address})');
      }
      
      return bondedDevices;
    } catch (e) {
      _logState?.error('❌ Android 蓝牙扫描失败: $e');
      return [];
    }
  }
  
  /// Get available Bluetooth devices on Windows
  Future<List<BluetoothDevice>> _getAvailableDevicesWindows() async {
    try {
      _logState?.info('🔍 Windows: 扫描配对的蓝牙设备...');
      
      // Get paired devices using flutter_bluetooth_classic
      final bluetoothClassic = classic.FlutterBluetoothClassic();
      final pairedDevices = await bluetoothClassic.getPairedDevices();
      
      if (pairedDevices.isEmpty) {
        _logState?.warning('⚠️ 未找到已配对的蓝牙设备');
        _logState?.info('   请先在Windows设置中配对蓝牙设备');
        return [];
      }
      
      _logState?.success('✅ 找到 ${pairedDevices.length} 个已配对设备:');
      
      // Convert classic.BluetoothDevice to BluetoothDevice
      final devices = <BluetoothDevice>[];
      for (var device in pairedDevices) {
        final deviceName = device.name.isEmpty ? "未知设备" : device.name;
        _logState?.info('  📱 $deviceName (${device.address})');
        // Create a compatible BluetoothDevice object
        devices.add(BluetoothDevice(
          name: device.name,
          address: device.address,
        ));
      }
      
      return devices;
    } catch (e) {
      _logState?.error('❌ Windows 蓝牙扫描失败: $e');
      return [];
    }
  }
  
  
  /// Check if current platform supports SPP Bluetooth
  bool _isPlatformSupported() {
    // Android: flutter_bluetooth_serial
    // Windows: flutter_bluetooth_classic_serial
    return Platform.isAndroid || Platform.isWindows;
  }
  
  /// Check if connected
  bool get isConnected => _isConnected;
  
  /// Get current device
  BluetoothDevice? get currentDevice => _currentDevice;
  
  /// Get data stream
  Stream<Uint8List> get dataStream => _dataController.stream;
  
  /// Connect to Bluetooth device by MAC address (optimized for Windows)
  /// This method allows direct connection without scanning first
  Future<bool> connectByAddress(String macAddress, {String? deviceName}) async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('🔗 通过MAC地址连接蓝牙设备');
      _logState?.info('   地址: $macAddress');
      if (deviceName != null) {
        _logState?.info('   名称: $deviceName');
      }
      
      // Create a BluetoothDevice object
      final device = BluetoothDevice(
        name: deviceName,
        address: macAddress,
      );
      
      return await connect(device);
    } catch (e) {
      _logState?.error('❌ 通过MAC地址连接失败: $e');
      return false;
    }
  }
  
  /// Connect to Bluetooth device via SPP
  Future<bool> connect(BluetoothDevice device) async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('🔗 开始连接蓝牙设备: ${device.name ?? "未知设备"}');
      _logState?.info('   地址: ${device.address}');
      
      // Check platform support
      if (!_isPlatformSupported()) {
        _logState?.error('❌ 当前平台 (${Platform.operatingSystem}) 不支持SPP蓝牙连接');
        return false;
      }
      
      // Disconnect existing connection
      await disconnect();
      
      // Platform-specific connection
      if (Platform.isAndroid) {
        return await _connectAndroid(device);
      } else if (Platform.isWindows) {
        return await _connectWindows(device);
      }
      
      _logState?.error('❌ 当前平台不支持SPP蓝牙连接');
      _logState?.info('   仅支持 Android 和 Windows 平台');
      return false;
    } catch (e) {
      _logState?.error('❌ SPP连接异常: $e');
      _isConnected = false;
      _currentDevice = null;
      return false;
    }
  }
  
  /// Connect to Bluetooth device on Android
  /// 
  /// 关于 SPP 连接和 RFCOMM 通道：
  /// - flutter_bluetooth_serial 使用 Serial Port Profile (SPP)
  /// - BluetoothConnection.toAddress() 会自动通过 SDP (Service Discovery Protocol) 
  ///   查找设备上的 SPP 服务并连接到对应的 RFCOMM 通道
  /// - 不需要手动指定 channel 或 UUID，库会自动处理
  /// - SPP 标准 UUID: 00001101-0000-1000-8000-00805F9B34FB
  /// - RFCOMM 通道通常在 1-30 之间，由设备的 SDP 服务器动态分配
  /// 
  /// 注意：当前版本不支持指定特定 UUID，如需连接非标准 SPP 服务，
  /// 需要等待库更新或使用其他蓝牙插件
  Future<bool> _connectAndroid(BluetoothDevice device) async {
    try {
      // Connect to device - 自动使用 SPP/RFCOMM
      _logState?.info('⏳ 正在建立SPP连接...');
      _logState?.debug('   通过 SDP 查找 SPP 服务 (UUID: 00001101-...)');
      _connection = await BluetoothConnection.toAddress(device.address);
      
      if (_connection == null || !_connection!.isConnected) {
        _logState?.error('❌ SPP连接失败');
        _logState?.warning('   可能原因: 设备未提供 SPP 服务或 RFCOMM 通道不可用');
        return false;
      }
      
      _currentDevice = device;
      _isConnected = true;
      
      _logState?.success('✅ SPP连接成功');
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // 打印连接详情
      _logState?.info('📋 连接信息:');
      _logState?.info('   设备名称: ${device.name ?? "未知"}');
      _logState?.info('   设备地址: ${device.address}');
      _logState?.info('   连接状态: ${_connection!.isConnected ? "已连接" : "未连接"}');
      _logState?.info('   SPP UUID: 00001101-0000-1000-8000-00805F9B34FB');
      
      // 注意：BluetoothConnection 类不提供获取 RFCOMM 通道号的方法
      // 如需查看通道号，可以通过以下方式：
      // 1. 使用 adb logcat 查看 Android 系统日志
      // 2. 搜索 "RFCOMM" 或 "BluetoothSocket" 关键字
      // 3. 日志中会显示类似 "connect to RFCOMM channel X" 的信息
      _logState?.debug('   提示: RFCOMM 通道号可通过 adb logcat 查看');
      _logState?.debug('   命令: adb logcat | grep -i "rfcomm\\|bluetooth"');
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // Start listening to incoming data
      _subscription = _connection!.input!.listen(
        _onDataReceived,
        onError: (error) {
          _logState?.error('❌ SPP数据接收错误: $error');
          disconnect();
        },
        onDone: () {
          _logState?.warning('⚠️ SPP连接已断开');
          disconnect();
        },
      );
      
      return true;
    } catch (e) {
      _logState?.error('❌ Android SPP连接失败: $e');
      return false;
    }
  }
  
  /// Connect to Bluetooth device on Windows
  Future<bool> _connectWindows(BluetoothDevice device) async {
    try {
      _logState?.info('⏳ Windows: 正在建立SPP连接...');
      
      // Connect using flutter_bluetooth_classic
      final bluetoothClassic = classic.FlutterBluetoothClassic();
      final result = await bluetoothClassic.connect(device.address);
      
      if (result != true) {
        _logState?.error('❌ Windows SPP连接失败');
        return false;
      }
      
      _currentDevice = device;
      _isConnected = true;
      
      _logState?.success('✅ Windows SPP连接成功');
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // 打印连接详情
      _logState?.info('📋 连接信息:');
      _logState?.info('   平台: Windows');
      _logState?.info('   设备名称: ${device.name ?? "未知"}');
      _logState?.info('   设备地址: ${device.address}');
      _logState?.info('   连接方式: 系统配对设备');
      _logState?.info('   SPP UUID: 00001101-0000-1000-8000-00805F9B34FB');
      _logState?.debug('   提示: Windows 使用系统蓝牙服务，通道信息由系统管理');
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // Start listening to incoming data
      bluetoothClassic.onDataReceived.listen(
        (data) {
          final receivedData = data.data;
          if (receivedData.isNotEmpty) {
            _onDataReceived(Uint8List.fromList(receivedData));
          }
        },
        onError: (error) {
          _logState?.error('❌ Windows SPP数据接收错误: $error');
        },
        onDone: () {
          _logState?.warning('⚠️ Windows SPP连接已断开');
          disconnect();
        },
      );
      
      return true;
    } catch (e) {
      _logState?.error('❌ Windows SPP连接失败: $e');
      return false;
    }
  }
  
  
  /// Disconnect from Bluetooth device
  Future<void> disconnect() async {
    try {
      if (_isConnected || _connection != null) {
        _logState?.info('🔌 断开SPP连接...');
        
        // Platform-specific disconnection
        if (Platform.isAndroid) {
          await _subscription?.cancel();
          _subscription = null;
          
          await _connection?.close();
          _connection = null;
        } else if (Platform.isWindows) {
          // Disconnect Windows Bluetooth
          final bluetoothClassic = classic.FlutterBluetoothClassic();
          await bluetoothClassic.disconnect();
        }
        
        _isConnected = false;
        _currentDevice = null;
        
        // Clear pending responses
        for (var completer in _pendingResponses.values) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
        _pendingResponses.clear();
        
        // Clear buffer
        _buffer = Uint8List(0);
        
        _logState?.success('✅ SPP连接已断开');
      }
    } catch (e) {
      _logState?.error('❌ 断开SPP连接时出错: $e');
    }
  }
  
  /// Send data via SPP
  Future<bool> sendData(Uint8List data) async {
    if (!_isConnected) {
      _logState?.error('❌ SPP未连接，无法发送数据');
      return false;
    }
    
    try {
      // Platform-specific data sending
      if (Platform.isAndroid) {
        if (_connection == null) {
          _logState?.error('❌ Android SPP连接为空');
          return false;
        }
        _connection!.output.add(data);
        await _connection!.output.allSent;
      } else if (Platform.isWindows) {
        // Send data via flutter_bluetooth_classic
        final bluetoothClassic = classic.FlutterBluetoothClassic();
        await bluetoothClassic.sendData(data);
      }
      
      _logState?.debug('📤 SPP发送: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      return true;
    } catch (e) {
      _logState?.error('❌ SPP发送数据失败: $e');
      return false;
    }
  }
  
  /// Send command and wait for response (similar to serial service)
  Future<Map<String, dynamic>?> sendCommandAndWaitResponse(
    Uint8List command, {
    Duration timeout = TestConfig.defaultTimeout,
    int? moduleId,
    int? messageId,
  }) async {
    if (!_isConnected) {
      _logState?.error('❌ SPP未连接');
      return {'error': 'SPP not connected'};
    }
    
    try {
      final seqNum = _sequenceNumber++;
      final completer = Completer<Map<String, dynamic>?>();
      _pendingResponses[seqNum] = completer;
      
      _logState?.debug('🔄 [SPP] 序列号: $seqNum, 等待响应 (超时: ${timeout.inSeconds}秒)');
      if (moduleId != null) {
        _logState?.debug('   期望模块ID: 0x${moduleId.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
      if (messageId != null) {
        _logState?.debug('   期望消息ID: 0x${messageId.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
      
      // Send command
      final success = await sendData(command);
      if (!success) {
        _pendingResponses.remove(seqNum);
        _logState?.error('❌ [SPP] 发送命令失败');
        return {'error': 'Failed to send command'};
      }
      
      _logState?.debug('⏳ [SPP] 等待响应中...');
      
      // Wait for response with timeout
      final response = await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingResponses.remove(seqNum);
          _logState?.warning('⚠️ [SPP] 命令超时 (${timeout.inSeconds}秒)');
          _logState?.warning('   当前待处理响应数: ${_pendingResponses.length}');
          _logState?.warning('   缓冲区大小: ${_buffer.length} 字节');
          return {'error': 'Timeout', 'details': 'No response received within ${timeout.inSeconds} seconds'};
        },
      );
      
      _pendingResponses.remove(seqNum);
      
      if (response != null && !response.containsKey('error')) {
        _logState?.success('✅ [SPP] 收到有效响应');
      }
      
      return response;
    } catch (e) {
      _logState?.error('❌ [SPP] 命令执行异常: $e');
      return {'error': e.toString(), 'details': 'Exception during command execution'};
    }
  }
  
  /// Handle received data
  void _onDataReceived(Uint8List data) {
    try {
      _logState?.debug('📥 SPP接收: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      
      // Add to buffer
      final newBuffer = Uint8List(_buffer.length + data.length);
      newBuffer.setRange(0, _buffer.length, _buffer);
      newBuffer.setRange(_buffer.length, newBuffer.length, data);
      _buffer = newBuffer;
      
      // Process complete packets from buffer
      _processBuffer();
      
      // Broadcast raw data
      _dataController.add(data);
    } catch (e) {
      _logState?.error('❌ SPP数据处理异常: $e');
    }
  }
  
  /// Process buffer to extract complete packets
  void _processBuffer() {
    while (_buffer.length >= 4) { // Minimum packet size
      // Try to find packet start (0xAA 0x55)
      int startIndex = -1;
      for (int i = 0; i < _buffer.length - 1; i++) {
        if (_buffer[i] == 0xAA && _buffer[i + 1] == 0x55) {
          startIndex = i;
          break;
        }
      }
      
      if (startIndex == -1) {
        // No packet start found, clear buffer
        _buffer = Uint8List(0);
        break;
      }
      
      // Remove data before packet start
      if (startIndex > 0) {
        _buffer = _buffer.sublist(startIndex);
      }
      
      // Check if we have enough data for header
      if (_buffer.length < 8) {
        break; // Wait for more data
      }
      
      // Parse packet length (assuming format: AA 55 LEN_H LEN_L ...)
      final packetLength = (_buffer[2] << 8) | _buffer[3];
      final totalLength = packetLength + 4; // Including header
      
      if (_buffer.length < totalLength) {
        break; // Wait for complete packet
      }
      
      // Extract complete packet
      final packet = _buffer.sublist(0, totalLength);
      _buffer = _buffer.sublist(totalLength);
      
      // Process packet
      _processPacket(packet);
    }
  }
  
  /// Process a complete packet
  void _processPacket(Uint8List packet) {
    try {
      _packetCount++;
      _logState?.debug('📦 SPP数据包 #$_packetCount: ${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      
      // Parse packet and complete pending response
      final response = {
        'payload': packet,
        'timestamp': DateTime.now(),
      };
      
      // Complete the oldest pending response
      if (_pendingResponses.isNotEmpty) {
        final firstKey = _pendingResponses.keys.first;
        final completer = _pendingResponses[firstKey];
        if (!completer!.isCompleted) {
          completer.complete(response);
        }
      }
    } catch (e) {
      _logState?.error('❌ SPP数据包处理异常: $e');
    }
  }
  
  /// Dispose resources
  void dispose() {
    disconnect();
    _dataController.close();
  }
}
