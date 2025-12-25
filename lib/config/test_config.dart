/// 测试配置类
/// 包含所有测试相关的全局配置参数
class TestConfig {
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
  
  /// 漏电流测试阈值 (uA)
  static const double leakageCurrentThresholdUa = 500.0;
  
  /// 工作功耗测试阈值 (mA)
  static const double workingCurrentThresholdMa = 380.0;
}
