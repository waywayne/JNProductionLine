import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'gtp_protocol.dart';
import 'production_test_commands.dart';
import '../models/log_state.dart';

/// 蓝牙 COM 口通讯服务
/// 专门用于通过蓝牙虚拟 COM 口与设备通讯
/// 基于 SerialService，但针对蓝牙 COM 口进行了优化
class BluetoothComService {
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
  
  /// 设置日志状态
  void setLogState(LogState logState) {
    _logState = logState;
  }
  
  /// 获取所有可用的串口（包括蓝牙 COM 口）
  static List<String> getAvailablePorts() {
    return SerialPort.availablePorts;
  }
  
  /// 查找蓝牙 COM 口
  /// 返回所有可能是蓝牙的 COM 口列表
  static List<String> findBluetoothComPorts() {
    final allPorts = SerialPort.availablePorts;
    final bluetoothPorts = <String>[];
    
    for (final portName in allPorts) {
      try {
        final port = SerialPort(portName);
        final description = port.description ?? '';
        final manufacturer = port.manufacturer ?? '';
        
        // 检查是否是蓝牙相关的端口
        if (description.toLowerCase().contains('bluetooth') ||
            description.toLowerCase().contains('蓝牙') ||
            manufacturer.toLowerCase().contains('bluetooth')) {
          bluetoothPorts.add(portName);
        }
        
        port.dispose();
      } catch (e) {
        // 忽略错误，继续检查下一个端口
      }
    }
    
    return bluetoothPorts;
  }
  
  /// 获取端口详细信息
  static Map<String, String> getPortInfo(String portName) {
    try {
      final port = SerialPort(portName);
      final info = {
        'name': portName,
        'description': port.description ?? 'Unknown',
        'manufacturer': port.manufacturer ?? 'Unknown',
        'serialNumber': port.serialNumber ?? 'Unknown',
        'productId': port.productId?.toString() ?? 'Unknown',
        'vendorId': port.vendorId?.toString() ?? 'Unknown',
      };
      port.dispose();
      return info;
    } catch (e) {
      return {
        'name': portName,
        'description': 'Error: $e',
        'manufacturer': 'Unknown',
        'serialNumber': 'Unknown',
        'productId': 'Unknown',
        'vendorId': 'Unknown',
      };
    }
  }
  
  /// 检查是否已连接
  bool get isConnected => _isConnected;
  
  /// 获取当前端口名称
  String? get currentPortName => _currentPortName;
  
  /// 获取数据流
  Stream<Uint8List> get dataStream => _dataController.stream;
  
  /// 连接到蓝牙 COM 口
  /// 
  /// [portName] COM 口名称，如 'COM3'
  /// [baudRate] 波特率，默认 115200（蓝牙常用波特率）
  /// [useDualLineUartInit] 是否使用双线 UART 初始化（蓝牙通常不需要）
  Future<bool> connect(String portName, {
    int baudRate = 115200, // 蓝牙 SPP 常用 115200
    int dataBits = 8,
    int stopBits = 1,
    int parity = SerialPortParity.none,
    bool useDualLineUartInit = false, // 蓝牙 COM 口通常不需要双线初始化
  }) async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('📱 开始连接蓝牙 COM 口: $portName');
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // 关闭现有连接
      await disconnect();
      
      _port = SerialPort(portName);
      _logState?.debug('创建串口对象: $portName');
      
      // 检查串口是否存在
      final availablePorts = SerialPort.availablePorts;
      _logState?.debug('当前可用串口: ${availablePorts.join(", ")}');
      
      if (!availablePorts.contains(portName)) {
        _logState?.warning('⚠️  串口 $portName 不在可用列表中');
        _logState?.info('   提示: 请确保蓝牙设备已配对并连接');
      }
      
      // 显示端口信息
      final portInfo = getPortInfo(portName);
      _logState?.debug('端口信息:');
      _logState?.debug('   描述: ${portInfo['description']}');
      _logState?.debug('   制造商: ${portInfo['manufacturer']}');
      
      // 打开端口
      _logState?.debug('正在打开串口...');
      if (!_port!.openReadWrite()) {
        _logState?.error('❌ 打开串口失败');
        _logState?.error('可能原因:');
        _logState?.error('  1. 串口被其他程序占用');
        _logState?.error('  2. 蓝牙设备未连接或已断开');
        _logState?.error('  3. 权限不足');
        _logState?.error('  4. 设备驱动未安装');
        return false;
      }
      _logState?.success('✅ 串口打开成功');
      
      // 配置串口参数
      final config = SerialPortConfig();
      config.baudRate = baudRate;
      config.bits = dataBits;
      config.stopBits = stopBits;
      config.parity = parity;
      
      _logState?.debug('配置串口参数:');
      _logState?.debug('   波特率: $baudRate');
      _logState?.debug('   数据位: $dataBits');
      _logState?.debug('   停止位: $stopBits');
      _logState?.debug('   校验位: $parity');
      
      try {
        _port!.config = config;
        _logState?.debug('✅ 串口配置成功');
      } catch (e) {
        _logState?.error('❌ 串口配置失败: $e');
        _port!.close();
        return false;
      }
      
      // 双线 UART 初始化（可选）
      if (useDualLineUartInit) {
        _logState?.info('开始双线 UART 初始化流程...');
        
        // 步骤 1: 设置为 9600 波特率并发送 16 个 0
        _logState?.debug('步骤 1: 设置波特率为 9600');
        final initConfig = SerialPortConfig();
        initConfig.baudRate = 9600;
        initConfig.bits = dataBits;
        initConfig.stopBits = stopBits;
        initConfig.parity = parity;
        _port!.config = initConfig;
        
        // 发送 16 个 0
        final initData = Uint8List(16);
        int written = _port!.write(initData);
        _logState?.debug('发送 16 个 0 字节 (9600 波特率): $written bytes');
        
        // 等待传输完成
        await Future.delayed(const Duration(milliseconds: 100));
        
        // 步骤 2: 切换到高速波特率
        final highSpeedConfig = SerialPortConfig();
        highSpeedConfig.baudRate = baudRate;
        highSpeedConfig.bits = dataBits;
        highSpeedConfig.stopBits = stopBits;
        highSpeedConfig.parity = parity;
        _port!.config = highSpeedConfig;
        
        _logState?.debug('步骤 2: 切换到 $baudRate 波特率');
        
        // 等待配置生效
        await Future.delayed(const Duration(milliseconds: 50));
        _logState?.success('✅ 双线 UART 初始化完成');
      }
      
      // 启动数据读取
      _logState?.debug('启动串口数据读取...');
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
      
      _logState?.success('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.success('✅ 蓝牙 COM 口连接成功');
      _logState?.success('   端口: $portName');
      _logState?.success('   波特率: $baudRate');
      _logState?.success('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      return true;
    } catch (e) {
      debugPrint('Connection error: $e');
      _logState?.error('❌ 连接异常: $e');
      return false;
    }
  }
  
  /// 从缓冲区提取完整的 GTP 数据包
  void _extractCompletePackets() {
    while (_buffer.length >= 12) {
      // 查找 GTP 前导码 (0xD0D2C5C2)
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
        if (_buffer.isNotEmpty) {
          _logState?.warning('⚠️  缓冲区中没有找到 GTP 前导码，清空 ${_buffer.length} 字节');
        }
        _buffer = Uint8List(0);
        break;
      }
      
      // 如果前导码不在开头，丢弃前面的数据
      if (gtpStart > 0) {
        _logState?.warning('⚠️  丢弃前导码之前的 $gtpStart 字节数据');
        _buffer = Uint8List.fromList(_buffer.sublist(gtpStart));
        gtpStart = 0;
      }
      
      // 检查是否有足够的数据读取 Length 字段
      if (_buffer.length < 7) {
        break; // 等待更多数据
      }
      
      // 读取 Length 字段 (offset 5-6, little-endian)
      final lengthField = _buffer[5] | (_buffer[6] << 8);
      final expectedPacketLength = 4 + lengthField + 4; // Preamble + Header+Payload + CRC32
      
      // 检查是否接收到完整的数据包
      if (_buffer.length < expectedPacketLength) {
        // 数据包不完整，等待更多数据
        break;
      }
      
      // 提取完整的数据包
      final packet = Uint8List.fromList(_buffer.sublist(0, expectedPacketLength));
      _buffer = Uint8List.fromList(_buffer.sublist(expectedPacketLength));
      
      // 处理数据包
      _processGtpPacket(packet);
    }
  }
  
  /// 处理 GTP 数据包
  void _processGtpPacket(Uint8List packet) {
    _packetCount++;
    
    try {
      // 解析 GTP 数据包
      final parsed = GTPProtocol.parseGTPPacket(packet);
      
      if (parsed == null) {
        _logState?.error('❌ GTP 数据包解析失败');
        return;
      }
      
      // 提取序列号
      final sn = parsed['sn'] as int?;
      
      // 如果有等待该序列号的响应，完成它
      if (sn != null && _pendingResponses.containsKey(sn)) {
        _pendingResponses[sn]?.complete(parsed);
        _pendingResponses.remove(sn);
      }
      
    } catch (e) {
      _logState?.error('❌ 处理 GTP 数据包时出错: $e');
    }
  }
  
  /// 断开连接
  Future<void> disconnect() async {
    try {
      await _subscription?.cancel();
      _subscription = null;
      
      _reader = null;
      
      _port?.close();
      _port?.dispose();
      _port = null;
      
      _currentPortName = null;
      _isConnected = false;
      _buffer = Uint8List(0);
      _packetCount = 0;
      
      // 取消所有待处理的响应
      for (final completer in _pendingResponses.values) {
        if (!completer.isCompleted) {
          completer.completeError('连接已断开');
        }
      }
      _pendingResponses.clear();
      
      _logState?.info('蓝牙 COM 口已断开');
    } catch (e) {
      debugPrint('Disconnect error: $e');
      _logState?.error('断开连接时出错: $e');
    }
  }
  
  /// 发送 GTP 命令并等待响应
  /// 
  /// [commandPayload] 命令负载数据
  /// [moduleId] 模块 ID，默认 0x0000
  /// [messageId] 消息 ID，默认 0x0000
  /// [timeout] 超时时间，默认 5 秒
  Future<Map<String, dynamic>?> sendGTPCommand(
    Uint8List commandPayload, {
    int moduleId = 0x0000,
    int messageId = 0x0000,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!_isConnected || _port == null) {
      _logState?.error('❌ 未连接到设备');
      return null;
    }
    
    try {
      // 生成序列号
      final sn = _sequenceNumber++;
      if (_sequenceNumber > 0xFFFF) {
        _sequenceNumber = 0;
      }
      
      // 构建 GTP 数据包
      final packet = GTPProtocol.buildGTPPacket(
        commandPayload,
        moduleId: moduleId,
        messageId: messageId,
        sn: sn,
      );
      
      // 创建响应等待器
      final completer = Completer<Map<String, dynamic>?>();
      _pendingResponses[sn] = completer;
      
      // 发送数据包
      _logState?.debug('📤 发送 GTP 数据包 (SN: $sn, ${packet.length} bytes)');
      final written = _port!.write(packet);
      
      if (written != packet.length) {
        _logState?.warning('⚠️  写入字节数不匹配: 期望 ${packet.length}, 实际 $written');
      }
      
      // 等待响应
      try {
        final response = await completer.future.timeout(timeout);
        _logState?.success('✅ 收到响应 (SN: $sn)');
        return response;
      } on TimeoutException {
        _logState?.error('❌ 等待响应超时 (SN: $sn)');
        _pendingResponses.remove(sn);
        return null;
      }
      
    } catch (e) {
      _logState?.error('❌ 发送命令失败: $e');
      return null;
    }
  }
  
  /// 测试读取蓝牙 MAC 地址
  Future<String?> testReadBluetoothMAC({Duration timeout = const Duration(seconds: 5)}) async {
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _logState?.info('📖 测试读取蓝牙 MAC 地址');
    
    try {
      // 构建读取蓝牙 MAC 地址的命令
      // CMD: 0x0D (蓝牙命令), OPT: 0x01 (读取)
      final commandPayload = Uint8List.fromList([0x0D, 0x01]);
      
      final response = await sendGTPCommand(
        commandPayload,
        timeout: timeout,
      );
      
      if (response == null) {
        _logState?.error('❌ 读取失败: 未收到响应');
        return null;
      }
      
      // 解析响应
      final payload = response['payload'] as Uint8List?;
      if (payload == null || payload.length < 8) {
        _logState?.error('❌ 响应数据格式错误');
        return null;
      }
      
      // 提取 MAC 地址 (6 字节，从 offset 2 开始)
      final macBytes = payload.sublist(2, 8);
      final macAddress = macBytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
      
      _logState?.success('✅ 蓝牙 MAC 地址: $macAddress');
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      return macAddress;
      
    } catch (e) {
      _logState?.error('❌ 测试失败: $e');
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return null;
    }
  }
  
  /// 清理资源
  void dispose() {
    disconnect();
    _dataController.close();
  }
}
