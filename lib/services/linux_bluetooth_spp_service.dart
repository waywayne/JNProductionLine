import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/log_state.dart';
import '../config/test_config.dart';
import 'gtp_protocol.dart';

/// 数据接收解析模式
enum DataParseMode {
  /// 模式1: Python 端 GTP 组装
  /// Python 脚本负责缓冲和组装完整的 GTP 数据包，Dart 端直接处理
  pythonGtpAssembly,
  
  /// 模式2: Dart 端 GTP 组装
  /// Python 脚本直接透传原始数据，Dart 端负责缓冲和组装 GTP 数据包
  dartGtpAssembly,
  
  /// 模式3: 原始数据直通
  /// 不进行 GTP 组装，直接处理原始数据（用于调试或非 GTP 协议）
  rawPassthrough,
  
  /// 模式4: 智能自适应
  /// 自动检测数据格式，根据是否有 GTP 头选择处理方式
  smartAdaptive,
}

/// 获取解析模式的显示名称
extension DataParseModeExtension on DataParseMode {
  String get displayName {
    switch (this) {
      case DataParseMode.pythonGtpAssembly:
        return 'Python端GTP组装';
      case DataParseMode.dartGtpAssembly:
        return 'Dart端GTP组装';
      case DataParseMode.rawPassthrough:
        return '原始数据直通';
      case DataParseMode.smartAdaptive:
        return '智能自适应';
    }
  }
  
  String get description {
    switch (this) {
      case DataParseMode.pythonGtpAssembly:
        return 'Python脚本负责缓冲和组装完整GTP包，推荐用于稳定通讯';
      case DataParseMode.dartGtpAssembly:
        return 'Dart端负责缓冲和组装GTP包，Python直接透传';
      case DataParseMode.rawPassthrough:
        return '不进行GTP组装，直接处理原始数据，用于调试';
      case DataParseMode.smartAdaptive:
        return '自动检测数据格式，智能选择处理方式';
    }
  }
}

/// Linux Bluetooth SPP Service
/// 基于 Linux 蓝牙栈实现的 SPP 协议通信服务
/// 支持自定义 UUID 服务发现和 RFCOMM 通道绑定
class LinuxBluetoothSppService {
  Process? _socketProcess;     // Python RFCOMM socket 进程
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
  
  // 连接模式：true = rfcomm bind 模式，false = socket 模式
  bool _useBindMode = true;  // 默认使用 bind 模式（与第三方工具一致）
  
  // 数据解析模式
  DataParseMode _parseMode = DataParseMode.pythonGtpAssembly;
  
  void setLogState(LogState logState) {
    _logState = logState;
  }
  
  /// 获取当前解析模式
  DataParseMode get parseMode => _parseMode;
  
  /// 设置解析模式
  void setParseMode(DataParseMode mode) {
    _parseMode = mode;
    _logState?.info('📋 设置数据解析模式: ${mode.displayName}');
    _logState?.info('   ${mode.description}');
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
        _logState?.info('   设备未配对，开始扫描并配对...');
        
        // 先扫描设备（关键步骤：设备必须先被发现才能配对）
        _logState?.info('   📡 开始扫描蓝牙设备...');
        final scanScript = '''
(
  echo "power on"
  sleep 1
  echo "agent on"
  sleep 0.5
  echo "default-agent"
  sleep 0.5
  echo "scan on"
  sleep 8
  echo "scan off"
  sleep 0.5
) | bluetoothctl
''';
        
        final scanResult = await Process.run('bash', ['-c', scanScript]);
        _logState?.debug('   扫描输出: ${scanResult.stdout}');
        
        // 检查设备是否被发现
        final checkDevice = await Process.run('bash', ['-c', 'echo "info $deviceAddress" | bluetoothctl']);
        final deviceFound = !checkDevice.stdout.toString().contains('Device $deviceAddress not available');
        
        if (!deviceFound) {
          _logState?.error('❌ 扫描后仍未发现设备: $deviceAddress');
          _logState?.info('   请确保设备已开机并处于可发现状态');
          return false;
        }
        
        _logState?.success('✅ 设备已发现');
        
        // 配对设备
        _logState?.info('   🔐 开始配对设备...');
        final pairScript = '''
(
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
      
      // ========== 步骤 1: 配对蓝牙设备（不需要 bluetoothctl connect）==========
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      final btConnected = await pairAndConnectDevice(deviceAddress);
      if (!btConnected) {
        _logState?.error('❌ 蓝牙配对失败，无法继续');
        return false;
      }
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // 直接使用默认通道 5（跳过 SDP 发现）
      int targetChannel;
      if (channel != null) {
        targetChannel = channel;
        _logState?.info('✅ 使用指定通道: $targetChannel');
      } else {
        targetChannel = 5;  // 默认通道 5（SPP 标准通道）
        _logState?.info('✅ 使用默认 SPP 通道: $targetChannel');
        _logState?.debug('   跳过 SDP 服务发现，直接连接');
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
      
      // 根据解析模式选择 Python 脚本
      // - pythonGtpAssembly: 使用带 GTP 组装的脚本
      // - dartGtpAssembly/rawPassthrough/smartAdaptive: 使用原始透传脚本
      String scriptName;
      String modeDesc;
      
      if (_useBindMode) {
        // Bind 模式
        if (_parseMode == DataParseMode.pythonGtpAssembly) {
          scriptName = 'rfcomm_bind_bridge.py';
          modeDesc = 'RFCOMM Bind + Python端GTP组装';
        } else {
          scriptName = 'rfcomm_bind_bridge_raw.py';
          modeDesc = 'RFCOMM Bind + 原始透传 (${_parseMode.displayName})';
        }
      } else {
        // Socket 模式
        scriptName = 'rfcomm_socket.py';
        modeDesc = 'RFCOMM Socket';
      }
      
      _logState?.info('⏳ 建立 RFCOMM 连接...');
      _logState?.info('   连接模式: $modeDesc');
      _logState?.info('   解析模式: ${_parseMode.displayName}');
      
      // 查找 Python 脚本路径（多种可能的位置）
      String? scriptPath;
      
      // 获取可执行文件所在目录
      final executablePath = Platform.resolvedExecutable;
      final executableDir = File(executablePath).parent.path;
      
      final possiblePaths = [
        '$executableDir/scripts/$scriptName',            // 打包后：与可执行文件同目录
        'scripts/$scriptName',                           // 开发环境：项目根目录
        '/opt/jn-production-line/scripts/$scriptName',   // 安装后的位置
        '${Platform.environment['HOME']}/git/JNProductionLine/scripts/$scriptName', // 开发路径
      ];
      
      for (final path in possiblePaths) {
        if (await File(path).exists()) {
          scriptPath = path;
          _logState?.debug('   找到脚本: $path');
          break;
        }
      }
      
      if (scriptPath == null) {
        _logState?.error('❌ RFCOMM Socket 脚本不存在');
        _logState?.error('   已尝试以下路径:');
        for (final path in possiblePaths) {
          _logState?.error('   - $path');
        }
        return false;
      }
      
      // 启动 Python RFCOMM socket 进程
      try {
        _logState?.debug('   启动命令: python3 $scriptPath $deviceAddress $targetChannel');
        
        final process = await Process.start(
          'python3',
          [scriptPath, deviceAddress, targetChannel.toString()],
        );
        
        _logState?.success('   ✅ RFCOMM Socket 进程已启动');
        
        // 保存进程引用（必须在监听前保存）
        _socketProcess = process;
        
        // 立即监听 stderr（日志输出）
        process.stderr.transform(const SystemEncoding().decoder).listen((line) {
          _logState?.debug('   [Python] $line');
        });
        
        // 立即监听 stdout（接收数据）
        _subscription = process.stdout.listen(
          (data) {
            if (data.isNotEmpty) {
              // 打印从 Python 进程接收到的原始字节
              final rawHex = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
              _logState?.debug('🔵 从 Python stdout 接收 [${data.length} 字节]: $rawHex');
              
              _onDataReceived(Uint8List.fromList(data));
            }
          },
          onError: (error) {
            _logState?.error('❌ 数据接收错误: $error');
            if (_isConnected) {
              disconnect();
            }
          },
          onDone: () {
            // stdout 关闭通常意味着 Python 进程退出
            _logState?.warning('⚠️ Socket 数据流结束');
            if (_isConnected) {
              disconnect();
            }
          },
          cancelOnError: false,  // 不要因为错误就取消订阅
        );
        
        // 监听进程退出
        process.exitCode.then((code) {
          _logState?.warning('⚠️ RFCOMM Socket 进程已退出 (退出码: $code)');
          if (_isConnected) {
            disconnect();
          }
        });
        
        // 等待连接建立（Python 脚本需要时间连接）
        await Future.delayed(const Duration(seconds: 2));
        
        // 连接成功
        _currentDeviceAddress = deviceAddress;
        _currentDeviceName = deviceName;
        _isConnected = true;
        
        // 重置序列号和缓冲区
        _sequenceNumber = 0;
        _buffer = Uint8List(0);
        _packetCount = 0;
        _pendingResponses.clear();
        
        _logState?.success('✅ RFCOMM Socket 连接已建立');
        _logState?.success('✅ SPP 连接成功');
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        _logState?.info('📋 连接信息:');
        _logState?.info('   设备地址: $deviceAddress');
        if (deviceName != null) {
          _logState?.info('   设备名称: $deviceName');
        }
        _logState?.info('   RFCOMM 通道: $targetChannel');
        _logState?.info('   服务 UUID: ${uuid ?? _serviceUuid}');
        _logState?.info('   连接模式: RFCOMM Socket (Python)');
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        
        return true;
        
      } catch (e) {
        _logState?.error('❌ 启动 RFCOMM Socket 失败: $e');
        return false;
      }
    } catch (e) {
      _logState?.error('❌ 连接失败: $e');
      await disconnect();
      return false;
    }
  }
  
  /// 方案 2: 直接连接（跳过扫描和配对，假设设备已配对）
  Future<bool> connectDirectly(String deviceAddress, {String? deviceName, int? channel}) async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('🟢 直接连接模式（跳过扫描配对）');
      _logState?.info('   设备地址: $deviceAddress');
      
      // 断开现有连接
      await disconnect();
      
      // 确保蓝牙开启
      await ensureBluetoothPower();
      
      // 直接尝试建立蓝牙连接（不扫描不配对）
      _logState?.info('   尝试直接连接蓝牙...');
      final connectScript = '''
(
  echo "connect $deviceAddress"
  sleep 3
) | bluetoothctl
''';
      final connectResult = await Process.run('bash', ['-c', connectScript]);
      _logState?.debug('   连接输出: ${connectResult.stdout}');
      
      // 检查连接状态
      final statusResult = await Process.run('bash', ['-c', 'echo "info $deviceAddress" | bluetoothctl']);
      final statusOutput = statusResult.stdout.toString();
      
      if (statusOutput.contains('Connected: yes')) {
        _logState?.success('✅ 蓝牙基础连接已建立');
      } else {
        _logState?.warning('⚠️ 蓝牙基础连接未建立，继续尝试 RFCOMM...');
      }
      
      // 启动 RFCOMM Socket
      return await _startRfcommSocket(deviceAddress, deviceName: deviceName, channel: channel ?? 5);
    } catch (e) {
      _logState?.error('❌ 直接连接失败: $e');
      return false;
    }
  }
  
  /// 方案 3: RFCOMM Bind 模式
  Future<bool> connectWithRfcommBind(String deviceAddress, {String? deviceName, int? channel}) async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('🟠 RFCOMM Bind 模式');
      _logState?.info('   设备地址: $deviceAddress');
      
      // 断开现有连接
      await disconnect();
      
      // 确保蓝牙开启
      await ensureBluetoothPower();
      
      final targetChannel = channel ?? 5;
      const devicePath = '/dev/rfcomm0';
      
      // 清理旧连接
      _logState?.info('   清理旧的 RFCOMM 连接...');
      await Process.run('pkill', ['-9', 'cat']).catchError((_) => null);
      await Process.run('rfcomm', ['release', '0']).catchError((_) => null);
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 使用 rfcomm bind 命令
      _logState?.info('   执行: sudo rfcomm bind 0 $deviceAddress $targetChannel');
      final bindResult = await Process.run('sudo', ['rfcomm', 'bind', '0', deviceAddress, targetChannel.toString()]);
      
      if (bindResult.exitCode != 0) {
        _logState?.error('❌ rfcomm bind 失败: ${bindResult.stderr}');
        return false;
      }
      
      // 等待设备文件创建
      await Future.delayed(const Duration(seconds: 1));
      
      // 检查设备文件是否存在
      final deviceFile = File(devicePath);
      if (!await deviceFile.exists()) {
        _logState?.error('❌ 设备文件 $devicePath 不存在');
        return false;
      }
      
      _logState?.success('✅ RFCOMM Bind 成功: $devicePath');
      
      // 使用 Python 脚本读写设备文件
      return await _startRfcommBindBridge(deviceAddress, deviceName: deviceName, channel: targetChannel);
    } catch (e) {
      _logState?.error('❌ RFCOMM Bind 失败: $e');
      return false;
    }
  }
  
  /// 方案 4: RFCOMM Socket 模式（直接使用 Python socket）
  Future<bool> connectWithRfcommSocket(String deviceAddress, {String? deviceName, int? channel}) async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('🟣 RFCOMM Socket 模式');
      _logState?.info('   设备地址: $deviceAddress');
      
      // 断开现有连接
      await disconnect();
      
      // 确保蓝牙开启
      await ensureBluetoothPower();
      
      // 直接启动 Python RFCOMM Socket（不做配对）
      return await _startRfcommSocket(deviceAddress, deviceName: deviceName, channel: channel ?? 5);
    } catch (e) {
      _logState?.error('❌ RFCOMM Socket 连接失败: $e');
      return false;
    }
  }
  
  /// 方案 5: 串口设备模式（使用 pyserial 读写 /dev/rfcomm0）
  Future<bool> connectWithSerial(String deviceAddress, {String? deviceName, int? channel}) async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('🟤 串口设备模式');
      _logState?.info('   设备地址: $deviceAddress');
      
      // 断开现有连接
      await disconnect();
      
      // 确保蓝牙开启
      await ensureBluetoothPower();
      
      final targetChannel = channel ?? 5;
      
      // 先绑定 RFCOMM 设备
      _logState?.info('   绑定 RFCOMM 设备...');
      await Process.run('sudo', ['rfcomm', 'release', '0']).catchError((_) => null);
      await Future.delayed(const Duration(milliseconds: 500));
      
      final bindResult = await Process.run('sudo', ['rfcomm', 'bind', '0', deviceAddress, targetChannel.toString()]);
      if (bindResult.exitCode != 0) {
        _logState?.error('❌ RFCOMM 绑定失败: ${bindResult.stderr}');
        return false;
      }
      
      await Future.delayed(const Duration(seconds: 1));
      
      // 启动串口读写脚本
      return await _startSerialBridge(deviceAddress, deviceName: deviceName, channel: targetChannel);
    } catch (e) {
      _logState?.error('❌ 串口模式连接失败: $e');
      return false;
    }
  }
  
  /// 方案 6: 命令行工具模式（使用 hcitool/bluetoothctl）
  Future<bool> connectWithCommandLine(String deviceAddress, {String? deviceName, int? channel}) async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('⚫ 命令行工具模式');
      _logState?.info('   设备地址: $deviceAddress');
      
      // 断开现有连接
      await disconnect();
      
      // 确保蓝牙开启
      await ensureBluetoothPower();
      
      // 启动命令行工具脚本
      return await _startCommandLineBridge(deviceAddress, deviceName: deviceName, channel: channel ?? 5);
    } catch (e) {
      _logState?.error('❌ 命令行模式连接失败: $e');
      return false;
    }
  }
  
  /// 启动 RFCOMM Socket 连接（内部方法）
  Future<bool> _startRfcommSocket(String deviceAddress, {String? deviceName, int? channel}) async {
    final targetChannel = channel ?? 5;
    _currentChannel = targetChannel;
    
    _logState?.info('   启动 RFCOMM Socket...');
    _logState?.info('   通道: $targetChannel');
    
    // 查找 Python 脚本
    String? scriptPath;
    final executablePath = Platform.resolvedExecutable;
    final executableDir = File(executablePath).parent.path;
    
    final possiblePaths = [
      '$executableDir/scripts/rfcomm_socket.py',
      'scripts/rfcomm_socket.py',
      '/opt/jn-production-line/scripts/rfcomm_socket.py',
      '${Platform.environment['HOME']}/git/JNProductionLine/scripts/rfcomm_socket.py',
    ];
    
    for (final path in possiblePaths) {
      if (await File(path).exists()) {
        scriptPath = path;
        break;
      }
    }
    
    if (scriptPath == null) {
      _logState?.error('❌ rfcomm_socket.py 脚本不存在');
      return false;
    }
    
    try {
      _logState?.debug('   启动命令: python3 $scriptPath $deviceAddress $targetChannel');
      
      final process = await Process.start(
        'python3',
        [scriptPath, deviceAddress, targetChannel.toString()],
      );
      
      _socketProcess = process;
      
      // 监听 stderr
      process.stderr.transform(const SystemEncoding().decoder).listen((line) {
        _logState?.debug('   [Python] $line');
      });
      
      // 监听 stdout
      _subscription = process.stdout.listen(
        (data) {
          if (data.isNotEmpty) {
            final rawHex = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
            _logState?.debug('🔵 接收 [${data.length} 字节]: $rawHex');
            _onDataReceived(Uint8List.fromList(data));
          }
        },
        onError: (error) {
          _logState?.error('❌ 数据接收错误: $error');
          if (_isConnected) disconnect();
        },
        onDone: () {
          _logState?.warning('⚠️ Socket 数据流结束');
          if (_isConnected) disconnect();
        },
      );
      
      process.exitCode.then((code) {
        _logState?.warning('⚠️ RFCOMM Socket 进程退出 (退出码: $code)');
        if (_isConnected) disconnect();
      });
      
      // 等待连接建立
      await Future.delayed(const Duration(seconds: 2));
      
      _currentDeviceAddress = deviceAddress;
      _currentDeviceName = deviceName;
      _isConnected = true;
      _sequenceNumber = 0;
      _buffer = Uint8List(0);
      _packetCount = 0;
      _pendingResponses.clear();
      
      _logState?.success('✅ RFCOMM Socket 连接成功');
      return true;
    } catch (e) {
      _logState?.error('❌ 启动 RFCOMM Socket 失败: $e');
      return false;
    }
  }
  
  /// 启动 RFCOMM Bind Bridge 连接（内部方法）
  Future<bool> _startRfcommBindBridge(String deviceAddress, {String? deviceName, int? channel}) async {
    final targetChannel = channel ?? 5;
    _currentChannel = targetChannel;
    
    _logState?.info('   启动 RFCOMM Bind Bridge...');
    
    // 查找 Python 脚本
    String? scriptPath;
    final executablePath = Platform.resolvedExecutable;
    final executableDir = File(executablePath).parent.path;
    
    final possiblePaths = [
      '$executableDir/scripts/rfcomm_bind_bridge.py',
      'scripts/rfcomm_bind_bridge.py',
      '/opt/jn-production-line/scripts/rfcomm_bind_bridge.py',
      '${Platform.environment['HOME']}/git/JNProductionLine/scripts/rfcomm_bind_bridge.py',
    ];
    
    for (final path in possiblePaths) {
      if (await File(path).exists()) {
        scriptPath = path;
        break;
      }
    }
    
    if (scriptPath == null) {
      _logState?.error('❌ rfcomm_bind_bridge.py 脚本不存在');
      return false;
    }
    
    try {
      _logState?.debug('   启动命令: python3 $scriptPath $deviceAddress $targetChannel');
      
      final process = await Process.start(
        'python3',
        [scriptPath, deviceAddress, targetChannel.toString()],
      );
      
      _socketProcess = process;
      
      // 监听 stderr
      process.stderr.transform(const SystemEncoding().decoder).listen((line) {
        _logState?.debug('   [Python] $line');
      });
      
      // 监听 stdout
      _subscription = process.stdout.listen(
        (data) {
          if (data.isNotEmpty) {
            final rawHex = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
            _logState?.debug('🔵 接收 [${data.length} 字节]: $rawHex');
            _onDataReceived(Uint8List.fromList(data));
          }
        },
        onError: (error) {
          _logState?.error('❌ 数据接收错误: $error');
          if (_isConnected) disconnect();
        },
        onDone: () {
          _logState?.warning('⚠️ Bind Bridge 数据流结束');
          if (_isConnected) disconnect();
        },
      );
      
      process.exitCode.then((code) {
        _logState?.warning('⚠️ RFCOMM Bind Bridge 进程退出 (退出码: $code)');
        if (_isConnected) disconnect();
      });
      
      // 等待连接建立
      await Future.delayed(const Duration(seconds: 2));
      
      _currentDeviceAddress = deviceAddress;
      _currentDeviceName = deviceName;
      _isConnected = true;
      _sequenceNumber = 0;
      _buffer = Uint8List(0);
      _packetCount = 0;
      _pendingResponses.clear();
      
      _logState?.success('✅ RFCOMM Bind Bridge 连接成功');
      return true;
    } catch (e) {
      _logState?.error('❌ 启动 RFCOMM Bind Bridge 失败: $e');
      return false;
    }
  }
  
  /// 启动串口桥接（内部方法）
  Future<bool> _startSerialBridge(String deviceAddress, {String? deviceName, int? channel}) async {
    final targetChannel = channel ?? 5;
    _currentChannel = targetChannel;
    
    _logState?.info('   启动串口桥接...');
    
    // 查找 Python 脚本
    String? scriptPath;
    final executablePath = Platform.resolvedExecutable;
    final executableDir = File(executablePath).parent.path;
    
    final possiblePaths = [
      '$executableDir/scripts/rfcomm_serial.py',
      'scripts/rfcomm_serial.py',
      '/opt/jn-production-line/scripts/rfcomm_serial.py',
      '${Platform.environment['HOME']}/git/JNProductionLine/scripts/rfcomm_serial.py',
    ];
    
    for (final path in possiblePaths) {
      if (await File(path).exists()) {
        scriptPath = path;
        break;
      }
    }
    
    if (scriptPath == null) {
      _logState?.error('❌ rfcomm_serial.py 脚本不存在');
      _logState?.error('   搜索路径: ${possiblePaths.join(', ')}');
      return false;
    }
    
    _logState?.info('   脚本路径: $scriptPath');
    
    try {
      // 启动 Python 脚本
      final process = await Process.start(
        'python3',
        [scriptPath, '/dev/rfcomm0', '115200'],
        mode: ProcessStartMode.normal,
      );
      
      _socketProcess = process;
      _logState?.info('   串口桥接进程已启动 (PID: ${process.pid})');
      
      // 监听 stderr（日志）
      process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            _logState?.debug('[Python] [SERIAL] $line');
          }
        }
      });
      
      // 监听 stdout（数据）
      _subscription = process.stdout.listen(
        (data) {
          _onDataReceived(Uint8List.fromList(data));
        },
        onError: (error) {
          _logState?.error('❌ 串口桥接数据流错误: $error');
          if (_isConnected) disconnect();
        },
        onDone: () {
          _logState?.warning('⚠️ 串口桥接数据流结束');
          if (_isConnected) disconnect();
        },
      );
      
      process.exitCode.then((code) {
        _logState?.warning('⚠️ 串口桥接进程退出 (退出码: $code)');
        if (_isConnected) disconnect();
      });
      
      // 等待连接建立
      await Future.delayed(const Duration(seconds: 2));
      
      _currentDeviceAddress = deviceAddress;
      _currentDeviceName = deviceName;
      _isConnected = true;
      _sequenceNumber = 0;
      _buffer = Uint8List(0);
      _packetCount = 0;
      _pendingResponses.clear();
      
      _logState?.success('✅ 串口桥接连接成功');
      return true;
    } catch (e) {
      _logState?.error('❌ 启动串口桥接失败: $e');
      return false;
    }
  }
  
  /// 启动命令行工具桥接（内部方法）
  Future<bool> _startCommandLineBridge(String deviceAddress, {String? deviceName, int? channel}) async {
    final targetChannel = channel ?? 5;
    _currentChannel = targetChannel;
    
    _logState?.info('   启动命令行工具桥接...');
    
    // 查找 Python 脚本
    String? scriptPath;
    final executablePath = Platform.resolvedExecutable;
    final executableDir = File(executablePath).parent.path;
    
    final possiblePaths = [
      '$executableDir/scripts/rfcomm_gatttool.py',
      'scripts/rfcomm_gatttool.py',
      '/opt/jn-production-line/scripts/rfcomm_gatttool.py',
      '${Platform.environment['HOME']}/git/JNProductionLine/scripts/rfcomm_gatttool.py',
    ];
    
    for (final path in possiblePaths) {
      if (await File(path).exists()) {
        scriptPath = path;
        break;
      }
    }
    
    if (scriptPath == null) {
      _logState?.error('❌ rfcomm_gatttool.py 脚本不存在');
      _logState?.error('   搜索路径: ${possiblePaths.join(', ')}');
      return false;
    }
    
    _logState?.info('   脚本路径: $scriptPath');
    
    try {
      // 启动 Python 脚本
      final process = await Process.start(
        'python3',
        [scriptPath, deviceAddress, targetChannel.toString()],
        mode: ProcessStartMode.normal,
      );
      
      _socketProcess = process;
      _logState?.info('   命令行桥接进程已启动 (PID: ${process.pid})');
      
      // 监听 stderr（日志）
      process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            _logState?.debug('[Python] [CMD] $line');
          }
        }
      });
      
      // 监听 stdout（数据）
      _subscription = process.stdout.listen(
        (data) {
          _onDataReceived(Uint8List.fromList(data));
        },
        onError: (error) {
          _logState?.error('❌ 命令行桥接数据流错误: $error');
          if (_isConnected) disconnect();
        },
        onDone: () {
          _logState?.warning('⚠️ 命令行桥接数据流结束');
          if (_isConnected) disconnect();
        },
      );
      
      process.exitCode.then((code) {
        _logState?.warning('⚠️ 命令行桥接进程退出 (退出码: $code)');
        if (_isConnected) disconnect();
      });
      
      // 等待连接建立
      await Future.delayed(const Duration(seconds: 3));
      
      _currentDeviceAddress = deviceAddress;
      _currentDeviceName = deviceName;
      _isConnected = true;
      _sequenceNumber = 0;
      _buffer = Uint8List(0);
      _packetCount = 0;
      _pendingResponses.clear();
      
      _logState?.success('✅ 命令行桥接连接成功');
      return true;
    } catch (e) {
      _logState?.error('❌ 启动命令行桥接失败: $e');
      return false;
    }
  }
  
  /// 断开连接
  Future<void> disconnect() async {
    try {
      if (_isConnected || _socketProcess != null) {
        _logState?.info('🔌 断开 SPP 连接...');
        
        // 先标记为未连接
        _isConnected = false;
        
        // 取消数据订阅
        await _subscription?.cancel();
        _subscription = null;
        
        // 杀掉 Python 进程
        if (_socketProcess != null) {
          _socketProcess!.kill();
          _socketProcess = null;
          _logState?.debug('   Python 进程已终止');
        }
        
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
  
  /// 发送数据（通过 Python 进程的 stdin）
  Future<bool> sendData(Uint8List data) async {
    if (!_isConnected || _socketProcess == null) {
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
      
      // 通过 Python 进程的 stdin 发送数据
      _socketProcess!.stdin.add(data);
      await _socketProcess!.stdin.flush();
      
      _logState?.success('✅ 数据已发送');
      
      return true;
    } catch (e) {
      _logState?.error('❌ 发送数据失败: $e');
      
      // 如果写入失败，可能是连接已断开
      _logState?.error('   Socket 连接可能已断开');
      await disconnect();
      
      return false;
    }
  }
  
  /// 发送命令并等待响应（带重试机制）
  /// 基于 GTP over SPP 协议通讯
  Future<Map<String, dynamic>?> sendCommandAndWaitResponse(
    Uint8List command, {
    Duration timeout = const Duration(seconds: 10),  // 增加默认超时到10秒
    int maxRetries = 3,  // 最多重试3次
    int? moduleId,
    int? messageId,
  }) async {
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _logState?.info('📡 GTP over SPP 发送命令');
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    if (!_isConnected) {
      _logState?.error('❌ SPP 未连接，无法发送命令');
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return {'error': 'Not connected'};
    }
    
    // 打印连接状态
    _logState?.info('📋 连接状态:');
    _logState?.info('   设备地址: $_currentDeviceAddress');
    if (_currentDeviceName != null) {
      _logState?.info('   设备名称: $_currentDeviceName');
    }
    _logState?.info('   RFCOMM Channel: $_currentChannel');
    _logState?.info('   协议: GTP over SPP');
    
    // 打印命令参数
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _logState?.info('📦 命令参数:');
    final cmdHex = command.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    _logState?.info('   Payload: [$cmdHex]');
    _logState?.info('   Payload 长度: ${command.length} 字节');
    _logState?.info('   超时时间: ${timeout.inSeconds} 秒');
    _logState?.info('   最大重试: $maxRetries 次');
    if (moduleId != null) {
      _logState?.info('   Module ID: 0x${moduleId.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
    if (messageId != null) {
      _logState?.info('   Message ID: 0x${messageId.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
    
    // 重试逻辑
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        _logState?.warning('🔄 第 $attempt 次重试...');
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      try {
        final seqNum = _sequenceNumber++;
        final completer = Completer<Map<String, dynamic>?>();
        _pendingResponses[seqNum] = completer;
        
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        _logState?.info('📤 发送 GTP 数据包 (尝试 ${attempt + 1}/${maxRetries + 1})');
        _logState?.info('   序列号 (SN): $seqNum');
        _logState?.info('   待处理响应数: ${_pendingResponses.length}');
        
        // 构建 GTP 数据包
        final gtpPacket = GTPProtocol.buildGTPPacket(
          command,
          moduleId: moduleId,
          messageId: messageId,
          sequenceNumber: seqNum,
        );
        
        // 详细打印 GTP 数据包结构
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        _logState?.info('📦 GTP 数据包结构:');
        final fullPacketHex = gtpPacket.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
        _logState?.info('   完整 HEX: [$fullPacketHex]');
        _logState?.info('   总长度: ${gtpPacket.length} 字节');
        
        // 解析 GTP 头部结构
        if (gtpPacket.length >= 12) {
          _logState?.info('   --- GTP 头部 ---');
          _logState?.info('   Preamble (4B): ${gtpPacket.sublist(0, 4).map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}').join(' ')}');
          _logState?.info('   Version (1B): 0x${gtpPacket[4].toRadixString(16).padLeft(2, '0').toUpperCase()}');
          final length = gtpPacket[5] | (gtpPacket[6] << 8);
          _logState?.info('   Length (2B): $length (0x${length.toRadixString(16).padLeft(4, '0').toUpperCase()})');
          _logState?.info('   Type (1B): 0x${gtpPacket[7].toRadixString(16).padLeft(2, '0').toUpperCase()}');
          _logState?.info('   FC (1B): 0x${gtpPacket[8].toRadixString(16).padLeft(2, '0').toUpperCase()}');
          final seq = gtpPacket[9] | (gtpPacket[10] << 8);
          _logState?.info('   Seq (2B): $seq');
          _logState?.info('   CRC8 (1B): 0x${gtpPacket[11].toRadixString(16).padLeft(2, '0').toUpperCase()}');
          
          // CLI 消息部分
          if (gtpPacket.length >= 28) {
            _logState?.info('   --- CLI 消息 ---');
            final cliStart = gtpPacket[12] | (gtpPacket[13] << 8);
            _logState?.info('   Start (2B): 0x${cliStart.toRadixString(16).padLeft(4, '0').toUpperCase()}');
            final cliModuleId = gtpPacket[14] | (gtpPacket[15] << 8);
            _logState?.info('   Module ID (2B): 0x${cliModuleId.toRadixString(16).padLeft(4, '0').toUpperCase()}');
            final cliCrc = gtpPacket[16] | (gtpPacket[17] << 8);
            _logState?.info('   CRC16 (2B): 0x${cliCrc.toRadixString(16).padLeft(4, '0').toUpperCase()}');
            final cliMsgId = gtpPacket[18] | (gtpPacket[19] << 8);
            _logState?.info('   Message ID (2B): 0x${cliMsgId.toRadixString(16).padLeft(4, '0').toUpperCase()}');
            _logState?.info('   Flags (1B): 0x${gtpPacket[20].toRadixString(16).padLeft(2, '0').toUpperCase()}');
            _logState?.info('   Result (1B): 0x${gtpPacket[21].toRadixString(16).padLeft(2, '0').toUpperCase()}');
            final cliLen = gtpPacket[22] | (gtpPacket[23] << 8);
            _logState?.info('   Payload Len (2B): $cliLen');
            final cliSn = gtpPacket[24] | (gtpPacket[25] << 8);
            _logState?.info('   SN (2B): $cliSn');
          }
        }
        
        // 发送完整的 GTP 数据包
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        _logState?.info('⏳ 发送数据包...');
        final success = await sendData(gtpPacket);
        if (!success) {
          _pendingResponses.remove(seqNum);
          _logState?.error('❌ 数据包发送失败');
          continue;  // 重试
        }
        _logState?.success('✅ 数据包已发送');
        
        // 等待响应
        _logState?.info('⏳ 等待响应 (超时: ${timeout.inSeconds}秒)...');
        final response = await completer.future.timeout(
          timeout,
          onTimeout: () {
            _pendingResponses.remove(seqNum);
            _logState?.error('❌ 响应超时 (${timeout.inSeconds}秒)');
            _logState?.info('   当前待处理响应数: ${_pendingResponses.length}');
            _logState?.info('   缓冲区大小: ${_buffer.length} 字节');
            
            // 超时时检查缓冲区是否有数据
            if (_buffer.isNotEmpty) {
              final bufferHex = _buffer.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
              _logState?.warning('⚠️ 超时时缓冲区有未处理数据: $bufferHex');
              
              // 尝试处理缓冲区中的数据作为原始响应
              if (_buffer.length >= 4) {
                _logState?.info('🔄 尝试将缓冲区数据作为响应处理');
                final bufferData = Uint8List.fromList(_buffer);
                _buffer = Uint8List(0);
                
                // 返回缓冲区数据作为 payload
                return {
                  'payload': bufferData,
                  'timestamp': DateTime.now(),
                  'raw': true,
                  'warning': '响应超时，返回缓冲区数据',
                };
              }
            }
            
            return {'error': 'Timeout', 'details': '响应超时 ${timeout.inSeconds}秒'};
          },
        );
        
        _pendingResponses.remove(seqNum);
        
        // 打印响应结果
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        if (response != null && !response.containsKey('error')) {
          _logState?.success('✅ 收到有效响应 (尝试 ${attempt + 1})');
          _logState?.info('📥 响应详情:');
          if (response.containsKey('moduleId')) {
            _logState?.info('   Module ID: 0x${(response['moduleId'] as int?)?.toRadixString(16).toUpperCase().padLeft(4, '0') ?? 'N/A'}');
          }
          if (response.containsKey('messageId')) {
            _logState?.info('   Message ID: 0x${(response['messageId'] as int?)?.toRadixString(16).toUpperCase().padLeft(4, '0') ?? 'N/A'}');
          }
          if (response.containsKey('sn')) {
            _logState?.info('   序列号: ${response['sn']}');
          }
          if (response.containsKey('result')) {
            _logState?.info('   Result: ${response['result']}');
          }
          if (response.containsKey('payload')) {
            final payload = response['payload'];
            if (payload is Uint8List && payload.isNotEmpty) {
              final payloadHex = payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
              _logState?.info('   Payload [${payload.length} 字节]: $payloadHex');
            }
          }
          _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          return response;
        }
        
        // 响应失败
        _logState?.error('❌ 响应失败');
        if (response != null && response.containsKey('error')) {
          _logState?.info('   错误: ${response['error']}');
          if (response.containsKey('details')) {
            _logState?.info('   详情: ${response['details']}');
          }
        }
        
        // 如果是最后一次尝试，返回错误
        if (attempt == maxRetries) {
          _logState?.error('❌ 所有重试均失败 ($maxRetries 次)');
          _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          return response;
        }
        
        // 否则继续重试
        _logState?.warning('⚠️ 准备重试...');
        
      } catch (e) {
        _logState?.error('❌ 命令执行异常: $e');
        if (attempt == maxRetries) {
          _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          return {'error': e.toString()};
        }
      }
    }
    
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    return {'error': 'Max retries exceeded'};
  }
  
  /// 处理接收到的数据
  void _onDataReceived(Uint8List data) {
    try {
      // ========== 原始响应日志（最优先） ==========
      final hexStr = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      final asciiStr = String.fromCharCodes(
        data.map((b) => (b >= 32 && b <= 126) ? b : 46), // 46 = '.'
      );
      
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('📥 原始响应数据 [${data.length} 字节] (模式: ${_parseMode.displayName})');
      _logState?.info('   HEX: $hexStr');
      _logState?.info('   ASCII: $asciiStr');
      _logState?.info('   字节数组: [${data.join(', ')}]');
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // 根据解析模式处理数据
      switch (_parseMode) {
        case DataParseMode.pythonGtpAssembly:
          // Python 端已组装完整 GTP 包，直接处理
          _processBufferPythonMode(data);
          break;
          
        case DataParseMode.dartGtpAssembly:
          // Dart 端负责组装 GTP 包
          _processBufferDartMode(data);
          break;
          
        case DataParseMode.rawPassthrough:
          // 原始数据直通，不进行 GTP 组装
          _processRawPassthrough(data);
          break;
          
        case DataParseMode.smartAdaptive:
          // 智能自适应模式
          _processSmartAdaptive(data);
          break;
      }
      
      // 广播原始数据
      _dataController.add(data);
    } catch (e) {
      _logState?.error('❌ 数据处理异常: $e');
    }
  }
  
  /// 模式1: Python 端 GTP 组装模式
  /// Python 脚本已经组装好完整的 GTP 数据包，直接处理
  void _processBufferPythonMode(Uint8List data) {
    // 添加到缓冲区
    final newBuffer = Uint8List(_buffer.length + data.length);
    newBuffer.setRange(0, _buffer.length, _buffer);
    newBuffer.setRange(_buffer.length, newBuffer.length, data);
    _buffer = newBuffer;
    
    // 处理完整数据包（假设 Python 已组装好）
    _processBuffer();
  }
  
  /// 模式2: Dart 端 GTP 组装模式
  /// Python 脚本直接透传原始数据，Dart 端负责缓冲和组装
  void _processBufferDartMode(Uint8List data) {
    // 添加到缓冲区
    final newBuffer = Uint8List(_buffer.length + data.length);
    newBuffer.setRange(0, _buffer.length, _buffer);
    newBuffer.setRange(_buffer.length, newBuffer.length, data);
    _buffer = newBuffer;
    
    _logState?.debug('🔧 Dart 端 GTP 组装模式，缓冲区: ${_buffer.length} 字节');
    
    // 处理缓冲区中的完整 GTP 数据包
    _processBuffer();
  }
  
  /// 模式3: 原始数据直通模式
  /// 不进行 GTP 组装，直接处理原始数据
  void _processRawPassthrough(Uint8List data) {
    _logState?.info('🔄 原始数据直通模式，直接处理 ${data.length} 字节');
    
    // 直接作为原始响应处理
    _processRawResponse(data);
  }
  
  /// 模式4: 智能自适应模式
  /// 自动检测数据格式，根据是否有 GTP 头选择处理方式
  void _processSmartAdaptive(Uint8List data) {
    // 添加到缓冲区
    final newBuffer = Uint8List(_buffer.length + data.length);
    newBuffer.setRange(0, _buffer.length, _buffer);
    newBuffer.setRange(_buffer.length, newBuffer.length, data);
    _buffer = newBuffer;
    
    _logState?.debug('🧠 智能自适应模式，缓冲区: ${_buffer.length} 字节');
    
    // 检查缓冲区是否有 GTP 前导码
    bool hasGtpPreamble = false;
    for (int i = 0; i <= _buffer.length - 4; i++) {
      if (_buffer[i] == 0xD0 && _buffer[i + 1] == 0xD2 && 
          _buffer[i + 2] == 0xC5 && _buffer[i + 3] == 0xC2) {
        hasGtpPreamble = true;
        break;
      }
    }
    
    if (hasGtpPreamble) {
      _logState?.info('🔍 检测到 GTP 前导码，使用 GTP 组装模式');
      _processBuffer();
    } else {
      // 检查是否有 CLI Tail (40 40)
      bool hasTail = false;
      for (int i = 0; i <= _buffer.length - 2; i++) {
        if (_buffer[i] == 0x40 && _buffer[i + 1] == 0x40) {
          hasTail = true;
          break;
        }
      }
      
      if (hasTail) {
        _logState?.info('🔍 检测到 CLI Tail (40 40) 但无 GTP 头，使用原始响应处理');
        _processRawResponse(_buffer);
        _buffer = Uint8List(0);
      } else if (_buffer.length > 100) {
        // 缓冲区过大且没有有效标志，清空并处理
        _logState?.warning('⚠️ 缓冲区过大 (${_buffer.length} 字节) 且无有效标志，直接处理');
        _processRawResponse(_buffer);
        _buffer = Uint8List(0);
      } else {
        _logState?.debug('   等待更多数据...');
      }
    }
  }
  
  /// 处理缓冲区中的数据包
  void _processBuffer() {
    final bufferHex = _buffer.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    _logState?.debug('🔍 处理缓冲区，当前长度: ${_buffer.length} 字节');
    _logState?.debug('   缓冲区内容: $bufferHex');
    
    // 至少需要 4 字节才能检查前导码
    while (_buffer.length >= 4) {
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
        _logState?.debug('🔍 缓冲区中未找到 GTP 起始标志 (D0 D2 C5 C2)');
        _logState?.debug('   缓冲区内容 [${_buffer.length} 字节]: $bufferHex');
        
        // 检查是否可能是前导码的部分（数据分片接收）
        // 前导码字节序列：D0 D2 C5 C2
        bool mightBePreambleStart = false;
        if (_buffer.length >= 1 && _buffer[_buffer.length - 1] == 0xD0) {
          mightBePreambleStart = true;
        } else if (_buffer.length >= 2 && _buffer[_buffer.length - 2] == 0xD0 && _buffer[_buffer.length - 1] == 0xD2) {
          mightBePreambleStart = true;
        } else if (_buffer.length >= 3 && _buffer[_buffer.length - 3] == 0xD0 && _buffer[_buffer.length - 2] == 0xD2 && _buffer[_buffer.length - 1] == 0xC5) {
          mightBePreambleStart = true;
        }
        
        if (mightBePreambleStart) {
          // 可能是前导码的开始，等待更多数据
          _logState?.debug('   可能是前导码的开始，等待更多数据...');
          break;
        }
        
        // 如果缓冲区太大（超过 500 字节）且仍未找到前导码，可能是数据损坏
        // 此时尝试作为原始响应处理
        if (_buffer.length >= 500) {
          _logState?.warning('⚠️ 缓冲区过大 (${_buffer.length} 字节) 且未找到 GTP 起始标志');
          _logState?.info('🔄 尝试解析为原始响应数据');
          _processRawResponse(_buffer);
          _buffer = Uint8List(0);
          break;
        }
        
        // 缓冲区较小，继续等待更多数据
        // 但如果等待时间过长（通过超时机制处理），则作为原始数据处理
        _logState?.debug('   缓冲区较小 (${_buffer.length} 字节)，继续等待更多数据...');
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
      
      // ========== 详细的 GTP 数据包日志 ==========
      final hexStr = packet.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('📦 GTP 数据包 #$_packetCount');
      _logState?.info('   总长度: ${packet.length} 字节');
      _logState?.info('   完整 HEX: $hexStr');
      _logState?.info('   字节数组: [${packet.join(', ')}]');
      
      // 解析 GTP 头部（与 GTPProtocol.parseGTPResponse 保持一致）
      if (packet.length >= 12) {
        _logState?.info('   --- GTP 头部 ---');
        _logState?.info('   Preamble (4B): ${packet.sublist(0, 4).map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}').join(' ')}');
        _logState?.info('   Version (1B): 0x${packet[4].toRadixString(16).padLeft(2, '0').toUpperCase()}');
        final length = packet[5] | (packet[6] << 8);
        _logState?.info('   Length (2B): $length (0x${length.toRadixString(16).padLeft(4, '0').toUpperCase()})');
        _logState?.info('   Type (1B): 0x${packet[7].toRadixString(16).padLeft(2, '0').toUpperCase()}');
        _logState?.info('   FC (1B): 0x${packet[8].toRadixString(16).padLeft(2, '0').toUpperCase()}');
        final seq = packet[9] | (packet[10] << 8);
        _logState?.info('   Seq (2B): $seq');
        _logState?.info('   CRC8 (1B): 0x${packet[11].toRadixString(16).padLeft(2, '0').toUpperCase()}');
        
        // CLI Payload 从字节 12 开始
        if (packet.length > 12 + 4) {
          final payloadLen = length - 12; // Length - (Version+Length+Type+FC+Seq+CRC8+CRC32)
          if (payloadLen > 0 && packet.length >= 12 + payloadLen) {
            final payload = packet.sublist(12, 12 + payloadLen);
            final payloadHex = payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
            _logState?.info('   CLI Payload (${payloadLen} 字节): $payloadHex');
          }
        }
        
        // CRC32 在最后 4 字节
        if (packet.length >= 4) {
          final crc = packet.sublist(packet.length - 4);
          _logState?.info('   CRC32 (4B): ${crc.map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}').join(' ')}');
        }
      }
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // 获取 Type 字段（与串口服务保持一致，只处理 Type 0x02 和 0x03）
      final type = packet[7];
      if (type != 0x02 && type != 0x03) {
        _logState?.debug('   忽略 Type 0x${type.toRadixString(16).padLeft(2, '0').toUpperCase()} 数据包');
        return;
      }
      
      // 使用 GTP 协议解析（跳过 CRC 验证，与串口服务保持一致）
      final parsedGTP = GTPProtocol.parseGTPResponse(packet, skipCrcVerify: true);
      
      if (parsedGTP == null) {
        _logState?.error('❌ GTP 解析失败');
        return;
      }
      
      if (parsedGTP.containsKey('error')) {
        _logState?.error('❌ GTP 错误: ${parsedGTP['error']}');
        return;
      }
      
      // Type 0x02 (设备日志) 不包含 CLI 消息结构，只记录日志
      if (type == 0x02) {
        _logState?.info('📋 设备日志 (Type 0x02)');
        final payload = parsedGTP['payload'] as Uint8List?;
        if (payload != null && payload.isNotEmpty) {
          final payloadHex = payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
          _logState?.info('   Payload [${payload.length} 字节]: $payloadHex');
        }
        return; // 设备日志不需要响应匹配
      }
      
      // Type 0x03 (CLI 消息) 需要解析 CLI 结构
      _logState?.info('✅ GTP 解析成功 (Type 0x03 CLI):');
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
  /// 设备可能返回两种格式：
  /// 1. 纯原始数据：[CMD] [数据...]
  /// 2. CLI 消息（无 GTP 外层）：... [23 23] [CLI数据] [40 40] ...
  void _processRawResponse(Uint8List rawData) {
    try {
      _packetCount++;
      
      final hexStr = rawData.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      _logState?.info('📦 原始响应数据 #$_packetCount [${rawData.length} 字节]: $hexStr');
      
      Map<String, dynamic>? response;
      
      // 尝试查找 CLI 消息结构 (Start: 0x2323, Tail: 0x4040)
      int cliStartIndex = -1;
      for (int i = 0; i <= rawData.length - 2; i++) {
        if (rawData[i] == 0x23 && rawData[i + 1] == 0x23) {
          cliStartIndex = i;
          break;
        }
      }
      
      if (cliStartIndex >= 0 && rawData.length >= cliStartIndex + 16) {
        _logState?.info('🔍 找到 CLI 消息起始标志 (23 23) 在位置 $cliStartIndex');
        
        // 提取 CLI 消息部分并解析
        final cliData = rawData.sublist(cliStartIndex);
        final cliResponse = GTPProtocol.parseCLIResponse(cliData);
        
        if (cliResponse != null && !cliResponse.containsKey('error')) {
          _logState?.success('✅ CLI 消息解析成功');
          _logState?.info('   Module ID: 0x${cliResponse['moduleId']?.toRadixString(16).padLeft(4, '0').toUpperCase() ?? 'N/A'}');
          _logState?.info('   Message ID: 0x${cliResponse['messageId']?.toRadixString(16).padLeft(4, '0').toUpperCase() ?? 'N/A'}');
          _logState?.info('   SN: ${cliResponse['sn'] ?? 'N/A'}');
          _logState?.info('   Result: ${cliResponse['result'] ?? 'N/A'}');
          
          final payload = cliResponse['payload'] as Uint8List?;
          if (payload != null && payload.isNotEmpty) {
            final payloadHex = payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
            _logState?.info('   Payload [${payload.length} 字节]: $payloadHex');
          }
          
          response = {
            'payload': cliResponse['payload'] ?? Uint8List(0),
            'timestamp': DateTime.now(),
            'moduleId': cliResponse['moduleId'],
            'messageId': cliResponse['messageId'],
            'sn': cliResponse['sn'],
            'result': cliResponse['result'],
            'raw': false,
          };
        } else {
          _logState?.warning('⚠️ CLI 消息解析失败，使用原始数据');
        }
      }
      
      // 如果 CLI 解析失败，使用原始数据
      if (response == null) {
        _logState?.info('🔄 使用原始数据作为 payload');
        
        // 尝试从原始数据中提取序列号
        int? responseSN;
        if (rawData.length >= 3) {
          responseSN = rawData[1] | (rawData[2] << 8);
          _logState?.info('   提取序列号: $responseSN (从字节 1-2)');
        }
        
        response = {
          'payload': rawData,
          'timestamp': DateTime.now(),
          'raw': true,
          'sn': responseSN,
        };
      }
      
      // 匹配待处理的请求
      final responseSN = response['sn'] as int?;
      if (responseSN != null && _pendingResponses.containsKey(responseSN)) {
        final completer = _pendingResponses[responseSN];
        _logState?.success('✅ 响应匹配序列号: $responseSN');
        if (!completer!.isCompleted) {
          completer.complete(response);
          _pendingResponses.remove(responseSN);
        }
      } else if (_pendingResponses.isNotEmpty) {
        // 如果序列号不匹配，使用第一个待处理请求
        final firstKey = _pendingResponses.keys.first;
        final completer = _pendingResponses[firstKey];
        _logState?.warning('⚠️ 响应 SN ($responseSN) 不匹配，使用第一个待处理请求: $firstKey');
        if (!completer!.isCompleted) {
          completer.complete(response);
          _pendingResponses.remove(firstKey);
        }
      } else {
        _logState?.warning('⚠️ 收到响应但没有待处理的请求');
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
