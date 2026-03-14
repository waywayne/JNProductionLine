import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/log_state.dart';
import '../config/test_config.dart';

/// Linux Bluetooth SPP Service
/// 基于 Linux 蓝牙栈实现的 SPP 协议通信服务
/// 支持自定义 UUID 服务发现和 RFCOMM 通道绑定
class LinuxBluetoothSppService {
  Process? _bluetoothProcess;
  Socket? _socket;
  StreamSubscription? _subscription;
  final StreamController<Uint8List> _dataController = StreamController<Uint8List>.broadcast();
  
  String? _currentDeviceAddress;
  String? _currentDeviceName;
  int? _currentChannel;
  bool _isConnected = false;
  LogState? _logState;
  
  // 数据包缓冲区
  Uint8List _buffer = Uint8List(0);
  int _packetCount = 0;
  
  // 序列号跟踪
  int _sequenceNumber = 0;
  final Map<int, Completer<Map<String, dynamic>?>> _pendingResponses = {};
  
  // 自定义 UUID（SPP 标准 UUID）
  static const String defaultSppUuid = '00001101-0000-1000-8000-00805F9B34FB';
  String _serviceUuid = defaultSppUuid;
  
  void setLogState(LogState logState) {
    _logState = logState;
  }
  
  /// 设置自定义服务 UUID
  void setServiceUuid(String uuid) {
    _serviceUuid = uuid;
    _logState?.info('设置服务 UUID: $_serviceUuid');
  }
  
  /// 检查是否已连接
  bool get isConnected => _isConnected;
  
  /// 获取当前设备地址
  String? get currentDeviceAddress => _currentDeviceAddress;
  
  /// 获取当前设备名称
  String? get currentDeviceName => _currentDeviceName;
  
  /// 获取当前 RFCOMM 通道
  int? get currentChannel => _currentChannel;
  
  /// 获取数据流
  Stream<Uint8List> get dataStream => _dataController.stream;
  
  /// 扫描可用的蓝牙设备
  Future<List<Map<String, String>>> scanDevices({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('🔍 开始扫描蓝牙设备 (Linux)');
      
      // 改进的扫描策略：
      // 1. 先清除已配对设备缓存（可选）
      // 2. 使用 hcitool 进行扫描（更可靠）
      // 3. 同时使用 bluetoothctl 获取设备名称
      
      _logState?.info('   使用 hcitool 扫描附近设备...');
      
      // 使用 hcitool scan 扫描附近设备（不依赖缓存）
      final scanScript = '''
# 确保蓝牙适配器开启
hciconfig hci0 up 2>/dev/null || true

# 使用 hcitool 扫描（实时扫描，不依赖缓存）
hcitool scan --flush 2>/dev/null || hcitool scan 2>/dev/null
''';
      
      final scanResult = await Process.run('bash', ['-c', scanScript]);
      
      _logState?.info('⏳ 解析扫描结果...');
      
      final devices = <Map<String, String>>[];
      final lines = scanResult.stdout.toString().split('\n');
      
      for (final line in lines) {
        if (line.trim().isEmpty || line.contains('Scanning')) continue;
        
        // hcitool scan 格式: \tAA:BB:CC:DD:EE:FF\tDevice Name
        final parts = line.trim().split('\t');
        if (parts.length >= 2) {
          final address = parts[0].trim().toUpperCase();
          final name = parts.length > 1 ? parts[1].trim() : 'Unknown Device';
          
          // 验证 MAC 地址格式
          if (RegExp(r'^[0-9A-F:]{17}$', caseSensitive: false).hasMatch(address)) {
            // 避免重复添加
            if (!devices.any((d) => d['address'] == address)) {
              devices.add({
                'address': address,
                'name': name.isNotEmpty ? name : 'Unknown Device',
              });
              _logState?.info('  📱 $name ($address)');
            }
          }
        }
      }
      
      // 如果 hcitool 没有找到设备，尝试使用 bluetoothctl
      if (devices.isEmpty) {
        _logState?.info('   hcitool 未找到设备，尝试 bluetoothctl...');
        
        final btctlScript = '''
# 清除设备缓存并重新扫描
bluetoothctl << EOF
remove *
scan on
EOF
sleep 3
bluetoothctl << EOF
scan off
devices
EOF
''';
        
        final btctlResult = await Process.run('bash', ['-c', btctlScript]);
        final btctlLines = btctlResult.stdout.toString().split('\n');
        
        for (final line in btctlLines) {
          if (line.trim().isEmpty) continue;
          
          // 格式: Device AA:BB:CC:DD:EE:FF Device Name
          final match = RegExp(r'Device\s+([0-9A-Fa-f:]+)\s+(.+)', caseSensitive: false).firstMatch(line);
          if (match != null) {
            final address = match.group(1)!.toUpperCase();
            final name = match.group(2)!.trim();
            
            if (!devices.any((d) => d['address'] == address)) {
              devices.add({
                'address': address,
                'name': name,
              });
              _logState?.info('  📱 $name ($address)');
            }
          }
        }
      }
      
      _logState?.success('✅ 找到 ${devices.length} 个设备');
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      return devices;
    } catch (e) {
      _logState?.error('❌ 扫描蓝牙设备异常: $e');
      return [];
    }
  }
  
  /// 通过 SDP 查询设备的服务和 RFCOMM 通道
  Future<int?> discoverServiceChannel(String deviceAddress, {String? uuid}) async {
    try {
      final targetUuid = uuid ?? _serviceUuid;
      _logState?.info('🔍 查询设备服务 (SDP)');
      _logState?.info('   设备地址: $deviceAddress');
      _logState?.info('   服务 UUID: $targetUuid');
      
      // 使用 sdptool 查询服务
      final result = await Process.run('sdptool', ['browse', deviceAddress]);
      
      if (result.exitCode != 0) {
        _logState?.error('❌ SDP 查询失败: ${result.stderr}');
        return null;
      }
      
      final output = result.stdout.toString();
      _logState?.debug('SDP 查询结果:\n$output');
      
      // 解析 RFCOMM 通道号
      // 查找包含目标 UUID 的服务记录
      final lines = output.split('\n');
      int? channel;
      bool foundService = false;
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        
        // 查找 UUID 匹配
        if (line.contains(targetUuid.toUpperCase()) || 
            line.contains(targetUuid.toLowerCase())) {
          foundService = true;
          _logState?.info('✅ 找到匹配的服务 UUID');
        }
        
        // 在找到服务后，查找 RFCOMM 通道号
        if (foundService && line.contains('Channel:')) {
          final channelMatch = RegExp(r'Channel:\s*(\d+)').firstMatch(line);
          if (channelMatch != null) {
            channel = int.parse(channelMatch.group(1)!);
            _logState?.success('✅ 发现 RFCOMM 通道: $channel');
            break;
          }
        }
      }
      
      if (channel == null) {
        _logState?.warning('⚠️ 未找到 RFCOMM 通道，使用默认通道 1');
        channel = 1;
      }
      
      return channel;
    } catch (e) {
      _logState?.error('❌ 服务发现异常: $e');
      _logState?.warning('⚠️ 使用默认通道 1');
      return 1;
    }
  }
  
  /// 连接到蓝牙设备
  Future<bool> connect(String deviceAddress, {String? deviceName, int? channel, String? uuid}) async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('🔗 开始连接蓝牙设备 (Linux SPP)');
      _logState?.info('   地址: $deviceAddress');
      if (deviceName != null) {
        _logState?.info('   名称: $deviceName');
      }
      
      // 断开现有连接
      await disconnect();
      
      // 如果未指定通道，则通过 SDP 查询
      int targetChannel;
      if (channel != null) {
        targetChannel = channel;
        _logState?.info('   使用指定通道: $targetChannel');
      } else {
        _logState?.info('   开始服务发现...');
        final discoveredChannel = await discoverServiceChannel(deviceAddress, uuid: uuid);
        if (discoveredChannel == null) {
          _logState?.error('❌ 服务发现失败');
          return false;
        }
        targetChannel = discoveredChannel;
      }
      
      _currentChannel = targetChannel;
      
      // 使用 rfcomm 绑定通道
      _logState?.info('⏳ 绑定 RFCOMM 通道...');
      final bindResult = await Process.run('rfcomm', [
        'bind',
        '0',
        deviceAddress,
        targetChannel.toString(),
      ]);
      
      if (bindResult.exitCode != 0) {
        _logState?.error('❌ RFCOMM 绑定失败: ${bindResult.stderr}');
        return false;
      }
      
      _logState?.success('✅ RFCOMM 通道绑定成功');
      
      // 等待设备文件创建
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 连接到 RFCOMM 设备
      final devicePath = '/dev/rfcomm0';
      _logState?.info('⏳ 连接到设备: $devicePath');
      
      // 使用 socat 建立连接
      _bluetoothProcess = await Process.start('socat', [
        '-',
        'FILE:$devicePath,b115200,raw,echo=0',
      ]);
      
      if (_bluetoothProcess == null) {
        _logState?.error('❌ 启动连接进程失败');
        await _unbindRfcomm();
        return false;
      }
      
      _currentDeviceAddress = deviceAddress;
      _currentDeviceName = deviceName;
      _isConnected = true;
      
      _logState?.success('✅ SPP 连接成功');
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('📋 连接信息:');
      _logState?.info('   设备地址: $deviceAddress');
      if (deviceName != null) {
        _logState?.info('   设备名称: $deviceName');
      }
      _logState?.info('   RFCOMM 通道: $targetChannel');
      _logState?.info('   服务 UUID: ${uuid ?? _serviceUuid}');
      _logState?.info('   设备路径: $devicePath');
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // 监听数据
      _subscription = _bluetoothProcess!.stdout.listen(
        (data) => _onDataReceived(Uint8List.fromList(data)),
        onError: (error) {
          _logState?.error('❌ 数据接收错误: $error');
          disconnect();
        },
        onDone: () {
          _logState?.warning('⚠️ 连接已断开');
          disconnect();
        },
      );
      
      return true;
    } catch (e) {
      _logState?.error('❌ 连接失败: $e');
      await _unbindRfcomm();
      return false;
    }
  }
  
  /// 解除 RFCOMM 绑定
  Future<void> _unbindRfcomm() async {
    try {
      await Process.run('rfcomm', ['release', '0']);
    } catch (e) {
      _logState?.debug('解除 RFCOMM 绑定时出错: $e');
    }
  }
  
  /// 断开连接
  Future<void> disconnect() async {
    try {
      if (_isConnected || _bluetoothProcess != null) {
        _logState?.info('🔌 断开 SPP 连接...');
        
        await _subscription?.cancel();
        _subscription = null;
        
        _bluetoothProcess?.kill();
        _bluetoothProcess = null;
        
        await _unbindRfcomm();
        
        _isConnected = false;
        _currentDeviceAddress = null;
        _currentDeviceName = null;
        _currentChannel = null;
        
        // 清理待处理的响应
        for (var completer in _pendingResponses.values) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
        _pendingResponses.clear();
        
        // 清理缓冲区
        _buffer = Uint8List(0);
        
        _logState?.success('✅ SPP 连接已断开');
      }
    } catch (e) {
      _logState?.error('❌ 断开连接时出错: $e');
    }
  }
  
  /// 发送数据
  Future<bool> sendData(Uint8List data) async {
    if (!_isConnected || _bluetoothProcess == null) {
      _logState?.error('❌ 未连接，无法发送数据');
      return false;
    }
    
    try {
      _bluetoothProcess!.stdin.add(data);
      await _bluetoothProcess!.stdin.flush();
      
      _logState?.debug('📤 发送: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      return true;
    } catch (e) {
      _logState?.error('❌ 发送数据失败: $e');
      return false;
    }
  }
  
  /// 发送命令并等待响应
  Future<Map<String, dynamic>?> sendCommandAndWaitResponse(
    Uint8List command, {
    Duration timeout = TestConfig.defaultTimeout,
    int? moduleId,
    int? messageId,
  }) async {
    if (!_isConnected) {
      _logState?.error('❌ 未连接');
      return {'error': 'Not connected'};
    }
    
    try {
      final seqNum = _sequenceNumber++;
      final completer = Completer<Map<String, dynamic>?>();
      _pendingResponses[seqNum] = completer;
      
      _logState?.debug('🔄 序列号: $seqNum, 等待响应 (超时: ${timeout.inSeconds}秒)');
      
      // 发送命令
      final success = await sendData(command);
      if (!success) {
        _pendingResponses.remove(seqNum);
        return {'error': 'Failed to send command'};
      }
      
      // 等待响应
      final response = await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingResponses.remove(seqNum);
          _logState?.warning('⚠️ 命令超时 (${timeout.inSeconds}秒)');
          return {'error': 'Timeout'};
        },
      );
      
      _pendingResponses.remove(seqNum);
      return response;
    } catch (e) {
      _logState?.error('❌ 命令执行异常: $e');
      return {'error': e.toString()};
    }
  }
  
  /// 处理接收到的数据
  void _onDataReceived(Uint8List data) {
    try {
      _logState?.debug('📥 接收: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      
      // 添加到缓冲区
      final newBuffer = Uint8List(_buffer.length + data.length);
      newBuffer.setRange(0, _buffer.length, _buffer);
      newBuffer.setRange(_buffer.length, newBuffer.length, data);
      _buffer = newBuffer;
      
      // 处理完整数据包
      _processBuffer();
      
      // 广播原始数据
      _dataController.add(data);
    } catch (e) {
      _logState?.error('❌ 数据处理异常: $e');
    }
  }
  
  /// 处理缓冲区中的数据包
  void _processBuffer() {
    while (_buffer.length >= 4) {
      // 查找数据包起始标志 (0xAA 0x55)
      int startIndex = -1;
      for (int i = 0; i < _buffer.length - 1; i++) {
        if (_buffer[i] == 0xAA && _buffer[i + 1] == 0x55) {
          startIndex = i;
          break;
        }
      }
      
      if (startIndex == -1) {
        _buffer = Uint8List(0);
        break;
      }
      
      if (startIndex > 0) {
        _buffer = _buffer.sublist(startIndex);
      }
      
      if (_buffer.length < 8) {
        break;
      }
      
      // 解析数据包长度
      final packetLength = (_buffer[2] << 8) | _buffer[3];
      final totalLength = packetLength + 4;
      
      if (_buffer.length < totalLength) {
        break;
      }
      
      // 提取完整数据包
      final packet = _buffer.sublist(0, totalLength);
      _buffer = _buffer.sublist(totalLength);
      
      _processPacket(packet);
    }
  }
  
  /// 处理完整数据包
  void _processPacket(Uint8List packet) {
    try {
      _packetCount++;
      _logState?.debug('📦 数据包 #$_packetCount: ${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      
      final response = {
        'payload': packet,
        'timestamp': DateTime.now(),
      };
      
      // 完成最早的待处理响应
      if (_pendingResponses.isNotEmpty) {
        final firstKey = _pendingResponses.keys.first;
        final completer = _pendingResponses[firstKey];
        if (!completer!.isCompleted) {
          completer.complete(response);
        }
      }
    } catch (e) {
      _logState?.error('❌ 数据包处理异常: $e');
    }
  }
  
  /// 释放资源
  void dispose() {
    disconnect();
    _dataController.close();
  }
}
