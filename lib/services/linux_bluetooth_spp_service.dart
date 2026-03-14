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
  
  /// 将短 UUID 转换为完整的 128-bit UUID
  String _expandUuid(String uuid) {
    // 移除可能的前缀
    uuid = uuid.replaceAll('0x', '').replaceAll('0X', '');
    
    // 如果是 4 位短 UUID (如 7033)
    if (uuid.length == 4) {
      return '0000$uuid-0000-1000-8000-00805F9B34FB'.toUpperCase();
    }
    
    // 如果是 8 位 UUID
    if (uuid.length == 8) {
      return '$uuid-0000-1000-8000-00805F9B34FB'.toUpperCase();
    }
    
    // 已经是完整 UUID
    return uuid.toUpperCase();
  }
  
  /// 通过 SDP 查询设备的服务和 RFCOMM 通道
  Future<int?> discoverServiceChannel(String deviceAddress, {String? uuid}) async {
    try {
      final inputUuid = uuid ?? _serviceUuid;
      final fullUuid = _expandUuid(inputUuid);
      final shortUuid = inputUuid.replaceAll('0x', '').replaceAll('0X', '');
      
      _logState?.info('🔍 查询设备服务 (SDP)');
      _logState?.info('   设备地址: $deviceAddress');
      _logState?.info('   输入 UUID: $inputUuid');
      _logState?.info('   完整 UUID: $fullUuid');
      
      // 使用 sdptool 查询服务
      final result = await Process.run('sdptool', ['browse', deviceAddress]);
      
      if (result.exitCode != 0) {
        _logState?.error('❌ SDP 查询失败: ${result.stderr}');
        return null;
      }
      
      final output = result.stdout.toString();
      _logState?.info('📋 SDP 查询结果:');
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info(output);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // 解析 RFCOMM 通道号
      // 将输出按服务记录分组
      final serviceRecords = <Map<String, dynamic>>[];
      Map<String, dynamic>? currentService;
      
      for (final line in lines) {
        // 检测新的服务记录开始
        if (line.contains('Service RecHandle:')) {
          if (currentService != null) {
            serviceRecords.add(currentService);
          }
          currentService = {
            'lines': <String>[],
            'channel': null,
            'uuids': <String>[],
          };
        }
        
        if (currentService != null) {
          currentService['lines'].add(line);
          
          // 提取通道号
          if (line.contains('Channel:')) {
            final channelMatch = RegExp(r'Channel:\s*(\d+)').firstMatch(line);
            if (channelMatch != null) {
              currentService['channel'] = int.parse(channelMatch.group(1)!);
            }
          }
          
          // 提取所有 UUID
          final uuidMatch = RegExp(r'0x([0-9a-fA-F]{4})').allMatches(line);
          for (final match in uuidMatch) {
            currentService['uuids'].add(match.group(1)!.toUpperCase());
          }
          
          // 也匹配完整 UUID
          final fullUuidMatch = RegExp(r'([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})').allMatches(line);
          for (final match in fullUuidMatch) {
            currentService['uuids'].add(match.group(1)!.toUpperCase());
          }
        }
      }
      
      if (currentService != null) {
        serviceRecords.add(currentService);
      }
      
      _logState?.info('📋 找到 ${serviceRecords.length} 个服务记录');
      
      // 查找匹配的服务
      int? channel;
      for (int i = 0; i < serviceRecords.length; i++) {
        final service = serviceRecords[i];
        final serviceChannel = service['channel'];
        final serviceUuids = service['uuids'] as List<String>;
        
        _logState?.debug('服务 #${i + 1}: 通道=$serviceChannel, UUIDs=$serviceUuids');
        
        // 检查是否包含目标 UUID
        bool matched = false;
        for (final uuid in serviceUuids) {
          if (uuid == shortUuid.toUpperCase() || uuid == fullUuid) {
            matched = true;
            _logState?.info('✅ 服务 #${i + 1} 匹配 UUID: $uuid');
            break;
          }
        }
        
        if (matched && serviceChannel != null) {
          channel = serviceChannel;
          _logState?.success('✅ 找到匹配的 RFCOMM 通道: $channel');
          _logState?.info('   服务 UUIDs: $serviceUuids');
          break;
        }
      }
      
      if (channel == null) {
        _logState?.warning('⚠️ 未找到匹配 UUID 的 RFCOMM 通道');
        _logState?.info('   提示: 可以在连接时手动指定通道号 (例如: channel: 4)');
        return null;
      }
      
      return channel;
    } catch (e) {
      _logState?.error('❌ 服务发现异常: $e');
      return null;
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
      
      // 详细的发送日志
      final hexStr = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      final asciiStr = String.fromCharCodes(
        data.map((b) => (b >= 32 && b <= 126) ? b : 46), // 46 = '.'
      );
      _logState?.debug('📤 发送 [${data.length} 字节]: $hexStr');
      _logState?.info('📤 发送: $hexStr (ASCII: $asciiStr)');
      
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
      
      _logState?.info('🔄 序列号: $seqNum, 等待响应 (超时: ${timeout.inSeconds}秒)');
      _logState?.debug('   命令长度: ${command.length} 字节');
      
      // 发送命令
      final success = await sendData(command);
      if (!success) {
        _pendingResponses.remove(seqNum);
        _logState?.error('❌ 命令发送失败');
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
      // 详细的接收日志
      final hexStr = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      final asciiStr = String.fromCharCodes(
        data.map((b) => (b >= 32 && b <= 126) ? b : 46), // 46 = '.'
      );
      _logState?.debug('📥 接收 [${data.length} 字节]: $hexStr');
      _logState?.info('📥 接收: $hexStr (ASCII: $asciiStr)');
      
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
    _logState?.debug('🔍 处理缓冲区，当前长度: ${_buffer.length} 字节');
    
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
        // 没有找到起始标志，记录并保留部分数据
        final bufferHex = _buffer.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
        _logState?.warning('⚠️ 缓冲区中未找到起始标志 (AA 55)');
        _logState?.debug('   缓冲区内容: $bufferHex');
        
        // 只保留最后一个字节（可能是 0xAA 的开始）
        if (_buffer.isNotEmpty) {
          _buffer = _buffer.sublist(_buffer.length - 1);
        } else {
          _buffer = Uint8List(0);
        }
        break;
      }
      
      if (startIndex > 0) {
        _logState?.debug('   跳过 $startIndex 字节垃圾数据');
        _buffer = _buffer.sublist(startIndex);
      }
      
      if (_buffer.length < 8) {
        _logState?.debug('   数据不足，等待更多数据 (当前: ${_buffer.length}, 需要: 8)');
        break;
      }
      
      // 解析数据包长度
      final packetLength = (_buffer[2] << 8) | _buffer[3];
      final totalLength = packetLength + 4;
      
      _logState?.debug('   数据包长度: $packetLength, 总长度: $totalLength');
      
      if (_buffer.length < totalLength) {
        _logState?.debug('   数据不完整，等待更多数据 (当前: ${_buffer.length}, 需要: $totalLength)');
        break;
      }
      
      // 提取完整数据包
      final packet = _buffer.sublist(0, totalLength);
      _buffer = _buffer.sublist(totalLength);
      
      _logState?.debug('   提取完整数据包，剩余缓冲区: ${_buffer.length} 字节');
      _processPacket(packet);
    }
  }
  
  /// 处理完整数据包
  void _processPacket(Uint8List packet) {
    try {
      _packetCount++;
      
      // 详细的数据包日志
      final hexStr = packet.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      _logState?.debug('📦 数据包 #$_packetCount [${packet.length} 字节]: $hexStr');
      _logState?.info('📦 完整数据包 #$_packetCount:');
      _logState?.info('   长度: ${packet.length} 字节');
      _logState?.info('   HEX: $hexStr');
      
      // 解析数据包结构（如果是标准格式）
      if (packet.length >= 8 && packet[0] == 0xAA && packet[1] == 0x55) {
        final length = (packet[2] << 8) | packet[3];
        final moduleId = packet[4];
        final messageId = packet[5];
        _logState?.info('   头部: AA 55 (起始标志)');
        _logState?.info('   长度: $length');
        _logState?.info('   模块ID: 0x${moduleId.toRadixString(16).padLeft(2, '0').toUpperCase()}');
        _logState?.info('   消息ID: 0x${messageId.toRadixString(16).padLeft(2, '0').toUpperCase()}');
        
        if (packet.length > 8) {
          final payload = packet.sublist(6, packet.length - 2);
          final payloadHex = payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
          _logState?.info('   数据: $payloadHex');
        }
        
        if (packet.length >= 2) {
          final checksum = (packet[packet.length - 2] << 8) | packet[packet.length - 1];
          _logState?.info('   校验和: 0x${checksum.toRadixString(16).padLeft(4, '0').toUpperCase()}');
        }
      }
      
      final response = {
        'payload': packet,
        'timestamp': DateTime.now(),
      };
      
      // 完成最早的待处理响应
      if (_pendingResponses.isNotEmpty) {
        final firstKey = _pendingResponses.keys.first;
        final completer = _pendingResponses[firstKey];
        _logState?.info('✅ 响应数据包 #$_packetCount 匹配序列号: $firstKey');
        if (!completer!.isCompleted) {
          completer.complete(response);
          _logState?.debug('   Completer 已完成');
        } else {
          _logState?.warning('   ⚠️ Completer 已经完成');
        }
      } else {
        _logState?.warning('⚠️ 收到数据包但没有待处理的响应');
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
