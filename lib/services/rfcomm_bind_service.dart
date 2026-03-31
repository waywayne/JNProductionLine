import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../models/log_state.dart';
import 'gtp_protocol.dart';

/// 方案二: rfcomm bind + 直接 Dart 读写 /dev/rfcomm0
/// 不依赖 Python 脚本，使用系统 rfcomm bind 建立连接
/// 然后 Dart 直接读写设备文件进行数据收发
class RfcommBindService {
  RandomAccessFile? _deviceFile;
  StreamSubscription<List<int>>? _readSubscription;
  Timer? _readTimer;

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

  // 设备文件路径
  static const String _devicePath = '/dev/rfcomm0';

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

  /// 连接设备
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
      // 1. 释放旧的 rfcomm0 绑定
      _log('🧹 释放旧的 rfcomm 绑定...');
      try {
        await Process.run('sudo', ['rfcomm', 'release', '0']);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));

      // 2. 执行 rfcomm bind
      _log('📎 执行: sudo rfcomm bind 0 $macAddress $channel');
      final bindResult = await Process.run(
        'sudo',
        ['rfcomm', 'bind', '0', macAddress, channel.toString()],
      );

      if (bindResult.exitCode != 0) {
        final stderr = bindResult.stderr.toString().trim();
        _logError('rfcomm bind 失败 (退出码: ${bindResult.exitCode}): $stderr');
        return false;
      }

      _log('📎 rfcomm bind 成功');

      // 3. 等待设备文件就绪
      _log('⏳ 等待设备文件 $_devicePath ...');
      bool deviceReady = false;
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await File(_devicePath).exists()) {
          deviceReady = true;
          break;
        }
      }

      if (!deviceReady) {
        _logError('设备文件 $_devicePath 未创建（超时 10s）');
        try {
          await Process.run('sudo', ['rfcomm', 'release', '0']);
        } catch (_) {}
        return false;
      }

      _log('📁 设备文件已就绪: $_devicePath');

      // 4. 打开设备文件进行读写
      _log('📂 打开设备文件...');
      try {
        _deviceFile = await File(_devicePath).open(mode: FileMode.writeOnlyAppend);
      } catch (e) {
        _logError('打开设备文件失败: $e');
        try {
          await Process.run('sudo', ['rfcomm', 'release', '0']);
        } catch (_) {}
        return false;
      }

      // 5. 启动读取循环（使用 Process cat 读取设备文件）
      _log('📖 启动数据读取...');
      _startReadLoop();

      _currentDeviceAddress = macAddress;
      _currentDeviceName = deviceName;
      _currentChannel = channel;
      _isConnected = true;

      _logSuccess('连接成功 (rfcomm bind 模式)');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return true;
    } catch (e) {
      _logError('连接失败: $e');
      await disconnect();
      return false;
    }
  }

  Process? _catProcess;

  /// 启动读取循环 — 使用 cat /dev/rfcomm0 读取数据
  void _startReadLoop() {
    // 使用 cat 命令持续读取设备文件
    Process.start('cat', [_devicePath]).then((process) {
      _catProcess = process;

      // 监听 stdout 获取蓝牙数据
      _readSubscription = process.stdout.listen(
        (data) {
          final bytes = Uint8List.fromList(data);
          _onDataReceived(bytes);
        },
        onError: (error) {
          _logError('读取错误: $error');
          if (_isConnected) {
            _isConnected = false;
            _log('⚠️ 连接已断开 (读取错误)');
          }
        },
        onDone: () {
          _log('📖 读取流结束');
          if (_isConnected) {
            _isConnected = false;
            _log('⚠️ 连接已断开 (流结束)');
          }
        },
      );

      // 监听 stderr
      process.stderr.transform(const SystemEncoding().decoder).listen((line) {
        _log('🔸 [cat stderr] $line');
      });

      // 监听进程退出
      process.exitCode.then((code) {
        _log('📖 cat 进程退出 (退出码: $code)');
        _catProcess = null;
        if (_isConnected) {
          _isConnected = false;
        }
      });
    }).catchError((e) {
      _logError('启动 cat 进程失败: $e');
    });
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

  /// 发送原始数据
  Future<bool> sendRawData(Uint8List data) async {
    if (!_isConnected || _deviceFile == null) {
      _logError('未连接，无法发送');
      return false;
    }

    try {
      final hexStr = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      _log('📤 发送 [${data.length}字节]: $hexStr');

      _deviceFile!.writeFromSync(data);
      _deviceFile!.flushSync();

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

    _readTimer?.cancel();
    _readTimer = null;

    // 关闭设备文件
    if (_deviceFile != null) {
      try {
        _deviceFile!.closeSync();
      } catch (_) {}
      _deviceFile = null;
    }

    // 关闭 cat 进程
    if (_catProcess != null) {
      try {
        _catProcess!.kill(ProcessSignal.sigterm);
        await _catProcess!.exitCode.timeout(const Duration(seconds: 2), onTimeout: () {
          _catProcess?.kill(ProcessSignal.sigkill);
          return -1;
        });
      } catch (_) {}
      _catProcess = null;
    }

    // 释放 rfcomm 绑定
    try {
      await Process.run('sudo', ['rfcomm', 'release', '0']);
      _log('📎 rfcomm 绑定已释放');
    } catch (_) {}

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
