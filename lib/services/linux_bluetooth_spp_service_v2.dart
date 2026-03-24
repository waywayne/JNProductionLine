import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/log_state.dart';
import '../config/test_config.dart';
import 'gtp_protocol.dart';

/// Linux Bluetooth SPP Service V2
/// 使用单 fd 双向通信模式（类似串口）
/// 更稳定可靠的 RFCOMM 通信实现
class LinuxBluetoothSppServiceV2 {
  // 单 fd 双向通信
  RandomAccessFile? _rfcommFile;  // 读写共用的文件句柄
  bool _isReading = false;
  
  Socket? _socket;  // 备用：RFCOMM socket 模式
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
  
  /// 连接到蓝牙设备（单 fd 模式）
  Future<bool> connect({
    required String deviceAddress,
    String? deviceName,
    int? channel,
    String? uuid,
  }) async {
    if (_isConnected) {
      _logState?.warning('⚠️ 已经连接到设备');
      return true;
    }
    
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('🔗 连接蓝牙设备 (单 fd 模式)');
      _logState?.info('   设备地址: $deviceAddress');
      if (deviceName != null) _logState?.info('   设备名称: $deviceName');
      
      // 确定通道
      int targetChannel;
      if (channel != null) {
        targetChannel = channel;
        _logState?.info('   使用指定通道: $targetChannel');
      } else {
        _logState?.info('   开始服务发现...');
        final discoveredChannel = await _discoverServiceChannel(deviceAddress, uuid: uuid);
        if (discoveredChannel == null) {
          _logState?.warning('⚠️ 服务发现失败，使用默认通道 5');
          targetChannel = 5;
        } else {
          targetChannel = discoveredChannel;
        }
      }
      
      _currentChannel = targetChannel;
      _logState?.info('   目标通道: $targetChannel');
      
      // 使用 rfcomm bind 创建设备文件
      final devicePath = '/dev/rfcomm0';
      _logState?.info('   绑定 RFCOMM 设备...');
      
      final bindResult = await Process.run('rfcomm', ['bind', '0', deviceAddress, targetChannel.toString()]);
      
      if (bindResult.exitCode == 0) {
        _logState?.success('   ✅ RFCOMM 绑定成功');
        
        // 等待设备文件创建
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 打开设备文件（读写模式）
        _logState?.info('   打开设备文件（读写模式）...');
        final file = File(devicePath);
        
        try {
          // 使用 readWrite 模式打开单个 fd
          _rfcommFile = await file.open(mode: FileMode.readWrite)
              .timeout(const Duration(seconds: 5), onTimeout: () {
            throw TimeoutException('打开设备文件超时');
          });
          
          _logState?.success('   ✅ 设备文件已打开（单 fd 双向通信）');
          
          // 启动读取循环
          _startReadLoop();
          
          // 连接成功
          _currentDeviceAddress = deviceAddress;
          _currentDeviceName = deviceName;
          _isConnected = true;
          
          // 重置状态
          _sequenceNumber = 0;
          _buffer = Uint8List(0);
          _packetCount = 0;
          _pendingResponses.clear();
          
          _logState?.success('✅ 蓝牙连接成功（单 fd 模式）');
          _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          
          return true;
        } catch (e) {
          _logState?.error('   ❌ 打开设备文件失败: $e');
          await _unbindRfcomm();
          return false;
        }
      } else {
        _logState?.error('❌ RFCOMM 绑定失败');
        _logState?.debug('   错误: ${bindResult.stderr}');
        return false;
      }
    } catch (e) {
      _logState?.error('❌ 连接失败: $e');
      await disconnect();
      return false;
    }
  }
  
  /// 启动读取循环（单 fd 模式）
  void _startReadLoop() {
    if (_rfcommFile == null) return;
    
    _logState?.info('🔄 启动数据读取循环（单 fd 模式）...');
    _isReading = true;
    
    // 在后台异步读取
    _readLoopAsync();
    
    _logState?.success('✅ 数据读取循环已启动');
  }
  
  /// 异步读取循环
  Future<void> _readLoopAsync() async {
    const bufferSize = 1024;
    final buffer = Uint8List(bufferSize);
    
    try {
      while (_isReading && _rfcommFile != null) {
        try {
          final bytesRead = await _rfcommFile!.readInto(buffer);
          
          if (bytesRead > 0) {
            final data = Uint8List.fromList(buffer.sublist(0, bytesRead));
            _onDataReceived(data);
          } else {
            // EOF，连接已断开
            _logState?.warning('⚠️ 读取到 EOF，连接已断开');
            break;
          }
        } catch (e) {
          if (_isReading) {
            _logState?.error('❌ 读取数据时出错: $e');
            break;
          }
        }
      }
    } catch (e) {
      _logState?.error('❌ 读取循环异常: $e');
    } finally {
      _isReading = false;
      if (_isConnected) {
        _logState?.warning('⚠️ 读取循环已停止，断开连接');
        await disconnect();
      }
    }
  }
  
  /// 发送数据（单 fd 模式）
  Future<bool> sendData(Uint8List data) async {
    if (!_isConnected || _rfcommFile == null) {
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
      
      // 写入数据
      await _rfcommFile!.writeFrom(data);
      await _rfcommFile!.flush();
      
      _logState?.success('✅ 数据已发送');
      
      return true;
    } catch (e) {
      _logState?.error('❌ 发送数据失败: $e');
      
      // 如果写入失败，可能是连接已断开
      if (e.toString().contains('Bad file descriptor') || 
          e.toString().contains('Input/output error')) {
        _logState?.error('   设备连接已断开');
        await disconnect();
      }
      
      return false;
    }
  }
  
  /// 发送命令并等待响应
  Future<Map<String, dynamic>?> sendCommandAndWaitResponse(
    Uint8List payload, {
    Duration timeout = const Duration(seconds: 10),
    int maxRetries = 3,
  }) async {
    if (!_isConnected) {
      _logState?.error('❌ 未连接，无法发送命令');
      return null;
    }
    
    for (int retry = 0; retry < maxRetries; retry++) {
      if (retry > 0) {
        _logState?.warning('⚠️ 重试发送命令 (${retry + 1}/$maxRetries)');
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      try {
        // 构建 GTP 数据包
        final seqNum = _sequenceNumber++;
        final gtpPacket = GtpProtocol.buildPacket(payload, seqNum);
        
        // 创建响应等待器
        final completer = Completer<Map<String, dynamic>?>();
        _pendingResponses[seqNum] = completer;
        
        // 日志
        final payloadHex = payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
        _logState?.info('📤 发送命令 Payload: $payloadHex');
        
        final gtpHex = gtpPacket.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
        _logState?.debug('📦 完整数据包 [${gtpPacket.length} 字节]: $gtpHex');
        
        // 发送数据
        final sent = await sendData(gtpPacket);
        if (!sent) {
          _pendingResponses.remove(seqNum);
          continue;
        }
        
        // 等待响应
        final response = await completer.future.timeout(
          timeout,
          onTimeout: () {
            _logState?.error('❌ 等待响应超时 (序列号: $seqNum)');
            return null;
          },
        );
        
        _pendingResponses.remove(seqNum);
        
        if (response != null) {
          final responsePayload = response['payload'] as Uint8List;
          final responseHex = responsePayload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
          _logState?.info('📥 收到响应 Payload: $responseHex');
          return response;
        }
      } catch (e) {
        _logState?.error('❌ 发送命令时出错: $e');
      }
    }
    
    _logState?.error('❌ 发送命令失败，已重试 $maxRetries 次');
    return null;
  }
  
  /// 数据接收回调
  void _onDataReceived(Uint8List data) {
    // 添加到缓冲区
    final newBuffer = Uint8List(_buffer.length + data.length);
    newBuffer.setRange(0, _buffer.length, _buffer);
    newBuffer.setRange(_buffer.length, newBuffer.length, data);
    _buffer = newBuffer;
    
    // 详细日志
    final hexStr = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    _logState?.debug('📥 收到数据 [${data.length} 字节]: $hexStr');
    _logState?.debug('   缓冲区大小: ${_buffer.length} 字节');
    
    // 尝试解析 GTP 数据包
    while (_buffer.isNotEmpty) {
      final packet = GtpProtocol.parsePacket(_buffer);
      
      if (packet == null) {
        // 没有完整的数据包
        if (_buffer.length > 1024) {
          _logState?.warning('⚠️ 缓冲区过大，清空前 ${_buffer.length ~/ 2} 字节');
          _buffer = _buffer.sublist(_buffer.length ~/ 2);
        }
        break;
      }
      
      // 解析成功
      _packetCount++;
      final payload = packet['payload'] as Uint8List;
      final seqNum = packet['sequenceNumber'] as int;
      
      _logState?.debug('✅ 解析到完整数据包 #$_packetCount (序列号: $seqNum, Payload: ${payload.length} 字节)');
      
      // 移除已解析的数据
      final consumedBytes = packet['consumedBytes'] as int;
      _buffer = _buffer.sublist(consumedBytes);
      _logState?.debug('   剩余缓冲区: ${_buffer.length} 字节');
      
      // 触发响应
      final completer = _pendingResponses[seqNum];
      if (completer != null && !completer.isCompleted) {
        completer.complete(packet);
      }
      
      // 广播数据
      _dataController.add(payload);
    }
  }
  
  /// 服务发现
  Future<int?> _discoverServiceChannel(String deviceAddress, {String? uuid}) async {
    try {
      final targetUuid = uuid ?? _serviceUuid;
      _logState?.debug('   查询 UUID: $targetUuid');
      
      final result = await Process.run('sdptool', ['browse', deviceAddress]);
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final lines = output.split('\n');
        
        int? channel;
        bool foundService = false;
        
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          
          if (line.contains(targetUuid)) {
            foundService = true;
          }
          
          if (foundService && line.contains('Channel:')) {
            final match = RegExp(r'Channel:\s*(\d+)').firstMatch(line);
            if (match != null) {
              channel = int.parse(match.group(1)!);
              _logState?.success('   ✅ 发现服务通道: $channel');
              return channel;
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      _logState?.debug('   服务发现失败: $e');
      return null;
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
      if (_isConnected || _rfcommFile != null) {
        _logState?.info('🔌 断开 SPP 连接...');
        
        // 停止读取循环
        _isReading = false;
        
        // 关闭文件句柄
        try {
          await _rfcommFile?.close();
          _rfcommFile = null;
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
  
  /// 释放资源
  Future<void> dispose() async {
    await disconnect();
    await _dataController.close();
  }
}
