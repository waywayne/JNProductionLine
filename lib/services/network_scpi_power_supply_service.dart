import 'dart:async';
import 'dart:io';

/// 网络SCPI程控电源服务
/// 通过 lxi 命令行工具发送SCPI命令控制程控电源
/// 
/// 安装 lxi-tools:
///   sudo apt-get install lxi-tools  (Ubuntu/Debian)
///   或从源码编译: https://github.com/lxi-tools/lxi-tools
class NetworkScpiPowerSupplyService {
  String? _currentAddress;
  bool _isConnected = false;
  
  /// 执行 lxi SCPI 命令
  /// [ipAddress] 程控电源的IP地址
  /// [command] SCPI命令
  /// [timeout] 超时时间（秒）
  Future<String?> _runLxiCommand(String ipAddress, String command, {int timeout = 10}) async {
    try {
      // 构建 lxi scpi 命令
      final fullCommand = 'lxi scpi --address $ipAddress "$command"';
      
      print('� 执行命令: $fullCommand');
      
      // 执行命令
      final result = await Process.run(
        'sh',
        ['-c', fullCommand],
        timeout: Duration(seconds: timeout),
      );
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty) {
          print('📥 响应: $output');
        }
        return output.isEmpty ? null : output;
      } else {
        final error = result.stderr.toString().trim();
        print('❌ 命令失败: $error');
        return null;
      }
    } on TimeoutException {
      print('⏱️ 命令超时: $command');
      return null;
    } catch (e) {
      print('❌ 执行命令异常: $e');
      return null;
    }
  }
  
  /// 连接到程控电源（测试连接）
  /// [ipAddress] 程控电源的IP地址，如 '192.168.1.13'
  /// [port] SCPI端口（lxi工具会自动使用，此参数保留兼容性）
  /// [timeout] 连接超时时间
  Future<bool> connect(String ipAddress, {int port = 5025, Duration timeout = const Duration(seconds: 5)}) async {
    try {
      print('🔌 测试程控电源连接: $ipAddress');
      
      _currentAddress = ipAddress;
      
      // 测试连接：查询设备ID
      final idn = await _runLxiCommand(ipAddress, '*IDN?', timeout: timeout.inSeconds);
      if (idn != null && idn.isNotEmpty) {
        print('✅ 程控电源连接成功');
        print('📟 设备ID: $idn');
        _isConnected = true;
        return true;
      } else {
        print('❌ 无法查询设备ID');
        _isConnected = false;
        return false;
      }
    } catch (e) {
      print('❌ 连接程控电源失败: $e');
      _isConnected = false;
      return false;
    }
  }
  
  /// 断开连接
  Future<void> disconnect() async {
    _isConnected = false;
    _currentAddress = null;
    print('✅ 程控电源已断开');
  }
  
  /// 发送SCPI写命令
  /// [command] SCPI命令，如 'VOLT 12.5'
  Future<bool> write(String command) async {
    if (_currentAddress == null) {
      print('❌ 未设置程控电源地址');
      return false;
    }
    
    final result = await _runLxiCommand(_currentAddress!, command);
    return result != null || result == ''; // 写命令可能没有返回值
  }
  
  /// 发送SCPI查询命令并等待响应
  /// [command] SCPI查询命令，如 '*IDN?'
  /// [timeout] 响应超时时间
  Future<String?> query(String command, {Duration timeout = const Duration(seconds: 5)}) async {
    if (_currentAddress == null) {
      print('❌ 未设置程控电源地址');
      return null;
    }
    
    return await _runLxiCommand(_currentAddress!, command, timeout: timeout.inSeconds);
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
  
  /// 释放资源
  void dispose() {
    disconnect();
  }
}
