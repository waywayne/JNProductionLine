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
  Process? _bluetoothProcess;  // rfcomm connect 进程（如果使用）
  Socket? _socket;             // RFCOMM socket（备用方案）
  StreamSubscription? _subscription;
  RandomAccessFile? _deviceFile;  // 写入句柄
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
      
      // 改进的扫描策略：使用 bluetoothctl（支持 BLE + 经典蓝牙）
      _logState?.info('   使用 bluetoothctl 扫描设备（包括 BLE）...');
      
      // 使用 bluetoothctl 扫描（支持 BLE 和经典蓝牙）
      final scanScript = '''
# 确保蓝牙适配器开启
hciconfig hci0 up 2>/dev/null || true

# 使用 bluetoothctl 扫描
(
  echo "power on"
  sleep 1
  echo "scan on"
  sleep ${timeout.inSeconds}
  echo "scan off"
  echo "devices"
) | bluetoothctl 2>&1
''';
      
      final scanResult = await Process.run('bash', ['-c', scanScript]);
      
      _logState?.info('⏳ 解析扫描结果...');
      
      final devices = <Map<String, String>>[];
      final lines = scanResult.stdout.toString().split('\n');
      
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        
        // 格式: Device AA:BB:CC:DD:EE:FF Device Name
        final match = RegExp(r'Device\s+([0-9A-Fa-f:]{2}:[0-9A-Fa-f:]{2}:[0-9A-Fa-f:]{2}:[0-9A-Fa-f:]{2}:[0-9A-Fa-f:]{2}:[0-9A-Fa-f:]{2})\s+(.+)', caseSensitive: false).firstMatch(line);
        if (match != null) {
          final address = match.group(1)!.toUpperCase();
          final name = match.group(2)!.trim();
          
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
  
  /// 确保蓝牙适配器已开启
  Future<bool> ensureBluetoothPower() async {
    try {
      _logState?.debug('� 确保蓝牙适配器已开启...');
      await Process.run('bash', ['-c', 'echo "power on" | bluetoothctl']);
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    } catch (e) {
      _logState?.error('❌ 开启蓝牙失败: $e');
      return false;
    }
  }
  
  /// 配对并连接蓝牙设备
  Future<bool> pairAndConnectDevice(String deviceAddress) async {
    try {
      _logState?.info('🔗 配对并连接蓝牙设备...');
      
      // 1. 检查是否已配对
      final checkPaired = await Process.run('bash', ['-c', 'echo "paired-devices" | bluetoothctl | grep -i $deviceAddress']);
      final alreadyPaired = checkPaired.exitCode == 0;
      
      if (alreadyPaired) {
        _logState?.info('   设备已配对');
      } else {
        _logState?.info('   开始配对设备...');
        
        // 配对设备（使用管道方式，一次性发送所有命令）
        final pairScript = '''
(
  echo "power on"
  sleep 1
  echo "agent on"
  sleep 1
  echo "default-agent"
  sleep 1
  echo "pair $deviceAddress"
  sleep 5
  echo "trust $deviceAddress"
  sleep 1
) | bluetoothctl
''';
        
        final pairResult = await Process.run('bash', ['-c', pairScript]);
        _logState?.debug('   配对输出: ${pairResult.stdout}');
        
        // 等待配对完成
        await Future.delayed(const Duration(seconds: 2));
        
        // 验证配对
        final checkAgain = await Process.run('bash', ['-c', 'echo "paired-devices" | bluetoothctl | grep -i $deviceAddress']);
        if (checkAgain.exitCode == 0) {
          _logState?.success('✅ 设备配对成功');
        } else {
          _logState?.warning('⚠️ 配对可能失败，继续尝试连接...');
        }
      }
      
      // 2. 检查设备状态
      _logState?.info('   检查设备状态...');
      final infoResult = await Process.run('bash', ['-c', 'echo "info $deviceAddress" | bluetoothctl']);
      final infoOutput = infoResult.stdout.toString();
      
      // 检查是否已配对和信任
      final isPaired = infoOutput.contains('Paired: yes');
      final isTrusted = infoOutput.contains('Trusted: yes');
      final isBonded = infoOutput.contains('Bonded: yes');
      
      if (isPaired && isTrusted) {
        _logState?.success('✅ 设备已配对和信任');
        _logState?.info('   Paired: yes');
        _logState?.info('   Trusted: yes');
        if (isBonded) {
          _logState?.info('   Bonded: yes');
        }
        
        // 尝试建立蓝牙基础连接（某些设备需要）
        _logState?.info('   尝试建立蓝牙连接...');
        final connectScript = '''
(
  echo "connect $deviceAddress"
  sleep 3
) | bluetoothctl
''';
        
        final connectResult = await Process.run('bash', ['-c', connectScript]);
        _logState?.debug('   连接输出: ${connectResult.stdout}');
        
        // 检查连接状态
        await Future.delayed(const Duration(seconds: 1));
        final statusResult = await Process.run('bash', ['-c', 'echo "info $deviceAddress" | bluetoothctl']);
        final statusOutput = statusResult.stdout.toString();
        
        if (statusOutput.contains('Connected: yes')) {
          _logState?.success('✅ 蓝牙基础连接已建立');
        } else {
          _logState?.warning('⚠️ 蓝牙基础连接未建立，但可能不影响 RFCOMM');
        }
        
        // 等待设备准备好
        await Future.delayed(const Duration(seconds: 1));
        
        return true;
      } else {
        _logState?.error('❌ 设备配对或信任失败');
        _logState?.error('   Paired: ${isPaired ? "yes" : "no"}');
        _logState?.error('   Trusted: ${isTrusted ? "yes" : "no"}');
        return false;
      }
    } catch (e) {
      _logState?.error('❌ 蓝牙连接异常: $e');
      return false;
    }
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
      
      // 确保蓝牙适配器已开启
      await ensureBluetoothPower();
      
      // ========== 步骤 1: 配对并连接蓝牙设备 ==========
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      final btConnected = await pairAndConnectDevice(deviceAddress);
      if (!btConnected) {
        _logState?.error('❌ 蓝牙连接失败，无法继续');
        return false;
      }
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // 如果未指定通道，则通过 SDP 查询
      int targetChannel;
      if (channel != null) {
        targetChannel = channel;
        _logState?.info('   使用指定通道: $targetChannel');
      } else {
        _logState?.info('   开始服务发现...');
        final discoveredChannel = await discoverServiceChannel(deviceAddress, uuid: uuid);
        if (discoveredChannel == null) {
          _logState?.warning('⚠️ 服务发现失败，使用默认通道 5');
          targetChannel = 5;  // 使用默认通道 5
        } else {
          targetChannel = discoveredChannel;
        }
      }
      
      _currentChannel = targetChannel;
      const devicePath = '/dev/rfcomm0';
      
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('⏳ 连接到 $deviceAddress 通道 $targetChannel...');
      
      // 清理旧连接
      _logState?.debug('🧹 清理旧的 RFCOMM 连接...');
      await Process.run('pkill', ['-9', 'cat']).catchError((_) => null);
      await Process.run('pkill', ['-9', 'rfcomm']).catchError((_) => null);
      await Future.delayed(const Duration(milliseconds: 200));
      
      await Process.run('rfcomm', ['release', '0']).catchError((_) => null);
      await Future.delayed(const Duration(milliseconds: 200));
      
      // 删除可能存在的设备文件
      final deviceFile = File(devicePath);
      if (await deviceFile.exists()) {
        try {
          await deviceFile.delete();
          _logState?.debug('   已删除旧设备文件');
        } catch (e) {
          _logState?.debug('   删除设备文件失败: $e');
        }
      }
      
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 建立 RFCOMM 连接（使用 rfcomm bind，已验证可行）
      _logState?.info('⏳ 建立 RFCOMM 连接...');
      _logState?.info('   方法: rfcomm bind + 后台连接');
      
      // 使用 rfcomm bind（更稳定）
      final bindResult = await Process.run('rfcomm', [
        'bind',
        '0',
        deviceAddress,
        targetChannel.toString(),
      ]);
      
      if (bindResult.exitCode == 0) {
        _logState?.info('   ✅ RFCOMM 绑定成功');
        
        // 等待设备文件创建
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 检查设备文件是否存在
        final deviceFile = File(devicePath);
        if (await deviceFile.exists()) {
          _logState?.success('   ✅ 设备文件已创建: $devicePath');
          
          // 打开设备文件（读写模式，单 fd 双向通信）
          _logState?.info('   打开设备文件（读写模式）...');
          try {
            _deviceFile = await deviceFile.open(mode: FileMode.readWrite)
                .timeout(const Duration(seconds: 5), onTimeout: () {
              throw TimeoutException('打开设备文件超时');
            });
            _logState?.success('   ✅ 设备文件已打开（单 fd 双向通信）');
          } catch (e) {
            _logState?.error('   ❌ 打开设备文件失败: $e');
            await _unbindRfcomm();
            return false;
          }
          
          // 启动读取循环（使用同一个 fd）
          _logState?.info('   启动读取循环...');
          _startReadLoop();
          
          // 连接成功
          _currentDeviceAddress = deviceAddress;
          _currentDeviceName = deviceName;
          _isConnected = true;
          
          // 重置序列号和缓冲区
          _sequenceNumber = 0;
          _buffer = Uint8List(0);
          _packetCount = 0;
          _pendingResponses.clear();
          
          _logState?.success('✅ RFCOMM 连接已建立 (bind 模式)');
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
          _logState?.info('   连接模式: RFCOMM bind');
          _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          
          return true;
        } else {
          _logState?.error('❌ 设备文件未创建');
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
  
  /// 启动读取循环（单 fd 双向通信）
  void _startReadLoop() {
    if (_deviceFile == null) {
      _logState?.error('❌ 设备文件未打开，无法启动读取循环');
      return;
    }
    
    _logState?.debug('   启动数据读取循环（单 fd 模式）...');
    
    // 在后台异步读取
    _readLoopAsync();
    
    _logState?.success('✅ 数据读取循环已启动');
  }
  
  /// 异步读取循环
  Future<void> _readLoopAsync() async {
    const bufferSize = 1024;
    final buffer = Uint8List(bufferSize);
    
    try {
      while (_isConnected && _deviceFile != null) {
        try {
          final bytesRead = await _deviceFile!.readInto(buffer);
          
          if (bytesRead > 0) {
            final data = Uint8List.fromList(buffer.sublist(0, bytesRead));
            _onDataReceived(data);
          } else {
            // EOF，连接已断开
            _logState?.warning('⚠️ 读取到 EOF，连接已断开');
            break;
          }
        } catch (e) {
          if (_isConnected) {
            _logState?.error('❌ 读取数据时出错: $e');
            break;
          }
        }
      }
    } catch (e) {
      _logState?.error('❌ 读取循环异常: $e');
    } finally {
      if (_isConnected) {
        _logState?.warning('⚠️ 读取循环已停止，断开连接');
        await disconnect();
      }
    }
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
        
        // 先标记为未连接，停止读取循环
        _isConnected = false;
        
        await _subscription?.cancel();
        _subscription = null;
        
        // 杀掉 rfcomm connect 进程（如果有）
        _bluetoothProcess?.kill();
        _bluetoothProcess = null;
        
        // 关闭设备文件（写入句柄）
        try {
          await _deviceFile?.close();
          _deviceFile = null;
          _logState?.debug('   写入句柄已关闭');
        } catch (e) {
          _logState?.debug('   关闭写入句柄时出错: $e');
        }
        
        await _unbindRfcomm();
        
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
  
  /// 发送数据（单 fd 模式）
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
      
      // 使用同一个 fd 写入数据
      _logState?.debug('   准备写入 ${data.length} 字节...');
      await _deviceFile!.writeFrom(data);
      await _deviceFile!.flush();  // 确保数据刷新到设备
      _logState?.debug('   数据已写入并刷新');
      
      _logState?.success('✅ 数据已发送');
      
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
  
  /// 发送命令并等待响应（带重试机制）
  Future<Map<String, dynamic>?> sendCommandAndWaitResponse(
    Uint8List command, {
    Duration timeout = const Duration(seconds: 10),  // 增加默认超时到10秒
    int maxRetries = 3,  // 最多重试3次
    int? moduleId,
    int? messageId,
  }) async {
    if (!_isConnected) {
      _logState?.error('❌ 未连接');
      return {'error': 'Not connected'};
    }
    
    // 重试逻辑
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        _logState?.warning('⚠️ 第 $attempt 次重试...');
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      try {
        final seqNum = _sequenceNumber++;
        final completer = Completer<Map<String, dynamic>?>();
        _pendingResponses[seqNum] = completer;
        
        _logState?.info('🔄 序列号: $seqNum, 等待响应 (超时: ${timeout.inSeconds}秒, 尝试: ${attempt + 1}/${maxRetries + 1})');
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
          continue;  // 重试
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
        
        // 如果响应成功（不是超时或错误），返回结果
        if (response != null && !response.containsKey('error')) {
          _logState?.success('✅ 命令响应成功 (尝试: ${attempt + 1})');
          return response;
        }
        
        // 如果是最后一次尝试，返回错误
        if (attempt == maxRetries) {
          _logState?.error('❌ 所有重试均失败');
          return response;
        }
        
        // 否则继续重试
        _logState?.warning('⚠️ 响应失败，准备重试...');
        
      } catch (e) {
        _logState?.error('❌ 命令执行异常: $e');
        if (attempt == maxRetries) {
          return {'error': e.toString()};
        }
      }
    }
    
    return {'error': 'Max retries exceeded'};
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
        // 没有找到 GTP 起始标志，可能是设备返回的原始数据（无 GTP 封装）
        final bufferHex = _buffer.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
        _logState?.warning('⚠️ 缓冲区中未找到 GTP 起始标志 (D0 D2 C5 C2)');
        _logState?.debug('   缓冲区内容 [${_buffer.length} 字节]: $bufferHex');
        
        // 尝试作为原始响应处理（设备可能不返回 GTP 封装）
        if (_buffer.length >= 10) {
          _logState?.info('🔄 尝试解析为原始响应数据（无 GTP 封装）');
          _processRawResponse(_buffer);
          _buffer = Uint8List(0);
        } else {
          // 保留最后 3 个字节（可能是 Preamble 的开始）
          if (_buffer.length > 3) {
            _buffer = _buffer.sublist(_buffer.length - 3);
          } else {
            _buffer = Uint8List(0);
          }
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
  
  /// 处理原始响应数据（无 GTP 封装）
  void _processRawResponse(Uint8List rawData) {
    try {
      _packetCount++;
      
      final hexStr = rawData.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      _logState?.info('📦 原始响应数据 #$_packetCount [${rawData.length} 字节]: $hexStr');
      
      // 尝试提取序列号（假设在固定位置，根据实际协议调整）
      // 从接收到的数据看：04 00 00 9A 23 23 06 00 DE 36 01 FF 02 00 02 00 00 00 00 01 40 40...
      // 可能格式：[CMD(1)] [SN(2)] [其他数据...]
      int? responseSN;
      if (rawData.length >= 3) {
        // 尝试从第1-2字节读取序列号（小端）
        responseSN = rawData[1] | (rawData[2] << 8);
        _logState?.info('   提取序列号: $responseSN (从字节 1-2)');
      }
      
      // 构造响应对象
      final response = {
        'payload': rawData,
        'timestamp': DateTime.now(),
        'raw': true,  // 标记为原始数据
        'sn': responseSN,
      };
      
      // 匹配待处理的请求
      if (responseSN != null && _pendingResponses.containsKey(responseSN)) {
        final completer = _pendingResponses[responseSN];
        _logState?.success('✅ 原始响应匹配序列号: $responseSN');
        if (!completer!.isCompleted) {
          completer.complete(response);
          _pendingResponses.remove(responseSN);
        }
      } else if (_pendingResponses.isNotEmpty) {
        // 如果序列号不匹配，使用第一个待处理请求
        final firstKey = _pendingResponses.keys.first;
        final completer = _pendingResponses[firstKey];
        _logState?.warning('⚠️ 原始响应 SN ($responseSN) 不匹配，使用第一个待处理请求: $firstKey');
        if (!completer!.isCompleted) {
          completer.complete(response);
          _pendingResponses.remove(firstKey);
        }
      } else {
        _logState?.warning('⚠️ 收到原始响应但没有待处理的请求');
      }
    } catch (e) {
      _logState?.error('❌ 原始响应处理异常: $e');
    }
  }
  
  /// 释放资源
  void dispose() {
    disconnect();
    _dataController.close();
  }
}
