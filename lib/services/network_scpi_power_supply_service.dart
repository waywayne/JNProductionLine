import 'dart:async';
import 'dart:io';

/// 网络SCPI程控电源服务
/// 通过TCP/IP Socket直接发送SCPI命令控制程控电源
class NetworkScpiPowerSupplyService {
  Socket? _socket;
  String? _currentAddress;
  int? _currentPort;
  bool _isConnected = false;
  
  final StreamController<String> _responseController = StreamController<String>.broadcast();
  Stream<String> get responseStream => _responseController.stream;
  
  /// 连接到程控电源
  /// [ipAddress] 程控电源的IP地址，如 '192.168.1.13'
  /// [port] SCPI端口，默认5025
  /// [timeout] 连接超时时间
  Future<bool> connect(String ipAddress, {int port = 5025, Duration timeout = const Duration(seconds: 5)}) async {
    try {
      // 如果已连接，先断开
      if (_isConnected) {
        await disconnect();
      }
      
      print('🔌 连接到程控电源: $ipAddress:$port');
      
      _socket = await Socket.connect(ipAddress, port, timeout: timeout);
      _currentAddress = ipAddress;
      _currentPort = port;
      _isConnected = true;
      
      // 监听数据
      _socket!.listen(
        (data) {
          final response = String.fromCharCodes(data).trim();
          _responseController.add(response);
        },
        onError: (error) {
          print('❌ Socket错误: $error');
          _isConnected = false;
        },
        onDone: () {
          print('🔌 Socket连接已关闭');
          _isConnected = false;
        },
      );
      
      print('✅ 程控电源连接成功');
      
      // 测试连接：查询设备ID
      final idn = await query('*IDN?', timeout: const Duration(seconds: 3));
      if (idn != null) {
        print('📟 设备ID: $idn');
        return true;
      } else {
        print('⚠️ 无法查询设备ID，但连接已建立');
        return true;
      }
    } catch (e) {
      print('❌ 连接程控电源失败: $e');
      _isConnected = false;
      return false;
    }
  }
  
  /// 断开连接
  Future<void> disconnect() async {
    if (_socket != null) {
      try {
        await _socket!.close();
        print('✅ 程控电源已断开');
      } catch (e) {
        print('⚠️ 断开连接时出错: $e');
      }
      _socket = null;
      _isConnected = false;
      _currentAddress = null;
      _currentPort = null;
    }
  }
  
  /// 发送SCPI写命令
  /// [command] SCPI命令，如 'VOLT 12.5'
  Future<bool> write(String command) async {
    if (!_isConnected || _socket == null) {
      print('❌ 未连接到程控电源');
      return false;
    }
    
    try {
      _socket!.write('$command\n');
      await _socket!.flush();
      print('📤 发送命令: $command');
      return true;
    } catch (e) {
      print('❌ 发送命令失败: $e');
      return false;
    }
  }
  
  /// 发送SCPI查询命令并等待响应
  /// [command] SCPI查询命令，如 '*IDN?'
  /// [timeout] 响应超时时间
  Future<String?> query(String command, {Duration timeout = const Duration(seconds: 5)}) async {
    if (!_isConnected || _socket == null) {
      print('❌ 未连接到程控电源');
      return null;
    }
    
    try {
      // 清空之前的响应
      final completer = Completer<String>();
      StreamSubscription? subscription;
      
      // 监听响应
      subscription = responseStream.listen((response) {
        if (!completer.isCompleted) {
          completer.complete(response);
        }
      });
      
      // 发送查询命令
      _socket!.write('$command\n');
      await _socket!.flush();
      print('📤 查询命令: $command');
      
      // 等待响应
      final response = await completer.future.timeout(
        timeout,
        onTimeout: () {
          print('⏱️ 查询超时: $command');
          return '';
        },
      );
      
      await subscription.cancel();
      
      if (response.isNotEmpty) {
        print('📥 响应: $response');
        return response;
      } else {
        return null;
      }
    } catch (e) {
      print('❌ 查询失败: $e');
      return null;
    }
  }
  
  /// 设置电压 (V)
  Future<bool> setVoltage(double voltage) async {
    return await write('VOLT ${voltage.toStringAsFixed(2)}');
  }
  
  /// 设置电流限制 (A)
  Future<bool> setCurrentLimit(double current) async {
    return await write('CURR ${current.toStringAsFixed(3)}');
  }
  
  /// 打开输出
  Future<bool> enableOutput() async {
    return await write('OUTP ON');
  }
  
  /// 关闭输出
  Future<bool> disableOutput() async {
    return await write('OUTP OFF');
  }
  
  /// 测量电压 (V)
  Future<double?> measureVoltage() async {
    final response = await query('MEAS:VOLT?');
    if (response != null) {
      try {
        return double.parse(response);
      } catch (e) {
        print('❌ 解析电压失败: $e');
        return null;
      }
    }
    return null;
  }
  
  /// 测量电流 (A)
  /// [sampleCount] 采样次数，默认10次
  /// [sampleRate] 采样频率(Hz)，默认10Hz
  Future<double?> measureCurrent({int sampleCount = 10, int sampleRate = 10}) async {
    try {
      final samples = <double>[];
      final delayMs = (1000 / sampleRate).round();
      
      print('📊 采集电流: $sampleCount 次 @ ${sampleRate}Hz');
      
      for (int i = 0; i < sampleCount; i++) {
        final response = await query('MEAS:CURR?', timeout: const Duration(seconds: 2));
        if (response != null) {
          try {
            final current = double.parse(response);
            samples.add(current);
            print('   样本 ${i + 1}/$sampleCount: ${(current * 1000).toStringAsFixed(2)}mA');
          } catch (e) {
            print('⚠️ 解析电流失败: $e');
          }
        }
        
        if (i < sampleCount - 1) {
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
      
      if (samples.isEmpty) {
        print('❌ 未采集到有效电流数据');
        return null;
      }
      
      // 计算平均值
      final average = samples.reduce((a, b) => a + b) / samples.length;
      print('📊 平均电流: ${(average * 1000).toStringAsFixed(2)}mA');
      
      return average;
    } catch (e) {
      print('❌ 测量电流失败: $e');
      return null;
    }
  }
  
  /// 查询当前电压设置 (V)
  Future<double?> queryVoltage() async {
    final response = await query('VOLT?');
    if (response != null) {
      try {
        return double.parse(response);
      } catch (e) {
        print('❌ 解析电压设置失败: $e');
        return null;
      }
    }
    return null;
  }
  
  /// 查询当前电流限制 (A)
  Future<double?> queryCurrentLimit() async {
    final response = await query('CURR?');
    if (response != null) {
      try {
        return double.parse(response);
      } catch (e) {
        print('❌ 解析电流限制失败: $e');
        return null;
      }
    }
    return null;
  }
  
  /// 查询输出状态
  Future<bool?> queryOutputState() async {
    final response = await query('OUTP?');
    if (response != null) {
      return response.trim() == '1' || response.trim().toUpperCase() == 'ON';
    }
    return null;
  }
  
  /// 检查是否已连接
  bool get isConnected => _isConnected;
  
  /// 获取当前连接地址
  String? get currentAddress => _currentAddress;
  
  /// 获取当前连接端口
  int? get currentPort => _currentPort;
  
  /// 释放资源
  void dispose() {
    disconnect();
    _responseController.close();
  }
}
