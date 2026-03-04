import 'package:shared_preferences/shared_preferences.dart';

/// 产测通用配置
/// 包含所有测试项的阈值和参数设置
class ProductionConfig {
  // 单例模式
  static final ProductionConfig _instance = ProductionConfig._internal();
  factory ProductionConfig() => _instance;
  ProductionConfig._internal();

  SharedPreferences? _prefs;

  // 配置键名
  static const String _keyHardwareVersion = 'hardware_version';
  static const String _keyLeakageCurrent = 'leakage_current_ua';
  static const String _keyWuqiPowerThreshold = 'wuqi_power_threshold_ma';
  static const String _keyIspWorkingPowerThreshold = 'isp_working_power_threshold_ma';
  static const String _keyFullPowerThreshold = 'full_power_threshold_ma';
  static const String _keyIspSleepPowerThreshold = 'isp_sleep_power_threshold_ma';
  static const String _keyMinVoltage = 'min_voltage_v';
  static const String _keyMinBattery = 'min_battery_percent';
  static const String _keyMaxBattery = 'max_battery_percent';
  static const String _keyTouchThreshold = 'touch_threshold';

  // 默认值
  static const String defaultHardwareVersion = '1.0.0';
  static const double defaultLeakageCurrentUa = 500.0;
  static const double defaultWuqiPowerThresholdMa = 15.0;
  static const double defaultIspWorkingPowerThresholdMa = 100.0;
  static const double defaultFullPowerThresholdMa = 400.0;
  static const double defaultIspSleepPowerThresholdMa = 30.0;
  static const double defaultMinVoltageV = 2.5;
  static const int defaultMinBatteryPercent = 0;
  static const int defaultMaxBatteryPercent = 100;
  static const int defaultTouchThreshold = 500;

  /// 初始化配置
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ========== 硬件版本号 ==========
  String get hardwareVersion => _prefs?.getString(_keyHardwareVersion) ?? defaultHardwareVersion;
  Future<void> setHardwareVersion(String value) async {
    await _prefs?.setString(_keyHardwareVersion, value);
  }

  // ========== 程控电流值（漏电流）==========
  double get leakageCurrentUa => _prefs?.getDouble(_keyLeakageCurrent) ?? defaultLeakageCurrentUa;
  Future<void> setLeakageCurrentUa(double value) async {
    await _prefs?.setDouble(_keyLeakageCurrent, value);
  }

  // ========== 只开启物奇的程控电流值 ==========
  double get wuqiPowerThresholdMa => _prefs?.getDouble(_keyWuqiPowerThreshold) ?? defaultWuqiPowerThresholdMa;
  Future<void> setWuqiPowerThresholdMa(double value) async {
    await _prefs?.setDouble(_keyWuqiPowerThreshold, value);
  }

  // ========== 开启物奇和ISP程控电流值 ==========
  double get ispWorkingPowerThresholdMa => _prefs?.getDouble(_keyIspWorkingPowerThreshold) ?? defaultIspWorkingPowerThresholdMa;
  Future<void> setIspWorkingPowerThresholdMa(double value) async {
    await _prefs?.setDouble(_keyIspWorkingPowerThreshold, value);
  }

  // ========== 开启物奇、ISP和WIFI的程控电流值 ==========
  double get fullPowerThresholdMa => _prefs?.getDouble(_keyFullPowerThreshold) ?? defaultFullPowerThresholdMa;
  Future<void> setFullPowerThresholdMa(double value) async {
    await _prefs?.setDouble(_keyFullPowerThreshold, value);
  }

  // ========== 开启物奇、ISP休眠状态的程控电流值 ==========
  double get ispSleepPowerThresholdMa => _prefs?.getDouble(_keyIspSleepPowerThreshold) ?? defaultIspSleepPowerThresholdMa;
  Future<void> setIspSleepPowerThresholdMa(double value) async {
    await _prefs?.setDouble(_keyIspSleepPowerThreshold, value);
  }

  // ========== 获取硬件检测电池电压值 ==========
  double get minVoltageV => _prefs?.getDouble(_keyMinVoltage) ?? defaultMinVoltageV;
  Future<void> setMinVoltageV(double value) async {
    await _prefs?.setDouble(_keyMinVoltage, value);
  }

  // ========== 电量值范围 ==========
  int get minBatteryPercent => _prefs?.getInt(_keyMinBattery) ?? defaultMinBatteryPercent;
  Future<void> setMinBatteryPercent(int value) async {
    await _prefs?.setInt(_keyMinBattery, value);
  }

  int get maxBatteryPercent => _prefs?.getInt(_keyMaxBattery) ?? defaultMaxBatteryPercent;
  Future<void> setMaxBatteryPercent(int value) async {
    await _prefs?.setInt(_keyMaxBattery, value);
  }

  // ========== Touch阈值变化量 ==========
  int get touchThreshold => _prefs?.getInt(_keyTouchThreshold) ?? defaultTouchThreshold;
  Future<void> setTouchThreshold(int value) async {
    await _prefs?.setInt(_keyTouchThreshold, value);
  }

  /// 重置所有配置为默认值
  Future<void> resetToDefaults() async {
    await setHardwareVersion(defaultHardwareVersion);
    await setLeakageCurrentUa(defaultLeakageCurrentUa);
    await setWuqiPowerThresholdMa(defaultWuqiPowerThresholdMa);
    await setIspWorkingPowerThresholdMa(defaultIspWorkingPowerThresholdMa);
    await setFullPowerThresholdMa(defaultFullPowerThresholdMa);
    await setIspSleepPowerThresholdMa(defaultIspSleepPowerThresholdMa);
    await setMinVoltageV(defaultMinVoltageV);
    await setMinBatteryPercent(defaultMinBatteryPercent);
    await setMaxBatteryPercent(defaultMaxBatteryPercent);
    await setTouchThreshold(defaultTouchThreshold);
  }

  /// 获取所有配置的摘要
  Map<String, dynamic> getSummary() {
    return {
      '硬件版本号': hardwareVersion,
      '程控电流值(漏电流)': '${leakageCurrentUa}μA',
      '物奇功耗阈值': '≤${wuqiPowerThresholdMa}mA',
      'ISP工作功耗阈值': '≤${ispWorkingPowerThresholdMa}mA',
      '完整功耗阈值': '≤${fullPowerThresholdMa}mA',
      'ISP休眠功耗阈值': '≤${ispSleepPowerThresholdMa}mA',
      '最小电压': '>${minVoltageV}V',
      '电量范围': '$minBatteryPercent~$maxBatteryPercent%',
      'Touch阈值变化量': '>$touchThreshold',
    };
  }
}
