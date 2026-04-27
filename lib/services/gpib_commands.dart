import 'dart:async';
import 'gpib_service.dart';
import '../models/log_state.dart';

/// GPIB 命令封装类
/// 用于 WFP60H 系列程控电源的 SCPI 命令
class GpibCommands {
  final GpibService _gpibService;
  LogState? _logState;
  
  GpibCommands(this._gpibService);
  
  void setLogState(LogState logState) {
    _logState = logState;
  }
  
  /// 查询设备型号
  Future<String?> identify() async {
    _logState?.info('查询设备型号...', type: LogType.gpib);
    final response = await _gpibService.query('*IDN?');
    if (response != null && response != 'TIMEOUT') {
      _logState?.success('设备型号: $response', type: LogType.gpib);
    }
    return response;
  }
  
  /// 复位仪器
  Future<bool> reset() async {
    _logState?.info('复位仪器...', type: LogType.gpib);
    final response = await _gpibService.sendCommand('*RST');
    if (response != null && response != 'TIMEOUT') {
      _logState?.success('仪器复位成功', type: LogType.gpib);
      // 等待复位完成
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }
    return false;
  }
  
  /// 设置输出电压
  /// voltage: 电压值（单位：V）
  Future<bool> setVoltage(double voltage) async {
    _logState?.info('设置输出电压: ${voltage}V', type: LogType.gpib);
    final response = await _gpibService.sendCommand(':SOURce1:VOLTage $voltage');
    if (response != null && response != 'TIMEOUT') {
      _logState?.success('电压设置成功: ${voltage}V', type: LogType.gpib);
      return true;
    }
    return false;
  }
  
  /// 设置电流限制
  /// current: 电流限制值（单位：A）
  Future<bool> setCurrentLimit(double current) async {
    _logState?.info('设置电流限制: ${current}A', type: LogType.gpib);
    final response = await _gpibService.sendCommand(':SOURce1:CURRent:LIMit $current');
    if (response != null && response != 'TIMEOUT') {
      _logState?.success('电流限制设置成功: ${current}A', type: LogType.gpib);
      return true;
    }
    return false;
  }
  
  /// 设置电流测量范围（自动）
  /// range: 电流范围（单位：A），WFP60H使用自动量程
  Future<bool> setCurrentRange(double range) async {
    _logState?.info('设置电流测量范围: 自动', type: LogType.gpib);
    final response = await _gpibService.sendCommand(':SENSe1:CURRent:RANGe:AUTO ON');
    if (response != null && response != 'TIMEOUT') {
      _logState?.success('电流范围设置成功: 自动', type: LogType.gpib);
      return true;
    }
    return false;
  }
  
  /// 开启电源输出
  Future<bool> enableOutput() async {
    _logState?.info('开启电源输出...', type: LogType.gpib);
    final response = await _gpibService.sendCommand(':OUTPut1 ON');
    if (response != null && response != 'TIMEOUT') {
      _logState?.success('电源输出已开启', type: LogType.gpib);
      return true;
    }
    return false;
  }
  
  /// 关闭电源输出
  Future<bool> disableOutput() async {
    _logState?.info('关闭电源输出...', type: LogType.gpib);
    final response = await _gpibService.sendCommand(':OUTPut1 OFF');
    if (response != null && response != 'TIMEOUT') {
      _logState?.success('电源输出已关闭', type: LogType.gpib);
      return true;
    }
    return false;
  }
  
  /// 测量电流（单次）
  Future<double?> measureCurrent() async {
    final response = await _gpibService.query(':READ1?');
    if (response != null && response != 'TIMEOUT') {
      try {
        final current = double.parse(response.trim());
        return current;
      } catch (e) {
        _logState?.error('解析电流值失败: $e', type: LogType.gpib);
      }
    }
    return null;
  }
  
  /// 查询当前电流限制设置
  Future<double?> queryCurrentLimit() async {
    final response = await _gpibService.query(':SOURce1:CURRent:LIMit?');
    if (response != null && response != 'TIMEOUT') {
      try {
        return double.parse(response.trim());
      } catch (e) {
        _logState?.error('解析电流限制值失败: $e', type: LogType.gpib);
      }
    }
    return null;
  }
  
  /// 查询当前电流测量范围
  Future<double?> queryCurrentRange() async {
    final response = await _gpibService.query(':SENSe1:CURRent:RANGe:AUTO?');
    if (response != null && response != 'TIMEOUT') {
      try {
        final isAuto = response.trim();
        if (isAuto == '1' || isAuto.toUpperCase() == 'ON') {
          return 0; // 0表示自动量程
        }
        return 1; // 非自动
      } catch (e) {
        _logState?.error('解析电流范围值失败: $e', type: LogType.gpib);
      }
    }
    return null;
  }
  
  /// 初始化电源（WFP60H）
  /// voltage: 输出电压（默认 5.0V）
  /// currentLimit: 电流限制（默认 1.5A）
  /// currentRange: 电流测量范围（保留参数兼容性，WFP60H使用自动量程）
  Future<bool> initializePowerSupply({
    double voltage = 5.0,
    double currentLimit = 1.5,
    double currentRange = 1.0,
  }) async {
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
    _logState?.info('开始初始化电源 (WFP60H)...', type: LogType.gpib);
    
    // 1. 复位
    if (!await reset()) {
      return false;
    }
    
    // 2. 配置测量功能为电流
    _logState?.info('配置测量功能: 电流', type: LogType.gpib);
    final funcResponse = await _gpibService.sendCommand(':SENSe1:FUNCtion CURR');
    if (funcResponse == null || funcResponse == 'TIMEOUT') {
      _logState?.error('配置测量功能失败', type: LogType.gpib);
      return false;
    }
    
    // 3. 设置电压
    if (!await setVoltage(voltage)) {
      return false;
    }
    
    // 4. 设置电流限制
    if (!await setCurrentLimit(currentLimit)) {
      return false;
    }
    
    // 5. 设置电流测量范围（自动）
    if (!await setCurrentRange(currentRange)) {
      return false;
    }
    
    // 6. 开启输出
    if (!await enableOutput()) {
      return false;
    }
    
    _logState?.success('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
    _logState?.success('电源初始化完成！', type: LogType.gpib);
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
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
    _logState?.info('开始采集 PCBA 工作电流...', type: LogType.gpib);
    _logState?.info('采样次数: $sampleCount, 采样率: ${sampleRate}Hz', type: LogType.gpib);
    
    final interval = Duration(milliseconds: (1000 / sampleRate).round());
    
    for (int i = 0; i < sampleCount; i++) {
      try {
        // 采集电流
        final current = await measureCurrent();
        if (current == null) {
          _logState?.warning('第 ${i + 1} 次采集失败', type: LogType.gpib);
          continue;
        }
        
        final timestamp = DateTime.now();
        
        // 数据显示
        _logState?.info('[$i/$sampleCount] 时间: ${_formatTimestamp(timestamp)}, 工作电流: ${current.toStringAsFixed(4)} A', type: LogType.gpib);
        
        // 异常报警
        if (alertThreshold != null && current > alertThreshold) {
          _logState?.warning('⚠️ 警告：PCBA 工作电流超出阈值！当前: ${current.toStringAsFixed(4)}A, 阈值: ${alertThreshold}A', type: LogType.gpib);
        }
        
        // 回调
        onData(i, current, timestamp);
        
        // 等待采样间隔
        if (i < sampleCount - 1) {
          await Future.delayed(interval);
        }
      } catch (e) {
        _logState?.error('采集过程出错: $e', type: LogType.gpib);
        break;
      }
    }
    
    _logState?.success('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
    _logState?.success('电流采集完成！', type: LogType.gpib);
    onComplete?.call();
  }
  
  /// 格式化时间戳
  String _formatTimestamp(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:'
           '${dt.second.toString().padLeft(2, '0')}.${dt.millisecond.toString().padLeft(3, '0')}';
  }
}
