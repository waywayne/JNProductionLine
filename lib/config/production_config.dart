import 'package:shared_preferences/shared_preferences.dart';

/// 产测通用配置
/// 包含所有测试项的阈值和参数设置
class ProductionConfig {
  // 单例模式
  static final ProductionConfig _instance = ProductionConfig._internal();
  factory ProductionConfig() => _instance;
  ProductionConfig._internal();

  SharedPreferences? _prefs;
  bool _isInitialized = false;

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
  static const String _keyTemperatureThreshold = 'temperature_threshold_c';
  static const String _keyTouchThreshold = 'touch_threshold';
  static const String _keyEmmcMinCapacityGb = 'emmc_min_capacity_gb';
  static const String _keyGpibAddress = 'gpib_address';
  static const String _keyWifiSsid = 'wifi_ssid';
  static const String _keyWifiPassword = 'wifi_password';
  static const String _keyProductLine = 'product_line';
  static const String _keyFactory = 'factory';
  static const String _keyProductionLine = 'production_line';
  static const String _keyBydMesIp = 'byd_mes_ip';
  static const String _keyBydMesClientId = 'byd_mes_client_id';
  static const String _keyBydMesStation = 'byd_mes_station';

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
  static const int defaultTemperatureThresholdC = 50;  // 默认50℃
  static const int defaultTouchThreshold = 500;
  static const double defaultEmmcMinCapacityGb = 1.0; // 默认1GB
  static const String defaultGpibAddress = 'GPIB0::5::INSTR';
  static const String defaultWifiSsid = '';  // 默认为空，需要用户配置
  static const String defaultWifiPassword = '';  // 默认为空，需要用户配置
  static const String defaultProductLine = '637';  // 默认 Kanaan-K2
  static const String defaultFactory = '1';  // 默认比亚迪
  static const String defaultProductionLine = '1';  // 默认产线1
  static const String defaultBydMesIp = '192.168.1.100';  // BYD MES 服务器 IP
  static const String defaultBydMesClientId = 'DEFAULT_CLIENT';  // BYD MES 客户端 ID
  static const String defaultBydMesStation = 'STATION1';  // BYD MES 站点名称

  /// 初始化配置
  /// 优先从注册表/SharedPreferences加载，如果不存在则使用默认值
  Future<void> init() async {
    if (_isInitialized) {
      print('⚠️  ProductionConfig 已经初始化，跳过重复初始化');
      return;
    }

    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      
      // 检查是否有保存的配置
      final hasConfig = _prefs?.containsKey(_keyHardwareVersion) ?? false;
      
      if (hasConfig) {
        print('✅ 从注册表/SharedPreferences加载配置');
        print('   硬件版本: $hardwareVersion');
        print('   产品线: $productLine');
        print('   工厂: $factory');
        print('   产线: $productionLine');
      } else {
        print('ℹ️  未找到保存的配置，使用默认值');
        print('   硬件版本: $defaultHardwareVersion');
        print('   产品线: $defaultProductLine');
        print('   工厂: $defaultFactory');
        print('   产线: $defaultProductionLine');
      }
    } catch (e) {
      print('❌ 初始化配置失败: $e');
      print('   将使用默认配置');
      _isInitialized = false;
    }
  }
  
  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;

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

  // ========== 温度阈值 (℃) ==========
  int get temperatureThresholdC => _prefs?.getInt(_keyTemperatureThreshold) ?? defaultTemperatureThresholdC;
  Future<void> setTemperatureThresholdC(int value) async {
    await _prefs?.setInt(_keyTemperatureThreshold, value);
  }

  // ========== Touch阈值变化量 ==========
  int get touchThreshold => _prefs?.getInt(_keyTouchThreshold) ?? defaultTouchThreshold;
  Future<void> setTouchThreshold(int value) async {
    await _prefs?.setInt(_keyTouchThreshold, value);
  }

  // ========== EMMC最小容量 (GB) ==========
  double get emmcMinCapacityGb => _prefs?.getDouble(_keyEmmcMinCapacityGb) ?? defaultEmmcMinCapacityGb;
  Future<void> setEmmcMinCapacityGb(double value) async {
    await _prefs?.setDouble(_keyEmmcMinCapacityGb, value);
  }
  
  /// EMMC最小容量（字节）- 用于与设备返回的字节数比对
  int get emmcMinCapacityBytes => (emmcMinCapacityGb * 1024 * 1024 * 1024).toInt();

  // ========== GPIB地址 ==========
  String get gpibAddress => _prefs?.getString(_keyGpibAddress) ?? defaultGpibAddress;
  Future<void> setGpibAddress(String value) async {
    await _prefs?.setString(_keyGpibAddress, value);
  }

  // ========== WiFi SSID ==========
  String get wifiSsid => _prefs?.getString(_keyWifiSsid) ?? defaultWifiSsid;
  Future<void> setWifiSsid(String value) async {
    await _prefs?.setString(_keyWifiSsid, value);
  }

  // ========== WiFi 密码 ==========
  String get wifiPassword => _prefs?.getString(_keyWifiPassword) ?? defaultWifiPassword;
  Future<void> setWifiPassword(String value) async {
    await _prefs?.setString(_keyWifiPassword, value);
  }

  // ========== 产品线代码 ==========
  String get productLine => _prefs?.getString(_keyProductLine) ?? defaultProductLine;
  Future<void> setProductLine(String value) async {
    await _prefs?.setString(_keyProductLine, value);
  }

  // ========== 工厂代码 ==========
  String get factory => _prefs?.getString(_keyFactory) ?? defaultFactory;
  Future<void> setFactory(String value) async {
    await _prefs?.setString(_keyFactory, value);
  }

  // ========== 产线代码 ==========
  String get productionLine => _prefs?.getString(_keyProductionLine) ?? defaultProductionLine;
  Future<void> setProductionLine(String value) async {
    await _prefs?.setString(_keyProductionLine, value);
  }

  // ========== BYD MES 服务器 IP ==========
  String get bydMesIp => _prefs?.getString(_keyBydMesIp) ?? defaultBydMesIp;
  Future<void> setBydMesIp(String value) async {
    await _prefs?.setString(_keyBydMesIp, value);
  }

  // ========== BYD MES 客户端 ID ==========
  String get bydMesClientId => _prefs?.getString(_keyBydMesClientId) ?? defaultBydMesClientId;
  Future<void> setBydMesClientId(String value) async {
    await _prefs?.setString(_keyBydMesClientId, value);
  }

  // ========== BYD MES 站点名称 ==========
  String get bydMesStation => _prefs?.getString(_keyBydMesStation) ?? defaultBydMesStation;
  Future<void> setBydMesStation(String value) async {
    await _prefs?.setString(_keyBydMesStation, value);
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
    await setEmmcMinCapacityGb(defaultEmmcMinCapacityGb);
    await setGpibAddress(defaultGpibAddress);
    await setWifiSsid(defaultWifiSsid);
    await setWifiPassword(defaultWifiPassword);
    await setProductLine(defaultProductLine);
    await setFactory(defaultFactory);
    await setProductionLine(defaultProductionLine);
    await setBydMesIp(defaultBydMesIp);
    await setBydMesClientId(defaultBydMesClientId);
    await setBydMesStation(defaultBydMesStation);
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
      'EMMC最小容量': '≥${emmcMinCapacityGb}GB',
      'GPIB地址': gpibAddress,
      'WiFi SSID': wifiSsid.isEmpty ? '(未配置)' : wifiSsid,
      'WiFi 密码': wifiPassword.isEmpty ? '(未配置)' : '******',
      '产品线': productLine,
      '工厂': factory,
      '产线': productionLine,
      'BYD MES IP': bydMesIp,
      'BYD MES Client ID': bydMesClientId,
      'BYD MES 站点': bydMesStation,
    };
  }
}
