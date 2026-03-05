import 'dart:async';
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../models/log_state.dart';
import '../config/test_config.dart';

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
      
      // Check platform support
      if (!_isPlatformSupported()) {
        _logState?.warning('⚠️ 当前平台 (${Platform.operatingSystem}) 不支持SPP蓝牙');
        _logState?.info('   支持的平台: Windows, Android');
        _logState?.info('   macOS/iOS 请使用BLE或其他通信方式');
        return [];
      }
      
      // Check if Bluetooth is available
      final isAvailable = await FlutterBluetoothSerial.instance.isAvailable ?? false;
      if (!isAvailable) {
        _logState?.error('❌ 蓝牙不可用');
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
      _logState?.error('❌ 扫描蓝牙设备失败: $e');
      if (e.toString().contains('MissingPluginException')) {
        _logState?.warning('   提示: flutter_bluetooth_serial 不支持当前平台');
        _logState?.info('   当前平台: ${Platform.operatingSystem}');
        _logState?.info('   支持平台: Windows, Android');
      }
      return [];
    }
  }
  
  /// Check if current platform supports SPP Bluetooth
  bool _isPlatformSupported() {
    // flutter_bluetooth_serial only supports Windows and Android
    return Platform.isWindows || Platform.isAndroid;
  }
  
  /// Check if connected
  bool get isConnected => _isConnected;
  
  /// Get current device
  BluetoothDevice? get currentDevice => _currentDevice;
  
  /// Get data stream
  Stream<Uint8List> get dataStream => _dataController.stream;
  
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
      
      // Connect to device
      _logState?.info('⏳ 正在建立SPP连接...');
      _connection = await BluetoothConnection.toAddress(device.address);
      
      if (_connection == null || !_connection!.isConnected) {
        _logState?.error('❌ SPP连接失败');
        return false;
      }
      
      _currentDevice = device;
      _isConnected = true;
      
      _logState?.success('✅ SPP连接成功');
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
      _logState?.error('❌ SPP连接异常: $e');
      _isConnected = false;
      _currentDevice = null;
      return false;
    }
  }
  
  /// Disconnect from Bluetooth device
  Future<void> disconnect() async {
    try {
      if (_connection != null) {
        _logState?.info('🔌 断开SPP连接...');
        
        await _subscription?.cancel();
        _subscription = null;
        
        await _connection?.close();
        _connection = null;
        
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
    if (!_isConnected || _connection == null) {
      _logState?.error('❌ SPP未连接，无法发送数据');
      return false;
    }
    
    try {
      _connection!.output.add(data);
      await _connection!.output.allSent;
      
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
      
      // Send command
      final success = await sendData(command);
      if (!success) {
        _pendingResponses.remove(seqNum);
        return {'error': 'Failed to send command'};
      }
      
      // Wait for response with timeout
      final response = await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingResponses.remove(seqNum);
          _logState?.warning('⚠️ SPP命令超时');
          return {'error': 'Timeout'};
        },
      );
      
      _pendingResponses.remove(seqNum);
      return response;
    } catch (e) {
      _logState?.error('❌ SPP命令执行异常: $e');
      return {'error': e.toString()};
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
