import 'production_config.dart';

/// 测试配置类
/// 包含所有测试相关的全局配置参数
class TestConfig {
  static final _prodConfig = ProductionConfig();
  
  /// 默认测试超时时间（秒）
  static const int defaultTimeoutSeconds = 5;
  
  /// 默认测试超时时间（Duration对象）
  static const Duration defaultTimeout = Duration(seconds: defaultTimeoutSeconds);
  
  /// 退出睡眠模式超时时间（秒）
  static const int exitSleepTimeoutSeconds = 2;
  
  /// 退出睡眠模式超时时间（Duration对象）
  static const Duration exitSleepTimeout = Duration(seconds: exitSleepTimeoutSeconds);
  
  /// 最大重试次数
  static const int maxRetries = 2;
  
  /// 重试间隔时间（毫秒）
  static const int retryDelayMs = 500;
  
  /// 重试间隔时间（Duration对象）
  static const Duration retryDelay = Duration(milliseconds: retryDelayMs);
  
  /// Touch测试间隔时间（毫秒）
  static const int touchTestDelayMs = 100;
  
  /// Touch测试间隔时间（Duration对象）
  static const Duration touchTestDelay = Duration(milliseconds: touchTestDelayMs);
  
  // ==================== GPIB 电流采样配置 ====================
  
  /// GPIB 采样次数
  static const int gpibSampleCount = 20;
  
  /// GPIB 采样率 (Hz)
  static const int gpibSampleRate = 10;
  
  /// GPIB 采样间隔时间（毫秒）= 1000ms / 采样率
  static int get gpibSampleIntervalMs => 1000 ~/ gpibSampleRate;
  
  /// GPIB 采样间隔时间（Duration对象）
  static Duration get gpibSampleInterval => Duration(milliseconds: gpibSampleIntervalMs);
  
  // ==================== 动态配置阈值（从ProductionConfig读取）====================
  
  /// 硬件版本号
  static String get hardwareVersion => _prodConfig.hardwareVersion;
  
  /// 漏电流测试阈值 (uA)
  static double get leakageCurrentThresholdUa => _prodConfig.leakageCurrentUa;
  
  /// 工作功耗测试阈值 (mA) - 保持兼容性
  static const double workingCurrentThresholdMa = 450.0;
  
  /// 物奇功耗测试阈值 (mA) - 只开启物奇
  static double get wuqiPowerThresholdMa => _prodConfig.wuqiPowerThresholdMa;
  
  /// ISP工作功耗测试阈值 (mA) - 开启物奇和ISP
  static double get ispWorkingPowerThresholdMa => _prodConfig.ispWorkingPowerThresholdMa;
  
  /// 完整功耗测试阈值 (mA) - 开启物奇、ISP和WIFI
  static double get fullPowerThresholdMa => _prodConfig.fullPowerThresholdMa;
  
  /// ISP休眠功耗测试阈值 (mA) - 开启物奇、ISP休眠状态
  static double get ispSleepPowerThresholdMa => _prodConfig.ispSleepPowerThresholdMa;
  
  /// 最小电压阈值 (V)
  static double get minVoltageV => _prodConfig.minVoltageV;
  
  /// 电量最小值 (%)
  static int get minBatteryPercent => _prodConfig.minBatteryPercent;
  
  /// 电量最大值 (%)
  static int get maxBatteryPercent => _prodConfig.maxBatteryPercent;
  
  /// Touch阈值变化量
  static int get touchThreshold => _prodConfig.touchThreshold;
  
  /// EMMC最小容量阈值 (MB) - EMMC容量检测
  static const int emmcMinCapacityMb = 100;
}
