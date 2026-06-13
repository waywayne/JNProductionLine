import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';

/// 治具串口通信服务
/// 通信格式: N81, 115200 baud
/// 指令格式: <COMMAND>\r\n
/// 成功响应: <COMMAND>_OK\r\n
/// 失败响应: XXX_ERROR\r\n 或 CMD_ERROR\r\n
class JigSerialService {
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<List<int>>? _subscription;
  bool _isConnected = false;
  String? _portName;

  final StringBuffer _buffer = StringBuffer();
  final StreamController<String> _lineController = StreamController<String>.broadcast();

  bool get isConnected => _isConnected;
  String? get portName => _portName;

  static List<String> getAvailablePorts() => SerialPort.availablePorts;

  /// 连接到指定串口
  Future<bool> connect(String portName) async {
    if (_isConnected) {
      await disconnect();
    }

    try {
      _port = SerialPort(portName);

      if (!_port!.openReadWrite()) {
        print('❌ 治具串口打开失败: $portName');
        _port!.dispose();
        _port = null;
        return false;
      }

      final config = SerialPortConfig();
      config.baudRate = 115200;
      config.bits = 8;
      config.parity = SerialPortParity.none;
      config.stopBits = 1;
      config.setFlowControl(SerialPortFlowControl.none);
      _port!.config = config;
      config.dispose();

      _reader = SerialPortReader(_port!);
      _subscription = _reader!.stream.listen(
        _onData,
        onError: (e) => print('❌ 治具串口读取错误: $e'),
        onDone: () {
          print('ℹ️  治具串口读取流结束');
          _isConnected = false;
        },
      );

      _isConnected = true;
      _portName = portName;
      print('✅ 治具串口已连接: $portName (115200 N81)');
      return true;
    } catch (e) {
      print('❌ 治具串口连接异常: $e');
      _port?.dispose();
      _port = null;
      return false;
    }
  }

  void _onData(List<int> data) {
    final text = latin1.decode(data);
    _buffer.write(text);
    final raw = _buffer.toString();
    final lines = raw.split('\r\n');
    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) {
        print('📥 治具响应: $line');
        _lineController.add(line);
      }
    }
    _buffer.clear();
    _buffer.write(lines.last);
  }

  /// 发送指令并等待响应
  /// 返回 true 表示收到 <COMMAND>_OK，false 表示收到错误或超时
  Future<bool> sendCommand(String command, {Duration timeout = const Duration(seconds: 10)}) async {
    if (!_isConnected || _port == null) {
      print('❌ 治具串口未连接，无法发送指令: $command');
      return false;
    }

    final upperCommand = command.toUpperCase();
    final expectedOk = '${upperCommand}_OK';
    final bytes = utf8.encode('$command\r\n');

    print('📤 发送治具指令: $command');

    final completer = Completer<bool>();
    late StreamSubscription<String> responseSub;
    responseSub = _lineController.stream.listen((line) {
      final upper = line.toUpperCase().trim();
      if (upper == expectedOk) {
        print('✅ 治具指令成功: $command → $line');
        if (!completer.isCompleted) completer.complete(true);
      } else if (upper.endsWith('_ERROR') || upper == 'CMD_ERROR') {
        print('❌ 治具指令失败: $command → $line');
        if (!completer.isCompleted) completer.complete(false);
      } else {
        print('⚠️  治具未知响应，继续等待: $line');
      }
    });

    try {
      _port!.write(Uint8List.fromList(bytes));
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          print('⏱️  治具指令超时: $command (${timeout.inSeconds}s)');
          return false;
        },
      );
    } catch (e) {
      print('❌ 治具指令写入/等待异常: $e');
      return false;
    } finally {
      await responseSub.cancel();
    }
  }

  /// 断开串口连接
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    _reader?.close();
    _reader = null;
    try {
      _port?.close();
    } catch (_) {}
    _port?.dispose();
    _port = null;
    _isConnected = false;
    _buffer.clear();
    print('ℹ️  治具串口已断开');
  }

  void dispose() {
    disconnect();
    _lineController.close();
  }
}
