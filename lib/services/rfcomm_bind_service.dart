import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/log_state.dart';
import 'gtp_protocol.dart';

/// 方案二: rfcomm bind + Python 桥接
/// 使用 rfcomm bind 创建 /dev/rfcomm0，然后通过 Python 桥接访问
/// 适用于需要设备文件方式的场景
class RfcommBindService {
  Process? _bridgeProcess;
  StreamSubscription<List<int>>? _readSubscription;

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

  void setLogState(LogState? logState) {
    _logState = logState;
  }

  bool get isConnected => _isConnected;
  String? get currentDeviceAddress => _currentDeviceAddress;
  String? get currentDeviceName => _currentDeviceName;
  int? get currentChannel => _currentChannel;
  Stream<Uint8List> get dataStream => _dataController.stream;
  Stream<String> get logStream => _logController.stream;
  int get bufferSize => _gtpBuffer.length;
  int get fragmentCount => _fragmentCount;
  int get packetCount => _packetCount;
  int get totalBytesReceived => _totalBytesReceived;
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

  /// 获取 Python 脚本路径
  String _getScriptPath() {
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$executableDir/scripts/rfcomm_spp_bridge.py',
      '${Directory.current.path}/scripts/rfcomm_spp_bridge.py',
      '/opt/jn-production-line/scripts/rfcomm_spp_bridge.py',
      '${Platform.environment['HOME']}/git/JNProductionLine/scripts/rfcomm_spp_bridge.py',
    ];
    
    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    
    return '${Directory.current.path}/scripts/rfcomm_spp_bridge.py';
  }

  /// 连接设备（与超声前整机产测完全一致）
  Future<bool> connect(String macAddress, {String? deviceName, int channel = 5}) async {
    if (_isConnected) {
      _log('⚠️ 已连接，先断开...');
      await disconnect();
    }

    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('🔗 开始连接 (rfcomm bind 模式)');
    _log('   MAC: $macAddress');
    _log('   Channel: $channel');
    if (deviceName != null) {
      _log('   Name: $deviceName');
    }
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      // 1. 清理旧连接
      _log('🧹 清理旧的 RFCOMM 连接...');
      try {
        await Process.run('pkill', ['-9', '-f', 'rfcomm_spp_bridge.py']);
      } catch (_) {}
      try {
        await Process.run('sudo', ['rfcomm', 'release', 'all']);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));

      // 2. 查找 Python 脚本
      final scriptPath = _getScriptPath();
      _log('📜 脚本: $scriptPath');

      if (!File(scriptPath).existsSync()) {
        _logError('脚本文件不存在: $scriptPath');
        return false;
      }

      // 3. 启动 Python rfcomm connect 桥接进程
      _log('🚀 启动 rfcomm connect 桥接...');
      final process = await Process.start(
        'python3',
        ['-u', scriptPath, macAddress, channel.toString()],
        environment: {'PYTHONUNBUFFERED': '1'},
      );

      _bridgeProcess = process;

      // 4. 监听 stderr（Python 日志 + 连接状态检测）
      bool connectionReady = false;
      process.stderr.transform(const SystemEncoding().decoder).listen((msg) {
        for (final line in msg.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            _log('[Python] $trimmed');
            if (trimmed.contains('连接已建立') || trimmed.contains('开始数据传输')) {
              connectionReady = true;
            }
          }
        }
      });

      // 5. 监听 stdout（数据流）
      _readSubscription = process.stdout.listen(
        (data) {
          if (data.isNotEmpty) {
            final bytes = Uint8List.fromList(data);
            _onDataReceived(bytes);
          }
        },
        onError: (error) {
          _logError('数据接收错误: $error');
          if (_isConnected) disconnect();
        },
        onDone: () {
          _log('⚠️ Python 桥接数据流结束');
          if (_isConnected) disconnect();
        },
      );

      // 6. 监听进程退出
      bool processExited = false;
      process.exitCode.then((code) {
        _log('⚠️ rfcomm_spp_bridge.py 进程退出 (退出码: $code)');
        processExited = true;
        if (_isConnected) disconnect();
      });

      // 7. 等待连接建立（最多 90 秒）
      _log('⏳ 等待连接建立...');
      for (int i = 0; i < 180; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (connectionReady) break;
        if (processExited) {
          _logError('桥接进程已退出，连接失败');
          _bridgeProcess = null;
          return false;
        }
      }

      if (!connectionReady && !processExited) {
        _logError('连接超时');
        await disconnect();
        return false;
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
      _sequenceNumber = 0;
      _gtpBuffer.clear();
      _packetCount = 0;
      _fragmentCount = 0;
      _pendingResponses.clear();

      _logSuccess('连接成功 (rfcomm bind 模式)');
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

    if (!_isDisposed && !_dataController.isClosed) {
      _dataController.add(data);
    }

    _gtpBuffer.addAll(data);
    _processGtpBuffer();
  }

  /// 处理 GTP 缓冲区
  void _processGtpBuffer() {
    while (_gtpBuffer.length >= 4) {
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

  /// 发送原始数据（通过 Python 桥接进程的 stdin）
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

  void clearBuffer() {
    _gtpBuffer.clear();
    _fragmentCount = 0;
    _log('🗑️ 缓冲区已清空');
  }

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

    _readSubscription?.cancel();
    _readSubscription = null;

    // 关闭 Python 桥接进程
    if (_bridgeProcess != null) {
      try {
        _bridgeProcess!.stdin.close();
      } catch (_) {}
      try {
        _bridgeProcess!.kill(ProcessSignal.sigterm);
        await _bridgeProcess!.exitCode.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            _bridgeProcess?.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
      } catch (_) {}
      _bridgeProcess = null;
    }

    // 清理待处理的响应
    for (final completer in _pendingResponses.values) {
      if (!completer.isCompleted) {
        completer.complete({'error': 'Disconnected'});
      }
    }
    _pendingResponses.clear();

    _currentDeviceAddress = null;
    _currentDeviceName = null;
    _currentChannel = null;
    _isConnected = false;

    _logSuccess('已断开连接');
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _dataController.close();
    _logController.close();
  }
}
