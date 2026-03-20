import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/log_state.dart';
import '../config/test_config.dart';
import 'gtp_protocol.dart';

/// Linux Bluetooth SPP Service
/// 基于 Linux 蓝牙栈实现的 SPP 协议通信服务
/// 支持自定义 UUID 服务发现和 RFCOMM 通道绑定
class LinuxBluetoothSppService {
  Process? _bluetoothProcess;
  Socket? _socket;
  StreamSubscription? _subscription;
  RandomAccessFile? _deviceFile;
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
      final lines = output.split('\n');
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
      
      // 简化连接流程，避免干扰
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('⏳ 连接 RFCOMM 通道 $targetChannel...');
      _logState?.info('   设备地址: $deviceAddress');
      
      // 清理旧连接
      await Process.run('rfcomm', ['release', '0']).catchError((_) => null);
      await Future.delayed(const Duration(milliseconds: 200));
      
      // 主动建立 RFCOMM 连接（后台进程）
      _logState?.info('⏳ 主动建立 RFCOMM 连接...');
      
      final connectScript = '''
        rfcomm connect 0 $deviceAddress $targetChannel </dev/null >/dev/null 2>&1 &
      ''';
      
      await Process.run('bash', ['-c', connectScript]);
      
      // 轮询等待设备文件创建（最多 5 秒）
      final devicePath = '/dev/rfcomm0';
      final file = File(devicePath);
      bool deviceReady = false;
      
      _logState?.info('⏳ 等待设备文件创建...');
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (await file.exists()) {
          deviceReady = true;
          _logState?.success('✅ 设备文件已创建: $devicePath');
          break;
        }
      }
      
      if (!deviceReady) {
        _logState?.error('❌ 设备文件创建超时（5秒）');
        _logState?.error('   可能原因: 设备未响应或通道号不正确');
        await _unbindRfcomm();
        return false;
      }
      
      // 配置串口参数
      await Process.run('stty', [
        '-F', devicePath,
        '115200', 'raw', '-echo', '-echoe', '-echok',
      ]).catchError((_) => null);
      
      // 打开设备文件用于写入
      try {
        _deviceFile = await file.open(mode: FileMode.writeOnly);
        _logState?.success('✅ 设备文件已打开');
        
        // 启动读取线程
        _startReadLoop(devicePath);
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        _logState?.error('❌ 打开设备文件失败: $e');
        await _unbindRfcomm();
        return false;
      }
      
      _currentDeviceAddress = deviceAddress;
      _currentDeviceName = deviceName;
      _isConnected = true;
      
      // 重置序列号和缓冲区
      _sequenceNumber = 0;
      _buffer = Uint8List(0);
      _packetCount = 0;
      _pendingResponses.clear();
      
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
      
      return true;
    } catch (e) {
      _logState?.error('❌ 连接失败: $e');
      await _unbindRfcomm();
      return false;
    }
  }
  
  /// 启动读取循环
  void _startReadLoop(String devicePath) {
    _logState?.info('🔄 启动数据读取循环...');
    
    // 使用 cat 命令持续读取数据
    Process.start('cat', [devicePath]).then((process) {
      _bluetoothProcess = process;
      
      _subscription = process.stdout.listen(
        (data) {
          if (data.isNotEmpty) {
            _onDataReceived(Uint8List.fromList(data));
          }
        },
        onError: (error) {
          _logState?.error('❌ 数据接收错误: $error');
          disconnect();
        },
        onDone: () {
          _logState?.warning('⚠️ 读取循环结束');
          disconnect();
        },
      );
      
      _logState?.success('✅ 数据读取循环已启动');
    }).catchError((e) {
      _logState?.error('❌ 启动读取循环失败: $e');
    });
  }
  
  /// 解除 RFCOMM 绑定
  Future<void> _unbindRfcomm() async {
    try {
      // 杀掉所有 rfcomm 进程
      await Process.run('pkill', ['-f', 'rfcomm connect']).catchError((_) => null);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 释放设备
      await Process.run('rfcomm', ['release', '0']);
    } catch (e) {
      _logState?.debug('解除 RFCOMM 绑定时出错: $e');
    }
  }
  
  /// 断开连接
  Future<void> disconnect() async {
    try {
      if (_isConnected || _bluetoothProcess != null || _deviceFile != null) {
        _logState?.info('🔌 断开 SPP 连接...');
        
        await _subscription?.cancel();
        _subscription = null;
        
        _bluetoothProcess?.kill();
        _bluetoothProcess = null;
        
        // 关闭设备文件
        try {
          await _deviceFile?.close();
          _deviceFile = null;
          _logState?.debug('   设备文件已关闭');
        } catch (e) {
          _logState?.debug('   关闭设备文件时出错: $e');
        }
        
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
    if (!_isConnected || _deviceFile == null) {
      _logState?.error('❌ 未连接，无法发送数据');
      return false;
    }
    
    try {
      // 详细的发送日志
      final hexStr = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      final asciiStr = String.fromCharCodes(
        data.map((b) => (b >= 32 && b <= 126) ? b : 46), // 46 = '.'
      );
      _logState?.debug('📤 准备发送 [${data.length} 字节]: $hexStr');
      _logState?.info('📤 发送数据: $hexStr (ASCII: $asciiStr)');
      
      // 直接写入设备文件
      await _deviceFile!.writeFrom(data);
      
      // 强制刷新到磁盘，确保数据真正发送
      await _deviceFile!.flush();
      
      // 添加短暂延迟，确保数据完全发送到设备
      await Future.delayed(const Duration(milliseconds: 50));
      
      _logState?.success('✅ 数据已写入设备文件');
      
      return true;
    } catch (e) {
      _logState?.error('❌ 发送数据失败: $e');
      _logState?.error('   错误详情: ${e.toString()}');
      
      // 如果写入失败，可能是连接已断开
      if (e.toString().contains('Bad file descriptor') || 
          e.toString().contains('Input/output error')) {
        _logState?.error('   设备连接可能已断开，尝试重新连接');
        await disconnect();
      }
      
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
      _logState?.debug('   Payload 长度: ${command.length} 字节');
      
      // 构建 GTP 数据包
      final gtpPacket = GTPProtocol.buildGTPPacket(
        command,
        moduleId: moduleId,
        messageId: messageId,
        sequenceNumber: seqNum,
      );
      
      // 打印 payload (CMD + OPT + 数据)
      final cmdHex = command.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      _logState?.info('📤 发送 Payload: [$cmdHex] (${command.length} 字节)');
      
      // 打印完整的 GTP 数据包
      final fullPacketHex = gtpPacket.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      _logState?.info('📦 完整数据包: [$fullPacketHex]');
      _logState?.info('   总长度: ${gtpPacket.length} 字节');
      
      // 发送完整的 GTP 数据包
      final success = await sendData(gtpPacket);
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
    
    while (_buffer.length >= 16) { // GTP 最小长度
      // 查找 GTP 数据包起始标志 (Preamble: 0xD0 0xD2 0xC5 0xC2)
      int startIndex = -1;
      for (int i = 0; i <= _buffer.length - 4; i++) {
        if (_buffer[i] == 0xD0 && _buffer[i + 1] == 0xD2 && 
            _buffer[i + 2] == 0xC5 && _buffer[i + 3] == 0xC2) {
          startIndex = i;
          break;
        }
      }
      
      if (startIndex == -1) {
        // 没有找到 GTP 起始标志
        final bufferHex = _buffer.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
        _logState?.warning('⚠️ 缓冲区中未找到 GTP 起始标志 (D0 D2 C5 C2)');
        _logState?.debug('   缓冲区内容 [${_buffer.length} 字节]: $bufferHex');
        
        // 保留最后 3 个字节（可能是 Preamble 的开始）
        if (_buffer.length > 3) {
          _buffer = _buffer.sublist(_buffer.length - 3);
        } else {
          _buffer = Uint8List(0);
        }
        break;
      }
      
      if (startIndex > 0) {
        _logState?.debug('   跳过 $startIndex 字节垃圾数据');
        _buffer = _buffer.sublist(startIndex);
      }
      
      if (_buffer.length < 16) {
        _logState?.debug('   数据不足，等待更多数据 (当前: ${_buffer.length}, 需要至少: 16)');
        break;
      }
      
      // 读取 GTP Length 字段 (offset 5-6, little endian)
      final gtpLength = (_buffer[5]) | (_buffer[6] << 8);
      // GTP 总长度 = Preamble(4) + Length字段指示的长度
      final totalLength = 4 + gtpLength;
      
      _logState?.debug('   GTP Length字段: $gtpLength, 总长度: $totalLength');
      
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
      _logState?.debug('📦 GTP 数据包 #$_packetCount [${packet.length} 字节]: $hexStr');
      _logState?.info('📦 完整 GTP 数据包 #$_packetCount:');
      _logState?.info('   总长度: ${packet.length} 字节');
      _logState?.info('   HEX: $hexStr');
      
      // 使用 GTP 协议解析
      final parsedGTP = GTPProtocol.parseGTPResponse(packet);
      
      if (parsedGTP == null) {
        _logState?.error('❌ GTP 解析失败');
        return;
      }
      
      if (parsedGTP.containsKey('error')) {
        _logState?.error('❌ GTP 错误: ${parsedGTP['error']}');
        return;
      }
      
      _logState?.info('✅ GTP 解析成功:');
      _logState?.info('   模块ID: 0x${parsedGTP['moduleId']?.toRadixString(16).padLeft(4, '0').toUpperCase() ?? 'N/A'}');
      _logState?.info('   消息ID: 0x${parsedGTP['messageId']?.toRadixString(16).padLeft(4, '0').toUpperCase() ?? 'N/A'}');
      _logState?.info('   序列号: ${parsedGTP['sn'] ?? 'N/A'}');
      _logState?.info('   结果: ${parsedGTP['result'] ?? 'N/A'}');
      
      // 显示声明的长度和实际长度（如果有）
      if (parsedGTP.containsKey('declaredLength') && parsedGTP.containsKey('actualLength')) {
        _logState?.info('   声明长度: ${parsedGTP['declaredLength']} 字节');
        _logState?.info('   实际长度: ${parsedGTP['actualLength']} 字节');
      }
      
      final payload = parsedGTP['payload'] as Uint8List?;
      if (payload != null && payload.isNotEmpty) {
        final payloadHex = payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
        _logState?.info('   实际 Payload [${payload.length} 字节]: $payloadHex');
      } else {
        _logState?.info('   实际 Payload: 空 (0 字节)');
      }
      
      final response = {
        'payload': payload ?? Uint8List(0),
        'timestamp': DateTime.now(),
        'moduleId': parsedGTP['moduleId'],
        'messageId': parsedGTP['messageId'],
        'sn': parsedGTP['sn'],
        'result': parsedGTP['result'],
      };
      
      // 根据响应的 SN 匹配对应的请求
      final responseSN = parsedGTP['sn'] as int?;
      if (responseSN != null && _pendingResponses.containsKey(responseSN)) {
        final completer = _pendingResponses[responseSN];
        _logState?.info('✅ 响应数据包 #$_packetCount 匹配序列号: $responseSN');
        if (!completer!.isCompleted) {
          completer.complete(response);
          _pendingResponses.remove(responseSN);
          _logState?.debug('   Completer 已完成并移除');
        } else {
          _logState?.warning('   ⚠️ Completer 已经完成');
        }
      } else if (_pendingResponses.isNotEmpty) {
        // 如果 SN 不匹配，尝试匹配第一个（兼容旧逻辑）
        final firstKey = _pendingResponses.keys.first;
        final completer = _pendingResponses[firstKey];
        _logState?.warning('⚠️ 响应 SN ($responseSN) 不匹配，使用第一个待处理请求: $firstKey');
        if (!completer!.isCompleted) {
          completer.complete(response);
          _pendingResponses.remove(firstKey);
        }
      } else {
        _logState?.warning('⚠️ 收到数据包但没有待处理的响应 (SN: $responseSN)');
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
