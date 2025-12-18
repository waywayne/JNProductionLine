import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'gtp_protocol.dart';
import 'production_test_commands.dart';
import '../models/log_state.dart';

/// Serial communication service for production testing
class SerialService {
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription? _subscription;
  final StreamController<Uint8List> _dataController = StreamController<Uint8List>.broadcast();
  
  String? _currentPortName;
  bool _isConnected = false;
  LogState? _logState;
  
  // 数据包缓冲区
  Uint8List _buffer = Uint8List(0);
  int _packetCount = 0;
  
  // 序列号跟踪
  int _sequenceNumber = 0;
  final Map<int, Completer<Map<String, dynamic>?>> _pendingResponses = {};
  
  void setLogState(LogState logState) {
    _logState = logState;
  }
  
  /// Get available serial ports
  static List<String> getAvailablePorts() {
    return SerialPort.availablePorts;
  }
  
  /// Check if connected
  bool get isConnected => _isConnected;
  
  /// Get current port name
  String? get currentPortName => _currentPortName;
  
  /// Get data stream
  Stream<Uint8List> get dataStream => _dataController.stream;
  
  /// Connect to serial port with dual-line UART initialization
  /// First sends 16 zeros at 9600 baud, then switches to 2000000 baud
  Future<bool> connect(String portName, {
    int baudRate = 2000000, // Default to 2000000 for normal operation
    int dataBits = 8,
    int stopBits = 1,
    int parity = SerialPortParity.none,
    bool useDualLineUartInit = true, // Enable dual-line UART initialization
  }) async {
    try {
      _logState?.info('开始连接串口: $portName');
      // Close existing connection
      await disconnect();
      
      _port = SerialPort(portName);
      _logState?.debug('创建串口对象: $portName');
      
      // 检查串口是否存在
      final availablePorts = SerialPort.availablePorts;
      _logState?.debug('当前可用串口: ${availablePorts.join(", ")}');
      
      if (!availablePorts.contains(portName)) {
        _logState?.warning('警告: 串口 $portName 不在可用列表中');
      }
      
      // Open port FIRST before configuring
      _logState?.debug('正在打开串口...');
      if (!_port!.openReadWrite()) {
        debugPrint('Failed to open port');
        _logState?.error('打开串口失败');
        _logState?.error('可能原因:');
        _logState?.error('  1) 串口被其他程序占用（如 WindTerm）');
        _logState?.error('  2) 权限不足，尝试: sudo chmod 666 $portName');
        _logState?.error('  3) 设备不存在或已断开');
        _logState?.error('  4) 驱动未安装（CH340/CP210x/FTDI）');
        return false;
      }
      _logState?.success('串口打开成功');
      
      // Configure port AFTER opening
      final config = SerialPortConfig();
      config.baudRate = baudRate;
      config.bits = dataBits;
      config.stopBits = stopBits;
      config.parity = parity;
      
      _logState?.debug('配置串口参数: 波特率=$baudRate, 数据位=$dataBits, 停止位=$stopBits');
      
      try {
        _port!.config = config;
        _logState?.debug('串口配置成功');
      } catch (e) {
        _logState?.error('串口配置失败: $e');
        _port!.close();
        return false;
      }
      
      // Dual-line UART initialization
      if (useDualLineUartInit) {
        debugPrint('Starting dual-line UART initialization...');
        _logState?.info('开始双线UART初始化流程');
        
        // Step 1: Set to 9600 baud and send 16 zeros
        _logState?.debug('步骤1: 设置波特率为9600');
        final initConfig = SerialPortConfig();
        initConfig.baudRate = 9600;
        initConfig.bits = dataBits;
        initConfig.stopBits = stopBits;
        initConfig.parity = parity;
        _port!.config = initConfig;
        
        // Send 16 zeros
        final initData = Uint8List(16); // All zeros by default
        int written = _port!.write(initData);
        debugPrint('Sent $written zeros at 9600 baud');
        _logState?.debug('发送16个0字节 (9600波特率): $written bytes');
        
        // Wait for transmission to complete
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Step 2: Switch to high-speed baud rate (2000000)
        final highSpeedConfig = SerialPortConfig();
        highSpeedConfig.baudRate = baudRate;
        highSpeedConfig.bits = dataBits;
        highSpeedConfig.stopBits = stopBits;
        highSpeedConfig.parity = parity;
        _port!.config = highSpeedConfig;
        
        debugPrint('Switched to $baudRate baud for normal operation');
        _logState?.debug('步骤2: 切换到$baudRate波特率');
        
        // Wait for configuration to take effect
        await Future.delayed(const Duration(milliseconds: 50));
        _logState?.success('双线UART初始化完成');
      }
      
      // Start reading
      _logState?.debug('启动串口数据读取');
      _reader = SerialPortReader(_port!);
      _subscription = _reader!.stream.listen(
        (data) {
          final receivedData = Uint8List.fromList(data);
          _dataController.add(receivedData);
          
          // 追加到缓冲区
          _buffer = Uint8List.fromList([..._buffer, ...receivedData]);
          
          // 尝试从缓冲区提取完整的 GTP 包
          _extractCompletePackets();
        },
        onError: (error) {
          debugPrint('Serial read error: $error');
          _logState?.error('串口读取错误: $error');
        },
      );
      
      _currentPortName = portName;
      _isConnected = true;
      debugPrint('Connected to $portName at $baudRate baud');
      _logState?.success('串口连接成功: $portName @ $baudRate baud');
      
      return true;
    } catch (e) {
      debugPrint('Connection error: $e');
      _logState?.error('连接异常: $e');
      return false;
    }
  }
  
  /// Extract complete GTP packets from buffer
  void _extractCompletePackets() {
    while (_buffer.length >= 12) {
      // 查找 GTP 前导码
      int gtpStart = -1;
      for (int i = 0; i <= _buffer.length - 4; i++) {
        if (_buffer[i] == 0xD0 && 
            _buffer[i+1] == 0xD2 && 
            _buffer[i+2] == 0xC5 && 
            _buffer[i+3] == 0xC2) {
          gtpStart = i;
          break;
        }
      }
      
      if (gtpStart == -1) {
        // 没有找到前导码，清空缓冲区
        _buffer = Uint8List(0);
        break;
      }
      
      // 如果前导码不在开头，丢弃前面的数据
      if (gtpStart > 0) {
        _buffer = _buffer.sublist(gtpStart);
        gtpStart = 0;
      }
      
      // 检查是否有足够的数据读取 Length 字段
      if (_buffer.length < 12) {
        // 数据不够，等待更多数据
        break;
      }
      
      // 读取 Length 字段 (位置 5-6, Little Endian)
      final length = ByteData.view(_buffer.buffer).getUint16(5, Endian.little);
      
      // 计算完整包的长度: Preamble(4) + Length字段包含的内容 + CRC32(4)
      final totalLength = 4 + length + 4;
      
      if (_buffer.length < totalLength) {
        // 数据不够，等待更多数据
        break;
      }
      
      // 提取完整的 GTP 包
      final packet = _buffer.sublist(0, totalLength);
      
      // 解析这个完整的包
      _parseCompleteGTPPacket(packet);
      
      // 从缓冲区移除已处理的数据
      _buffer = _buffer.sublist(totalLength);
    }
  }
  
  /// Parse a complete GTP packet
  void _parseCompleteGTPPacket(Uint8List packet) {
    _packetCount++;
    
    try {
      // 解析 GTP Header
      final version = packet[4];
      final length = ByteData.view(packet.buffer).getUint16(5, Endian.little);
      final type = packet[7];
      final fc = packet[8];
      final seq = ByteData.view(packet.buffer).getUint16(9, Endian.little);
      final crc8 = packet[11];
      
      // 处理响应匹配
      bool isResponse = false;
      
      // 只处理 Type 0x02 (设备日志) 和 0x03 (CLI 消息)
      if (type != 0x02 && type != 0x03) {
        return; // 忽略其他类型的数据包
      }
      
      // _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      // _logState?.info('📦 完整 GTP 数据包 #$_packetCount (${packet.length} bytes)');
      // _logState?.info(_formatHexData(packet));
      
      // _logState?.debug('GTP Header:');
      // _logState?.debug('  Preamble: D0 D2 C5 C2');
      // _logState?.debug('  Version: 0x${version.toRadixString(16).padLeft(2, '0').toUpperCase()}');
      // _logState?.debug('  Length: $length');
      // _logState?.debug('  Type: 0x${type.toRadixString(16).padLeft(2, '0').toUpperCase()}');
      // _logState?.debug('  FC: 0x${fc.toRadixString(16).padLeft(2, '0').toUpperCase()}');
      // _logState?.debug('  Seq: $seq');
      // _logState?.debug('  CRC8: 0x${crc8.toRadixString(16).padLeft(2, '0').toUpperCase()}');
      
      // 解析日志消息（Type 0x02）
      if (type == 0x02 && packet.length >= 12 + 10) {
        _parseDebugLog(packet.sublist(12));
      }
      // 解析 CLI 消息（如果存在且 Type 是 CLI）
      else if (type == 0x03 && packet.length >= 12 + 2) {
        final cliStart = packet.sublist(12); // CLI 从位置 12 开始
        
        // 如果勾选了显示原始 hex 数据，直接打印完整的 hex 数据
        if (_logState?.showRawHex ?? false) {
          _logState?.debug('Type 0x03 完整数据包 (HEX):', type: LogType.debug);
          _logState?.debug(_formatHexData(packet), type: LogType.debug);
        }
        
        if (cliStart.length >= 2 && cliStart[0] == 0x23 && cliStart[1] == 0x23) {
          if (cliStart.length >= 14) {
                      final moduleId = ByteData.view(cliStart.buffer, cliStart.offsetInBytes).getUint16(2, Endian.little);
                      final crc16 = ByteData.view(cliStart.buffer, cliStart.offsetInBytes).getUint16(4, Endian.little);
                      final messageId = ByteData.view(cliStart.buffer, cliStart.offsetInBytes).getUint16(6, Endian.little);
                      final flags = cliStart[8];
                      final result = cliStart[9];
                      final payloadLength = ByteData.view(cliStart.buffer, cliStart.offsetInBytes).getUint16(10, Endian.little);
                      final sn = ByteData.view(cliStart.buffer, cliStart.offsetInBytes).getUint16(12, Endian.little);
                      
                      // 检查是否是响应
                      final isAckResponse = (flags & 0x80) != 0;
                      final isTypeResponse = (flags & 0x0E) == 0x02;
                      final hasPendingRequest = _pendingResponses.containsKey(sn);
                      
                      // 先提取 payload 数据
                      Uint8List? payload;
                      if (cliStart.length >= 14 + payloadLength) {
                        if (payloadLength > 0) {
                          payload = cliStart.sublist(14, 14 + payloadLength);
                          // 显示Payload长度和内容
                          final payloadHex = payload.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
                          _logState?.debug('   Len: $payloadLength, Data: [$payloadHex]', type: LogType.debug);
                          
                          // 尝试解析 Payload 内容
                          _parsePayload(moduleId, messageId, payload, result);
                        }
                      }
                      
                      if (isAckResponse || isTypeResponse || hasPendingRequest) {
                        isResponse = true;
                        
                        // 尝试匹配待处理的响应
                        if (_pendingResponses.containsKey(sn)) {
                          final completer = _pendingResponses.remove(sn);
                          if (completer != null && !completer.isCompleted) {
                            // 简化日志：只显示SN匹配
                            _logState?.success('✅ SN: $sn', type: LogType.debug);
                            completer.complete({
                              'moduleId': moduleId,
                              'messageId': messageId,
                              'sn': sn,
                              'result': result,
                              'payloadLength': payloadLength,
                              'payload': payload,  // 包含payload
                            });
                          } else {
                            _logState?.warning('⚠️  Completer 已完成或为空 (SN: $sn)', type: LogType.debug);
                          }
                        } else {
                          _logState?.warning('⚠️  未找到匹配的等待序列号 (SN: $sn)', type: LogType.debug);
                        }
                      }
                    }
                  }
                }
                
      
      // 解析 GTP CRC32（在数据包末尾）
      // 简化日志，不显示CRC32
      // if (packet.length >= 4 + length + 4) {
      //   final crc32Offset = 4 + length;
      //   final crc32 = ByteData.view(packet.buffer).getUint32(crc32Offset, Endian.little);
      //   _logState?.debug('GTP CRC32: 0x${crc32.toRadixString(16).padLeft(8, '0').toUpperCase()}');
      // }
    } catch (e) {
      _logState?.debug('解析 GTP/CLI 数据时出错: $e');
    }
  }
  
  /// Send exit sleep mode command multiple times
  /// 发送退出休眠命令（可能需要多次发送）
  Future<bool> sendExitSleepMode({int retries = 3}) async {
    if (!_isConnected) {
      _logState?.error('串口未连接，无法发送退出休眠命令');
      return false;
    }
    
    _logState?.info('发送退出休眠命令 (尝试 $retries 次)');
    
    // 使用示例中的参数: deep=0, light=0xFFFFFFFF, core=0xFF
    final exitSleepCommand = ProductionTestCommands.createExitSleepModeCommand();
    
    bool success = false;
    for (int i = 0; i < retries; i++) {
      _logState?.debug('第 ${i + 1}/$retries 次发送退出休眠命令');
      
      try {
        // 使用退出休眠的 module ID 和 message ID
        final response = await sendCommandAndWaitResponse(
          exitSleepCommand,
          moduleId: ProductionTestCommands.exitSleepModuleId,
          messageId: ProductionTestCommands.exitSleepMessageId,
          timeout: const Duration(seconds: 2),
        );
        
        if (response != null && !response.containsKey('error')) {
          _logState?.success('退出休眠命令响应成功 (第 ${i + 1} 次)');
          success = true;
          break;
        } else {
          _logState?.warning('第 ${i + 1} 次未收到有效响应，继续尝试...');
        }
      } catch (e) {
        _logState?.debug('第 ${i + 1} 次发送失败: $e');
      }
      
      // 等待一小段时间再重试
      if (i < retries - 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    
    if (success) {
      _logState?.success('设备已退出休眠模式');
    } else {
      _logState?.warning('退出休眠命令未收到响应，但继续尝试通信');
    }
    
    return success;
  }
  
  /// Disconnect from serial port
  Future<void> disconnect() async {
    try {
      await _subscription?.cancel();
      _subscription = null;
      
      _reader?.close();
      _reader = null;
      
      _port?.close();
      _port?.dispose();
      _port = null;
      
      _currentPortName = null;
      _isConnected = false;
      
      debugPrint('Disconnected from serial port');
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
  }
  
  /// Parse debug log message (Type 0x02)
  void _parseDebugLog(Uint8List logData) {
    try {
      if (logData.length < 10) {
        _logState?.warning('日志数据长度不足');
        return;
      }
      
      final buffer = ByteData.view(logData.buffer, logData.offsetInBytes);
      
      // 解析 wq_dbglog_common_header (8 bytes)
      final timestamp = buffer.getUint32(0, Endian.little);
      final coreIdAndSeq = buffer.getUint16(4, Endian.little);
      final coreId = coreIdAndSeq & 0x03; // 低 2 bits
      final sequenceNum = (coreIdAndSeq >> 2) & 0x3FF; // 中间 10 bits
      final version = (coreIdAndSeq >> 12) & 0x0F; // 高 4 bits
      final payloadLength = buffer.getUint16(6, Endian.little);
      
      // 解析 wq_dbglog_raw_log_header (2 bytes)
      if (logData.length < 10) {
        _logState?.warning('日志头部数据不足');
        return;
      }
      
      final levelAndReserved = logData[8];
      final level = levelAndReserved & 0x07; // 低 3 bits
      final moduleId = logData[9];
      
      // 日志级别映射 (根据 DBGLOG_LEVEL 枚举)
      final levelNames = ['ALL', 'VERBOSE', 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL', 'NONE'];
      final levelName = level < levelNames.length ? levelNames[level] : 'UNKNOWN';
      
      // 日志级别 Emoji
      final levelEmoji = ['🌐', '🔍', '🐛', 'ℹ️', '⚠️', '❌', '💀', '⭕'];
      final emoji = level < levelEmoji.length ? levelEmoji[level] : '❓';
      
      // 提取日志内容 (从位置 10 开始)
      String logContent = '';
      if (logData.length > 10 && payloadLength > 0) {
        final contentLength = payloadLength < (logData.length - 10) ? payloadLength : (logData.length - 10);
        final contentBytes = logData.sublist(10, 10 + contentLength);
        
        // 尝试解析为 UTF-8 字符串
        try {
          // 移除末尾的 null 字符
          final validBytes = contentBytes.takeWhile((b) => b != 0).toList();
          // 使用 utf8.decode 正确解析 UTF-8 编码（包括中文）
          logContent = utf8.decode(validBytes, allowMalformed: true);
        } catch (e) {
          // 如果不是有效的文本，显示十六进制
          logContent = contentBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        }
      }
      
      // 格式化输出
      // _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      // _logState?.info('$emoji 设备日志 [$levelName]');
      // _logState?.debug('  Timestamp: $timestamp (RTC cycles)');
      // _logState?.debug('  Core ID: $coreId');
      // _logState?.debug('  Sequence: $sequenceNum');
      // _logState?.debug('  Version: $version');
      // _logState?.debug('  Module ID: $moduleId');
      // _logState?.debug('  Payload Length: $payloadLength');
      
      if (logContent.isNotEmpty) {
        // 根据日志级别使用不同的输出方法，标记为设备日志 (Type 0x02)
        switch (level) {
          case 0: // ALL
          case 1: // VERBOSE
          case 2: // DEBUG
            _logState?.debug('$emoji $logContent', type: LogType.device);
            break;
          case 3: // INFO
            _logState?.info('$emoji $logContent', type: LogType.device);
            break;
          case 4: // WARNING
            _logState?.warning('$emoji $logContent', type: LogType.device);
            break;
          case 5: // ERROR
          case 6: // CRITICAL
            _logState?.error('$emoji $logContent', type: LogType.device);
            break;
          case 7: // NONE
            _logState?.info('$emoji $logContent', type: LogType.device);
            break;
          default:
            _logState?.info('$emoji $logContent', type: LogType.device);
        }
      }
    } catch (e) {
      _logState?.error('解析日志消息时出错: $e');
    }
  }
  
  /// Parse CLI Payload based on Module ID and Message ID
  void _parsePayload(int moduleId, int messageId, Uint8List payload, int result) {
    try {
      // 检查是否是日志消息 (通常 Module ID 可能是特定值，这里需要根据实际协议确定)
      // 尝试将 payload 解析为 UTF-8 字符串
      if (_isLikelyTextData(payload)) {
        try {
          // 移除末尾的 null 字符
          final validBytes = payload.takeWhile((b) => b != 0).toList();
          // 使用 utf8.decode 正确解析 UTF-8 编码（包括中文）
          final text = utf8.decode(validBytes, allowMalformed: true);
          if (text.isNotEmpty) {
            _logState?.info('📝 Payload 内容: $text', type: LogType.debug);
          }
        } catch (e) {
          // 不是有效的文本
        }
      }
      
      // 根据 Module ID 和 Message ID 解析特定命令，标记为调试信息 (Type 0x03)
      if (moduleId == 5 && messageId == 4) {
        // Exit Sleep Mode 响应
        _logState?.success('✓ 退出休眠模式响应 (Result: $result)', type: LogType.debug);
        if (result == 0) {
          _logState?.success('  设备已成功退出休眠模式', type: LogType.debug);
        } else {
          _logState?.warning('  退出休眠失败，错误码: $result', type: LogType.debug);
        }
      } else if (moduleId == 6 && messageId == 0) {
        // Reboot 响应
        _logState?.success('✓ 重启命令响应 (Result: $result)', type: LogType.debug);
      } else {
        // 其他命令
        _logState?.info('📦 Module $moduleId, Message $messageId (Result: $result)', type: LogType.debug);
      }
      
      // 尝试解析常见的数据结构
      if (payload.length >= 4) {
        final buffer = ByteData.view(payload.buffer, payload.offsetInBytes);
        
        // 检查是否包含时间戳 (通常是 uint32 或 uint64)
        if (payload.length >= 8) {
          final timestamp = buffer.getUint64(0, Endian.little);
          if (timestamp > 1000000000 && timestamp < 9999999999999) {
            final date = DateTime.fromMillisecondsSinceEpoch((timestamp ~/ 1000).toInt());
            _logState?.debug('  可能的时间戳: $date', type: LogType.debug);
          }
        }
      }
    } catch (e) {
      _logState?.debug('  Payload 解析出错: $e', type: LogType.debug);
    }
  }
  
  /// Check if data is likely text (contains mostly printable ASCII)
  bool _isLikelyTextData(Uint8List data) {
    if (data.isEmpty) return false;
    
    int printableCount = 0;
    for (var byte in data) {
      // Printable ASCII (space to ~) or newline/carriage return
      if ((byte >= 0x20 && byte <= 0x7E) || byte == 0x0A || byte == 0x0D || byte == 0x00) {
        printableCount++;
      }
    }
    
    // If more than 70% are printable, consider it text
    return printableCount > data.length * 0.7;
  }

  /// Format data as hex string for logging
  String _formatHexData(Uint8List data, {int bytesPerLine = 16}) {
    // 如果数据较短（小于等于32字节），在一行显示
    if (data.length <= 32) {
      return data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    }
    
    // 数据较长时，分行显示
    final buffer = StringBuffer();
    for (int i = 0; i < data.length; i += bytesPerLine) {
      final end = (i + bytesPerLine < data.length) ? i + bytesPerLine : data.length;
      final chunk = data.sublist(i, end);
      final hex = chunk.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      if (i > 0) buffer.write('\n');
      buffer.write('  ${i.toString().padLeft(4, '0')}: $hex');
    }
    return buffer.toString();
  }

  /// Send raw data
  Future<bool> sendData(Uint8List data) async {
    if (!_isConnected || _port == null) {
      debugPrint('Not connected to serial port');
      _logState?.error('未连接到串口，无法发送数据');
      return false;
    }
    
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('发送数据 (${data.length} bytes)');
      
      // 如果勾选了显示原始 hex 数据，则打印完整的 hex 数据
      if (_logState?.showRawHex ?? false) {
        _logState?.debug('完整数据包 (HEX):');
        _logState?.debug(_formatHexData(data));
      }
      
      int bytesWritten = _port!.write(data);
      debugPrint('Sent $bytesWritten bytes');
      _logState?.success('成功发送 $bytesWritten bytes');
      return bytesWritten == data.length;
    } catch (e) {
      debugPrint('Send error: $e');
      _logState?.error('发送数据失败: $e');
      return false;
    }
  }
  
  /// Send GTP command with CLI payload
  Future<bool> sendGTPCommand(Uint8List cliPayload, {int? moduleId, int? messageId, int? sequenceNumber}) async {
    Uint8List gtpPacket = GTPProtocol.buildGTPPacket(cliPayload, moduleId: moduleId, messageId: messageId, sequenceNumber: sequenceNumber);
    
    _logState?.info('📤 发送 GTP 命令', type: LogType.debug);
    
    // 如果勾选了显示原始 hex 数据，则打印完整的 GTP 数据包
    if (_logState?.showRawHex ?? false) {
      _logState?.debug('完整 GTP 数据包 (${gtpPacket.length} bytes):', type: LogType.debug);
      _logState?.debug(_formatHexData(gtpPacket), type: LogType.debug);
    } else {
      // 否则只显示 CLI Payload
      _logState?.debug('CLI Payload (${cliPayload.length} bytes):', type: LogType.debug);
      _logState?.debug(_formatHexData(cliPayload), type: LogType.debug);
    }
    
    // 解析 GTP 头部信息
    if (gtpPacket.length >= 16) {
      final preamble = gtpPacket.sublist(0, 4);
      final version = gtpPacket[4];
      final length = ByteData.view(gtpPacket.buffer).getUint16(5, Endian.little);
      final type = gtpPacket[7];
      final fc = gtpPacket[8];
      final seq = ByteData.view(gtpPacket.buffer).getUint16(9, Endian.little);
      final crc8 = gtpPacket[11];
      
      _logState?.debug('GTP Header:', type: LogType.debug);
      _logState?.debug('  Preamble: ${preamble.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}', type: LogType.debug);
      _logState?.debug('  Version: 0x${version.toRadixString(16).padLeft(2, '0').toUpperCase()}', type: LogType.debug);
      _logState?.debug('  Length: $length', type: LogType.debug);
      _logState?.debug('  Type: 0x${type.toRadixString(16).padLeft(2, '0').toUpperCase()}', type: LogType.debug);
      _logState?.debug('  FC: 0x${fc.toRadixString(16).padLeft(2, '0').toUpperCase()}', type: LogType.debug);
      _logState?.debug('  Seq: $seq', type: LogType.debug);
      _logState?.debug('  CRC8: 0x${crc8.toRadixString(16).padLeft(2, '0').toUpperCase()}', type: LogType.debug);
    }
    
    // 解析 CLI 消息信息
    if (moduleId != null && messageId != null) {
      _logState?.debug('CLI Message:', type: LogType.debug);
      _logState?.debug('  Module ID: 0x${moduleId.toRadixString(16).padLeft(4, '0').toUpperCase()}', type: LogType.debug);
      _logState?.debug('  Message ID: 0x${messageId.toRadixString(16).padLeft(4, '0').toUpperCase()}', type: LogType.debug);
    }
    
    debugPrint('Sending GTP packet: ${gtpPacket.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    
    return await sendData(gtpPacket);
  }
  
  /// Send production test command
  Future<bool> sendProductionTestCommand(Uint8List command, {int? moduleId, int? messageId, int? sequenceNumber}) async {
    return await sendGTPCommand(command, moduleId: moduleId, messageId: messageId, sequenceNumber: sequenceNumber);
  }
  
  /// Send command and wait for response
  Future<Map<String, dynamic>?> sendCommandAndWaitResponse(
    Uint8List command, {
    Duration timeout = const Duration(seconds: 5),
    int? moduleId,
    int? messageId,
  }) async {
    // 生成序列号
    final sn = _sequenceNumber++;
    if (_sequenceNumber > 0xFFFF) {
      _sequenceNumber = 0; // 循环使用
    }
    
    // 创建 completer 等待响应（在发送之前注册，避免竞态条件）
    final completer = Completer<Map<String, dynamic>?>();
    _pendingResponses[sn] = completer;
    
    // 记录命令发送
    _logState?.debug('📤 发送命令 (SN: $sn, Module: ${moduleId ?? "N/A"}, Message: ${messageId ?? "N/A"})', type: LogType.debug);
    _logState?.debug('   命令长度: ${command.length} bytes', type: LogType.debug);
    _logState?.debug('   已注册等待序列号: $sn', type: LogType.debug);
    
    // 设置超时
    Timer? timer;
    timer = Timer(timeout, () {
      if (_pendingResponses.containsKey(sn)) {
        final c = _pendingResponses.remove(sn);
        if (c != null && !c.isCompleted) {
          _logState?.warning('⏱️  等待响应超时 (SN: $sn, ${timeout.inSeconds}秒)', type: LogType.debug);
          c.complete(null);
        }
      }
    });
    
    // 发送命令
    bool sent = await sendProductionTestCommand(command, moduleId: moduleId, messageId: messageId, sequenceNumber: sn);
    if (!sent) {
      timer.cancel();
      _pendingResponses.remove(sn);
      _logState?.error('❌ 命令发送失败', type: LogType.debug);
      return {'error': 'Failed to send command'};
    }
    
    _logState?.debug('✅ 命令已发送 (SN: $sn)，等待响应...', type: LogType.debug);
    
    // 等待响应
    final response = await completer.future;
    timer.cancel();
    
    if (response == null) {
      // 已经在超时处理中记录了
    } else if (response.containsKey('error')) {
      _logState?.error('❌ 响应错误: ${response['error']}', type: LogType.debug);
    } else {
      _logState?.success('📥 收到响应 (SN: $sn)', type: LogType.debug);
    }
    
    return response;
  }
  
  /// Connect without dual-line UART initialization (for testing)
  Future<bool> connectSimple(String portName, {
    int baudRate = 115200,
    int dataBits = 8,
    int stopBits = 1,
    int parity = SerialPortParity.none,
  }) async {
    return await connect(
      portName,
      baudRate: baudRate,
      dataBits: dataBits,
      stopBits: stopBits,
      parity: parity,
      useDualLineUartInit: false,
    );
  }
  
  /// Dispose resources
  void dispose() {
    disconnect();
    _dataController.close();
  }
}
