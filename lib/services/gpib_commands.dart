import 'dart:async';
import 'gpib_service.dart';
import '../models/log_state.dart';

/// GPIB 命令封装类
/// 专门用于 Keysight 66319D 电源的 SCPI 命令
class GpibCommands {
  final GpibService _gpibService;
  LogState? _logState;
  
  GpibCommands(this._gpibService);
  
  void setLogState(LogState logState) {
    _logState = logState;
  }
  
  /// 查询设备型号
  Future<String?> identify() async {
    _logState?.info('查询设备型号...');
    final response = await _gpibService.query('*IDN?');
    if (response != null && response != 'TIMEOUT') {
      _logState?.success('设备型号: $response');
    }
    return response;
  }
  
  /// 复位仪器
  Future<bool> reset() async {
    _logState?.info('复位仪器...');
    final response = await _gpibService.sendCommand('*RST');
    if (response != null && response != 'TIMEOUT') {
      _logState?.success('仪器复位成功');
      // 等待复位完成
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }
    return false;
  }
  
  /// 设置输出电压
  /// voltage: 电压值（单位：V）
  Future<bool> setVoltage(double voltage) async {
    _logState?.info('设置输出电压: ${voltage}V');
    final response = await _gpibService.sendCommand('VOLT:LEV $voltage');
    if (response != null && response != 'TIMEOUT') {
      _logState?.success('电压设置成功: ${voltage}V');
      return true;
    }
    return false;
  }
  
  /// 设置电流限制
  /// current: 电流限制值（单位：A）
  Future<bool> setCurrentLimit(double current) async {
    _logState?.info('设置电流限制: ${current}A');
    final response = await _gpibService.sendCommand('CURR:LEV $current');
    if (response != null && response != 'TIMEOUT') {
      _logState?.success('电流限制设置成功: ${current}A');
      return true;
    }
    return false;
  }
  
  /// 设置电流测量范围
  /// range: 电流范围（单位：A）
  Future<bool> setCurrentRange(double range) async {
    _logState?.info('设置电流测量范围: ${range}A');
    final response = await _gpibService.sendCommand('CURR:RANG $range');
    if (response != null && response != 'TIMEOUT') {
      _logState?.success('电流范围设置成功: ${range}A');
      return true;
    }
    return false;
  }
  
  /// 开启电源输出
  Future<bool> enableOutput() async {
    _logState?.info('开启电源输出...');
    final response = await _gpibService.sendCommand('OUTP:STAT ON');
    if (response != null && response != 'TIMEOUT') {
      _logState?.success('电源输出已开启');
      return true;
    }
    return false;
  }
  
  /// 关闭电源输出
  Future<bool> disableOutput() async {
    _logState?.info('关闭电源输出...');
    final response = await _gpibService.sendCommand('OUTP:STAT OFF');
    if (response != null && response != 'TIMEOUT') {
      _logState?.success('电源输出已关闭');
      return true;
    }
    return false;
  }
  
  /// 测量电流（单次）
  Future<double?> measureCurrent() async {
    final response = await _gpibService.query('MEAS:CURR?');
    if (response != null && response != 'TIMEOUT') {
      try {
        final current = double.parse(response.trim());
        return current;
      } catch (e) {
        _logState?.error('解析电流值失败: $e');
      }
    }
    return null;
  }
  
  /// 查询当前电流限制设置
  Future<double?> queryCurrentLimit() async {
    final response = await _gpibService.query('CURR:LEV?');
    if (response != null && response != 'TIMEOUT') {
      try {
        return double.parse(response.trim());
      } catch (e) {
        _logState?.error('解析电流限制值失败: $e');
      }
    }
    return null;
  }
  
  /// 查询当前电流测量范围
  Future<double?> queryCurrentRange() async {
    final response = await _gpibService.query('CURR:RANG?');
    if (response != null && response != 'TIMEOUT') {
      try {
        return double.parse(response.trim());
      } catch (e) {
        _logState?.error('解析电流范围值失败: $e');
      }
    }
    return null;
  }
  
  /// 初始化电源（按照 demo 中的参数）
  /// voltage: 输出电压（默认 5.0V）
  /// currentLimit: 电流限制（默认 1.5A）
  /// currentRange: 电流测量范围（默认 1.0A）
  Future<bool> initializePowerSupply({
    double voltage = 5.0,
    double currentLimit = 1.5,
    double currentRange = 1.0,
  }) async {
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _logState?.info('开始初始化电源...');
    
    // 1. 复位
    if (!await reset()) {
      return false;
    }
    
    // 2. 设置电压
    if (!await setVoltage(voltage)) {
      return false;
    }
    
    // 3. 设置电流限制
    if (!await setCurrentLimit(currentLimit)) {
      return false;
    }
    
    // 4. 设置电流测量范围
    if (!await setCurrentRange(currentRange)) {
      return false;
    }
    
    // 5. 开启输出
    if (!await enableOutput()) {
      return false;
    }
    
    _logState?.success('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _logState?.success('电源初始化完成！');
    return true;
  }
  
  /// 连续采集电流数据
  /// sampleCount: 采样次数
  /// sampleRate: 采样率（Hz）
  /// onData: 数据回调函数
  /// onComplete: 完成回调函数
  Future<void> collectCurrentData({
    required int sampleCount,
    required double sampleRate,
    required Function(int index, double current, DateTime timestamp) onData,
    Function()? onComplete,
    double? alertThreshold,
  }) async {
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _logState?.info('开始采集 PCBA 工作电流...');
    _logState?.info('采样次数: $sampleCount, 采样率: ${sampleRate}Hz');
    
    final interval = Duration(milliseconds: (1000 / sampleRate).round());
    
    for (int i = 0; i < sampleCount; i++) {
      try {
        // 采集电流
        final current = await measureCurrent();
        if (current == null) {
          _logState?.warning('第 ${i + 1} 次采集失败');
          continue;
        }
        
        final timestamp = DateTime.now();
        
        // 数据显示
        _logState?.info('[$i/$sampleCount] 时间: ${_formatTimestamp(timestamp)}, 工作电流: ${current.toStringAsFixed(4)} A');
        
        // 异常报警
        if (alertThreshold != null && current > alertThreshold) {
          _logState?.warning('⚠️ 警告：PCBA 工作电流超出阈值！当前: ${current.toStringAsFixed(4)}A, 阈值: ${alertThreshold}A');
        }
        
        // 回调
        onData(i, current, timestamp);
        
        // 等待采样间隔
        if (i < sampleCount - 1) {
          await Future.delayed(interval);
        }
      } catch (e) {
        _logState?.error('采集过程出错: $e');
        break;
      }
    }
    
    _logState?.success('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _logState?.success('电流采集完成！');
    onComplete?.call();
  }
  
  /// 格式化时间戳
  String _formatTimestamp(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:'
           '${dt.second.toString().padLeft(2, '0')}.${dt.millisecond.toString().padLeft(3, '0')}';
  }
}
