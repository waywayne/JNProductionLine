import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../models/log_state.dart';
import 'gtp_protocol.dart';

/// 纯 Dart 实现的 RFCOMM 服务
/// 使用 Python bluetooth socket 进行 SPP 通信（不使用 rfcomm bind）
/// 不会断开系统蓝牙设置中的连接
class NativeRfcommService {
  Process? _bridgeProcess;
  StreamSubscription<List<int>>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  
  final StreamController<Uint8List> _dataController = StreamController<Uint8List>.broadcast();
  final StreamController<String> _logController = StreamController<String>.broadcast();
  
  bool _isDisposed = false;
  
  String? _currentDeviceAddress;
  String? _currentDeviceName;
  int? _currentChannel;
  bool _isConnected = false;
  LogState? _logState;
  
  // GTP 缓冲区
  final List<int> _gtpBuffer = [];
  int _fragmentCount = 0;
  int _packetCount = 0;
  
  // 待处理的响应
  final Map<int, Completer<Map<String, dynamic>?>> _pendingResponses = {};
  int _sequenceNumber = 0;
  
  // 统计信息
  int _totalBytesReceived = 0;
  int _totalBytesSent = 0;
  
  /// 设置日志状态
  void setLogState(LogState? logState) {
    _logState = logState;
  }
  
  /// 获取连接状态
  bool get isConnected => _isConnected;
  
  /// 获取当前设备地址
  String? get currentDeviceAddress => _currentDeviceAddress;
  
  /// 获取当前设备名称
  String? get currentDeviceName => _currentDeviceName;
  
  /// 获取当前 RFCOMM 通道
  int? get currentChannel => _currentChannel;
  
  /// 获取数据流
  Stream<Uint8List> get dataStream => _dataController.stream;
  
  /// 获取日志流
  Stream<String> get logStream => _logController.stream;
  
  /// 获取缓冲区大小
  int get bufferSize => _gtpBuffer.length;
  
  /// 获取分片计数
  int get fragmentCount => _fragmentCount;
  
  /// 获取数据包计数
  int get packetCount => _packetCount;
  
  /// 获取接收字节数
  int get totalBytesReceived => _totalBytesReceived;
  
  /// 获取发送字节数
  int get totalBytesSent => _totalBytesSent;
  
  void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logMessage = '[$timestamp] $message';
    _logState?.info(logMessage);
    if (!_isDisposed && !_logController.isClosed) {
      _logController.add(logMessage);
    }
  }
  
  void _logError(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logMessage = '[$timestamp] ❌ $message';
    _logState?.error(logMessage);
    if (!_isDisposed && !_logController.isClosed) {
      _logController.add(logMessage);
    }
  }
  
  void _logSuccess(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logMessage = '[$timestamp] ✅ $message';
    _logState?.success(logMessage);
    if (!_isDisposed && !_logController.isClosed) {
      _logController.add(logMessage);
    }
  }
  
  /// 彻底清理 RFCOMM 资源（解决 Errno 12 Cannot allocate memory）
  /// 通过 hciconfig hci0 reset 强制重置蓝牙适配器释放所有内核资源
  /// 绝不 bluetoothctl disconnect/connect
  Future<void> _cleanupRfcommResources() async {
    _log('🧹 彻底清理 RFCOMM 资源...');
    
    // 1. 强杀旧的 Python 桥接进程
    try {
      await Process.run('pkill', ['-9', '-f', 'rfcomm_socket_simple.py']);
    } catch (_) {}
    
    // 2. 强杀残留的 cat /dev/rfcomm 进程
    try {
      await Process.run('pkill', ['-9', '-f', 'cat /dev/rfcomm']);
    } catch (_) {}
    
    await Future.delayed(const Duration(milliseconds: 300));
    
    // 3. 释放所有 rfcomm 绑定
    try {
      await Process.run('rfcomm', ['release', 'all']);
    } catch (_) {}
    try {
      await Process.run('sudo', ['rfcomm', 'release', 'all']);
    } catch (_) {}
    
    // 4. 重置蓝牙适配器 — 唯一能强制释放内核 RFCOMM 资源的方法
    _log('   🔄 重置蓝牙适配器 hci0...');
    try {
      await Process.run('sudo', ['hciconfig', 'hci0', 'reset']);
      await Future.delayed(const Duration(seconds: 1));
      await Process.run('sudo', ['hciconfig', 'hci0', 'up']);
      await Future.delayed(const Duration(milliseconds: 500));
      await Process.run('sudo', ['hciconfig', 'hci0', 'piscan']);
      _log('   ✅ 蓝牙适配器已重置');
    } catch (e) {
      _log('   ⚠️ hciconfig reset 失败: $e');
    }
    
    // 5. 等待适配器就绪
    await Future.delayed(const Duration(seconds: 1));
    _log('🧹 清理完成');
  }

  /// 获取 Python 脚本路径
  String _getScriptPath() {
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    // 尝试多个可能的路径
    final candidates = [
      '$executableDir/scripts/rfcomm_socket_simple.py',
      '${Directory.current.path}/scripts/rfcomm_socket_simple.py',
      '/opt/jn-production-line/scripts/rfcomm_socket_simple.py',
      '${Platform.environment['HOME']}/git/JNProductionLine/scripts/rfcomm_socket_simple.py',
      '${Platform.resolvedExecutable.contains('/') ? File(Platform.resolvedExecutable).parent.parent.path : '.'}/data/flutter_assets/scripts/rfcomm_socket_simple.py',
    ];
    
    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    
    // 默认路径
    return '${Directory.current.path}/scripts/rfcomm_socket_simple.py';
  }
  
  /// 连接设备
  Future<bool> connect(String macAddress, {String? deviceName, int channel = 1}) async {
    if (_isConnected) {
      _log('⚠️ 已连接，先断开...');
      await disconnect();
    }
    
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('🔗 开始连接 (Socket 模式，不使用 rfcomm bind)');
    _log('   MAC: $macAddress');
    _log('   Channel: $channel');
    if (deviceName != null) {
      _log('   Name: $deviceName');
    }
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    try {
      // 清理僵尸 RFCOMM 资源（释放内核内存，解决 Errno 12）
      // ⚠️ 只 pkill 旧 python 桥接 + rfcomm release，绝不 bluetoothctl disconnect
      await _cleanupRfcommResources();
      
      // 启动 Python socket 桥接脚本
      final scriptPath = _getScriptPath();
      _log('📜 脚本: $scriptPath');
      
      if (!File(scriptPath).existsSync()) {
        _logError('脚本文件不存在: $scriptPath');
        return false;
      }
      
      _bridgeProcess = await Process.start(
        'python3',
        ['-u', scriptPath, macAddress, channel.toString()],
        environment: {'PYTHONUNBUFFERED': '1'},
      );
      
      _log('🚀 桥接进程已启动 (PID: ${_bridgeProcess!.pid})');
      
      // 监听 stdout（设备数据）
      _stdoutSubscription = _bridgeProcess!.stdout.listen(
        (data) {
          if (data.isNotEmpty) {
            _onDataReceived(Uint8List.fromList(data));
          }
        },
        onError: (error) {
          _logError('stdout 错误: $error');
        },
        onDone: () {
          _log('📭 stdout 流结束');
          if (_isConnected) {
            _isConnected = false;
            _log('⚠️ 桥接进程已退出，连接断开');
          }
        },
      );
      
      // 监测连接状态
      bool connectionReady = false;
      
      // 监听 stderr（日志 + 连接状态检测）- 使用 UTF-8 解码
      _stderrSubscription = _bridgeProcess!.stderr
          .transform(const SystemEncoding().decoder)
          .listen((msg) {
            if (msg.trim().isNotEmpty) {
              for (final line in msg.split('\n')) {
                if (line.trim().isNotEmpty) {
                  _log('🐍 $line');
                  // Python 脚本在连接成功后输出此消息
                  if (line.contains('连接已建立') || line.contains('连接成功')) {
                    connectionReady = true;
                  }
                }
              }
            }
          });
      
      // 等待连接建立，同时监测进程是否提前退出
      _log('⏳ 等待 socket 连接建立...');
      bool processExited = false;
      int? processExitCode;
      _bridgeProcess!.exitCode.then((code) {
        processExitCode = code;
        processExited = true;
      });
      
      // 等待连接建立（检测 Python 成功消息，或进程退出表示失败，最多 15s）
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (connectionReady) {
          _logSuccess('Python 桥接连接已就绪');
          break;
        }
        if (processExited) {
          _logError('桥接进程已退出 (退出码: $processExitCode)，连接失败');
          _bridgeProcess = null;
          return false;
        }
      }
      
      if (processExited) {
        _logError('桥接进程已退出，连接失败');
        _bridgeProcess = null;
        return false;
      }
      
      _currentDeviceAddress = macAddress;
      _currentDeviceName = deviceName;
      _currentChannel = channel;
      _isConnected = true;
      
      _logSuccess('连接成功 (Socket 模式)');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      return true;
    } catch (e) {
      _logError('连接失败: $e');
      await disconnect();
      return false;
    }
  }
  
  /// 处理接收到的数据
  void _onDataReceived(Uint8List data) {
    _fragmentCount++;
    _totalBytesReceived += data.length;
    
    final hexStr = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    _log('📥 接收 #$_fragmentCount [${data.length}字节]: $hexStr');
    
    // 广播原始数据
    if (!_isDisposed && !_dataController.isClosed) {
      _dataController.add(data);
    }
    
    // 添加到 GTP 缓冲区
    _gtpBuffer.addAll(data);
    
    // 尝试解析 GTP 数据包
    _processGtpBuffer();
  }
  
  /// 处理 GTP 缓冲区
  void _processGtpBuffer() {
    while (_gtpBuffer.length >= 4) {
      // 查找 GTP 前导码 (D0 D2 C5 C2)
      int preambleIndex = -1;
      for (int i = 0; i <= _gtpBuffer.length - 4; i++) {
        if (_gtpBuffer[i] == 0xD0 && _gtpBuffer[i + 1] == 0xD2 &&
            _gtpBuffer[i + 2] == 0xC5 && _gtpBuffer[i + 3] == 0xC2) {
          preambleIndex = i;
          break;
        }
      }
      
      if (preambleIndex == -1) {
        if (_gtpBuffer.length > 500) {
          _log('⚠️ 缓冲区过大 (${_gtpBuffer.length}字节) 且未找到 GTP 前导码，清空');
          _gtpBuffer.clear();
          _fragmentCount = 0;
        }
        break;
      }
      
      if (preambleIndex > 0) {
        _log('⚠️ 跳过 $preambleIndex 字节垃圾数据');
        _gtpBuffer.removeRange(0, preambleIndex);
      }
      
      if (_gtpBuffer.length < 7) break;
      
      // 读取 Length 字段 (offset 5-6, little endian)
      final gtpLength = _gtpBuffer[5] | (_gtpBuffer[6] << 8);
      final totalLength = 4 + gtpLength;
      
      if (_gtpBuffer.length < totalLength) {
        _log('⏳ 等待更多数据 (需要: $totalLength, 当前: ${_gtpBuffer.length})');
        break;
      }
      
      final gtpPacket = Uint8List.fromList(_gtpBuffer.sublist(0, totalLength));
      _gtpBuffer.removeRange(0, totalLength);
      _packetCount++;
      _fragmentCount = 0;
      
      _processGtpPacket(gtpPacket);
    }
  }
  
  /// 处理完整的 GTP 数据包
  void _processGtpPacket(Uint8List packet) {
    final hexStr = packet.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    _logSuccess('📦 GTP #$_packetCount [${packet.length}字节]: $hexStr');
    
    final parsedGTP = GTPProtocol.parseGTPResponse(packet, skipCrcVerify: true);
    
    if (parsedGTP == null || parsedGTP.containsKey('error')) {
      _logError('GTP 解析失败');
      return;
    }
    
    if (parsedGTP.containsKey('moduleId')) {
      _log('   ModuleID=0x${(parsedGTP['moduleId'] as int).toRadixString(16).padLeft(4, '0').toUpperCase()}, '
           'MessageID=0x${(parsedGTP['messageId'] as int).toRadixString(16).padLeft(4, '0').toUpperCase()}, '
           'Result=${parsedGTP['result']}, SN=${parsedGTP['sn']}');
    }
    
    // 匹配待处理的请求
    final responseSN = parsedGTP['sn'] as int?;
    if (responseSN != null && _pendingResponses.containsKey(responseSN)) {
      final completer = _pendingResponses[responseSN];
      if (!completer!.isCompleted) {
        completer.complete({
          'rawBytes': packet,
          'payload': parsedGTP['payload'] ?? Uint8List(0),
          'timestamp': DateTime.now(),
          'moduleId': parsedGTP['moduleId'],
          'messageId': parsedGTP['messageId'],
          'sn': parsedGTP['sn'],
          'result': parsedGTP['result'],
        });
        _pendingResponses.remove(responseSN);
        _logSuccess('响应匹配 SN: $responseSN');
      }
    } else if (_pendingResponses.isNotEmpty) {
      final firstKey = _pendingResponses.keys.first;
      final completer = _pendingResponses[firstKey];
      if (!completer!.isCompleted) {
        completer.complete({
          'rawBytes': packet,
          'payload': parsedGTP['payload'] ?? Uint8List(0),
          'timestamp': DateTime.now(),
          'moduleId': parsedGTP['moduleId'],
          'messageId': parsedGTP['messageId'],
          'sn': parsedGTP['sn'],
          'result': parsedGTP['result'],
        });
        _pendingResponses.remove(firstKey);
        _log('⚠️ 响应 SN 不匹配，使用第一个待处理请求');
      }
    }
  }
  
  /// 发送原始数据
  Future<bool> sendRawData(Uint8List data) async {
    if (!_isConnected || _bridgeProcess == null) {
      _logError('未连接，无法发送');
      return false;
    }
    
    try {
      final hexStr = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      _log('📤 发送 [${data.length}字节]: $hexStr');
      
      _bridgeProcess!.stdin.add(data);
      await _bridgeProcess!.stdin.flush();
      
      _totalBytesSent += data.length;
      _logSuccess('发送完成');
      return true;
    } catch (e) {
      _logError('发送失败: $e');
      return false;
    }
  }
  
  /// 发送 GTP 命令并等待响应
  Future<Map<String, dynamic>?> sendCommandAndWaitResponse(
    Uint8List payload, {
    int? moduleId,
    int? messageId,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!_isConnected) {
      _logError('未连接，无法发送命令');
      return {'error': 'Not connected'};
    }
    
    _sequenceNumber = (_sequenceNumber + 1) % 65536;
    final seqNum = _sequenceNumber;
    
    final gtpPacket = GTPProtocol.buildGTPPacket(
      payload,
      moduleId: moduleId ?? 0x0006,
      messageId: messageId ?? 0xFF01,
      sequenceNumber: seqNum,
    );
    
    final hexStr = gtpPacket.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('📦 发送 GTP 命令');
    _log('   SN: $seqNum');
    _log('   ModuleID: 0x${(moduleId ?? 0x0006).toRadixString(16).padLeft(4, '0').toUpperCase()}');
    _log('   MessageID: 0x${(messageId ?? 0xFF01).toRadixString(16).padLeft(4, '0').toUpperCase()}');
    _log('   Payload: ${payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}');
    _log('   完整包: $hexStr');
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    final completer = Completer<Map<String, dynamic>?>();
    _pendingResponses[seqNum] = completer;
    
    if (!await sendRawData(gtpPacket)) {
      _pendingResponses.remove(seqNum);
      return {'error': 'Send failed'};
    }
    
    try {
      final response = await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingResponses.remove(seqNum);
          _logError('响应超时 (${timeout.inSeconds}秒)');
          
          if (_gtpBuffer.isNotEmpty) {
            final bufferData = Uint8List.fromList(_gtpBuffer);
            _gtpBuffer.clear();
            _log('⚠️ 超时时缓冲区有 ${bufferData.length} 字节数据');
            return {
              'rawBytes': bufferData,
              'payload': bufferData,
              'timestamp': DateTime.now(),
              'raw': true,
              'warning': '响应超时，返回缓冲区数据',
            };
          }
          
          return {'error': 'Timeout'};
        },
      );
      
      return response;
    } catch (e) {
      _pendingResponses.remove(seqNum);
      _logError('等待响应异常: $e');
      return {'error': e.toString()};
    }
  }
  
  /// 清空缓冲区
  void clearBuffer() {
    _gtpBuffer.clear();
    _fragmentCount = 0;
    _log('🗑️ 缓冲区已清空');
  }
  
  /// 重置统计
  void resetStats() {
    _totalBytesReceived = 0;
    _totalBytesSent = 0;
    _packetCount = 0;
    _fragmentCount = 0;
    _log('📊 统计已重置');
  }
  
  /// 断开连接
  Future<void> disconnect() async {
    _log('🔌 断开连接...');
    
    _stdoutSubscription?.cancel();
    _stdoutSubscription = null;
    
    _stderrSubscription?.cancel();
    _stderrSubscription = null;
    
    // 关闭桥接进程 — 先 SIGTERM 让 Python 正常关闭 socket，避免内核资源泄漏
    if (_bridgeProcess != null) {
      try {
        _bridgeProcess!.stdin.close();  // 关闭 stdin，Python 会检测到并退出
      } catch (e) {
        // 忽略
      }
      
      try {
        _bridgeProcess!.kill(ProcessSignal.sigterm);  // SIGTERM 正常退出
      } catch (_) {}
      
      // 等待进程退出，超时才 SIGKILL
      try {
        await _bridgeProcess!.exitCode.timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            try { _bridgeProcess?.kill(ProcessSignal.sigkill); } catch (_) {}
            return -1;
          },
        );
      } catch (e) {
        try { _bridgeProcess?.kill(ProcessSignal.sigkill); } catch (_) {}
      }
      _bridgeProcess = null;
      // 等待内核释放 RFCOMM 资源
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // 清理待处理的响应
    for (final completer in _pendingResponses.values) {
      if (!completer.isCompleted) {
        completer.complete({'error': 'Disconnected'});
      }
    }
    _pendingResponses.clear();
    
    _gtpBuffer.clear();
    _fragmentCount = 0;
    
    _currentDeviceAddress = null;
    _currentDeviceName = null;
    _currentChannel = null;
    _isConnected = false;
    
    _logSuccess('已断开连接');
  }
  
  /// 释放资源
  void dispose() {
    _isDisposed = true;
    disconnect();
    _dataController.close();
    _logController.close();
  }
}
