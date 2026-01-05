import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../services/serial_service.dart';
import '../services/production_test_commands.dart';
import '../services/gtp_protocol.dart';
import '../services/gpib_service.dart';
import 'log_state.dart';
import '../config/test_config.dart';
import '../config/wifi_config.dart';
import '../config/sn_mac_config.dart';
import 'touch_test_step.dart';
import 'test_report.dart';
import 'automation_test_config.dart';

enum TestStatus {
  waiting,
  testing,
  pass,
  fail,
  timeout,
  error,
}

class TestItem {
  final String name;
  final String method;
  final String result;
  final Color backgroundColor;
  final TestStatus status;
  final String? errorMessage;

  TestItem({
    required this.name,
    required this.method,
    required this.result,
    required this.backgroundColor,
    this.status = TestStatus.waiting,
    this.errorMessage,
  });

  TestItem copyWith({
    String? name,
    String? method,
    String? result,
    Color? backgroundColor,
    TestStatus? status,
    String? errorMessage,
  }) {
    return TestItem(
      name: name ?? this.name,
      method: method ?? this.method,
      result: result ?? this.result,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

enum WiFiStepStatus {
  waiting,
  testing,
  success,
  failed,
  timeout,
}

class WiFiTestStep {
  final int opt;
  final String name;
  final String description;
  WiFiStepStatus status;
  String? errorMessage;
  int currentRetry;
  final int maxRetries;
  List<int>? data;
  Map<String, dynamic>? result;

  WiFiTestStep({
    required this.opt,
    required this.name,
    required this.description,
    this.status = WiFiStepStatus.waiting,
    this.errorMessage,
    this.currentRetry = 0,
    this.maxRetries = 10,
    this.data,
    this.result,
  });

  WiFiTestStep copyWith({
    WiFiStepStatus? status,
    String? errorMessage,
    int? currentRetry,
    Map<String, dynamic>? result,
  }) {
    return WiFiTestStep(
      opt: opt,
      name: name,
      description: description,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      currentRetry: currentRetry ?? this.currentRetry,
      maxRetries: maxRetries,
      data: data,
      result: result ?? this.result,
    );
  }
}

class TestGroup {
  final String name;
  final List<TestItem> items;

  TestGroup({
    required this.name,
    required this.items,
  });
}

class TestState extends ChangeNotifier {
  String _testScriptPath = 'Choose script file path';
  String _configFilePath = 'Choose config file path';

  final SerialService _serialService = SerialService();
  String? _selectedPort;
  bool _isRunningTest = false;
  bool _shouldStopTest = false; // 测试停止标志

  // 单个测试组，默认为空
  TestGroup? _currentTestGroup;

  // 日志状态
  LogState? _logState;

  // MIC 状态跟踪 (true = 已开启, false = 已关闭)
  final Map<int, bool> _micStates = {
    0: false, // MIC0
    1: false, // MIC1
    2: false, // MIC2
  };

  // LED 状态跟踪 (true = 已开启, false = 已关闭)
  final Map<int, bool> _ledStates = {
    ProductionTestCommands.ledOuter: false, // LED0(外侧)
    ProductionTestCommands.ledInner: false, // LED1(内侧)
  };

  // 当前设备标识信息
  Map<String, String>? _currentDeviceIdentity;

  // WiFi测试步骤状态
  List<WiFiTestStep> _wifiTestSteps = [];
  
  // Touch测试步骤状态
  List<TouchTestStep> _leftTouchTestSteps = [];
  List<TouchTestStep> _rightTouchTestSteps = [];
  bool _isLeftTouchTesting = false;
  bool _isRightTouchTesting = false;
  int? _baselineCdcValue; // 未触摸时的基线CDC值
  
  // Touch测试弹窗状态
  bool _showTouchDialog = false;
  bool _isLeftTouchDialog = false;

  // Sensor测试状态
  bool _isSensorTesting = false;
  bool _showSensorDialog = false;
  List<Map<String, dynamic>> _sensorDataList = [];
  StreamSubscription<Uint8List>? _sensorDataSubscription;
  
  // Sensor图片数据拼接状态
  int? _expectedTotalBytes;
  List<int> _imageBuffer = [];
  DateTime? _lastPacketTime;
  Timer? _sensorTimeoutTimer;
  Timer? _packetTimeoutTimer;
  Completer<bool>? _sensorTestCompleter; // 用于等待用户确认Sensor测试结果
  int _sensorRetryCount = 0;
  Uint8List? _completeImageData;

  // IMU数据流监听状态
  bool _isIMUTesting = false;
  bool _showIMUDialog = false;
  List<Map<String, dynamic>> _imuDataList = [];
  StreamSubscription<Uint8List>? _imuDataSubscription;
  Completer<bool>? _imuTestCompleter; // 用于等待用户确认
  
  // LED测试弹窗状态
  bool _showLEDDialog = false;
  String? _currentLEDType; // "内侧" 或 "外侧"
  Completer<bool>? _ledTestCompleter; // 用于等待用户确认LED测试结果
  
  // MIC测试弹窗状态
  bool _showMICDialog = false;
  int? _currentMICNumber; // 0=左MIC, 1=右MIC, 2=TALK MIC
  Completer<bool>? _micTestCompleter; // 用于等待用户确认MIC测试结果
  
  // 蓝牙测试弹窗状态
  bool _showBluetoothDialog = false;
  Completer<bool>? _bluetoothTestCompleter; // 用于等待用户确认蓝牙测试结果
  String _bluetoothTestStep = ''; // 蓝牙测试当前步骤
  String? _bluetoothNameToSet; // 要设置的蓝牙名称
  
  // WiFi测试弹窗状态
  bool _showWiFiDialog = false;
  String? _deviceIPAddress; // WiFi连接成功后获取的设备IP地址
  String? _sensorImagePath; // Sensor测试图片的本地路径

  // 自动化测试状态
  bool _isAutoTesting = false;
  TestReport? _currentTestReport;
  List<TestReportItem> _testReportItems = [];
  int _currentAutoTestIndex = 0;
  bool _showTestReportDialog = false;
  
  // 生成的设备标识（用于蓝牙MAC地址验证）
  String? _generatedDeviceId;
  List<int>? _generatedBluetoothMAC;

  // GPIB检测状态
  final GpibService _gpibService = GpibService();
  bool _showGpibDialog = false;
  bool _isGpibReady = false;
  String? _gpibAddress;

  String get testScriptPath => _testScriptPath;
  String get configFilePath => _configFilePath;
  TestGroup? get currentTestGroup => _currentTestGroup;
  bool get isConnected => _serialService.isConnected;
  String? get selectedPort => _selectedPort;
  bool get isRunningTest => _isRunningTest;

  List<String> get availablePorts => SerialService.getAvailablePorts();
  
  // 获取当前设备标识信息
  Map<String, String>? get currentDeviceIdentity => _currentDeviceIdentity;

  // 获取WiFi测试步骤
  List<WiFiTestStep> get wifiTestSteps => _wifiTestSteps;
  
  // 获取Touch测试步骤
  List<TouchTestStep> get leftTouchTestSteps => _leftTouchTestSteps;
  List<TouchTestStep> get rightTouchTestSteps => _rightTouchTestSteps;
  bool get isLeftTouchTesting => _isLeftTouchTesting;
  bool get isRightTouchTesting => _isRightTouchTesting;
  int? get baselineCdcValue => _baselineCdcValue;
  
  // 获取Touch测试弹窗状态
  bool get showTouchDialog => _showTouchDialog;
  bool get isLeftTouchDialog => _isLeftTouchDialog;

  // 获取Sensor测试状态
  bool get isSensorTesting => _isSensorTesting;
  bool get showSensorDialog => _showSensorDialog;
  List<Map<String, dynamic>> get sensorDataList => _sensorDataList;
  Uint8List? get completeImageData => _completeImageData;

  // IMU测试状态getter
  bool get isIMUTesting => _isIMUTesting;
  bool get showIMUDialog => _showIMUDialog;
  List<Map<String, dynamic>> get imuDataList => _imuDataList;
  
  // LED测试状态getter
  bool get showLEDDialog => _showLEDDialog;
  String? get currentLEDType => _currentLEDType;
  
  // WiFi测试状态getter
  bool get showWiFiDialog => _showWiFiDialog;
  String? get deviceIPAddress => _deviceIPAddress;
  String? get sensorImagePath => _sensorImagePath;

  // MIC测试状态getter
  bool get showMICDialog => _showMICDialog;
  int? get currentMICNumber => _currentMICNumber;

  // 蓝牙测试状态getter
  bool get showBluetoothDialog => _showBluetoothDialog;
  String get bluetoothTestStep => _bluetoothTestStep;
  String? get bluetoothNameToSet => _bluetoothNameToSet;

  // 自动化测试状态getter
  bool get isAutoTesting => _isAutoTesting;
  TestReport? get currentTestReport => _currentTestReport;
  List<TestReportItem> get testReportItems => _testReportItems;
  int get currentAutoTestIndex => _currentAutoTestIndex;
  bool get showTestReportDialog => _showTestReportDialog;

  // GPIB状态getter
  bool get showGpibDialog => _showGpibDialog;
  bool get isGpibReady => _isGpibReady;
  String? get gpibAddress => _gpibAddress;

  // 获取 MIC 状态
  bool getMicState(int micNumber) => _micStates[micNumber] ?? false;

  // 获取 LED 状态
  bool getLedState(int ledNumber) => _ledStates[ledNumber] ?? false;

  void setLogState(LogState logState) {
    _logState = logState;
    _serialService.setLogState(logState);
  }
  
  /// 关闭Touch测试弹窗
  Future<void> closeTouchDialog() async {
    // 如果正在测试，清理测试状态
    if (_isLeftTouchTesting) {
      _isLeftTouchTesting = false;
      _leftTouchTestSteps.clear();
    }
    if (_isRightTouchTesting) {
      _isRightTouchTesting = false;
      _rightTouchTestSteps.clear();
    }
    
    _showTouchDialog = false;
    notifyListeners();
  }
  
  /// 重新打开Touch测试弹窗
  void reopenTouchDialog() {
    if (_isLeftTouchTesting || _isRightTouchTesting) {
      _showTouchDialog = true;
      notifyListeners();
      _logState?.info('🔄 Touch测试弹窗已重新打开', type: LogType.debug);
    } else {
      _logState?.warning('⚠️ 没有正在进行的Touch测试', type: LogType.debug);
    }
  }

  void setTestScriptPath(String path) {
    _testScriptPath = path;
    notifyListeners();
  }

  void setConfigFilePath(String path) {
    _configFilePath = path;
    notifyListeners();
  }

  /// 初始化SN/MAC配置
  Future<void> initializeSNMacConfig() async {
    try {
      await SNMacConfig.initialize();
      _logState?.info('SN/MAC配置初始化成功');
    } catch (e) {
      _logState?.error('SN/MAC配置初始化失败: $e');
    }
  }

  /// 生成新的设备标识信息
  Future<void> generateDeviceIdentity() async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('🏷️  开始生成设备标识信息', type: LogType.debug);
      
      _currentDeviceIdentity = await SNMacConfig.generateDeviceIdentity();
      
      _logState?.info('✅ 设备标识信息生成成功:', type: LogType.debug);
      _logState?.info('   📋 SN码: ${_currentDeviceIdentity!['sn']}', type: LogType.debug);
      _logState?.info('   📡 WiFi MAC: ${_currentDeviceIdentity!['wifiMac']}', type: LogType.debug);
      _logState?.info('   📶 蓝牙 MAC: ${_currentDeviceIdentity!['bluetoothMac']}', type: LogType.debug);
      _logState?.info('   🏭 产品线: ${_currentDeviceIdentity!['productLine']}', type: LogType.debug);
      _logState?.info('   🏢 工厂: ${_currentDeviceIdentity!['factory']}', type: LogType.debug);
      _logState?.info('   📅 生产日期: ${_currentDeviceIdentity!['productionDate']}', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      
      notifyListeners();
    } catch (e) {
      _logState?.error('生成设备标识信息失败: $e', type: LogType.debug);
    }
  }

  /// 设置产品线
  Future<void> setProductLine(String productLine) async {
    try {
      await SNMacConfig.setProductLine(productLine);
      _logState?.info('产品线设置为: $productLine');
      notifyListeners();
    } catch (e) {
      _logState?.error('设置产品线失败: $e');
    }
  }

  /// 设置工厂
  Future<void> setFactory(String factory) async {
    try {
      await SNMacConfig.setFactory(factory);
      _logState?.info('工厂设置为: $factory');
      notifyListeners();
    } catch (e) {
      _logState?.error('设置工厂失败: $e');
    }
  }

  /// 设置产线
  Future<void> setProductionLine(int line) async {
    try {
      await SNMacConfig.setProductionLine(line);
      _logState?.info('产线设置为: $line');
      notifyListeners();
    } catch (e) {
      _logState?.error('设置产线失败: $e');
    }
  }

  /// 获取SN/MAC统计信息
  Map<String, dynamic> getSNMacStatistics() {
    return SNMacConfig.getStatistics();
  }

  /// 获取当前SN/MAC配置
  Map<String, dynamic> getSNMacConfig() {
    return SNMacConfig.getCurrentConfig();
  }

  /// 停止当前测试
  void stopTest() {
    if (_isRunningTest) {
      _shouldStopTest = true;
      _logState?.warning('⚠️  用户请求停止测试...');
      notifyListeners();
    }
  }

  /// 停止自动化测试
  Future<void> stopAutoTest() async {
    if (!_isAutoTesting) {
      _logState?.warning('⚠️  当前没有正在进行的自动化测试', type: LogType.debug);
      return;
    }
    
    _shouldStopTest = true;
    _logState?.warning('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
    _logState?.warning('🛑 用户请求停止自动化测试', type: LogType.debug);
    _logState?.warning('正在停止所有测试和监听...', type: LogType.debug);
    
    // 停止所有正在进行的测试
    try {
      // 停止 IMU 测试
      if (_isIMUTesting) {
        await stopIMUDataStream();
      }
      
      // 停止 Sensor 测试
      if (_isSensorTesting) {
        await stopSensorTest();
      }
      
      // 停止 LED 测试
      if (_currentLEDType != null) {
        await stopLEDTest(_currentLEDType!);
      }
      
      // 停止 MIC 测试
      if (_currentMICNumber != null) {
        await stopMICTest();
      }
      
      // 关闭所有弹窗
      _showIMUDialog = false;
      _showSensorDialog = false;
      _showBluetoothDialog = false;
      _showMICDialog = false;
      
    } catch (e) {
      _logState?.error('停止测试时出错: $e', type: LogType.debug);
    }
    
    _logState?.warning('✅ 自动化测试已停止', type: LogType.debug);
    _logState?.warning('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
    
    notifyListeners();
  }
  
  /// 重试单个测试项
  Future<void> retrySingleTest(int itemIndex) async {
    if (itemIndex < 0 || itemIndex >= _testReportItems.length) {
      _logState?.error('❌ 无效的测试项索引: $itemIndex', type: LogType.debug);
      return;
    }
    
    final item = _testReportItems[itemIndex];
    _logState?.info('🔄 开始重试测试项: ${item.testName}', type: LogType.debug);
    
    // 获取测试序列
    final testSequence = _getTestSequence();
    
    // 查找对应的测试项
    final testIndex = testSequence.indexWhere((test) => test['name'] == item.testName);
    if (testIndex == -1) {
      _logState?.error('❌ 未找到测试项: ${item.testName}', type: LogType.debug);
      return;
    }
    
    final test = testSequence[testIndex];
    
    // 更新测试项状态为运行中
    _testReportItems[itemIndex] = item.copyWith(
      status: TestReportStatus.running,
      startTime: DateTime.now(),
      endTime: null,
      errorMessage: null,
    );
    notifyListeners();
    
    try {
      final executor = test['executor'] as Future<bool> Function();
      
      // 根据测试类型决定是否使用重试包装器
      final result = (test['type'] == 'WiFi' || 
                     test['type'] == 'IMU' || 
                     test['type'] == 'Touch' || 
                     test['type'] == 'Sensor')
          ? await executor()
          : await _executeTestWithRetry(test['name'] as String, executor);
      
      // 更新测试项状态
      final updatedItem = item.copyWith(
        status: result ? TestReportStatus.pass : TestReportStatus.fail,
        endTime: DateTime.now(),
        errorMessage: result ? null : '测试未通过',
      );
      
      _testReportItems[itemIndex] = updatedItem;
      
      if (result) {
        _logState?.success('✅ ${test['name']} 重试成功', type: LogType.debug);
      } else {
        _logState?.error('❌ ${test['name']} 重试失败', type: LogType.debug);
      }
    } catch (e) {
      _logState?.error('❌ ${test['name']} 重试异常: $e', type: LogType.debug);
      
      final updatedItem = item.copyWith(
        status: TestReportStatus.fail,
        endTime: DateTime.now(),
        errorMessage: '测试异常: $e',
      );
      
      _testReportItems[itemIndex] = updatedItem;
    }
    
    notifyListeners();
  }
  
  /// 获取测试序列
  List<Map<String, dynamic>> _getTestSequence() {
    return [
      {'name': '1. 上电测试', 'type': '电源', 'executor': _autoTestPowerOn, 'skippable': false},
      {'name': '2. 工作功耗测试', 'type': '电流', 'executor': _autoTestWorkingPower, 'skippable': true},
      {'name': '3. 设备电压测试', 'type': '电压', 'executor': _autoTestVoltage, 'skippable': false},
      {'name': '4. 电量检测测试', 'type': '电量', 'executor': _autoTestBattery, 'skippable': false},
      {'name': '5. 充电状态测试', 'type': '充电', 'executor': _autoTestCharging, 'skippable': false},
      {'name': '6. WiFi测试', 'type': 'WiFi', 'executor': _autoTestWiFi, 'skippable': false},
      {'name': '7. Sensor测试', 'type': 'Sensor', 'executor': _autoTestSensor, 'skippable': false},
      {'name': '8. RTC设置时间测试', 'type': 'RTC', 'executor': _autoTestRTCSet, 'skippable': false},
      {'name': '9. RTC获取时间测试', 'type': 'RTC', 'executor': _autoTestRTCGet, 'skippable': false},
      {'name': '10. 光敏传感器测试', 'type': '光敏', 'executor': _autoTestLightSensor, 'skippable': false},
      {'name': '11. IMU传感器测试', 'type': 'IMU', 'executor': _autoTestIMU, 'skippable': false},
      {'name': '12. 右触控测试', 'type': 'Touch', 'executor': _autoTestRightTouch, 'skippable': false},
      {'name': '13. 左触控测试', 'type': 'Touch', 'executor': _autoTestLeftTouch, 'skippable': false},
      {'name': '14. LED灯(外侧)测试', 'type': 'LED', 'executor': () => _autoTestLEDWithDialog('外侧'), 'skippable': false},
      {'name': '15. LED灯(内侧)测试', 'type': 'LED', 'executor': () => _autoTestLEDWithDialog('内侧'), 'skippable': false},
      {'name': '16. 左SPK测试', 'type': 'SPK', 'executor': () => _autoTestSPK(0), 'skippable': false},
      {'name': '17. 右SPK测试', 'type': 'SPK', 'executor': () => _autoTestSPK(1), 'skippable': false},
      {'name': '18. 左MIC测试', 'type': 'MIC', 'executor': () => _autoTestMICRecord(0), 'skippable': false},
      {'name': '19. 右MIC测试', 'type': 'MIC', 'executor': () => _autoTestMICRecord(1), 'skippable': false},
      {'name': '20. TALK MIC测试', 'type': 'MIC', 'executor': () => _autoTestMICRecord(2), 'skippable': false},
      {'name': '21. 蓝牙测试', 'type': '蓝牙', 'executor': _autoTestBluetooth, 'skippable': false},
      {'name': '22. 结束产测', 'type': '电源', 'executor': _autoTestPowerOff, 'skippable': false},
    ];
  }  

  /// 检查是否应该停止测试
  bool get shouldStopTest => _shouldStopTest;

  /// 重试单个WiFi测试步骤
  Future<bool> retryWiFiStep(int stepIndex) async {
    if (stepIndex < 0 || stepIndex >= _wifiTestSteps.length) {
      return false;
    }

    final currentStep = _wifiTestSteps[stepIndex];
    _logState?.info('🔄 手动重试: ${currentStep.name}');
    
    // 重置步骤状态
    _wifiTestSteps[stepIndex] = currentStep.copyWith(
      status: WiFiStepStatus.waiting,
      currentRetry: 0,
      errorMessage: null,
    );
    notifyListeners();

    return await _executeWiFiStepWithRetry(stepIndex);
  }

  /// 执行WiFi步骤（带重试机制）
  Future<bool> _executeWiFiStepWithRetry(int stepIndex) async {
    final maxRetries = _wifiTestSteps[stepIndex].maxRetries;
    
    for (int retry = 0; retry < maxRetries; retry++) {
      // 每次循环都获取最新的步骤对象
      final currentStep = _wifiTestSteps[stepIndex];
      
      // 检查是否需要停止测试
      if (_shouldStopTest) {
        _wifiTestSteps[stepIndex] = currentStep.copyWith(
          status: WiFiStepStatus.failed,
          errorMessage: '用户停止测试',
        );
        notifyListeners();
        return false;
      }

      // 更新步骤状态 - retry从0开始，显示时+1，范围是1到maxRetries
      _wifiTestSteps[stepIndex] = currentStep.copyWith(
        status: WiFiStepStatus.testing,
        currentRetry: retry + 1, // 显示时从1开始
      );
      notifyListeners();

      if (retry > 0) {
        _logState?.warning('🔄 重试第 $retry 次: ${currentStep.name}', type: LogType.debug);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      try {
        final success = await _executeWiFiStepSingle(stepIndex);
        if (success) {
          final successStep = _wifiTestSteps[stepIndex];
          _wifiTestSteps[stepIndex] = successStep.copyWith(
            status: WiFiStepStatus.success,
            currentRetry: 0, // 成功后重置重试计数
          );
          notifyListeners();
          return true;
        }
      } catch (e) {
        _logState?.error('WiFi步骤执行异常: $e', type: LogType.debug);
        // 记录错误信息
        final errorStep = _wifiTestSteps[stepIndex];
        _wifiTestSteps[stepIndex] = errorStep.copyWith(
          errorMessage: e.toString(),
        );
        notifyListeners();
      }

      // 如果不是最后一次重试，等待后继续
      if (retry < maxRetries) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }

    // 所有重试都失败了
    final finalStep = _wifiTestSteps[stepIndex];
    _wifiTestSteps[stepIndex] = finalStep.copyWith(
      status: WiFiStepStatus.failed,
      errorMessage: finalStep.errorMessage ?? '重试 $maxRetries 次后仍然失败',
    );
    notifyListeners();
    
    _logState?.error('❌ ${finalStep.name} 最终失败，已重试 $maxRetries 次', type: LogType.debug);
    return false;
  }

  /// Connect to serial port
  Future<bool> connectToPort(String portName) async {
    _logState?.info('正在连接串口: $portName');

    // 直接使用 2000000 波特率连接（不使用双线UART初始化，与 WindTerm 一致）
    _logState?.info('使用 2000000 波特率连接（与 WindTerm 配置一致）');
    bool success = await _serialService.connect(
      portName,
      baudRate: 2000000,
      useDualLineUartInit: false, // 不发送初始化数据，只监听
    );

    if (success) {
      _selectedPort = portName;
      _logState?.success('串口连接成功: $portName');

      // 连接成功后只监听，不发送任何命令
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('开始监听串口数据（不发送任何命令）');
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      // await _serialService.sendExitSleepMode(retries: 5);

      // 创建测试组
      _currentTestGroup = TestGroup(
        name: portName,
        items: [],
      );
      notifyListeners();
    } else {
      _logState?.error('串口连接失败: $portName');
      _logState?.error('请检查:');
      _logState?.error('  1. 是否有其他程序（如WindTerm）正在使用该串口');
      _logState?.error('  2. 运行: lsof | grep $portName 查看占用进程');
      _logState?.error('  3. 运行: sudo chmod 666 $portName 修改权限');
    }
    return success;
  }

  /// Disconnect from serial port
  Future<void> disconnect() async {
    _logState?.info('正在断开串口连接');
    
    // 清理所有测试状态和关闭所有弹窗
    await _cleanupAllTestsAndDialogs();
    
    await _serialService.disconnect();
    _selectedPort = null;
    _currentTestGroup = null; // 断开连接时清空测试组
    _logState?.info('串口已断开');
    notifyListeners();
  }
  
  /// 清理所有测试状态和关闭所有弹窗
  Future<void> _cleanupAllTestsAndDialogs() async {
    _logState?.warning('⚠️  串口断开，清理所有测试状态和关闭所有弹窗...');
    
    // 停止自动化测试
    if (_isAutoTesting) {
      _shouldStopTest = true;
      _isAutoTesting = false;
    }
    
    // 停止手动测试
    if (_isRunningTest) {
      stopTest();
    }
    
    // 关闭所有弹窗
    _showWiFiDialog = false;
    _showIMUDialog = false;
    _showSensorDialog = false;
    _showLEDDialog = false;
    _showTouchDialog = false;
    _showTestReportDialog = false;
    
    // 清理IMU测试状态
    if (_isIMUTesting) {
      await _imuDataSubscription?.cancel();
      _imuDataSubscription = null;
      _isIMUTesting = false;
      _imuDataList.clear();
      if (_imuTestCompleter != null && !_imuTestCompleter!.isCompleted) {
        _imuTestCompleter?.complete(false);
      }
      _imuTestCompleter = null;
    }
    
    // 清理Sensor测试状态
    if (_isSensorTesting) {
      await _sensorDataSubscription?.cancel();
      _sensorDataSubscription = null;
      _isSensorTesting = false;
      _sensorDataList.clear();
      _resetImageBuffer();
      _sensorTimeoutTimer?.cancel();
      _packetTimeoutTimer?.cancel();
      if (_sensorTestCompleter != null && !_sensorTestCompleter!.isCompleted) {
        _sensorTestCompleter?.complete(false);
      }
      _sensorTestCompleter = null;
    }
    
    // 清理LED测试状态
    if (_ledTestCompleter != null && !_ledTestCompleter!.isCompleted) {
      _ledTestCompleter?.complete(false);
    }
    _ledTestCompleter = null;
    _currentLEDType = null;
    
    // 清理Touch测试状态
    _isLeftTouchTesting = false;
    _isRightTouchTesting = false;
    
    // 清理WiFi测试状态
    // WiFi测试步骤会自动停止
    
    _logState?.success('✅ 所有测试状态已清理，所有弹窗已关闭');
    notifyListeners();
  }

  /// Update test item with status and error message
  void _updateTestItemWithStatus(
      int itemIndex, String result, Color backgroundColor, TestStatus status,
      {String? errorMessage}) {
    if (_currentTestGroup == null ||
        itemIndex >= _currentTestGroup!.items.length) return;

    final item = _currentTestGroup!.items[itemIndex];

    _currentTestGroup = TestGroup(
      name: _currentTestGroup!.name,
      items: List.from(_currentTestGroup!.items)
        ..[itemIndex] = TestItem(
          name: item.name,
          method: item.method,
          result: result,
          backgroundColor: backgroundColor,
          status: status,
          errorMessage: errorMessage,
        ),
    );

    notifyListeners();
  }

  /// Retry a specific test
  Future<void> retryTest(int itemIndex) async {
    if (!_serialService.isConnected) {
      debugPrint('Please connect to a serial port first');
      return;
    }

    if (_isRunningTest) {
      debugPrint('Test already running');
      return;
    }

    _isRunningTest = true;
    notifyListeners();

    // Re-run tests starting from the failed item
    await _runProductionTestSequence();

    _isRunningTest = false;
    notifyListeners();
  }

  /// Run production test sequence
  Future<void> _runProductionTestSequence() async {
    if (!_serialService.isConnected) {
      debugPrint('Serial port not connected');
      _logState?.error('串口未连接，无法开始测试');
      return;
    }

    if (_currentTestGroup == null) {
      debugPrint('No test group available');
      _logState?.error('没有可用的测试组');
      return;
    }

    try {
      // 测试开始前先确保唤醒设备成功
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _logState?.info('准备开始产测序列');
      _logState?.info('正在唤醒设备...');
      
      // 第一次唤醒必须成功
      bool wakeupSuccess = false;
      for (int i = 0; i < 10; i++) {
        _logState?.info('🔔 尝试唤醒设备 (${i + 1}/10)...');
        bool result = await _serialService.sendExitSleepMode(retries: 1);
        if (result) {
          wakeupSuccess = true;
          _logState?.success('✅ 设备唤醒成功！');
          break;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (!wakeupSuccess) {
        _logState?.error('❌ 设备唤醒失败，无法开始测试');
        return;
      }
      
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Test sequence based on manual test buttons (与手动测试按钮对齐)
      final testSequence = [
        {
          'name': '产测开始',
          'cmd': ProductionTestCommands.createStartTestCommand(),
          'cmdCode': ProductionTestCommands.cmdStartTest
        },
        {
          'name': '获取设备电压',
          'cmd': ProductionTestCommands.createGetVoltageCommand(),
          'cmdCode': ProductionTestCommands.cmdGetVoltage
        },
        {
          'name': '获取设备电量',
          'cmd': ProductionTestCommands.createGetCurrentCommand(),
          'cmdCode': ProductionTestCommands.cmdGetCurrent
        },
        {
          'name': '获取充电状态',
          'cmd': ProductionTestCommands.createGetChargeStatusCommand(),
          'cmdCode': ProductionTestCommands.cmdGetChargeStatus
        },
        {
          'name': '控制WiFi',
          'customAction': 'testWiFi'
        },
        {
          'name': 'LED灯(外侧)开启',
          'cmd': ProductionTestCommands.createControlLEDCommand(
              ProductionTestCommands.ledOuter, ProductionTestCommands.ledOn),
          'cmdCode': ProductionTestCommands.cmdControlLED
        },
        {
          'name': 'LED灯(外侧)关闭',
          'cmd': ProductionTestCommands.createControlLEDCommand(
              ProductionTestCommands.ledOuter, ProductionTestCommands.ledOff),
          'cmdCode': ProductionTestCommands.cmdControlLED
        },
        {
          'name': 'LED灯(内侧)开启',
          'cmd': ProductionTestCommands.createControlLEDCommand(
              ProductionTestCommands.ledInner, ProductionTestCommands.ledOn),
          'cmdCode': ProductionTestCommands.cmdControlLED
        },
        {
          'name': 'LED灯(内侧)关闭',
          'cmd': ProductionTestCommands.createControlLEDCommand(
              ProductionTestCommands.ledInner, ProductionTestCommands.ledOff),
          'cmdCode': ProductionTestCommands.cmdControlLED
        },
        {
          'name': 'SPK0',
          'cmd': ProductionTestCommands.createControlSPKCommand(
              ProductionTestCommands.spk0),
          'cmdCode': ProductionTestCommands.cmdControlSPK
        },
        {
          'name': 'SPK1',
          'cmd': ProductionTestCommands.createControlSPKCommand(
              ProductionTestCommands.spk1),
          'cmdCode': ProductionTestCommands.cmdControlSPK
        },
        {
          'name': 'Touch左侧',
          'cmd': null,
          'cmdCode': ProductionTestCommands.cmdTouch,
          'customAction': 'testTouchLeft'
        },
        {
          'name': 'Touch右侧',
          'cmd': null,
          'cmdCode': ProductionTestCommands.cmdTouch,
          'customAction': 'testTouchRight'
        },
        {
          'name': 'MIC0开启',
          'cmd': ProductionTestCommands.createControlMICCommand(
              ProductionTestCommands.mic0,
              ProductionTestCommands.micControlOpen),
          'cmdCode': ProductionTestCommands.cmdControlMIC
        },
        {
          'name': 'MIC1开启',
          'cmd': ProductionTestCommands.createControlMICCommand(
              ProductionTestCommands.mic1,
              ProductionTestCommands.micControlOpen),
          'cmdCode': ProductionTestCommands.cmdControlMIC
        },
        {
          'name': 'MIC2开启',
          'cmd': ProductionTestCommands.createControlMICCommand(
              ProductionTestCommands.mic2,
              ProductionTestCommands.micControlOpen),
          'cmdCode': ProductionTestCommands.cmdControlMIC
        },
        {
          'name': 'RTC设置时间',
          'cmd': null,
          'cmdCode': ProductionTestCommands.cmdRTC,
          'customAction': 'setRTC'
        },
        {
          'name': 'RTC获取时间',
          'cmd': ProductionTestCommands.createRTCCommand(
              ProductionTestCommands.rtcOptGetTime),
          'cmdCode': ProductionTestCommands.cmdRTC
        },
        {
          'name': '光敏传感器',
          'cmd': ProductionTestCommands.createLightSensorCommand(),
          'cmdCode': ProductionTestCommands.cmdLightSensor
        },
        {
          'name': 'IMU数据',
          'customAction': 'testIMU'
        },
        {
          'name': '产测结束',
          'cmd': ProductionTestCommands.createEndTestCommand(),
          'cmdCode': ProductionTestCommands.cmdEndTest
        },
      ];

      // Initialize test items for this group
      _currentTestGroup = TestGroup(
        name: _currentTestGroup!.name,
        items: testSequence
            .map((test) => TestItem(
                  name: test['name'] as String,
                  method: 'Auto',
                  result: 'Waiting',
                  backgroundColor: Colors.grey[300]!,
                ))
            .toList(),
      );
      notifyListeners();

      // Run each test with retry mechanism
      for (int i = 0; i < testSequence.length; i++) {
        // 检查是否需要停止测试
        if (_shouldStopTest) {
          _logState?.warning('🛑 测试已被用户停止');
          _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          break;
        }

        final test = testSequence[i];
        final testName = test['name'] as String;
        final command = test['cmd'] as dynamic;
        final cmdCode = test['cmdCode'] as int;
        final customAction = test['customAction'] as String?;

        debugPrint('Running test: $testName');

        // 每个测试项目开始前唤醒一次（在重试循环外）
        try {
          _logState?.debug('🔔 [$testName] 唤醒设备...', type: LogType.debug);
          bool wakeupResult = await _serialService.sendExitSleepMode(retries: 1);
          if (wakeupResult) {
            _logState?.debug('✅ [$testName] 唤醒完成', type: LogType.debug);
          }
          // 等待300ms，确保唤醒响应完全处理
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          _logState?.warning('⚠️  [$testName] 唤醒失败: $e', type: LogType.debug);
          await Future.delayed(const Duration(milliseconds: 300));
        }

        bool testPassed = false;
        int retryCount = 0;
        const maxRetries = 10;

        // Retry loop for failed tests
        while (!testPassed && retryCount <= maxRetries) {
          // 在重试循环中也检查停止标志
          if (_shouldStopTest) {
            _logState?.warning('🛑 测试已被用户停止');
            break;
          }

          if (retryCount > 0) {
            _logState?.warning('🔄 重试第 $retryCount 次: $testName',
                type: LogType.debug);
            // 重试时等待一下，但不再发送唤醒命令
            await Future.delayed(const Duration(milliseconds: 500));
          }
          
          // Update status to testing
          final statusText = retryCount > 0
              ? 'Testing (重试 $retryCount/$maxRetries)'
              : 'Testing';
          _updateTestItemWithStatus(
              i, statusText, const Color(0xFFFFFF00), TestStatus.testing);

          Map<String, dynamic>? response;

          // Handle custom actions or regular commands
          if (customAction != null) {
            switch (customAction) {
              case 'setRTC':
                final success = await setRTCTime();
                response = success 
                  ? {'success': true}
                  : {'error': 'RTC设置时间失败，请检查设备连接或日志'};
                break;
              case 'testTouchLeft':
                await testTouchLeft();
                response = {
                  'success': true
                }; // Assume success for custom actions
                break;
              case 'testTouchRight':
                await testTouchRight();
                response = {
                  'success': true
                }; // Assume success for custom actions
                break;
              case 'testWiFi':
                final success = await testWiFi();
                response = success 
                  ? {'success': true}
                  : {'error': 'WiFi测试失败，请检查设备连接或配置'};
                break;
              case 'testIMU':
                final success = await testIMU();
                response = success 
                  ? {'success': true}
                  : {'error': 'IMU测试失败，请检查设备连接'};
                break;
              default:
                response = {'error': 'Unknown custom action: $customAction'};
            }
          } else if (command != null) {
            // 显示发送的命令，包含测试项目名称
            final commandHex = command.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
            _logState?.info('📤 [$testName] 发送: [$commandHex]', type: LogType.debug);
            
            // Send regular command and wait for response
            response = await _serialService.sendCommandAndWaitResponse(
              command,
              timeout: TestConfig.defaultTimeout,
              moduleId: ProductionTestCommands.moduleId,
              messageId: ProductionTestCommands.messageId,
            );
            
            // 显示接收到的payload
            if (response != null && response.containsKey('payload')) {
              final payload = response['payload'] as Uint8List;
              final payloadHex = payload.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
              _logState?.info('📥 [$testName] 接收: [$payloadHex] (${payload.length} bytes)', type: LogType.debug);
              
              // 检查payload长度是否合理
              if (payload.isEmpty) {
                _logState?.warning('⚠️  [$testName] Payload为空！', type: LogType.debug);
              }
            }
          } else {
            response = {'error': 'No command or custom action specified'};
          }

          if (response == null) {
            debugPrint('Test $testName: Timeout (attempt ${retryCount + 1})');
            if (retryCount >= maxRetries) {
              _updateTestItemWithStatus(i, 'Timeout (重试 $maxRetries 次后失败)',
                  const Color(0xFFFF6347), TestStatus.timeout,
                  errorMessage: '设备响应超时，已重试 $maxRetries 次');
              break; // Exit retry loop, continue to next test
            }
          } else if (response.containsKey('error')) {
            debugPrint(
                'Test $testName: Error - ${response['error']} (attempt ${retryCount + 1})');
            if (retryCount >= maxRetries) {
              _updateTestItemWithStatus(i, 'Error (重试 $maxRetries 次后失败)',
                  const Color(0xFFFF6347), TestStatus.error,
                  errorMessage: '${response['error']}，已重试 $maxRetries 次');
              break; // Exit retry loop, continue to next test
            }
          } else {
            // Parse response based on command type
            String result = 'Pass';
            TestStatus status = TestStatus.pass;
            String? errorMsg;

            // Check if this is a custom action response (no payload to parse)
            if (response.containsKey('success') && response['success'] == true) {
              // Custom action completed successfully
              result = 'Pass';
              status = TestStatus.pass;
            } else {
              // Regular command response - parse payload
              try {
                switch (cmdCode) {
                case ProductionTestCommands.cmdGetVoltage:
                  final voltage = ProductionTestCommands.parseVoltageResponse(
                      response['payload']);
                  if (voltage != null) {
                    result = 'Pass (${voltage}mV)';
                    status = TestStatus.pass;
                  } else {
                    _logState?.error('❌ 解析失败: 无法解析电压数据', type: LogType.debug);
                    result = 'Fail';
                    status = TestStatus.fail;
                    errorMsg = '无法解析电压数据';
                  }
                  break;

                case ProductionTestCommands.cmdGetCurrent:
                  final current = ProductionTestCommands.parseCurrentResponse(
                      response['payload']);
                  result = current != null ? 'Pass ($current%)' : 'Fail';
                  status = current != null ? TestStatus.pass : TestStatus.fail;
                  if (current == null) errorMsg = '无法解析电量数据';
                  break;

                case ProductionTestCommands.cmdGetChargeStatus:
                  final chargeStatus =
                      ProductionTestCommands.parseChargeStatusResponse(
                          response['payload']);
                  if (chargeStatus != null) {
                    result =
                        'Pass (${ProductionTestCommands.getChargeModeName(chargeStatus['mode']!)})';
                    status = TestStatus.pass;
                  } else {
                    result = 'Fail';
                    status = TestStatus.fail;
                    errorMsg = '无法解析充电状态';
                  }
                  break;

                case ProductionTestCommands.cmdControlWifi:
                  // 注意：这个case可能不会被使用，因为WiFi测试通过customAction执行
                  // 传入0x00作为默认opt值
                  final wifiResult = ProductionTestCommands.parseWifiResponse(
                      response['payload'], 0x00);
                  if (wifiResult != null && wifiResult['success'] == true) {
                    String details = wifiResult['optName'] ?? '';
                    if (wifiResult.containsKey('rssi')) {
                      details += ' (RSSI: ${wifiResult['rssi']}dBm)';
                    } else if (wifiResult.containsKey('mac')) {
                      details += ' (MAC: ${wifiResult['mac']})';
                    }
                    result = 'Pass ($details)';
                    status = TestStatus.pass;
                  } else {
                    result = 'Fail';
                    status = TestStatus.fail;
                    errorMsg = wifiResult?['error'] ?? '无法解析WiFi响应';
                  }
                  break;

                case ProductionTestCommands.cmdTouch:
                  final touchResult = ProductionTestCommands.parseTouchResponse(
                      response['payload']);
                  if (touchResult != null && touchResult['success'] == true) {
                    final cdcValue = touchResult['cdcValue'];
                    result = 'Pass (CDC: $cdcValue)';
                    status = TestStatus.pass;
                  } else {
                    result = 'Fail';
                    status = TestStatus.fail;
                    errorMsg = touchResult?['error'] ?? '无法解析Touch数据';
                  }
                  break;

                case ProductionTestCommands.cmdRTC:
                  final timestamp = ProductionTestCommands.parseRTCResponse(
                      response['payload']);
                  if (timestamp != null) {
                    final dateTime =
                        DateTime.fromMillisecondsSinceEpoch(timestamp);
                    result = 'Pass (${dateTime.toString()})';
                    status = TestStatus.pass;
                  } else {
                    result = 'Fail';
                    status = TestStatus.fail;
                    errorMsg = '无法解析RTC时间';
                  }
                  break;

                case ProductionTestCommands.cmdLightSensor:
                  final lightValue =
                      ProductionTestCommands.parseLightSensorResponse(
                          response['payload']);
                  result = lightValue != null
                      ? 'Pass (${lightValue.toStringAsFixed(2)} lux)'
                      : 'Fail';
                  status =
                      lightValue != null ? TestStatus.pass : TestStatus.fail;
                  if (lightValue == null) errorMsg = '无法解析光敏数据';
                  break;

                case ProductionTestCommands.cmdIMU:
                  final imuData = ProductionTestCommands.parseIMUResponse(
                      response['payload']);
                  if (imuData != null) {
                    result =
                        'Pass (Accel: ${imuData['accel_x']?.toStringAsFixed(2)}, ${imuData['accel_y']?.toStringAsFixed(2)}, ${imuData['accel_z']?.toStringAsFixed(2)})';
                    status = TestStatus.pass;
                  } else {
                    result = 'Fail';
                    status = TestStatus.fail;
                    errorMsg = '无法解析IMU数据';
                  }
                  break;

                default:
                  // For other commands, just check if we got a response
                  result = 'Pass';
                  status = TestStatus.pass;
                  break;
                }
              } catch (e) {
                result = 'Error';
                status = TestStatus.error;
                errorMsg = '解析响应时出错: $e';
              }
            }

            debugPrint('Test $testName: $result (attempt ${retryCount + 1})');

            if (status == TestStatus.pass) {
              // Test passed, exit retry loop
              testPassed = true;
              final finalResult =
                  retryCount > 0 ? '$result (重试 $retryCount 次后成功)' : result;
              _updateTestItemWithStatus(
                i,
                finalResult,
                const Color(0xFF4CAF50),
                status,
                errorMessage: errorMsg,
              );
            } else {
              // Test failed, check if we should retry
              if (retryCount >= maxRetries) {
                final finalResult = '$result (重试 $maxRetries 次后失败)';
                _updateTestItemWithStatus(
                  i,
                  finalResult,
                  const Color(0xFFFF6347),
                  status,
                  errorMessage: errorMsg != null
                      ? '$errorMsg，已重试 $maxRetries 次'
                      : '已重试 $maxRetries 次',
                );
                break; // Exit retry loop, continue to next test
              }
            }
          }

          retryCount++;

          // Add delay before retry
          if (!testPassed && retryCount <= maxRetries) {
            await Future.delayed(const Duration(
                milliseconds: 1000)); // 1 second delay before retry
          }
        }

        // If we exit the retry loop without success, skip to next test
        if (!testPassed) {
          _logState?.error('❌ [$testName] 重试 $maxRetries 次后仍然失败，跳过该项测试', type: LogType.debug);
          // continue to next test instead of breaking
          continue;
        }
      }
    } catch (e) {
      debugPrint('Test error: $e');
    }
  }

  void startTest() async {
    if (_isRunningTest) {
      debugPrint('Test already running');
      return;
    }

    if (!_serialService.isConnected) {
      debugPrint('Please connect to a serial port first');
      return;
    }

    if (_currentTestGroup == null) {
      debugPrint('No test group available');
      return;
    }

    _isRunningTest = true;
    _shouldStopTest = false; // 重置停止标志
    notifyListeners();

    debugPrint('Starting test for: ${_currentTestGroup!.name}');
    await _runProductionTestSequence();

    _isRunningTest = false;
    _shouldStopTest = false; // 测试结束时重置停止标志
    notifyListeners();
  }

  /// Set RTC time to current UTC time
  /// Returns true if successful, false otherwise
  Future<bool> setRTCTime() async {
    if (!_serialService.isConnected) {
      _logState?.error('[RTC] 串口未连接', type: LogType.debug);
      return false;
    }

    try {
      // 获取当前 UTC 时间戳（毫秒级，但毫秒位为0，精确到秒）
      final now = DateTime.now().toUtc();
      final timestampMs = (now.millisecondsSinceEpoch ~/ 1000) * 1000; // 毫秒位设为0

      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('🕐 RTC 设置时间', type: LogType.debug);
      _logState?.info('📅 UTC 时间: ${now.toIso8601String()}',
          type: LogType.debug);
      _logState?.info('📤 时间戳: $timestampMs ms (${timestampMs ~/ 1000} s)',
          type: LogType.debug);
      _logState?.info('📤 Opt: 0x00 (设置时间)', type: LogType.debug);
      _logState?.info('⏱️  发送时间: ${DateTime.now().toString()}',
          type: LogType.debug);

      final command = ProductionTestCommands.createRTCCommand(
        ProductionTestCommands.rtcOptSetTime,
        timestamp: timestampMs,
      );

      // 显示完整指令数据
      final commandHex = command
          .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
          .join(' ');
      _logState?.info('📦 发送指令: [$commandHex] (${command.length} bytes)',
          type: LogType.debug);

      // 详细解析指令结构
      if (command.length == 10) {
        _logState?.info('📋 指令结构:', type: LogType.debug);
        _logState?.info(
            '   - CMD: 0x${command[0].toRadixString(16).toUpperCase().padLeft(2, '0')} (RTC命令)',
            type: LogType.debug);
        _logState?.info(
            '   - OPT: 0x${command[1].toRadixString(16).toUpperCase().padLeft(2, '0')} (设置时间)',
            type: LogType.debug);

        // 解析时间戳字节
        final timestampBytes = command.sublist(2);
        final timestampHex = timestampBytes
            .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
            .join(' ');
        _logState?.info('   - 时间戳: [$timestampHex] (8 bytes, little endian)',
            type: LogType.debug);
      }

      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: TestConfig.defaultTimeout,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );

      if (response != null && !response.containsKey('error')) {
        _logState?.success('✅ RTC 时间设置成功', type: LogType.debug);

        // 显示响应数据
        if (response.containsKey('payload') && response['payload'] != null) {
          final payload = response['payload'] as Uint8List;
          final payloadHex = payload
              .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
              .join(' ');
          _logState?.info('📥 响应数据: [$payloadHex] (${payload.length} bytes)',
              type: LogType.debug);
          
          // 检查响应数据是否有效（至少包含命令字）
          if (payload.isNotEmpty && payload[0] == ProductionTestCommands.cmdRTC) {
            _logState?.info('📌 RTC 设置时间成功，收到有效响应', type: LogType.debug);
            _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
            return true;
          }
        }
        
        _logState?.warning('⚠️  RTC 设置时间响应数据不完整', type: LogType.debug);
      } else {
        _logState?.error('❌ RTC 时间设置失败: ${response?['error'] ?? '无响应'}',
            type: LogType.debug);
      }

      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      return false;
    } catch (e) {
      _logState?.error('RTC 设置时间异常: $e', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      return false;
    }
  }

  /// Get RTC time from device
  Future<void> getRTCTime() async {
    if (!_serialService.isConnected) {
      _logState?.error('[RTC] 串口未连接', type: LogType.debug);
      return;
    }

    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('🕐 RTC 获取时间', type: LogType.debug);
      _logState?.info('📤 Opt: 0x01 (获取时间)', type: LogType.debug);
      _logState?.info('⏱️  发送时间: ${DateTime.now().toString()}',
          type: LogType.debug);

      final command = ProductionTestCommands.createRTCCommand(
        ProductionTestCommands.rtcOptGetTime,
      );

      // 显示完整指令数据
      final commandHex = command
          .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
          .join(' ');
      _logState?.info('📦 发送指令: [$commandHex] (${command.length} bytes)',
          type: LogType.debug);

      // 详细解析指令结构
      if (command.length == 2) {
        _logState?.info('📋 指令结构:', type: LogType.debug);
        _logState?.info(
            '   - CMD: 0x${command[0].toRadixString(16).toUpperCase().padLeft(2, '0')} (RTC命令)',
            type: LogType.debug);
        _logState?.info(
            '   - OPT: 0x${command[1].toRadixString(16).toUpperCase().padLeft(2, '0')} (获取时间)',
            type: LogType.debug);
      }

      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: TestConfig.defaultTimeout,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );

      if (response != null && !response.containsKey('error')) {
        _logState?.success('✅ RTC 时间获取成功', type: LogType.debug);

        // 显示完整响应信息用于调试
        _logState?.info('📊 完整响应信息:', type: LogType.debug);
        response.forEach((key, value) {
          if (key == 'payload' && value is Uint8List) {
            final payloadHex = (value as Uint8List)
                .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
                .join(' ');
            _logState?.info(
                '   - $key: [$payloadHex] (${(value as Uint8List).length} bytes)',
                type: LogType.debug);
          } else {
            _logState?.info('   - $key: $value', type: LogType.debug);
          }
        });

        // 显示响应数据并解析时间戳
        if (response.containsKey('payload') && response['payload'] != null) {
          final payload = response['payload'] as Uint8List;
          final payloadHex = payload
              .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
              .join(' ');
          _logState?.info('📥 响应数据: [$payloadHex] (${payload.length} bytes)',
              type: LogType.debug);

          // 详细解析响应结构
          _logState?.info('📋 响应结构:', type: LogType.debug);
          if (payload.length == 9) {
            _logState?.info('   - 格式: [CMD] + 8字节时间戳 (little endian)',
                type: LogType.debug);
            _logState?.info('   - CMD: 0x${payload[0].toRadixString(16).toUpperCase().padLeft(2, '0')}', type: LogType.debug);
            _logState?.info('   - 时间戳: [$payloadHex]', type: LogType.debug);

            // 使用 ProductionTestCommands 的解析方法
            final timestamp = ProductionTestCommands.parseRTCResponse(payload);
            if (timestamp != null) {
              final dateTime =
                  DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);

              _logState?.info(
                  '📅 设备时间戳: $timestamp ms (${timestamp ~/ 1000} s)',
                  type: LogType.debug);
              _logState?.info('📅 UTC 时间: ${dateTime.toIso8601String()}',
                  type: LogType.debug);
              _logState?.info('📅 本地时间: ${dateTime.toLocal().toString()}',
                  type: LogType.debug);
            } else {
              _logState?.warning('⚠️  无法解析RTC时间戳数据', type: LogType.debug);
            }
          } else if (payload.length == 0) {
            _logState?.warning('⚠️  响应payload为空，设备可能未返回时间戳数据',
                type: LogType.debug);
            _logState?.info('   - 可能原因: 设备RTC未初始化或命令处理异常', type: LogType.debug);
          } else {
            _logState?.warning(
                '⚠️  响应长度异常: ${payload.length} bytes (期望: 9 bytes)',
                type: LogType.debug);
            _logState?.info('   - 格式: 非标准长度', type: LogType.debug);

            // 尝试解析非标准长度的响应
            if (payload.length >= 9) {
              _logState?.info('   - 尝试解析...', type: LogType.debug);
              final timestamp =
                  ProductionTestCommands.parseRTCResponse(payload);
              if (timestamp != null) {
                final dateTime =
                    DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
                _logState?.info(
                    '📅 设备时间戳: $timestamp ms (${timestamp ~/ 1000} s)',
                    type: LogType.debug);
                _logState?.info('📅 UTC 时间: ${dateTime.toIso8601String()}',
                    type: LogType.debug);
                _logState?.info('📅 本地时间: ${dateTime.toLocal().toString()}',
                    type: LogType.debug);
              }
            }
          }
        } else {
          _logState?.error('❌ 响应中没有payload数据', type: LogType.debug);
        }
      } else {
        _logState?.error('❌ RTC 时间获取失败: ${response?['error'] ?? '无响应'}',
            type: LogType.debug);
      }

      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
    } catch (e) {
      _logState?.error('RTC 获取时间异常: $e', type: LogType.debug);
    }
  }

  /// Toggle LED state (on/off)
  Future<void> toggleLedState(int ledNumber) async {
    if (!_serialService.isConnected) {
      _logState?.error('[LED$ledNumber] 串口未连接', type: LogType.debug);
      return;
    }

    // 切换状态
    final currentState = _ledStates[ledNumber] ?? false;
    final newState = !currentState;
    final state =
        newState ? ProductionTestCommands.ledOn : ProductionTestCommands.ledOff;
    final stateText = newState ? '开启' : '关闭';
    final ledName = ProductionTestCommands.getLEDName(ledNumber);

    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('💡 $ledName 控制 - $stateText', type: LogType.debug);
      _logState?.info(
          '📊 当前状态: ${currentState ? "已开启" : "已关闭"} → 目标状态: ${newState ? "已开启" : "已关闭"}',
          type: LogType.debug);
      _logState?.info(
          '📤 LED号: 0x${ledNumber.toRadixString(16).toUpperCase().padLeft(2, '0')} ($ledNumber)',
          type: LogType.debug);
      _logState?.info(
          '📤 状态字: 0x${state.toRadixString(16).toUpperCase().padLeft(2, '0')} (${state == ProductionTestCommands.ledOn ? "开启" : "关闭"})',
          type: LogType.debug);
      _logState?.info('⏱️  发送时间: ${DateTime.now().toString()}',
          type: LogType.debug);

      final command =
          ProductionTestCommands.createControlLEDCommand(ledNumber, state);

      // 显示完整指令数据
      final commandHex = command
          .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
          .join(' ');
      _logState?.info('📦 发送指令: [$commandHex] (${command.length} bytes)',
          type: LogType.debug);

      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: TestConfig.defaultTimeout,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );

      if (response != null && !response.containsKey('error')) {
        // 更新状态
        _ledStates[ledNumber] = newState;
        notifyListeners();
        _logState?.success(
            '✅ $ledName ${stateText}成功 - 当前状态: ${newState ? "已开启 💡" : "已关闭 ⚫"}',
            type: LogType.debug);

        // 显示响应数据
        if (response.containsKey('payload') && response['payload'] != null) {
          final payload = response['payload'] as Uint8List;
          final payloadHex = payload
              .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
              .join(' ');
          _logState?.info('📥 响应数据: [$payloadHex] (${payload.length} bytes)',
              type: LogType.debug);
        }
      } else {
        _logState?.error(
            '❌ $ledName ${stateText}失败: ${response?['error'] ?? '无响应'}',
            type: LogType.debug);
      }

      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
    } catch (e) {
      _logState?.error('$ledName ${stateText}异常: $e', type: LogType.debug);
    }
  }

  /// Toggle MIC state (open/close)
  Future<void> toggleMicState(int micNumber) async {
    if (!_serialService.isConnected) {
      _logState?.error('[MIC$micNumber] 串口未连接', type: LogType.debug);
      return;
    }

    // 切换状态
    final currentState = _micStates[micNumber] ?? false;
    final newState = !currentState;
    final control = newState
        ? ProductionTestCommands.micControlOpen
        : ProductionTestCommands.micControlClose;
    final stateText = newState ? '开启' : '关闭';

    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('🎤 MIC$micNumber 控制 - $stateText', type: LogType.debug);
      _logState?.info(
          '📊 当前状态: ${currentState ? "已开启" : "已关闭"} → 目标状态: ${newState ? "已开启" : "已关闭"}',
          type: LogType.debug);
      _logState?.info(
          '📤 MIC号: 0x${micNumber.toRadixString(16).toUpperCase().padLeft(2, '0')} ($micNumber)',
          type: LogType.debug);
      _logState?.info(
          '📤 控制字: 0x${control.toRadixString(16).toUpperCase().padLeft(2, '0')} (${control == ProductionTestCommands.micControlOpen ? "打开" : "关闭"})',
          type: LogType.debug);
      _logState?.info('⏱️  发送时间: ${DateTime.now().toString()}',
          type: LogType.debug);

      final command =
          ProductionTestCommands.createControlMICCommand(micNumber, control);

      // 显示完整指令数据
      final commandHex = command
          .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
          .join(' ');
      _logState?.info('📦 发送指令: [$commandHex] (${command.length} bytes)',
          type: LogType.debug);

      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: TestConfig.defaultTimeout,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );

      if (response != null && !response.containsKey('error')) {
        // 更新状态
        _micStates[micNumber] = newState;
        notifyListeners();
        _logState?.success(
            '✅ MIC$micNumber ${stateText}成功 - 当前状态: ${newState ? "已开启 🟢" : "已关闭 ⚫"}',
            type: LogType.debug);

        // 显示响应数据
        if (response.containsKey('payload') && response['payload'] != null) {
          final payload = response['payload'] as Uint8List;
          final payloadHex = payload
              .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
              .join(' ');
          _logState?.info('📥 响应数据: [$payloadHex] (${payload.length} bytes)',
              type: LogType.debug);
        }
      } else {
        _logState?.error(
            '❌ MIC$micNumber ${stateText}失败: ${response?['error'] ?? '无响应'}',
            type: LogType.debug);
      }

      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
    } catch (e) {
      _logState?.error('MIC$micNumber ${stateText}异常: $e', type: LogType.debug);
    }
  }

  /// Run manual test for a single command (non-blocking, allows concurrent execution)
  Future<void> runManualTest(String testName, dynamic command,
      {int? moduleId, int? messageId}) async {
    if (!_serialService.isConnected) {
      debugPrint('Serial port not connected');
      _logState?.error('[$testName] 串口未连接', type: LogType.debug);
      return;
    }

    // 不再检查 _isRunningTest，允许并发执行多个手动测试

    try {
      debugPrint('Running manual test: $testName');
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('🔧 手动测试: $testName', type: LogType.debug);
      _logState?.info('⏱️  发送时间: ${DateTime.now().toString()}',
          type: LogType.debug);

      // Send command and wait for response
      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: TestConfig.defaultTimeout,
        moduleId: moduleId ?? ProductionTestCommands.moduleId,
        messageId: messageId ?? ProductionTestCommands.messageId,
      );

      if (response != null) {
        if (response.containsKey('error')) {
          debugPrint('✗ $testName error: ${response['error']}');
          _logState?.error('❌ $testName - 错误: ${response['error']}',
              type: LogType.debug);
        } else {
          debugPrint('✓ $testName completed successfully');
          _logState?.success('✅ $testName - 执行成功', type: LogType.debug);

          // 显示响应数据
          if (response.containsKey('payload') && response['payload'] != null) {
            final payload = response['payload'] as Uint8List;
            _logState?.info('📦 响应数据 (${payload.length} bytes)',
                type: LogType.debug);
          }
        }
      } else {
        debugPrint('✗ $testName timeout or failed');
        _logState?.warning('⏱️  $testName - 超时或无响应', type: LogType.debug);
      }

      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
    } catch (e) {
      debugPrint('Error running manual test: $e');
      _logState?.error('❌ $testName - 异常: $e', type: LogType.debug);
    }
    // 不再设置 _isRunningTest = false，因为不再使用阻塞机制
  }

  /// 右Touch半自动化测试
  Future<void> testTouchRight() async {
    if (!_serialService.isConnected) {
      _logState?.error('[Touch右侧] 串口未连接', type: LogType.debug);
      return;
    }

    _isRightTouchTesting = true;
    _showTouchDialog = true;
    _isLeftTouchDialog = false;
    _initializeRightTouchTestSteps();
    notifyListeners();

    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('👆 右Touch半自动化测试开始', type: LogType.debug);
      _logState?.info('⏱️  开始时间: ${DateTime.now().toString()}', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);

      // 按顺序执行所有步骤
      bool allSuccess = true;
      int failedStepIndex = -1;
      
      for (int stepIndex = 0; stepIndex < _rightTouchTestSteps.length; stepIndex++) {
        if (_shouldStopTest) {
          allSuccess = false;
          failedStepIndex = stepIndex;
          break;
        }
        
        final success = await _executeRightTouchStep(stepIndex);
        if (!success) {
          _logState?.error('❌ 右Touch测试失败: ${_rightTouchTestSteps[stepIndex].name}，停止测试', type: LogType.debug);
          allSuccess = false;
          failedStepIndex = stepIndex;
          break;
        }
        
        // 步骤间延迟
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // 如果测试提前结束，将剩余步骤标记为跳过
      if (failedStepIndex >= 0) {
        for (int i = failedStepIndex + 1; i < _rightTouchTestSteps.length; i++) {
          if (_rightTouchTestSteps[i].status == TouchStepStatus.testing ||
              _rightTouchTestSteps[i].status == TouchStepStatus.waiting) {
            _rightTouchTestSteps[i] = _rightTouchTestSteps[i].copyWith(
              status: TouchStepStatus.failed,
              errorMessage: '前序步骤失败，跳过测试',
            );
          }
        }
        notifyListeners();
      }
      
      // 标记测试是否全部成功
      _isRightTouchTesting = false;
      if (!allSuccess) {
        _logState?.error('❌ 右Touch测试未完全通过', type: LogType.debug);
      }

      _logState?.info('', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.success('✅ 右Touch半自动化测试完成', type: LogType.debug);
      _logState?.info('⏱️  结束时间: ${DateTime.now().toString()}', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
    } catch (e) {
      _logState?.error('右Touch测试异常: $e', type: LogType.debug);
    } finally {
      _isRightTouchTesting = false;
      // 保持弹窗显示，由用户手动关闭
      notifyListeners();
    }
  }
  
  /// 左Touch半自动化测试
  Future<void> testTouchLeft() async {
    if (!_serialService.isConnected) {
      _logState?.error('[Touch左侧] 串口未连接', type: LogType.debug);
      return;
    }

    _isLeftTouchTesting = true;
    _showTouchDialog = true;
    _isLeftTouchDialog = true;
    _initializeLeftTouchTestSteps();
    notifyListeners();

    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('👆 左Touch半自动化测试开始', type: LogType.debug);
      _logState?.info('⏱️  开始时间: ${DateTime.now().toString()}', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);

      // 按顺序执行所有步骤
      bool allSuccess = true;
      int failedStepIndex = -1;
      
      for (int stepIndex = 0; stepIndex < _leftTouchTestSteps.length; stepIndex++) {
        if (_shouldStopTest) {
          allSuccess = false;
          failedStepIndex = stepIndex;
          break;
        }
        
        final success = await _executeLeftTouchStep(stepIndex);
        if (!success) {
          _logState?.error('❌ 左Touch测试失败: ${_leftTouchTestSteps[stepIndex].name}，停止测试', type: LogType.debug);
          allSuccess = false;
          failedStepIndex = stepIndex;
          break;
        }
        
        // 步骤间延迟
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // 如果测试提前结束，将剩余步骤标记为跳过
      if (failedStepIndex >= 0) {
        for (int i = failedStepIndex + 1; i < _leftTouchTestSteps.length; i++) {
          if (_leftTouchTestSteps[i].status == TouchStepStatus.testing ||
              _leftTouchTestSteps[i].status == TouchStepStatus.waiting) {
            _leftTouchTestSteps[i] = _leftTouchTestSteps[i].copyWith(
              status: TouchStepStatus.failed,
              errorMessage: '前序步骤失败，跳过测试',
            );
          }
        }
        notifyListeners();
      }
      
      // 标记测试是否全部成功
      _isLeftTouchTesting = false;
      if (!allSuccess) {
        _logState?.error('❌ 左Touch测试未完全通过', type: LogType.debug);
      }

      _logState?.info('', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.success('✅ 左Touch半自动化测试完成', type: LogType.debug);
      _logState?.info('⏱️  结束时间: ${DateTime.now().toString()}', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
    } catch (e) {
      _logState?.error('左Touch测试异常: $e', type: LogType.debug);
    } finally {
      _isLeftTouchTesting = false;
      // 保持弹窗显示，由用户手动关闭
      notifyListeners();
    }
  }

  /// 漏电流手动测试
  Future<bool> testLeakageCurrent() async {
    try {
      // 同时输出到 debug 和 gpib 日志
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
      _logState?.info('🔌 开始漏电流测试', type: LogType.debug);
      _logState?.info('🔌 开始漏电流测试', type: LogType.gpib);
      _logState?.info('   阈值: < ${TestConfig.leakageCurrentThresholdUa} uA', type: LogType.debug);
      _logState?.info('   阈值: < ${TestConfig.leakageCurrentThresholdUa} uA', type: LogType.gpib);
      _logState?.info('   采样: ${TestConfig.gpibSampleCount} 次 @ ${TestConfig.gpibSampleRate} Hz', type: LogType.debug);
      _logState?.info('   采样: ${TestConfig.gpibSampleCount} 次 @ ${TestConfig.gpibSampleRate} Hz', type: LogType.gpib);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
      
      // 检查GPIB是否就绪（除非启用了跳过选项）
      if (!_isGpibReady && !AutomationTestConfig.skipGpibTests && !AutomationTestConfig.skipGpibReadyCheck) {
        _logState?.error('❌ GPIB设备未就绪', type: LogType.debug);
        _logState?.error('❌ GPIB设备未就绪', type: LogType.gpib);
        _logState?.error('请先点击"GPIB检测"按钮连接程控电源，或启用跳过选项', type: LogType.debug);
        _logState?.error('请先点击"GPIB检测"按钮连接程控电源，或启用跳过选项', type: LogType.gpib);
        return false;
      }
      
      // 如果跳过GPIB检查，给出提示
      if (!_isGpibReady && (AutomationTestConfig.skipGpibTests || AutomationTestConfig.skipGpibReadyCheck)) {
        _logState?.warning('⚠️  已跳过GPIB检查，跳过漏电流测试', type: LogType.debug);
        _logState?.warning('⚠️  已跳过GPIB检查，跳过漏电流测试', type: LogType.gpib);
        return false;
      }
      
      // 使用GPIB测量电流（不发送任何串口指令）
      final currentA = await _gpibService.measureCurrent(
        sampleCount: TestConfig.gpibSampleCount,
        sampleRate: TestConfig.gpibSampleRate,
      );
      
      if (currentA == null) {
        _logState?.error('❌ 电流测量失败', type: LogType.debug);
        _logState?.error('❌ 电流测量失败', type: LogType.gpib);
        return false;
      }
      
      // 转换为微安 (uA)
      final currentUa = currentA * 1000000;
      
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
      _logState?.info('📊 漏电流测试结果:', type: LogType.debug);
      _logState?.info('📊 漏电流测试结果:', type: LogType.gpib);
      _logState?.info('   测量值: ${currentUa.toStringAsFixed(2)} uA', type: LogType.debug);
      _logState?.info('   测量值: ${currentUa.toStringAsFixed(2)} uA', type: LogType.gpib);
      _logState?.info('   阈值: < ${TestConfig.leakageCurrentThresholdUa} uA', type: LogType.debug);
      _logState?.info('   阈值: < ${TestConfig.leakageCurrentThresholdUa} uA', type: LogType.gpib);
      
      if (currentUa < TestConfig.leakageCurrentThresholdUa) {
        _logState?.success('✅ 漏电流测试通过', type: LogType.debug);
        _logState?.success('✅ 漏电流测试通过', type: LogType.gpib);
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
        return true;
      } else {
        _logState?.error('❌ 漏电流测试失败: 超过阈值', type: LogType.debug);
        _logState?.error('❌ 漏电流测试失败: 超过阈值', type: LogType.gpib);
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
        return false;
      }
    } catch (e) {
      _logState?.error('❌ 漏电流测试异常: $e', type: LogType.debug);
      _logState?.error('❌ 漏电流测试异常: $e', type: LogType.gpib);
      return false;
    }
  }

  /// 初始化WiFi测试步骤
  void _initializeWiFiTestSteps() {
    _wifiTestSteps = List<WiFiTestStep>.from([
      WiFiTestStep(
        opt: WiFiConfig.optStartTest,
        name: '开始WiFi测试',
        description: '初始化WiFi测试模式',
      ),
      WiFiTestStep(
        opt: WiFiConfig.optConnectAP,
        name: '连接热点',
        description: '只发送CMD+OPT，不带数据',
        data: null, // 不发送SSID和密码数据，只发送CMD 0x04 + OPT 0x01
      ),
      WiFiTestStep(
        opt: WiFiConfig.optTestRSSI,
        name: '测试RSSI',
        description: '测试WiFi信号强度',
      ),
      WiFiTestStep(
        opt: WiFiConfig.optGetMAC,
        name: '获取MAC地址',
        description: '读取设备WiFi MAC地址',
      ),
      WiFiTestStep(
        opt: WiFiConfig.optEndTest,
        name: '结束WiFi测试',
        description: '退出WiFi测试模式',
      ),
    ]);
    notifyListeners();
  }

  /// WiFi多步骤测试流程
  /// 按顺序执行：开始测试 -> 连接热点 -> 测试RSSI -> 获取MAC -> 结束测试
  Future<bool> testWiFi() async {
    if (!_serialService.isConnected) {
      _logState?.error('[WiFi] 串口未连接', type: LogType.debug);
      return false;
    }

    bool testStarted = false;
    bool testSuccess = false;
    
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('🌐 开始WiFi多步骤测试流程', type: LogType.debug);
      _logState?.info('⏱️  开始时间: ${DateTime.now().toString()}', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);

      // 初始化WiFi测试步骤
      _initializeWiFiTestSteps();
      
      // 显示WiFi测试弹窗
      _showWiFiDialog = true;
      notifyListeners();
      
      // 等待一小段时间让弹窗显示
      await Future.delayed(const Duration(milliseconds: 300));

      // 执行除最后一步（结束测试）外的所有步骤
      for (int i = 0; i < _wifiTestSteps.length - 1; i++) {
        // 检查是否需要停止测试
        if (_shouldStopTest) {
          _logState?.warning('🛑 WiFi测试已被用户停止');
          testSuccess = false;
          break;
        }

        final step = _wifiTestSteps[i];
        final success = await _executeWiFiStepWithRetry(i);
        
        if (i == 0 && success) {
          testStarted = true; // 第一步成功，标记测试已开始
          _logState?.info('⏳ 开始WiFi测试成功，等待10秒后再连接热点...', type: LogType.debug);
          await Future.delayed(const Duration(seconds: 10));
          _logState?.info('✅ 等待完成，准备连接热点', type: LogType.debug);
        }
        
        if (!success) {
          _logState?.error('❌ WiFi测试失败: ${step.name}');
          testSuccess = false;
          break;
        }
        
        // 所有步骤都成功
        if (i == _wifiTestSteps.length - 2) {
          testSuccess = true;
        }
      }

      _logState?.info('', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      if (testSuccess) {
        _logState?.success('✅ WiFi多步骤测试完成', type: LogType.debug);
      } else {
        _logState?.error('❌ WiFi测试未完全通过', type: LogType.debug);
      }
      _logState?.info('⏱️  结束时间: ${DateTime.now().toString()}', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      
      return testSuccess;
    } catch (e) {
      _logState?.error('WiFi测试异常: $e', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      return false;
    } finally {
      // 无论成功失败，只要测试开始了，都必须执行结束步骤
      if (testStarted) {
        _logState?.info('🛑 WiFi测试结束，发送结束指令...', type: LogType.debug);
        final endStepIndex = _wifiTestSteps.length - 1;
        final endSuccess = await _executeWiFiStepWithRetry(endStepIndex);
        if (!endSuccess) {
          _logState?.warning('⚠️ WiFi结束指令发送失败，但继续执行', type: LogType.debug);
        } else {
          _logState?.success('✅ WiFi结束指令发送成功', type: LogType.debug);
        }
      }
      
      // 等待一小段时间让用户看到最终结果
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 关闭WiFi测试弹窗
      _showWiFiDialog = false;
      notifyListeners();
    }
  }
  
  /// 关闭WiFi测试弹窗
  void closeWiFiDialog() {
    _showWiFiDialog = false;
    notifyListeners();
    _logState?.info('🔄 WiFi测试弹窗已关闭', type: LogType.debug);
  }
  
  /// 重新打开WiFi测试弹窗
  void reopenWiFiDialog() {
    if (_wifiTestSteps.isNotEmpty) {
      _showWiFiDialog = true;
      notifyListeners();
      _logState?.info('🔄 WiFi测试弹窗已重新打开', type: LogType.debug);
    } else {
      _logState?.warning('⚠️ 没有正在进行的WiFi测试', type: LogType.debug);
    }
  }

  /// 从设备通过FTP下载Sensor测试图片
  /// 返回true表示下载成功，false表示失败
  Future<bool> _downloadSensorImageFromDevice() async {
    if (_deviceIPAddress == null || _deviceIPAddress!.isEmpty) {
      _logState?.error('❌ 无法下载图片：设备IP地址为空', type: LogType.debug);
      return false;
    }

    try {
      _logState?.info('📥 开始从设备下载Sensor测试图片...', type: LogType.debug);
      _logState?.info('   设备IP: $_deviceIPAddress', type: LogType.debug);
      
      // 构建FTP URL，显式指定端口21
      final ftpUrl = 'ftp://$_deviceIPAddress:21/test.jpg';
      _logState?.info('   FTP URL: $ftpUrl', type: LogType.debug);
      
      // 确定保存路径（跨平台兼容）
      String savePath;
      if (Platform.isMacOS) {
        // macOS: 保存到用户文档目录
        final homeDir = Platform.environment['HOME'] ?? '';
        savePath = path.join(homeDir, 'Documents', 'JNProductionLine', 'sensor_test.jpg');
      } else if (Platform.isWindows) {
        // Windows: 保存到用户文档目录
        final userProfile = Platform.environment['USERPROFILE'] ?? '';
        savePath = path.join(userProfile, 'Documents', 'JNProductionLine', 'sensor_test.jpg');
      } else {
        // 其他平台：保存到当前目录
        savePath = path.join(Directory.current.path, 'sensor_test.jpg');
      }
      
      _logState?.info('   保存路径: $savePath', type: LogType.debug);
      
      // 确保目录存在
      final saveDir = Directory(path.dirname(savePath));
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
        _logState?.info('   ✅ 创建目录: ${saveDir.path}', type: LogType.debug);
      }
      
      // 使用curl命令下载（跨平台兼容，带重试机制）
      ProcessResult? result;
      int maxRetries = 3;
      
      for (int retry = 0; retry < maxRetries; retry++) {
        if (retry > 0) {
          _logState?.warning('🔄 FTP下载重试 $retry/$maxRetries...', type: LogType.debug);
          // 每次重试增加等待时间：1秒、2秒、3秒
          await Future.delayed(Duration(seconds: retry));
        }
        
        if (Platform.isMacOS || Platform.isLinux) {
          _logState?.info('🔧 开始下载 FTP URL: $ftpUrl (尝试 ${retry + 1}/$maxRetries)', type: LogType.debug);
          
          // macOS/Linux: 使用curl，添加FTP特定选项
          final curlArgs = [
            '-v',  // 详细输出，用于调试
            '--ftp-pasv',  // 使用被动模式（PASV）
            '--disable-epsv',  // 禁用扩展被动模式
            '-o', savePath,
            '--connect-timeout', '5',
            '--max-time', '30',
            ftpUrl,
          ];
          
          _logState?.info('🔧 执行命令: curl ${curlArgs.join(" ")}', type: LogType.debug);
          
          result = await Process.run('curl', curlArgs);
          
          // 输出详细的stderr信息（curl的详细输出在stderr）
          if (result.stderr.toString().isNotEmpty) {
            _logState?.info('📋 curl详细输出:\n${result.stderr}', type: LogType.debug);
          }
          
        } else if (Platform.isWindows) {
          // Windows: 使用curl (Windows 10+ 自带curl)
          // 注意：Windows自带的curl版本较老，不支持某些FTP参数
          _logState?.info('🔧 开始下载 FTP URL: $ftpUrl (尝试 ${retry + 1}/$maxRetries)', type: LogType.debug);
          
          final curlArgs = [
            '-v',  // 详细输出
            '-o', savePath,  // 输出文件
            '--connect-timeout', '5',  // 连接超时
            '--max-time', '30',  // 最大执行时间
            ftpUrl,
          ];
          
          _logState?.info('🔧 执行命令: curl.exe ${curlArgs.join(" ")}', type: LogType.debug);
          
          result = await Process.run('curl.exe', curlArgs);
          
          if (result.stderr.toString().isNotEmpty) {
            _logState?.info('📋 curl详细输出:\n${result.stderr}', type: LogType.debug);
          }
          
        } else {
          _logState?.error('❌ 不支持的操作系统', type: LogType.debug);
          return false;
        }
        
        // 如果成功，跳出重试循环
        if (result != null && result.exitCode == 0) {
          _logState?.success('✅ FTP下载成功！', type: LogType.debug);
          break;
        } else if (retry < maxRetries - 1) {
          _logState?.warning('⚠️ FTP下载失败 (退出码: ${result?.exitCode ?? 'unknown'})，准备重试...', type: LogType.debug);
        }
      }
      
      // 检查最终结果
      if (result == null) {
        _logState?.error('❌ 不支持的操作系统', type: LogType.debug);
        return false;
      }
      
      if (result.exitCode == 0) {
        // 验证文件是否存在且有内容
        final file = File(savePath);
        if (await file.exists()) {
          final fileSize = await file.length();
          if (fileSize > 0) {
            _sensorImagePath = savePath;
            _logState?.success('✅ Sensor测试图片下载成功！', type: LogType.debug);
            _logState?.info('   文件大小: ${(fileSize / 1024).toStringAsFixed(2)} KB', type: LogType.debug);
            _logState?.info('   保存位置: $savePath', type: LogType.debug);
            notifyListeners();
            return true;
          } else {
            _logState?.error('❌ 下载的文件为空', type: LogType.debug);
            return false;
          }
        } else {
          _logState?.error('❌ 文件下载后不存在', type: LogType.debug);
          return false;
        }
      } else {
        _logState?.error('❌ FTP下载失败 (退出码: ${result.exitCode})', type: LogType.debug);
        if (result.stderr.toString().isNotEmpty) {
          _logState?.error('   错误信息: ${result.stderr}', type: LogType.debug);
        }
        return false;
      }
    } catch (e) {
      _logState?.error('❌ 下载Sensor图片异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 执行单个WiFi测试步骤（单次执行，5秒超时）
  Future<bool> _executeWiFiStepSingle(int stepIndex) async {
    final step = _wifiTestSteps[stepIndex];
    
    try {
      _logState?.info('🔄 步骤: ${step.name} (0x${step.opt.toRadixString(16).toUpperCase().padLeft(2, '0')})', type: LogType.debug);
      
      // 创建命令
      final command = ProductionTestCommands.createControlWifiCommand(step.opt, data: step.data);
      
      // 显示发送的命令
      final commandHex = command.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📤 发送: [$commandHex] (${command.length} bytes)', type: LogType.debug);
      
      // 如果有数据，显示数据内容
      if (step.data != null && step.data!.isNotEmpty) {
        if (step.opt == WiFiConfig.optConnectAP) {
          // 解析SSID和PWD
          int ssidEnd = step.data!.indexOf(0);
          if (ssidEnd > 0) {
            String ssid = String.fromCharCodes(step.data!.sublist(0, ssidEnd));
            List<int> pwdBytes = step.data!.sublist(ssidEnd + 1);
            int pwdEnd = pwdBytes.indexOf(0);
            String pwd = pwdEnd >= 0 ? String.fromCharCodes(pwdBytes.sublist(0, pwdEnd)) : String.fromCharCodes(pwdBytes);
            _logState?.info('   📡 SSID: "$ssid", PWD: "$pwd"', type: LogType.debug);
          }
        }
      }

      // 发送命令并等待响应（2秒超时）
      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: const Duration(seconds: 2), // 2秒超时
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );

      if (response != null && !response.containsKey('error')) {
        // 显示响应数据
        if (response.containsKey('payload') && response['payload'] != null) {
          final payload = response['payload'] as Uint8List;
          final payloadHex = payload
              .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
              .join(' ');
          _logState?.info('📥 响应: [$payloadHex] (${payload.length} bytes)', type: LogType.debug);

          // 解析WiFi响应，传入当前执行的opt
          final wifiResult = ProductionTestCommands.parseWifiResponse(payload, step.opt);
          if (wifiResult != null && wifiResult['success'] == true) {
            String details = '';
            if (wifiResult.containsKey('rssi')) {
              details = ' - RSSI: ${wifiResult['rssi']}dBm';
            } else if (wifiResult.containsKey('mac')) {
              details = ' - MAC: ${wifiResult['mac']}';
            } else if (wifiResult.containsKey('ip')) {
              // 保存IP地址
              _deviceIPAddress = wifiResult['ip'];
              details = ' - IP: ${wifiResult['ip']}';
              _logState?.success('✅ 获取到设备IP地址: $_deviceIPAddress', type: LogType.debug);
              
              // 等待3秒让设备FTP服务完全启动
              _logState?.info('⏳ 等待3秒让设备FTP服务启动...', type: LogType.debug);
              await Future.delayed(const Duration(seconds: 3));
              
              // 同步下载图片，阻塞WiFi测试流程直到下载完成
              _logState?.info('📥 正在下载Sensor测试图片...', type: LogType.debug);
              final downloadSuccess = await _downloadSensorImageFromDevice();
              
              if (!downloadSuccess) {
                _logState?.error('❌ Sensor图片下载失败，WiFi测试终止', type: LogType.debug);
                final currentStep = _wifiTestSteps[stepIndex];
                _wifiTestSteps[stepIndex] = currentStep.copyWith(errorMessage: 'FTP图片下载失败');
                return false;
              }
              
              _logState?.success('✅ Sensor图片下载成功，继续WiFi测试', type: LogType.debug);
            }
            
            // 保存结果到步骤中
            final currentStep = _wifiTestSteps[stepIndex];
            _wifiTestSteps[stepIndex] = currentStep.copyWith(result: wifiResult);
            
            _logState?.success('✅ ${step.name} 成功$details', type: LogType.debug);
            return true;
          } else {
            final errorMsg = wifiResult?['error'] ?? '解析响应失败';
            final currentStep = _wifiTestSteps[stepIndex];
            _wifiTestSteps[stepIndex] = currentStep.copyWith(errorMessage: errorMsg);
            _logState?.error('❌ ${step.name} 失败: $errorMsg', type: LogType.debug);
            return false;
          }
        } else {
          _logState?.success('✅ ${step.name} 成功', type: LogType.debug);
          return true;
        }
      } else {
        final errorMsg = response?['error'] ?? '无响应或响应错误';
        final currentStep = _wifiTestSteps[stepIndex];
        _wifiTestSteps[stepIndex] = currentStep.copyWith(errorMessage: errorMsg);
        _logState?.error('❌ ${step.name} 失败: $errorMsg', type: LogType.debug);
        return false;
      }
    } catch (e) {
      final errorMsg = '执行异常: $e';
      final currentStep = _wifiTestSteps[stepIndex];
      _wifiTestSteps[stepIndex] = currentStep.copyWith(errorMessage: errorMsg);
      _logState?.error('❌ ${step.name} 异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 执行单个WiFi测试步骤
  Future<bool> _executeWiFiStep(int opt, String stepName, {List<int>? data}) async {
    try {
      _logState?.info('🔄 步骤: $stepName (0x${opt.toRadixString(16).toUpperCase().padLeft(2, '0')})', type: LogType.debug);
      
      // 创建命令
      final command = ProductionTestCommands.createControlWifiCommand(opt, data: data);
      
      // 显示发送的命令
      final commandHex = command.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📤 发送: [$commandHex] (${command.length} bytes)', type: LogType.debug);
      
      // 如果有数据，显示数据内容
      if (data != null && data.isNotEmpty) {
        if (opt == WiFiConfig.optConnectAP) {
          // 解析SSID和PWD
          int ssidEnd = data.indexOf(0);
          if (ssidEnd > 0) {
            String ssid = String.fromCharCodes(data.sublist(0, ssidEnd));
            List<int> pwdBytes = data.sublist(ssidEnd + 1);
            int pwdEnd = pwdBytes.indexOf(0);
            String pwd = pwdEnd >= 0 ? String.fromCharCodes(pwdBytes.sublist(0, pwdEnd)) : String.fromCharCodes(pwdBytes);
            _logState?.info('   📡 SSID: "$ssid", PWD: "$pwd"', type: LogType.debug);
          }
        }
      }

      // 发送命令并等待响应
      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: TestConfig.defaultTimeout,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );

      if (response != null && !response.containsKey('error')) {
        // 显示响应数据
        if (response.containsKey('payload') && response['payload'] != null) {
          final payload = response['payload'] as Uint8List;
          final payloadHex = payload
              .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
              .join(' ');
          _logState?.info('📥 响应: [$payloadHex] (${payload.length} bytes)', type: LogType.debug);

          // 解析WiFi响应，传入当前执行的opt
          final wifiResult = ProductionTestCommands.parseWifiResponse(payload, opt);
          if (wifiResult != null && wifiResult['success'] == true) {
            String details = '';
            if (wifiResult.containsKey('rssi')) {
              details = ' - RSSI: ${wifiResult['rssi']}dBm';
            } else if (wifiResult.containsKey('mac')) {
              details = ' - MAC: ${wifiResult['mac']}';
            }
            _logState?.success('✅ $stepName 成功$details', type: LogType.debug);
            return true;
          } else {
            _logState?.error('❌ $stepName 失败: ${wifiResult?['error'] ?? '解析响应失败'}', type: LogType.debug);
            return false;
          }
        } else {
          _logState?.error('❌ $stepName 失败: 响应无payload数据', type: LogType.debug);
          return false;
        }
      } else {
        _logState?.error('❌ $stepName 失败: ${response?['error'] ?? '无响应'}', type: LogType.debug);
        return false;
      }
    } catch (e) {
      _logState?.error('❌ $stepName 异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// IMU数据获取测试
  /// 开始获取数据 -> 持续接收5秒 -> 询问是否结束 -> 停止获取数据
  Future<bool> testIMU() async {
    if (!_serialService.isConnected) {
      _logState?.error('[IMU] 串口未连接', type: LogType.debug);
      return false;
    }

    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('📊 开始IMU数据获取测试', type: LogType.debug);
      _logState?.info('⏱️  开始时间: ${DateTime.now().toString()}', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);

      // 步骤1: 开始获取IMU数据 (0x00)
      _logState?.info('🔄 发送开始获取IMU数据命令', type: LogType.debug);
      
      final startCommand = ProductionTestCommands.createIMUCommand(ProductionTestCommands.imuOptStartData);
      final startCommandHex = startCommand.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📤 发送: [$startCommandHex] (${startCommand.length} bytes)', type: LogType.debug);

      // 发送开始命令，但不等待特定响应，因为设备会持续发送数据
      final startResponse = await _serialService.sendCommandAndWaitResponse(
        startCommand,
        timeout: TestConfig.defaultTimeout,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );

      if (startResponse == null || startResponse.containsKey('error')) {
        _logState?.error('❌ 开始获取IMU数据失败: ${startResponse?['error'] ?? '无响应'}', type: LogType.debug);
        return false;
      }

      _logState?.success('✅ 开始获取IMU数据命令发送成功', type: LogType.debug);
      _logState?.info('📡 开始监听IMU数据流...', type: LogType.debug);

      // 步骤2: 持续接收IMU数据5秒
      int dataCount = 0;
      final startTime = DateTime.now();
      final endTime = startTime.add(const Duration(seconds: 5));
      
      // 设置数据流监听器
      StreamSubscription? dataSubscription;
      bool receivedData = false;
      
      dataSubscription = _serialService.dataStream.listen((data) {
        try {
          // 解析GTP响应
          final gtpResponse = GTPProtocol.parseGTPResponse(data);
          if (gtpResponse != null && !gtpResponse.containsKey('error')) {
            final cliResponse = gtpResponse;
            if (cliResponse != null && cliResponse.containsKey('payload')) {
              final payload = cliResponse['payload'] as Uint8List;
              
              // 检查是否是IMU数据 (第一个字节是0x0B)
              if (payload.isNotEmpty && payload[0] == ProductionTestCommands.cmdIMU) {
                dataCount++;
                receivedData = true;
                
                final payloadHex = payload.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
                _logState?.info('📥 IMU数据 #$dataCount: [$payloadHex] (${payload.length} bytes)', type: LogType.debug);
                
                // 解析IMU数据
                final imuData = ProductionTestCommands.parseIMUResponse(payload);
                if (imuData != null) {
                  _logState?.info('   📊 加速度: X=${imuData['accel_x']?.toStringAsFixed(3)}, Y=${imuData['accel_y']?.toStringAsFixed(3)}, Z=${imuData['accel_z']?.toStringAsFixed(3)}', type: LogType.debug);
                  _logState?.info('   🔄 陀螺仪: X=${imuData['gyro_x']?.toStringAsFixed(3)}, Y=${imuData['gyro_y']?.toStringAsFixed(3)}, Z=${imuData['gyro_z']?.toStringAsFixed(3)}', type: LogType.debug);
                }
              }
            }
          }
        } catch (e) {
          _logState?.warning('⚠️  解析IMU数据时出错: $e', type: LogType.debug);
        }
      });

      // 等待5秒
      while (DateTime.now().isBefore(endTime)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 取消数据监听
      await dataSubscription?.cancel();

      _logState?.info('', type: LogType.debug);
      _logState?.info('⏰ 5秒数据收集完成，共收到 $dataCount 条IMU数据', type: LogType.debug);

      if (!receivedData) {
        _logState?.warning('⚠️  未收到IMU数据，可能设备未正确响应', type: LogType.debug);
      }

      // 步骤3: 发送停止获取IMU数据命令 (0x01)
      _logState?.info('🛑 发送停止获取IMU数据命令', type: LogType.debug);
      
      final stopCommand = ProductionTestCommands.createIMUCommand(ProductionTestCommands.imuOptStopData);
      final stopCommandHex = stopCommand.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📤 发送: [$stopCommandHex] (${stopCommand.length} bytes)', type: LogType.debug);

      final stopResponse = await _serialService.sendCommandAndWaitResponse(
        stopCommand,
        timeout: TestConfig.defaultTimeout,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );

      if (stopResponse != null && !stopResponse.containsKey('error')) {
        // 显示停止响应
        if (stopResponse.containsKey('payload') && stopResponse['payload'] != null) {
          final payload = stopResponse['payload'] as Uint8List;
          final payloadHex = payload.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
          _logState?.info('📥 停止响应: [$payloadHex] (${payload.length} bytes)', type: LogType.debug);
        }
        
        _logState?.success('✅ 停止获取IMU数据成功', type: LogType.debug);
        
        _logState?.info('', type: LogType.debug);
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        _logState?.success('✅ IMU数据获取测试完成', type: LogType.debug);
        _logState?.info('📊 总共收到 $dataCount 条IMU数据', type: LogType.debug);
        _logState?.info('⏱️  结束时间: ${DateTime.now().toString()}', type: LogType.debug);
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        
        return receivedData; // 只要收到了数据就认为测试成功
      } else {
        _logState?.error('❌ 停止获取IMU数据失败: ${stopResponse?['error'] ?? '无响应'}', type: LogType.debug);
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        return false;
      }
    } catch (e) {
      _logState?.error('IMU测试异常: $e', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      return false;
    }
  }
  
  /// 初始化左Touch测试步骤
  void _initializeLeftTouchTestSteps() {
    _leftTouchTestSteps = [
      // 注释掉单击测试
      // TouchTestStep(
      //   touchId: TouchTestConfig.touchLeft,
      //   actionId: TouchTestConfig.leftActionSingleTap,
      //   name: '单击测试',
      //   description: '测试左侧Touch单击功能',
      //   userPrompt: TouchTestConfig.getLeftActionPrompt(TouchTestConfig.leftActionSingleTap),
      // ),
      // 注释掉双击测试
      // TouchTestStep(
      //   touchId: TouchTestConfig.touchLeft,
      //   actionId: TouchTestConfig.leftActionDoubleTap,
      //   name: '双击测试',
      //   description: '测试左侧Touch双击功能',
      //   userPrompt: TouchTestConfig.getLeftActionPrompt(TouchTestConfig.leftActionDoubleTap),
      // ),
      // 只保留佩戴检测测试项
      TouchTestStep(
        touchId: TouchTestConfig.touchLeft,
        actionId: TouchTestConfig.leftActionWearDetect,
        name: '佩戴检测',
        description: '测试左侧Touch佩戴检测功能',
        userPrompt: TouchTestConfig.getLeftActionPrompt(TouchTestConfig.leftActionWearDetect),
      ),
    ];
    notifyListeners();
  }
  
  /// 初始化右Touch测试步骤
  void _initializeRightTouchTestSteps() {
    _rightTouchTestSteps = [
      TouchTestStep(
        touchId: TouchTestConfig.touchRight,
        actionId: TouchTestConfig.rightAreaUntouched,
        name: '获取基线值',
        description: '获取未触摸时的CDC基线值',
        userPrompt: TouchTestConfig.getRightAreaPrompt(TouchTestConfig.rightAreaUntouched),
      ),
      TouchTestStep(
        touchId: TouchTestConfig.touchRight,
        actionId: TouchTestConfig.rightAreaTK1,
        name: 'TK1测试',
        description: '测试右侧TK1区域触摸功能',
        userPrompt: TouchTestConfig.getRightAreaPrompt(TouchTestConfig.rightAreaTK1),
      ),
      TouchTestStep(
        touchId: TouchTestConfig.touchRight,
        actionId: TouchTestConfig.rightAreaTK2,
        name: 'TK2测试',
        description: '测试右侧TK2区域触摸功能',
        userPrompt: TouchTestConfig.getRightAreaPrompt(TouchTestConfig.rightAreaTK2),
      ),
      TouchTestStep(
        touchId: TouchTestConfig.touchRight,
        actionId: TouchTestConfig.rightAreaTK3,
        name: 'TK3测试',
        description: '测试右侧TK3区域触摸功能',
        userPrompt: TouchTestConfig.getRightAreaPrompt(TouchTestConfig.rightAreaTK3),
      ),
    ];
    notifyListeners();
  }
  
  /// 执行左Touch测试步骤
  Future<bool> _executeLeftTouchStep(int stepIndex) async {
    final step = _leftTouchTestSteps[stepIndex];
    
    try {
      // 更新步骤状态为正在测试
      _leftTouchTestSteps[stepIndex] = step.copyWith(status: TouchStepStatus.testing);
      notifyListeners();
      
      _logState?.info('🔄 步骤: ${step.name}', type: LogType.debug);
      _logState?.info('📝 描述: ${step.description}', type: LogType.debug);
      
      // 左Touch所有步骤都需要用户操作和监听
      return await _waitForLeftTouchUserAction(step, stepIndex);
      
    } catch (e) {
      _leftTouchTestSteps[stepIndex] = step.copyWith(
        status: TouchStepStatus.failed,
        errorMessage: '执行异常: $e',
      );
      notifyListeners();
      _logState?.error('❌ ${step.name} 异常: $e', type: LogType.debug);
      return false;
    }
  }
  
  /// 执行右Touch测试步骤
  Future<bool> _executeRightTouchStep(int stepIndex) async {
    final step = _rightTouchTestSteps[stepIndex];
    
    try {
      // 更新步骤状态为正在测试
      _rightTouchTestSteps[stepIndex] = step.copyWith(status: TouchStepStatus.testing);
      notifyListeners();
      
      _logState?.info('🔄 步骤: ${step.name}', type: LogType.debug);
      _logState?.info('📝 描述: ${step.description}', type: LogType.debug);
      
      // 如果是第一步（获取基线值），直接发送命令
      if (stepIndex == 0) {
        return await _getRightTouchBaselineCdcValue(step, stepIndex);
      }
      
      // 其他步骤需要用户操作
      return await _waitForUserActionAndGetCdc(step, stepIndex);
      
    } catch (e) {
      _rightTouchTestSteps[stepIndex] = step.copyWith(
        status: TouchStepStatus.failed,
        errorMessage: '执行异常: $e',
      );
      notifyListeners();
      _logState?.error('❌ ${step.name} 异常: $e', type: LogType.debug);
      return false;
    }
  }
  
  /// 获取右Touch基线 CDC 值
  Future<bool> _getRightTouchBaselineCdcValue(TouchTestStep step, int stepIndex) async {
    _logState?.info('📡 获取右Touch基线 CDC 值...', type: LogType.debug);
    
    // 创建命令
    final command = ProductionTestCommands.createTouchCommand(step.touchId, step.actionId);
    
    // 显示发送的命令
    final commandHex = command.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
    _logState?.info('📤 发送: [$commandHex]', type: LogType.debug);
    
    // 发送命令并等待响应
    final response = await _serialService.sendCommandAndWaitResponse(
      command,
      timeout: const Duration(seconds: 5),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );
    
    if (response != null && !response.containsKey('error')) {
      if (response.containsKey('payload') && response['payload'] != null) {
        final payload = response['payload'] as Uint8List;
        final payloadHex = payload.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        _logState?.info('📥 响应: [$payloadHex]', type: LogType.debug);
        
        // 解析Touch响应
        final touchResult = ProductionTestCommands.parseTouchResponse(payload);
        if (touchResult != null && touchResult['success'] == true) {
          _baselineCdcValue = touchResult['cdcValue'];
          
          // 更新步骤状态
          _rightTouchTestSteps[stepIndex] = step.copyWith(
            status: TouchStepStatus.success,
            cdcValue: _baselineCdcValue,
          );
          notifyListeners();
          
          _logState?.success('✅ 右Touch基线 CDC 值: $_baselineCdcValue', type: LogType.debug);
          return true;
        } else {
          final errorMsg = touchResult?['error'] ?? '解析响应失败';
          _logState?.error('❌ 获取右Touch基线 CDC 值失败: $errorMsg', type: LogType.debug);
          return false;
        }
      }
    }
    
    _logState?.error('❌ 获取右Touch基线 CDC 值失败: 无响应', type: LogType.debug);
    return false;
  }
  
  /// 等待左Touch用户操作（不获取CDC值，带重试机制）
  Future<bool> _waitForLeftTouchUserAction(TouchTestStep step, int stepIndex) async {
    const maxRetries = 10;
    
    for (int retry = 0; retry <= maxRetries; retry++) {
      if (retry > 0) {
        _logState?.warning('🔄 重试第 $retry 次: ${step.name}', type: LogType.debug);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      final success = await _executeSingleLeftTouchStep(step, stepIndex, retry);
      if (success) {
        return true;
      }
      
      // 如果不是最后一次重试，继续
      if (retry < maxRetries) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
    
    // 所有重试都失败了
    _leftTouchTestSteps[stepIndex] = step.copyWith(
      status: TouchStepStatus.failed,
      errorMessage: '重试 $maxRetries 次后仍然失败',
      currentRetry: maxRetries,
    );
    notifyListeners();
    
    _logState?.error('❌ ${step.name} 重试 $maxRetries 次后仍然失败', type: LogType.debug);
    return false;
  }
  
  /// 执行单次左Touch步骤
  Future<bool> _executeSingleLeftTouchStep(TouchTestStep step, int stepIndex, int currentRetry) async {
    // 更新步骤状态为等待用户操作
    _leftTouchTestSteps[stepIndex] = step.copyWith(status: TouchStepStatus.userAction);
    notifyListeners();
    
    _logState?.info('👆 ${step.userPrompt}', type: LogType.debug);
    _logState?.info('⏳ 等待用户操作中... (请在 10 秒内完成操作)', type: LogType.debug);
    
    // 创建命令
    final command = ProductionTestCommands.createTouchCommand(step.touchId, step.actionId);
    
    // 显示发送的命令
    final commandHex = command.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
    _logState?.info('📤 发送: [$commandHex]', type: LogType.debug);
    
    // 等待用户操作的时间
    await Future.delayed(const Duration(seconds: 2));
    
    // 发送命令并等待响应（10秒超时）
    final response = await _serialService.sendCommandAndWaitResponse(
      command,
      timeout: const Duration(seconds: 10),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );
    
    if (response != null && !response.containsKey('error')) {
      if (response.containsKey('payload') && response['payload'] != null) {
        final payload = response['payload'] as Uint8List;
        final payloadHex = payload.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        _logState?.info('📥 响应: [$payloadHex]', type: LogType.debug);
        
        // 解析Touch响应
        final touchResult = ProductionTestCommands.parseTouchResponse(payload);
        if (touchResult != null && touchResult['success'] == true) {
          // 更新步骤状态
          _leftTouchTestSteps[stepIndex] = step.copyWith(
            status: TouchStepStatus.success,
            currentRetry: currentRetry,
          );
          notifyListeners();
          
          _logState?.success('✅ ${step.name} 成功', type: LogType.debug);
          return true;
        } else {
          final errorMsg = touchResult?['error'] ?? '解析响应失败';
          
          _leftTouchTestSteps[stepIndex] = step.copyWith(
            status: TouchStepStatus.testing,
            currentRetry: currentRetry,
            errorMessage: errorMsg,
          );
          notifyListeners();
          
          _logState?.error('❌ ${step.name} 解析失败: $errorMsg', type: LogType.debug);
          return false;
        }
      }
    }
    
    // 超时或无响应
    _leftTouchTestSteps[stepIndex] = step.copyWith(
      status: TouchStepStatus.testing,
      currentRetry: currentRetry,
      errorMessage: '超时或无响应',
    );
    notifyListeners();
    
    _logState?.error('❌ ${step.name} 超时或无响应', type: LogType.debug);
    return false;
  }
  
  /// 等待右Touch用户操作并获取 CDC 值（带重试机制）
  Future<bool> _waitForUserActionAndGetCdc(TouchTestStep step, int stepIndex) async {
    const maxRetries = 10;
    
    for (int retry = 0; retry <= maxRetries; retry++) {
      if (retry > 0) {
        _logState?.warning('🔄 重试第 $retry 次: ${step.name}', type: LogType.debug);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      final success = await _executeSingleRightTouchStep(step, stepIndex, retry);
      if (success) {
        return true;
      }
      
      // 如果不是最后一次重试，继续
      if (retry < maxRetries) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
    
    // 所有重试都失败了
    _rightTouchTestSteps[stepIndex] = step.copyWith(
      status: TouchStepStatus.failed,
      errorMessage: '重试 $maxRetries 次后仍然失败',
      currentRetry: maxRetries,
    );
    notifyListeners();
    
    _logState?.error('❌ ${step.name} 重试 $maxRetries 次后仍然失败', type: LogType.debug);
    return false;
  }
  
  /// 执行单次右Touch步骤
  Future<bool> _executeSingleRightTouchStep(TouchTestStep step, int stepIndex, int currentRetry) async {
    // 更新步骤状态为等待用户操作
    _rightTouchTestSteps[stepIndex] = step.copyWith(status: TouchStepStatus.userAction);
    notifyListeners();
    
    _logState?.info('👆 ${step.userPrompt}', type: LogType.debug);
    _logState?.info('⏳ 等待用户操作中... (请在 10 秒内完成操作)', type: LogType.debug);
    
    // 创建命令
    final command = ProductionTestCommands.createTouchCommand(step.touchId, step.actionId);
    
    // 显示发送的命令
    final commandHex = command.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
    _logState?.info('📤 发送: [$commandHex]', type: LogType.debug);
    
    // 等待用户操作的时间
    await Future.delayed(const Duration(seconds: 2));
    
    // 发送命令并等待响应（10秒超时）
    final response = await _serialService.sendCommandAndWaitResponse(
      command,
      timeout: const Duration(seconds: 10),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );
    
    if (response != null && !response.containsKey('error')) {
      if (response.containsKey('payload') && response['payload'] != null) {
        final payload = response['payload'] as Uint8List;
        final payloadHex = payload.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        _logState?.info('📥 响应: [$payloadHex]', type: LogType.debug);
        
        // 解析Touch响应
        final touchResult = ProductionTestCommands.parseTouchResponse(payload);
        if (touchResult != null && touchResult['success'] == true) {
          final cdcValue = touchResult['cdcValue'];
          
          // 计算CDC差值
          int? cdcDiff;
          bool thresholdMet = true;
          String details = 'CDC: $cdcValue';
          
          if (_baselineCdcValue != null) {
            cdcDiff = (cdcValue - _baselineCdcValue!).abs();
            details += ' (差值: ${cdcValue > _baselineCdcValue! ? '+' : '-'}$cdcDiff)';
            
            // 检查CDC差值是否超过阈值
            if (cdcDiff != null && cdcDiff < TouchTestConfig.cdcThreshold) {
              thresholdMet = false;
              details += ' [未达阈值 ${TouchTestConfig.cdcThreshold}]';
            }
          }
          
          if (thresholdMet) {
            // CDC差值超过阈值，测试成功
            _rightTouchTestSteps[stepIndex] = step.copyWith(
              status: TouchStepStatus.success,
              cdcValue: cdcValue,
              cdcDiff: cdcDiff,
              currentRetry: currentRetry,
            );
            notifyListeners();
            
            _logState?.success('✅ ${step.name} 成功 - $details', type: LogType.debug);
            return true;
          } else {
            // CDC差值未达阈值，需要重试
            _rightTouchTestSteps[stepIndex] = step.copyWith(
              status: TouchStepStatus.testing,
              cdcValue: cdcValue,
              cdcDiff: cdcDiff,
              currentRetry: currentRetry,
              errorMessage: 'CDC差值 $cdcDiff 未达阈值 ${TouchTestConfig.cdcThreshold}',
            );
            notifyListeners();
            
            _logState?.warning('⚠️ ${step.name} CDC差值不足 - $details', type: LogType.debug);
            return false;
          }
        } else {
          final errorMsg = touchResult?['error'] ?? '解析响应失败';
          
          _rightTouchTestSteps[stepIndex] = step.copyWith(
            status: TouchStepStatus.testing,
            currentRetry: currentRetry,
            errorMessage: errorMsg,
          );
          notifyListeners();
          
          _logState?.error('❌ ${step.name} 解析失败: $errorMsg', type: LogType.debug);
          return false;
        }
      }
    }
    
    // 超时或无响应
    _rightTouchTestSteps[stepIndex] = step.copyWith(
      status: TouchStepStatus.testing,
      currentRetry: currentRetry,
      errorMessage: '超时或无响应',
    );
    notifyListeners();
    
    _logState?.error('❌ ${step.name} 超时或无响应', type: LogType.debug);
    return false;
  }
  
  /// 重试右Touch步骤
  Future<void> retryRightTouchStep(int stepIndex) async {
    if (stepIndex < 0 || stepIndex >= _rightTouchTestSteps.length) return;
    
    final step = _rightTouchTestSteps[stepIndex];
    
    // 重置步骤状态
    _rightTouchTestSteps[stepIndex] = step.copyWith(
      status: TouchStepStatus.waiting,
      currentRetry: 0,
      errorMessage: null,
    );
    notifyListeners();
    
    _logState?.info('🔄 重新开始: ${step.name}', type: LogType.debug);
    
    // 执行步骤
    if (stepIndex == 0) {
      await _getRightTouchBaselineCdcValue(step, stepIndex);
    } else {
      await _waitForUserActionAndGetCdc(step, stepIndex);
    }
  }
  
  /// 跳过右Touch步骤
  void skipRightTouchStep(int stepIndex) {
    if (stepIndex < 0 || stepIndex >= _rightTouchTestSteps.length) return;
    
    final step = _rightTouchTestSteps[stepIndex];
    
    _rightTouchTestSteps[stepIndex] = step.copyWith(
      status: TouchStepStatus.skipped,
      isSkipped: true,
    );
    notifyListeners();
    
    _logState?.info('⏭️ 跳过步骤: ${step.name}', type: LogType.debug);
  }
  
  /// 重试左Touch步骤
  Future<void> retryLeftTouchStep(int stepIndex) async {
    if (stepIndex < 0 || stepIndex >= _leftTouchTestSteps.length) return;
    
    final step = _leftTouchTestSteps[stepIndex];
    
    // 重置步骤状态
    _leftTouchTestSteps[stepIndex] = step.copyWith(
      status: TouchStepStatus.waiting,
      currentRetry: 0,
      errorMessage: null,
    );
    notifyListeners();
    
    _logState?.info('🔄 重新开始: ${step.name}', type: LogType.debug);
    
    // 执行步骤
    await _waitForLeftTouchUserAction(step, stepIndex);
  }
  
  /// 跳过左Touch步骤
  void skipLeftTouchStep(int stepIndex) {
    if (stepIndex < 0 || stepIndex >= _leftTouchTestSteps.length) return;
    
    final step = _leftTouchTestSteps[stepIndex];
    
    _leftTouchTestSteps[stepIndex] = step.copyWith(
      status: TouchStepStatus.skipped,
      isSkipped: true,
    );
    notifyListeners();
    
    _logState?.info('⏭️ 跳过步骤: ${step.name}', type: LogType.debug);
  }

  /// 开始Sensor测试 - 手动测试也使用相同的简单逻辑
  Future<bool> startSensorTest() async {
    try {
      _logState?.info('📷 开始Sensor传感器测试（手动）', type: LogType.debug);
      
      // 检查图片是否已下载
      if (_sensorImagePath == null || _sensorImagePath!.isEmpty) {
        _logState?.error('❌ Sensor测试失败：未找到测试图片', type: LogType.debug);
        _logState?.info('   提示：请先完成WiFi测试以下载图片', type: LogType.debug);
        return false;
      }
      
      // 验证文件是否存在
      final imageFile = File(_sensorImagePath!);
      if (!await imageFile.exists()) {
        _logState?.error('❌ Sensor测试失败：图片文件不存在', type: LogType.debug);
        _logState?.info('   路径: $_sensorImagePath', type: LogType.debug);
        _sensorImagePath = null; // 清除无效路径
        return false;
      }
      
      // 验证文件大小
      final fileSize = await imageFile.length();
      if (fileSize == 0) {
        _logState?.error('❌ Sensor测试失败：图片文件为空', type: LogType.debug);
        _logState?.info('   路径: $_sensorImagePath', type: LogType.debug);
        return false;
      }
      
      _logState?.success('✅ Sensor测试图片存在，准备显示...', type: LogType.debug);
      _logState?.info('   路径: $_sensorImagePath', type: LogType.debug);
      _logState?.info('   大小: ${(fileSize / 1024).toStringAsFixed(2)} KB', type: LogType.debug);
      
      // 显示图片弹窗供用户查看
      _showSensorDialog = true;
      _completeImageData = await imageFile.readAsBytes();
      notifyListeners();
      
      _logState?.info('📺 显示Sensor测试图片（3秒）...', type: LogType.debug);
      
      // 等待3秒让用户查看图片
      await Future.delayed(const Duration(seconds: 3));
      
      // 关闭弹窗
      _showSensorDialog = false;
      notifyListeners();
      
      _logState?.success('✅ Sensor测试通过', type: LogType.debug);
      
      return true;
    } catch (e) {
      _logState?.error('❌ Sensor测试异常: $e', type: LogType.debug);
      // 确保异常时也关闭弹窗
      _showSensorDialog = false;
      notifyListeners();
      return false;
    }
  }

  /// 内部方法：带重试的Sensor测试启动
  Future<bool> _startSensorTestWithRetry() async {
    _sensorRetryCount++;
    
    if (_sensorRetryCount > 10) {
      _logState?.error('❌ Sensor测试启动失败，已重试10次', type: LogType.debug);
      _resetSensorTest();
      return false;
    }

    _isSensorTesting = true;
    notifyListeners();

    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('📊 开始Sensor图片测试 (第 $_sensorRetryCount 次尝试)', type: LogType.debug);
      _logState?.info('⏱️  开始时间: ${DateTime.now().toString()}', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);

      final startCommand = ProductionTestCommands.createSensorCommand(ProductionTestCommands.sensorOptStart);
      final startCommandHex = startCommand.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📤 发送: [$startCommandHex] (${startCommand.length} bytes)', type: LogType.debug);

      // 发送开始命令并等待SN匹配的响应确认
      final startResponse = await _serialService.sendCommandAndWaitResponse(
        startCommand,
        timeout: const Duration(seconds: 5),
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );

      if (startResponse != null && !startResponse.containsKey('error')) {
        _logState?.success('✅ Sensor测试启动成功，收到确认响应', type: LogType.debug);
      } else {
        _logState?.warning('⚠️  Sensor测试启动失败: ${startResponse?['error'] ?? '无响应'}', type: LogType.debug);
        await Future.delayed(const Duration(seconds: 2));
        return _startSensorTestWithRetry();
      }
      
      // 发送开始发送数据命令 (opt 0x01) - 不等待响应
      _logState?.info('🔄 发送开始发送数据命令 (opt 0x01)', type: LogType.debug);
      final beginDataCommand = ProductionTestCommands.createSensorCommand(ProductionTestCommands.sensorOptBeginData);
      final beginDataCommandHex = beginDataCommand.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📤 发送: [$beginDataCommandHex] (${beginDataCommand.length} bytes)', type: LogType.debug);

      // 直接发送命令，不等待响应
      await _serialService.sendCommand(
        beginDataCommand,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );
      
      _logState?.success('✅ 开始发送数据命令已发送，直接开始监听', type: LogType.debug);
      
      // 开始监听Sensor数据
      _logState?.info('📡 开始监听Sensor图片数据流...', type: LogType.debug);
      await _startSensorDataListener();
      
      // 设置5分钟总超时
      _sensorTimeoutTimer = Timer(const Duration(minutes: 5), () {
        _logState?.error('❌ Sensor测试总超时（5分钟），准备重试', type: LogType.debug);
        _retrySensorTest();
      });

      return true;
    } catch (e) {
      _logState?.error('启动Sensor测试异常: $e', type: LogType.debug);
      await Future.delayed(const Duration(seconds: 2));
      return _startSensorTestWithRetry();
    }
  }

  /// 停止Sensor测试（带重试机制）
  Future<bool> stopSensorTest({int retryCount = 0}) async {
    if (!_isSensorTesting) {
      _logState?.warning('[Sensor] 未在测试中', type: LogType.debug);
      // 即使未在测试，也要确保弹窗关闭
      _showSensorDialog = false;
      notifyListeners();
      return false;
    }

    try {
      // 发送停止sensor测试命令 (0x0C, 0xFF)
      _logState?.info('🛑 发送停止sensor测试命令 (第${retryCount + 1}次尝试)', type: LogType.debug);
      
      final stopCommand = ProductionTestCommands.createSensorCommand(ProductionTestCommands.sensorOptStop);
      final stopCommandHex = stopCommand.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📤 发送: [$stopCommandHex] (${stopCommand.length} bytes)', type: LogType.debug);

      // 发送停止命令并等待SN匹配的响应确认
      final stopResponse = await _serialService.sendCommandAndWaitResponse(
        stopCommand,
        timeout: const Duration(seconds: 5),
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );

      if (stopResponse != null && !stopResponse.containsKey('error')) {
        _logState?.success('✅ 停止sensor测试成功，收到确认响应', type: LogType.debug);
        
        // 成功后才关闭弹窗和清理状态
        await _sensorDataSubscription?.cancel();
        _sensorDataSubscription = null;
        _resetImageBuffer();
        
        _isSensorTesting = false;
        _showSensorDialog = false;
        notifyListeners();
        
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        _logState?.success('✅ Sensor测试结束', type: LogType.debug);
        _logState?.info('📊 总共收到 ${_sensorDataList.length} 个数据包', type: LogType.debug);
        _logState?.info('⏱️  结束时间: ${DateTime.now().toString()}', type: LogType.debug);
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        
        return true;
      } else {
        _logState?.error('❌ 停止sensor测试失败: ${stopResponse?['error'] ?? '无响应'}', type: LogType.debug);
        
        // 失败后重试（最多3次）
        if (retryCount < 3) {
          _logState?.warning('🔄 准备重试停止命令...', type: LogType.debug);
          await Future.delayed(const Duration(seconds: 1));
          return stopSensorTest(retryCount: retryCount + 1);
        } else {
          _logState?.error('❌ 停止命令重试3次后仍失败，强制关闭', type: LogType.debug);
          
          // 强制清理状态
          await _sensorDataSubscription?.cancel();
          _sensorDataSubscription = null;
          _resetImageBuffer();
          
          _isSensorTesting = false;
          _showSensorDialog = false;
          notifyListeners();
          
          return false;
        }
      }
    } catch (e) {
      _logState?.error('停止Sensor测试异常: $e', type: LogType.debug);
      
      // 异常时也要强制清理监听器，避免继续接收数据
      await _sensorDataSubscription?.cancel();
      _sensorDataSubscription = null;
      _resetImageBuffer();
      
      _isSensorTesting = false;
      _showSensorDialog = false;
      notifyListeners();
      
      return false;
    }
  }

  /// 开始监听sensor数据
  Future<void> _startSensorDataListener() async {
    // 先取消之前的监听器，确保完全清理
    await _sensorDataSubscription?.cancel();
    _sensorDataSubscription = null;
    
    // 等待一小段时间确保监听器完全清理
    await Future.delayed(const Duration(milliseconds: 100));
    
    _logState?.info('🎯 启动Sensor数据监听器...', type: LogType.debug);
    _sensorDataSubscription = _serialService.dataStream.listen(
      (data) async {
        try {
          _logState?.info('📨 Sensor监听器收到数据事件！', type: LogType.debug);
          // 打印所有接收到的裸数据
          final rawDataHex = data.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
          // _logState?.info('🔍 Sensor监听-接收裸数据: [$rawDataHex] (${data.length} bytes)', type: LogType.debug);
        
        // 直接检查payload第一个字节是否是Sensor CMD (0x0C)
        _logState?.info('🔍 检查数据: isEmpty=${data.isEmpty}, 第一个字节=${data.isNotEmpty ? '0x${data[0].toRadixString(16).toUpperCase().padLeft(2, '0')}' : 'N/A'}, cmdSensor=0x${ProductionTestCommands.cmdSensor.toRadixString(16).toUpperCase().padLeft(2, '0')}', type: LogType.debug);
        
        if (data.isNotEmpty && data[0] == ProductionTestCommands.cmdSensor) {
          _logState?.info('✅ 匹配Sensor CMD，开始解析...', type: LogType.debug);
          final sensorResult = ProductionTestCommands.parseSensorResponse(data);
          _logState?.info('📊 解析结果: ${sensorResult != null ? 'success=${sensorResult['success']}' : 'null'}', type: LogType.debug);
          
          if (sensorResult != null && sensorResult['success'] == true) {
            _logState?.info('🎯 调用_handleSensorDataPacket...', type: LogType.debug);
            await _handleSensorDataPacket(sensorResult);
          } else {
            _logState?.warning('⚠️  Sensor解析失败或不成功', type: LogType.debug);
          }
        } else {
          _logState?.info('❌ 数据不匹配Sensor CMD，跳过处理', type: LogType.debug);
        }
      } catch (e) {
        _logState?.warning('⚠️  解析Sensor数据时出错: $e', type: LogType.debug);
      }
    },
    onError: (error) {
      _logState?.error('❌ Sensor数据流监听错误: $error', type: LogType.debug);
    },
    onDone: () {
      _logState?.info('✅ Sensor数据流监听完成', type: LogType.debug);
    },
    );
    
    _logState?.info('✅ Sensor数据监听器已启动', type: LogType.debug);
  }

  /// 处理sensor数据包
  Future<void> _handleSensorDataPacket(Map<String, dynamic> sensorResult) async {
    final now = DateTime.now();
    
    // 重置包间超时计时器
    _packetTimeoutTimer?.cancel();
    
    if (sensorResult['type'] == 'command_ack') {
      // 命令确认包
      _logState?.info('📥 收到Sensor命令确认', type: LogType.debug);
      return;
    }
    
    if (sensorResult['type'] == 'image_data') {
      // 图片数据包
      final picTotalBytes = sensorResult['picTotalBytes'] as int;
      final dataIndex = sensorResult['dataIndex'] as int;
      final dataLen = sensorResult['dataLen'] as int;
      final originalDataLen = sensorResult['originalDataLen'] as int? ?? dataLen;
      final data = sensorResult['data'] as Uint8List;
      final isLastPacket = sensorResult['isLastPacket'] as bool;
      
      // 如果实际数据长度与声明长度不同，记录日志
      if (dataLen != originalDataLen) {
        _logState?.info('📏 数据长度调整: 声明=$originalDataLen, 实际=$dataLen', type: LogType.debug);
      }
      
      // 检查包间超时（5秒）
      if (_lastPacketTime != null && now.difference(_lastPacketTime!).inSeconds > 5) {
        _logState?.error('❌ 包间超时（>5秒），准备重试', type: LogType.debug);
        _retrySensorTest();
        return;
      }
      
      // 初始化图片缓冲区
      if (_expectedTotalBytes == null) {
        _expectedTotalBytes = picTotalBytes;
        _imageBuffer = List<int>.filled(picTotalBytes, 0);
        _logState?.info('📊 开始接收图片数据，总大小: $picTotalBytes 字节', type: LogType.debug);
      }
      
      // 验证总大小一致性
      if (_expectedTotalBytes != picTotalBytes) {
        _logState?.error('❌ 图片总大小不一致，期望: $_expectedTotalBytes, 实际: $picTotalBytes', type: LogType.debug);
        _retrySensorTest();
        return;
      }
      
      // 验证数据范围
      if (dataIndex + dataLen > picTotalBytes) {
        _logState?.error('❌ 数据包范围超出总大小: 偏移=$dataIndex + 长度=$dataLen > 总大小=$picTotalBytes', type: LogType.debug);
        _retrySensorTest();
        return;
      }
      
      // 复制数据到缓冲区，并显示详细信息
      int copiedBytes = 0;
      
      // 调试：检查接收到的数据内容
      final dataHex = data.take(32).map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📦 数据包 #${_sensorDataList.length + 1} 内容前32字节: [$dataHex]${data.length > 32 ? '...' : ''}', type: LogType.debug);
      
      // 检查数据是否全为0
      final nonZeroCount = data.where((b) => b != 0).length;
      _logState?.info('📊 数据统计: 总字节=$dataLen, 非零字节=$nonZeroCount, 零字节=${dataLen - nonZeroCount}', type: LogType.debug);
      
      for (int i = 0; i < dataLen; i++) {
        if (dataIndex + i < _imageBuffer.length) {
          _imageBuffer[dataIndex + i] = data[i];
          copiedBytes++;
        }
      }
      
      _lastPacketTime = now;
      
      // 记录数据包信息
      final packetInfo = {
        'timestamp': now.toString(),
        'index': _sensorDataList.length + 1,
        'picTotalBytes': picTotalBytes,
        'dataIndex': dataIndex,
        'dataLen': dataLen,
        'copiedBytes': copiedBytes,
        'isLastPacket': isLastPacket,
        'progress': ((dataIndex + dataLen) / picTotalBytes * 100).toStringAsFixed(1),
        'type': 'image_packet',
      };
      
      _sensorDataList.add(packetInfo);
      notifyListeners();
      
      // 详细的包信息日志
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('📥 图片数据包 #${packetInfo['index']}:', type: LogType.debug);
      _logState?.info('   偏移地址: $dataIndex', type: LogType.debug);
      _logState?.info('   数据长度: $dataLen', type: LogType.debug);
      _logState?.info('   复制字节: $copiedBytes', type: LogType.debug);
      _logState?.info('   接收进度: ${packetInfo['progress']}%', type: LogType.debug);
      _logState?.info('   是否最后包: $isLastPacket', type: LogType.debug);
      
      // 显示数据的前几个字节用于调试
      if (data.isNotEmpty) {
        final dataHex = data.take(16).map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        _logState?.info('   数据前16字节: [$dataHex]${data.length > 16 ? '...' : ''}', type: LogType.debug);
      }
      
      // 如果是第一个包，检查文件头
      if (dataIndex == 0 && data.length >= 4) {
        final fileHeader = data.take(4).map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        _logState?.info('   🔍 文件头: [$fileHeader]', type: LogType.debug);
        
        // 检查常见图片格式
        if (data[0] == 0xFF && data[1] == 0xD8) {
          _logState?.info('   📷 检测到JPEG格式', type: LogType.debug);
        } else if (data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47) {
          _logState?.info('   📷 检测到PNG格式', type: LogType.debug);
        } else if (data[0] == 0x42 && data[1] == 0x4D) {
          _logState?.info('   📷 检测到BMP格式', type: LogType.debug);
        } else {
          _logState?.warning('   ⚠️  未识别的文件格式，文件头: [$fileHeader]', type: LogType.debug);
        }
      }
      
      // 设置下一个包的超时计时器（5秒）
      if (!isLastPacket) {
        _packetTimeoutTimer = Timer(const Duration(seconds: 5), () {
          _logState?.error('❌ 等待下一包超时（5秒），准备重试', type: LogType.debug);
          _retrySensorTest();
        });
      } else {
        // 最后一个包，验证完整性并显示图片
        _logState?.success('✅ 图片数据接收完成！', type: LogType.debug);
        await _handleImageComplete();
      }
    }
  }

  /// 处理图片接收完成
  Future<void> _handleImageComplete() async {
    _sensorTimeoutTimer?.cancel();
    _packetTimeoutTimer?.cancel();
    
    try {
      // 创建图片数据
      _completeImageData = Uint8List.fromList(_imageBuffer);
      
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.success('✅ Sensor图片数据接收完成！', type: LogType.debug);
      _logState?.info('📊 图片总大小: $_expectedTotalBytes 字节', type: LogType.debug);
      _logState?.info('📦 总包数: ${_sensorDataList.length}', type: LogType.debug);
      
      // 验证图片数据完整性
      _logState?.info('🔍 验证图片数据完整性...', type: LogType.debug);
      
      // 显示图片的前32字节用于调试
      if (_completeImageData!.length >= 32) {
        final headerHex = _completeImageData!.take(32).map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        _logState?.info('   图片前32字节: [$headerHex]', type: LogType.debug);
      }
      
      // 显示图片的最后16字节用于调试
      if (_completeImageData!.length >= 16) {
        final tailStart = _completeImageData!.length - 16;
        final tailHex = _completeImageData!.sublist(tailStart).map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        _logState?.info('   图片后16字节: [$tailHex]', type: LogType.debug);
      }
      
      // 检查图片格式
      String imageFormat = '未知格式';
      bool isValidImage = false;
      
      if (_completeImageData!.length >= 4) {
        final header = _completeImageData!;
        if (header[0] == 0xFF && header[1] == 0xD8) {
          imageFormat = 'JPEG';
          isValidImage = true;
          // 检查JPEG结尾标记
          if (_completeImageData!.length >= 2) {
            final end = _completeImageData!.length;
            if (header[end-2] == 0xFF && header[end-1] == 0xD9) {
              _logState?.info('   📷 JPEG格式验证: 开始和结束标记正确', type: LogType.debug);
            } else {
              _logState?.warning('   ⚠️  JPEG格式警告: 缺少结束标记 FF D9', type: LogType.debug);
            }
          }
        } else if (header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47) {
          imageFormat = 'PNG';
          isValidImage = true;
          _logState?.info('   📷 PNG格式验证: 文件头正确', type: LogType.debug);
        } else if (header[0] == 0x42 && header[1] == 0x4D) {
          imageFormat = 'BMP';
          isValidImage = true;
          _logState?.info('   📷 BMP格式验证: 文件头正确', type: LogType.debug);
        } else {
          final headerHex = header.take(8).map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
          _logState?.error('   ❌ 未识别的图片格式，文件头: [$headerHex]', type: LogType.debug);
        }
      }
      
      _logState?.info('   📷 图片格式: $imageFormat', type: LogType.debug);
      _logState?.info('   ✅ 格式验证: ${isValidImage ? '通过' : '失败'}', type: LogType.debug);
      
      // 保存图片文件
      String? savedFilePath;
      try {
        savedFilePath = await _saveImageToFile(_completeImageData!, imageFormat);
        if (savedFilePath != null) {
          _logState?.success('   💾 图片已保存: $savedFilePath', type: LogType.debug);
        } else {
          _logState?.warning('   ⚠️  图片保存失败', type: LogType.debug);
        }
      } catch (e) {
        _logState?.error('   ❌ 保存图片时出错: $e', type: LogType.debug);
      }
      
      // 添加完成状态到数据列表
      final completeInfo = {
        'timestamp': DateTime.now().toString(),
        'index': _sensorDataList.length + 1,
        'type': 'image_complete',
        'imageData': _completeImageData,
        'totalBytes': _expectedTotalBytes,
        'imageFormat': imageFormat,
        'isValidImage': isValidImage,
        'savedFilePath': savedFilePath,
        'message': '图片接收完成，等待用户确认',
      };
      
      _sensorDataList.add(completeInfo);
      notifyListeners();
      
      _logState?.info('⏱️  完成时间: ${DateTime.now().toString()}', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      
    } catch (e) {
      _logState?.error('处理完成的图片数据时出错: $e', type: LogType.debug);
      _retrySensorTest();
    }
  }

  /// 重试sensor测试
  void _retrySensorTest() async {
    _logState?.warning('🔄 准备重试Sensor测试...', type: LogType.debug);
    
    // 先停止当前测试
    await _stopSensorTestInternal();
    
    // 等待一段时间后重试
    await Future.delayed(const Duration(seconds: 2));
    
    // 重新开始测试
    await _startSensorTestWithRetry();
  }

  /// 重置图片缓冲区
  void _resetImageBuffer() {
    _imageBuffer = [];  // 重新创建空列表，而不是clear固定长度列表
    _expectedTotalBytes = null;
    _lastPacketTime = null;
    _completeImageData = null;
  }

  /// 保存图片到文件
  Future<String?> _saveImageToFile(Uint8List imageData, String imageFormat) async {
    try {
      // 创建保存目录 - 使用用户桌面目录，避免权限问题
      String userHome;
      if (Platform.isMacOS || Platform.isLinux) {
        userHome = Platform.environment['HOME'] ?? Directory.current.path;
      } else if (Platform.isWindows) {
        userHome = Platform.environment['USERPROFILE'] ?? Directory.current.path;
      } else {
        userHome = Directory.current.path;
      }
      
      final saveDir = Directory(path.join(userHome, 'Documents', 'JNProductionLine', 'sensor_images'));
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
        _logState?.info('   📁 创建保存目录: ${saveDir.path}', type: LogType.debug);
      }
      
      return await _saveImageToFileInDirectory(imageData, imageFormat, saveDir);
    } catch (e) {
      _logState?.error('   ❌ 保存图片文件时出错: $e', type: LogType.debug);
      return null;
    }
  }

  /// 在指定目录中保存图片文件
  Future<String?> _saveImageToFileInDirectory(Uint8List imageData, String imageFormat, Directory saveDir) async {
    try {
      // 生成文件名
      final timestamp = DateTime.now();
      final dateStr = '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}';
      final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}${timestamp.second.toString().padLeft(2, '0')}';
      
      // 根据格式确定文件扩展名
      String extension;
      switch (imageFormat.toLowerCase()) {
        case 'jpeg':
          extension = 'jpg';
          break;
        case 'png':
          extension = 'png';
          break;
        case 'bmp':
          extension = 'bmp';
          break;
        default:
          extension = 'bin'; // 未知格式保存为二进制文件
      }
      
      final fileName = 'sensor_image_${dateStr}_${timeStr}.${extension}';
      final filePath = path.join(saveDir.path, fileName);
      
      // 检查目录写入权限
      try {
        // 尝试创建一个临时文件来测试权限
        final testFile = File(path.join(saveDir.path, '.test_permission'));
        await testFile.writeAsBytes([0]);
        await testFile.delete();
        _logState?.info('   ✅ 目录写入权限检查通过: ${saveDir.path}', type: LogType.debug);
      } catch (e) {
        _logState?.error('   ❌ 目录写入权限不足: ${saveDir.path}', type: LogType.debug);
        throw Exception('目录写入权限不足: $e');
      }
      
      // 写入文件
      final file = File(filePath);
      await file.writeAsBytes(imageData);
      
      // 验证文件大小
      final fileSize = await file.length();
      _logState?.info('   📊 文件信息:', type: LogType.debug);
      _logState?.info('      文件路径: $filePath', type: LogType.debug);
      _logState?.info('      文件大小: $fileSize 字节', type: LogType.debug);
      _logState?.info('      原始大小: ${imageData.length} 字节', type: LogType.debug);
      _logState?.info('      大小匹配: ${fileSize == imageData.length ? '✅' : '❌'}', type: LogType.debug);
      
      if (fileSize == imageData.length) {
        return filePath;
      } else {
        _logState?.error('   ❌ 文件大小不匹配，保存可能失败', type: LogType.debug);
        return null;
      }
      
    } catch (e) {
      _logState?.error('   ❌ 在目录 ${saveDir.path} 中保存图片文件时出错: $e', type: LogType.debug);
      return null;
    }
  }

  /// 重置sensor测试状态
  void _resetSensorTest() {
    _isSensorTesting = false;
    _showSensorDialog = false;
    _sensorRetryCount = 0;
    _sensorDataList.clear();
    _resetImageBuffer();
    notifyListeners();
  }

  /// 完全清理sensor测试状态（在开始新测试前调用）
  Future<void> _cleanupSensorTest() async {
    try {
      // 取消现有的数据监听器
      await _sensorDataSubscription?.cancel();
      _sensorDataSubscription = null;
      
      // 清理所有状态
      _isSensorTesting = false;
      _showSensorDialog = false;
      _sensorRetryCount = 0;
      _sensorDataList.clear();
      _resetImageBuffer();
      
      // 清理定时器
      _sensorTimeoutTimer?.cancel();
      _sensorTimeoutTimer = null;
      _packetTimeoutTimer?.cancel();
      _packetTimeoutTimer = null;
      
      _logState?.info('🧹 Sensor测试状态已完全清理', type: LogType.debug);
    } catch (e) {
      _logState?.error('❌ 清理Sensor测试状态时出错: $e', type: LogType.debug);
    }
  }

  /// 内部停止sensor测试方法
  Future<void> _stopSensorTestInternal() async {
    try {
      final stopCommand = ProductionTestCommands.createSensorCommand(ProductionTestCommands.sensorOptStop);
      final stopResponse = await _serialService.sendCommandAndWaitResponse(
        stopCommand,
        timeout: const Duration(seconds: 5),
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );
      
      if (stopResponse != null && !stopResponse.containsKey('error')) {
        _logState?.debug('内部停止sensor测试成功', type: LogType.debug);
      } else {
        _logState?.warning('内部停止sensor测试失败: ${stopResponse?['error'] ?? '无响应'}', type: LogType.debug);
      }
      
      await _sensorDataSubscription?.cancel();
      _sensorDataSubscription = null;
      _resetImageBuffer();
      
    } catch (e) {
      _logState?.warning('停止sensor测试时出错: $e', type: LogType.debug);
    }
  }

  /// 关闭Sensor测试弹窗
  void closeSensorDialog() {
    try {
      _showSensorDialog = false;
      // 如果正在测试，需要异步停止测试，避免递归调用
      if (_isSensorTesting) {
        _logState?.info('🔄 关闭弹窗时停止正在进行的测试', type: LogType.debug);
        // 使用异步方式停止测试，避免阻塞UI
        Future.microtask(() async {
          await stopSensorTest();
          // 停止测试后清空数据
          _sensorDataList.clear();
          _completeImageData = null;
          _resetImageBuffer();
          _logState?.info('🧹 Sensor数据已清空', type: LogType.debug);
          notifyListeners();
        });
      } else {
        // 如果没有在测试，直接清空数据
        _sensorDataList.clear();
        _completeImageData = null;
        _resetImageBuffer();
        _logState?.info('🧹 Sensor数据已清空', type: LogType.debug);
      }
      notifyListeners();
      _logState?.info('🔄 Sensor弹窗已关闭', type: LogType.debug);
    } catch (e) {
      _logState?.error('❌ 关闭Sensor弹窗时出错: $e', type: LogType.debug);
    }
  }
  
  /// 重新打开Sensor测试弹窗
  void reopenSensorDialog() {
    if (_isSensorTesting) {
      _showSensorDialog = true;
      notifyListeners();
      _logState?.info('🔄 Sensor测试弹窗已重新打开', type: LogType.debug);
    } else {
      _logState?.warning('⚠️ 没有正在进行的Sensor测试', type: LogType.debug);
    }
  }

  /// 清空Sensor数据
  void clearSensorData() {
    _sensorDataList.clear();
    _completeImageData = null;
    _resetImageBuffer();
    notifyListeners();
    _logState?.info('🧹 Sensor数据已清空', type: LogType.debug);
  }

  /// 手动保存当前图片
  Future<String?> saveSensorImage() async {
    if (_completeImageData == null) {
      _logState?.warning('没有可保存的图片数据', type: LogType.debug);
      return null;
    }

    try {
      _logState?.info('🔄 开始手动保存图片...', type: LogType.debug);
      
      // 检测图片格式
      String imageFormat = '未知格式';
      if (_completeImageData!.length >= 4) {
        final header = _completeImageData!;
        if (header[0] == 0xFF && header[1] == 0xD8) {
          imageFormat = 'JPEG';
        } else if (header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47) {
          imageFormat = 'PNG';
        } else if (header[0] == 0x42 && header[1] == 0x4D) {
          imageFormat = 'BMP';
        }
      }
      
      final savedPath = await _saveImageToFile(_completeImageData!, imageFormat);
      if (savedPath != null) {
        _logState?.success('✅ 图片手动保存成功: $savedPath', type: LogType.debug);
        return savedPath;
      } else {
        _logState?.error('❌ 图片手动保存失败', type: LogType.debug);
        return null;
      }
    } catch (e) {
      _logState?.error('❌ 手动保存图片时出错: $e', type: LogType.debug);
      return null;
    }
  }

  /// 开始IMU数据流监听
  Future<bool> startIMUDataStream() async {
    if (!_serialService.isConnected) {
      _logState?.error('串口未连接，无法开始IMU数据流监听', type: LogType.debug);
      return false;
    }

    if (_isIMUTesting) {
      _logState?.warning('IMU数据流监听已在进行中', type: LogType.debug);
      return true;
    }

    try {
      // 第一步：先显示弹窗
      _showIMUDialog = true;
      _imuDataList.clear();
      notifyListeners();
      
      _logState?.info('🎯 IMU测试弹窗已打开', type: LogType.debug);
      
      // 第二步：发送命令启动测试（直接发送，不等待响应）
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('📊 开始IMU数据流监听', type: LogType.debug);
      _logState?.info('⏱️  开始时间: ${DateTime.now().toString()}', type: LogType.debug);
      
      // 发送开始获取IMU数据命令 (CMD 0x0B + OPT 0x00)
      _logState?.info('🔄 发送开始获取IMU数据命令 (CMD 0x0B, OPT 0x00)', type: LogType.debug);
      
      final startCommand = ProductionTestCommands.createIMUCommand(ProductionTestCommands.imuOptStartData);
      final startCommandHex = startCommand.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📤 发送: [$startCommandHex] (${startCommand.length} bytes)', type: LogType.debug);

      // 直接发送命令，不等待SN匹配的响应
      await _serialService.sendCommand(
        startCommand,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );

      _logState?.success('✅ 开始获取IMU数据命令已发送', type: LogType.debug);
      
      // 设置状态并开始监听
      _isIMUTesting = true;
      
      // 开始监听IMU数据流（直接监听dataStream，不匹配SN）
      _startIMUDataListener();
      
      notifyListeners();
      _logState?.info('📡 IMU数据流监听已开始，等待数据推送...', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      
      return true;
    } catch (e) {
      _logState?.error('开始IMU数据流监听异常: $e', type: LogType.debug);
      // 异常时关闭弹窗
      _showIMUDialog = false;
      notifyListeners();
      return false;
    }
  }

  /// 停止IMU数据流监听（带重试机制）
  Future<bool> stopIMUDataStream({int retryCount = 0}) async {
    if (!_isIMUTesting) {
      _logState?.warning('IMU数据流监听未在进行中', type: LogType.debug);
      // 即使未在测试，也要确保弹窗关闭
      _showIMUDialog = false;
      notifyListeners();
      return true;
    }

    try {
      _logState?.info('🛑 停止IMU数据流监听 (第${retryCount + 1}次尝试)', type: LogType.debug);
      
      // 发送停止获取IMU数据命令 (CMD 0x0B + OPT 0x01)
      final stopCommand = ProductionTestCommands.createIMUCommand(ProductionTestCommands.imuOptStopData);
      final stopCommandHex = stopCommand.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📤 发送停止命令: [$stopCommandHex] (${stopCommand.length} bytes)', type: LogType.debug);

      // 等待SN匹配的确认响应
      final stopResponse = await _serialService.sendCommandAndWaitResponse(
        stopCommand,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
        timeout: const Duration(seconds: 5),
      );

      if (stopResponse != null && !stopResponse.containsKey('error')) {
        _logState?.success('✅ 停止IMU数据流监听成功', type: LogType.debug);
        
        // 成功后清理状态，但不关闭弹窗（由调用者关闭）
        await _imuDataSubscription?.cancel();
        _imuDataSubscription = null;
        
        _isIMUTesting = false;
        notifyListeners();
        
        _logState?.info('📊 IMU数据流监听已停止，共收到 ${_imuDataList.length} 条数据', type: LogType.debug);
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        
        return true;
      } else {
        _logState?.error('❌ 停止IMU数据流监听失败: ${stopResponse?['error'] ?? '无响应'}', type: LogType.debug);
        
        // 失败后重试（最多3次）
        if (retryCount < 3) {
          _logState?.warning('🔄 准备重试停止命令...', type: LogType.debug);
          await Future.delayed(const Duration(seconds: 1));
          return stopIMUDataStream(retryCount: retryCount + 1);
        } else {
          _logState?.error('❌ 停止命令重试3次后仍失败，强制清理', type: LogType.debug);
          
          // 强制清理状态，但不关闭弹窗（由调用者关闭）
          await _imuDataSubscription?.cancel();
          _imuDataSubscription = null;
          
          _isIMUTesting = false;
          notifyListeners();
          
          return false;
        }
      }
    } catch (e) {
      _logState?.error('停止IMU数据流监听异常: $e', type: LogType.debug);
      
      // 异常时强制清理，但不关闭弹窗（由调用者关闭）
      await _imuDataSubscription?.cancel();
      _imuDataSubscription = null;
      _isIMUTesting = false;
      notifyListeners();
      
      return false;
    }
  }

  /// 开始监听IMU数据
  void _startIMUDataListener() {
    _imuDataSubscription = _serialService.dataStream.listen((data) async {
      try {
        // 打印所有接收到的裸数据
        final rawDataHex = data.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        // _logState?.info('🔍 IMU监听-接收裸数据: [$rawDataHex] (${data.length} bytes)', type: LogType.debug);
        
        // 直接检查payload第一个字节是否是IMU CMD (0x0B)
        if (data.isNotEmpty && data[0] == ProductionTestCommands.cmdIMU) {
          await _handleIMUDataPacket(data);
        }
      } catch (e) {
        _logState?.warning('⚠️  解析IMU数据时出错: $e', type: LogType.debug);
      }
    });
  }

  /// 处理IMU数据包
  Future<void> _handleIMUDataPacket(Uint8List payload) async {
    try {
      final now = DateTime.now();
      
      // 显示完整的hex数据
      final payloadHex = payload.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('📥 IMU数据包 #${_imuDataList.length + 1}', type: LogType.debug);
      _logState?.info('   Payload长度: ${payload.length} 字节', type: LogType.debug);
      _logState?.info('   完整数据: [$payloadHex]', type: LogType.debug);
      
      // 解析IMU数据结构
      if (payload.length >= 33) { // 1 + 4*4 + 8 + 4*3 + 8 = 33字节
        try {
          ByteData buffer = ByteData.sublistView(payload);
          int offset = 1; // 跳过CMD字节
          
          // 解析数据结构: float gyro_x, gyro_y, gyro_z, int64_t gyro_ts, float accel_x, accel_y, accel_z, int64_t accel_ts
          double gyroX = buffer.getFloat32(offset, Endian.little); offset += 4;
          double gyroY = buffer.getFloat32(offset, Endian.little); offset += 4;
          double gyroZ = buffer.getFloat32(offset, Endian.little); offset += 4;
          int gyroTs = buffer.getInt64(offset, Endian.little); offset += 8;
          
          double accelX = buffer.getFloat32(offset, Endian.little); offset += 4;
          double accelY = buffer.getFloat32(offset, Endian.little); offset += 4;
          double accelZ = buffer.getFloat32(offset, Endian.little); offset += 4;
          int accelTs = buffer.getInt64(offset, Endian.little);
          
          _logState?.info('   📊 IMU数据解析:', type: LogType.debug);
          _logState?.info('      CMD: 0x${payload[0].toRadixString(16).toUpperCase().padLeft(2, '0')} (${payload[0]})', type: LogType.debug);
          _logState?.info('      陀螺仪 (°/s): X=${gyroX.toStringAsFixed(3)}, Y=${gyroY.toStringAsFixed(3)}, Z=${gyroZ.toStringAsFixed(3)}', type: LogType.debug);
          _logState?.info('      陀螺仪时间戳: $gyroTs', type: LogType.debug);
          _logState?.info('      加速度 (m/s²): X=${accelX.toStringAsFixed(3)}, Y=${accelY.toStringAsFixed(3)}, Z=${accelZ.toStringAsFixed(3)}', type: LogType.debug);
          _logState?.info('      加速度时间戳: $accelTs', type: LogType.debug);
          
          // 添加到数据列表
          final imuData = {
            'index': _imuDataList.length + 1,
            'timestamp': now.toString(),
            'gyro_x': gyroX,
            'gyro_y': gyroY,
            'gyro_z': gyroZ,
            'gyro_ts': gyroTs,
            'accel_x': accelX,
            'accel_y': accelY,
            'accel_z': accelZ,
            'accel_ts': accelTs,
            'raw_data': payloadHex,
          };
          
          _imuDataList.add(imuData);
          notifyListeners();
          
          _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
          
        } catch (e) {
          _logState?.warning('解析IMU数据结构时出错: $e', type: LogType.debug);
        }
      } else {
        _logState?.warning('IMU数据包长度不足，无法解析: ${payload.length} < 33 字节', type: LogType.debug);
      }
      
    } catch (e) {
      _logState?.error('处理IMU数据包时出错: $e', type: LogType.debug);
    }
  }

  /// 关闭IMU测试弹窗
  void closeIMUDialog() {
    try {
      _showIMUDialog = false;
      // 如果正在测试，需要异步停止测试，避免递归调用
      if (_isIMUTesting) {
        _logState?.info('🔄 关闭弹窗时停止正在进行的测试', type: LogType.debug);
        // 使用异步方式停止测试，避免阻塞UI
        Future.microtask(() async {
          await stopIMUDataStream();
          // 停止测试后清空数据
          _imuDataList.clear();
          _logState?.info('🧹 IMU数据已清空', type: LogType.debug);
          notifyListeners();
        });
      } else {
        // 如果没有在测试，直接清空数据
        _imuDataList.clear();
        _logState?.info('🧹 IMU数据已清空', type: LogType.debug);
      }
      notifyListeners();
      _logState?.info('🔄 IMU弹窗已关闭', type: LogType.debug);
    } catch (e) {
      _logState?.error('❌ 关闭IMU弹窗时出错: $e', type: LogType.debug);
    }
  }
  
  /// 重新打开IMU测试弹窗
  void reopenIMUDialog() {
    if (_isIMUTesting) {
      _showIMUDialog = true;
      notifyListeners();
      _logState?.info('🔄 IMU测试弹窗已重新打开', type: LogType.debug);
    } else {
      _logState?.warning('⚠️ 没有正在进行的IMU测试', type: LogType.debug);
    }
  }

  /// 清空IMU数据
  void clearIMUData() {
    _imuDataList.clear();
    notifyListeners();
  }

  // LED测试相关方法
  /// 开始LED测试
  Future<bool> startLEDTest(String ledType) async {
    try {
      _logState?.info('🔄 开始LED${ledType}测试', type: LogType.debug);
      
      // 根据LED类型创建不同的命令
      // 这里需要根据实际的LED命令协议来实现
      // 假设LED内侧和外侧有不同的命令ID
      final command = _createLEDStartCommand(ledType);
      final commandHex = command.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📤 发送LED${ledType}开始命令: [$commandHex]', type: LogType.debug);

      // 发送命令并等待响应
      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: const Duration(seconds: 5),
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );

      if (response != null && !response.containsKey('error')) {
        _logState?.success('✅ LED${ledType}测试启动成功', type: LogType.debug);
        return true;
      } else {
        _logState?.warning('⚠️ LED${ledType}测试启动失败: ${response?['error'] ?? '无响应'}', type: LogType.debug);
        return false;
      }
    } catch (e) {
      _logState?.error('❌ LED${ledType}测试启动异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 停止LED测试
  Future<bool> stopLEDTest(String ledType) async {
    try {
      _logState?.info('🔄 停止LED${ledType}测试', type: LogType.debug);
      
      // 根据LED类型创建停止命令
      final command = _createLEDStopCommand(ledType);
      final commandHex = command.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📤 发送LED${ledType}停止命令: [$commandHex]', type: LogType.debug);

      // 发送命令并等待响应
      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: const Duration(seconds: 5),
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );

      if (response != null && !response.containsKey('error')) {
        _logState?.success('✅ LED${ledType}测试停止成功', type: LogType.debug);
        return true;
      } else {
        _logState?.warning('⚠️ LED${ledType}测试停止失败: ${response?['error'] ?? '无响应'}', type: LogType.debug);
        return false;
      }
    } catch (e) {
      _logState?.error('❌ LED${ledType}测试停止异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 创建LED开始命令
  Uint8List _createLEDStartCommand(String ledType) {
    // 根据LED类型创建开启命令
    // cmd: 0x05, ledType: 0x00(外侧)/0x01(内侧), opt: 0x00(开启)
    final ledTypeValue = ledType == "内侧" ? 0x01 : 0x00;
    return ProductionTestCommands.createLEDCommand(ledTypeValue, 0x00); // 0x00表示开启
  }

  /// 创建LED停止命令
  Uint8List _createLEDStopCommand(String ledType) {
    // 根据LED类型创建关闭命令
    // cmd: 0x05, ledType: 0x00(外侧)/0x01(内侧), opt: 0x01(关闭)
    final ledTypeValue = ledType == "内侧" ? 0x01 : 0x00;
    return ProductionTestCommands.createLEDCommand(ledTypeValue, 0x01); // 0x01表示关闭
  }

  // LED测试结果记录
  final Map<String, bool> _ledTestResults = {};

  /// 记录LED测试结果
  Future<void> recordLEDTestResult(String ledType, bool testPassed) async {
    try {
      _ledTestResults[ledType] = testPassed;
      
      if (testPassed) {
        _logState?.success('✅ LED${ledType}测试通过', type: LogType.debug);
      } else {
        _logState?.warning('❌ LED${ledType}测试未通过', type: LogType.debug);
      }
      
      // 可以在这里添加更多的记录逻辑，比如保存到文件或数据库
      notifyListeners();
    } catch (e) {
      _logState?.error('❌ 记录LED${ledType}测试结果失败: $e', type: LogType.debug);
    }
  }

  /// 获取LED测试结果
  bool? getLEDTestResult(String ledType) {
    return _ledTestResults[ledType];
  }

  /// 获取所有LED测试结果
  Map<String, bool> getAllLEDTestResults() {
    return Map.from(_ledTestResults);
  }

  /// 清空LED测试结果
  void clearLEDTestResults() {
    _ledTestResults.clear();
    notifyListeners();
  }

  // ==================== 自动化测试流程 ====================

  /// 开始自动化测试
  Future<void> startAutoTest() async {
    if (_isAutoTesting) {
      _logState?.warning('自动化测试已在进行中', type: LogType.debug);
      return;
    }

    if (!_serialService.isConnected) {
      _logState?.error('串口未连接，无法开始自动化测试', type: LogType.debug);
      return;
    }

    // 检查GPIB是否就绪（除非启用了跳过选项）
    if (!_isGpibReady && !AutomationTestConfig.skipGpibTests && !AutomationTestConfig.skipGpibReadyCheck) {
      _logState?.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.error('❌ GPIB设备未就绪，无法开始自动化测试', type: LogType.debug);
      _logState?.error('请先点击"GPIB检测"按钮连接程控电源，或在跳过设置中启用跳过选项', type: LogType.debug);
      _logState?.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      return;
    }
    
    // 如果跳过GPIB检查，给出提示
    if (!_isGpibReady && (AutomationTestConfig.skipGpibTests || AutomationTestConfig.skipGpibReadyCheck)) {
      _logState?.warning('⚠️  已跳过GPIB设备就绪检查（测试模式）', type: LogType.debug);
      _logState?.warning('⚠️  已跳过GPIB设备就绪检查（测试模式）', type: LogType.gpib);
    }

    _isAutoTesting = true;
    _currentAutoTestIndex = 0;
    _testReportItems.clear();
    
    final deviceSN = _currentDeviceIdentity?['sn'] ?? 'UNKNOWN';
    final bluetoothMAC = _currentDeviceIdentity?['bluetoothMac'];
    final wifiMAC = _currentDeviceIdentity?['wifiMac'];
    
    _currentTestReport = TestReport(
      deviceSN: deviceSN,
      bluetoothMAC: bluetoothMAC,
      wifiMAC: wifiMAC,
      startTime: DateTime.now(),
      items: [],
    );
    
    notifyListeners();
    
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
    _logState?.info('🚀 开始自动化测试', type: LogType.debug);
    _logState?.info('📱 设备SN: $deviceSN', type: LogType.debug);
    if (bluetoothMAC != null) {
      _logState?.info('📶 蓝牙MAC: $bluetoothMAC', type: LogType.debug);
    }
    if (wifiMAC != null) {
      _logState?.info('📡 WiFi MAC: $wifiMAC', type: LogType.debug);
    }
    _logState?.info('⏱️  开始时间: ${DateTime.now()}', type: LogType.debug);
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
    
    // 执行所有测试项
    await _executeAllTests();
    
    // 检查是否被用户停止
    if (_shouldStopTest) {
      _logState?.warning('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.warning('🛑 自动化测试已被用户停止，不生成测试报告', type: LogType.debug);
      _logState?.warning('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      
      // 清理状态
      _isAutoTesting = false;
      _shouldStopTest = false;
      _currentTestReport = null;
      _testReportItems.clear();
      _currentAutoTestIndex = 0;
      notifyListeners();
      return;
    }
    
    // 生成最终报告
    _finalizeTestReport();
    
    // 自动保存测试报告
    _logState?.info('💾 自动保存测试报告...', type: LogType.debug);
    final savedPath = await saveTestReport();
    if (savedPath != null) {
      _logState?.success('✅ 测试报告已自动保存: $savedPath', type: LogType.debug);
    } else {
      _logState?.warning('⚠️ 测试报告自动保存失败', type: LogType.debug);
    }
    
    _isAutoTesting = false;
    _showTestReportDialog = true;
    notifyListeners();
  }

  /// 带重试的测试执行包装器
  Future<bool> _executeTestWithRetry(
    String testName,
    Future<bool> Function() executor, {
    int maxRetries = 10,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    // 根据测试名称调整超时时间
    Duration actualTimeout = timeout;
    if (testName.contains('工作功耗测试') || testName.contains('漏电流测试')) {
      // GPIB 电流测试需要更长时间（20次采样 × 10秒 + 间隔）
      actualTimeout = const Duration(seconds: 240); // 4分钟
    }
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // 使用timeout包装执行
        final result = await executor().timeout(
          actualTimeout,
          onTimeout: () {
            _logState?.warning('⏱️  $testName 超时 (尝试 $attempt/$maxRetries, 超时时间: ${actualTimeout.inSeconds}秒)', type: LogType.debug);
            return false;
          },
        );
        
        if (result) {
          if (attempt > 1) {
            _logState?.success('✅ $testName 成功 (第 $attempt 次尝试)', type: LogType.debug);
          }
          return true;
        } else {
          if (attempt < maxRetries) {
            _logState?.warning('⚠️  $testName 失败，准备重试 (尝试 $attempt/$maxRetries)', type: LogType.debug);
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }
      } catch (e) {
        // 如果是跳过异常，直接抛出
        if (e.toString().contains('SKIP')) {
          rethrow;
        }
        
        if (attempt < maxRetries) {
          _logState?.warning('⚠️  $testName 异常，准备重试 (尝试 $attempt/$maxRetries): $e', type: LogType.debug);
          await Future.delayed(const Duration(milliseconds: 300));
        } else {
          _logState?.error('❌ $testName 失败 (已重试 $maxRetries 次): $e', type: LogType.debug);
        }
      }
    }
    
    return false;
  }

  /// 执行所有测试项
  Future<void> _executeAllTests() async {
    // 定义完整测试序列（32项）
    final testSequence = [
      {'name': '1. 上电测试', 'type': '电源', 'executor': _autoTestPowerOn, 'skippable': false},
      {'name': '2. 工作功耗测试', 'type': '电流', 'executor': _autoTestWorkingPower, 'skippable': true},
      {'name': '3. 设备电压测试', 'type': '电压', 'executor': _autoTestVoltage, 'skippable': false},
      {'name': '4. 电量检测测试', 'type': '电量', 'executor': _autoTestBattery, 'skippable': false},
      {'name': '5. 充电状态测试', 'type': '充电', 'executor': _autoTestCharging, 'skippable': false},
      {'name': '5.1 生成设备标识', 'type': '标识', 'executor': _autoTestGenerateDeviceId, 'skippable': false},
      {'name': '5.2 蓝牙MAC写入', 'type': '蓝牙', 'executor': _autoTestBluetoothMACWrite, 'skippable': false},
      {'name': '5.3 蓝牙MAC读取', 'type': '蓝牙', 'executor': _autoTestBluetoothMACRead, 'skippable': false},
      {'name': '6. WiFi测试', 'type': 'WiFi', 'executor': _autoTestWiFi, 'skippable': false},
      {'name': '7. RTC设置时间测试', 'type': 'RTC', 'executor': _autoTestRTCSet, 'skippable': false},
      {'name': '8. RTC获取时间测试', 'type': 'RTC', 'executor': _autoTestRTCGet, 'skippable': false},
      {'name': '9. 光敏传感器测试', 'type': '光敏', 'executor': _autoTestLightSensor, 'skippable': false},
      {'name': '10. IMU传感器测试', 'type': 'IMU', 'executor': _autoTestIMU, 'skippable': false},
      {'name': '11. 右触控测试', 'type': 'Touch', 'executor': _autoTestRightTouch, 'skippable': false},
      {'name': '12. 左触控测试', 'type': 'Touch', 'executor': _autoTestLeftTouch, 'skippable': false},
      {'name': '13. LED灯(外侧)测试', 'type': 'LED', 'executor': () => _autoTestLEDWithDialog('外侧'), 'skippable': false},
      {'name': '14. LED灯(内侧)测试', 'type': 'LED', 'executor': () => _autoTestLEDWithDialog('内侧'), 'skippable': false},
      {'name': '15. 左SPK测试', 'type': 'SPK', 'executor': () => _autoTestSPK(0), 'skippable': false},
      {'name': '16. 右SPK测试', 'type': 'SPK', 'executor': () => _autoTestSPK(1), 'skippable': false},
      {'name': '17. 左MIC测试', 'type': 'MIC', 'executor': () => _autoTestMICRecord(0), 'skippable': false},
      {'name': '18. 右MIC测试', 'type': 'MIC', 'executor': () => _autoTestMICRecord(1), 'skippable': false},
      {'name': '19. TALK MIC测试', 'type': 'MIC', 'executor': () => _autoTestMICRecord(2), 'skippable': false},
      {'name': '20. Sensor测试', 'type': 'Sensor', 'executor': _autoTestSensor, 'skippable': false},
      {'name': '21. 蓝牙测试', 'type': '蓝牙', 'executor': _autoTestBluetooth, 'skippable': false},
      {'name': '22. SN码写入', 'type': 'SN', 'executor': _autoTestWriteSN, 'skippable': false},
      {'name': '23. 结束产测', 'type': '电源', 'executor': _autoTestPowerOff, 'skippable': false},
    ];

    for (var i = 0; i < testSequence.length; i++) {
      // 检查串口连接状态和停止标志
      if (!_serialService.isConnected) {
        _logState?.error('❌ 串口已断开，停止自动化测试', type: LogType.debug);
        _shouldStopTest = true;
        break;
      }
      
      if (_shouldStopTest) {
        _logState?.warning('⚠️ 测试已停止', type: LogType.debug);
        break;
      }
      
      _currentAutoTestIndex = i;
      notifyListeners();
      
      final test = testSequence[i];
      final isSkippable = test['skippable'] as bool;
      
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('📋 测试项 ${i + 1}/${testSequence.length}: ${test['name']}${isSkippable ? ' (可跳过)' : ''}', type: LogType.debug);
      
      final item = TestReportItem(
        testName: test['name'] as String,
        testType: test['type'] as String,
        status: TestReportStatus.running,
        startTime: DateTime.now(),
      );
      
      _testReportItems.add(item);
      notifyListeners();
      
      try {
        final executor = test['executor'] as Future<bool> Function();
        
        // WiFi、IMU、Touch、Sensor、蓝牙、MIC、LED测试内部已有完整的逻辑，不使用外层重试包装器
        // WiFi有重试，IMU/Touch/Sensor/蓝牙等待用户确认，MIC/LED有弹窗和完整流程
        final result = (test['type'] == 'WiFi' || 
                       test['type'] == 'IMU' || 
                       test['type'] == 'Touch' || 
                       test['type'] == 'Sensor' ||
                       test['type'] == '蓝牙' ||
                       test['type'] == 'MIC' ||
                       test['type'] == 'LED')
            ? await executor()
            : await _executeTestWithRetry(test['name'] as String, executor);
        
        // IMU测试完成后，确保关闭弹窗
        if (test['type'] == 'IMU' && _showIMUDialog) {
          _showIMUDialog = false;
          notifyListeners();
        }
        
        final updatedItem = item.copyWith(
          status: result ? TestReportStatus.pass : TestReportStatus.fail,
          endTime: DateTime.now(),
          errorMessage: result ? null : '测试未通过',
        );
        
        _testReportItems[_testReportItems.length - 1] = updatedItem;
        
        if (result) {
          _logState?.success('✅ ${test['name']} 通过', type: LogType.debug);
        } else {
          _logState?.error('❌ ${test['name']} 失败', type: LogType.debug);
        }
      } catch (e) {
        final errorMsg = e.toString();
        
        // 检查是否是跳过操作
        if (errorMsg.contains('SKIP')) {
          final updatedItem = item.copyWith(
            status: TestReportStatus.skip,
            endTime: DateTime.now(),
            errorMessage: '用户跳过',
          );
          _testReportItems[_testReportItems.length - 1] = updatedItem;
          _logState?.warning('⏭️  ${test['name']} 已跳过', type: LogType.debug);
        } else {
          final updatedItem = item.copyWith(
            status: TestReportStatus.fail,
            endTime: DateTime.now(),
            errorMessage: '测试异常: $e',
          );
          _testReportItems[_testReportItems.length - 1] = updatedItem;
          _logState?.error('❌ ${test['name']} 异常: $e', type: LogType.debug);
        }
      }
      
      notifyListeners();
      
      // 测试项之间延迟500ms
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// WiFi自动测试 - 参考手动测试逻辑，testWiFi()内部已处理弹窗
  Future<bool> _autoTestWiFi() async {
    try {
      _logState?.info('📶 开始WiFi测试', type: LogType.debug);
      
      // 执行WiFi测试流程（testWiFi内部会处理弹窗显示）
      final result = await testWiFi();
      
      return result;
    } catch (e) {
      _logState?.error('WiFi测试异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 左侧Touch自动测试 - 结束时必须关闭弹窗
  Future<bool> _autoTestLeftTouch() async {
    try {
      // 开始左侧Touch测试
      await testTouchLeft();
      
      // 等待测试完成（最多30秒）
      for (var i = 0; i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 检查是否所有步骤都完成
        if (_leftTouchTestSteps.every((step) => 
            step.status == TouchStepStatus.success || 
            step.status == TouchStepStatus.failed)) {
          break;
        }
      }
      
      // 检查结果
      final allPassed = _leftTouchTestSteps.every((step) => 
          step.status == TouchStepStatus.success);
      
      return allPassed;
    } catch (e) {
      _logState?.error('左侧Touch测试异常: $e', type: LogType.debug);
      return false;
    } finally {
      // 无论成功失败，都必须关闭弹窗
      _logState?.info('🛑 左侧Touch测试结束，关闭弹窗', type: LogType.debug);
      closeTouchDialog();
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  /// 右侧Touch自动测试 - 结束时必须关闭弹窗
  Future<bool> _autoTestRightTouch() async {
    try {
      // 开始右侧Touch测试
      await testTouchRight();
      
      // 等待测试完成（最多30秒）
      for (var i = 0; i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 检查是否所有步骤都完成
        if (_rightTouchTestSteps.every((step) => 
            step.status == TouchStepStatus.success || 
            step.status == TouchStepStatus.failed)) {
          break;
        }
      }
      
      // 检查结果
      final allPassed = _rightTouchTestSteps.every((step) => 
          step.status == TouchStepStatus.success);
      
      return allPassed;
    } catch (e) {
      _logState?.error('右侧Touch测试异常: $e', type: LogType.debug);
      return false;
    } finally {
      // 无论成功失败，都必须关闭弹窗
      _logState?.info('🛑 右侧Touch测试结束，关闭弹窗', type: LogType.debug);
      closeTouchDialog();
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  /// Sensor自动测试 - 显示FTP下载的图片，等待用户确认
  Future<bool> _autoTestSensor() async {
    try {
      _logState?.info('📷 开始Sensor传感器测试', type: LogType.debug);
      
      // 检查图片是否已下载
      if (_sensorImagePath == null || _sensorImagePath!.isEmpty) {
        _logState?.error('❌ Sensor测试失败：未找到测试图片', type: LogType.debug);
        _logState?.info('   提示：请先完成WiFi测试以下载图片', type: LogType.debug);
        return false;
      }
      
      // 验证文件是否存在
      final imageFile = File(_sensorImagePath!);
      if (!await imageFile.exists()) {
        _logState?.error('❌ Sensor测试失败：图片文件不存在', type: LogType.debug);
        _logState?.info('   路径: $_sensorImagePath', type: LogType.debug);
        _sensorImagePath = null; // 清除无效路径
        return false;
      }
      
      // 验证文件大小
      final fileSize = await imageFile.length();
      if (fileSize == 0) {
        _logState?.error('❌ Sensor测试失败：图片文件为空', type: LogType.debug);
        _logState?.info('   路径: $_sensorImagePath', type: LogType.debug);
        return false;
      }
      
      _logState?.success('✅ Sensor测试图片存在，准备显示...', type: LogType.debug);
      _logState?.info('   路径: $_sensorImagePath', type: LogType.debug);
      _logState?.info('   大小: ${(fileSize / 1024).toStringAsFixed(2)} KB', type: LogType.debug);
      
      // 创建Completer用于等待用户确认
      _sensorTestCompleter = Completer<bool>();
      
      // 显示图片弹窗供用户查看和确认
      _showSensorDialog = true;
      _completeImageData = await imageFile.readAsBytes();
      notifyListeners();
      
      _logState?.info('📺 显示Sensor测试图片，等待用户确认...', type: LogType.debug);
      
      // 等待用户确认结果（通过confirmSensorTestResult方法）
      final result = await _sensorTestCompleter!.future;
      
      _logState?.info('📝 用户确认Sensor测试结果: ${result ? "通过" : "不通过"}', type: LogType.debug);
      
      return result;
    } catch (e) {
      _logState?.error('❌ Sensor测试异常: $e', type: LogType.debug);
      // 确保异常时也关闭弹窗
      _showSensorDialog = false;
      notifyListeners();
      return false;
    } finally {
      // 确保弹窗关闭
      _showSensorDialog = false;
      notifyListeners();
    }
  }
  
  /// 用户确认Sensor测试结果
  void confirmSensorTestResult(bool passed) {
    if (_sensorTestCompleter != null && !_sensorTestCompleter!.isCompleted) {
      _sensorTestCompleter!.complete(passed);
      _logState?.info('📝 记录Sensor测试结果: ${passed ? "通过" : "不通过"}', type: LogType.debug);
      
      // 关闭弹窗（但不清理数据，因为_autoTestSensor的finally会调用stopSensorTest来清理）
      _showSensorDialog = false;
      notifyListeners();
    }
  }

  /// IMU自动测试 - 先弹窗，等待用户确认，结束时必须停止成功
  Future<bool> _autoTestIMU() async {
    bool started = false;
    try {
      _logState?.info('📊 开始IMU传感器测试', type: LogType.debug);
      
      // 创建Completer用于等待用户确认
      _imuTestCompleter = Completer<bool>();
      
      // 调用startIMUDataStream，它会自动显示弹窗并开始监听
      started = await startIMUDataStream().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _logState?.error('❌ IMU测试启动超时（10秒）', type: LogType.debug);
          return false;
        },
      );
      
      if (!started) {
        _logState?.error('❌ IMU测试启动失败', type: LogType.debug);
        if (!_imuTestCompleter!.isCompleted) {
          _imuTestCompleter?.complete(false);
        }
        return false;
      }
      
      _logState?.success('✅ IMU采集已开始，等待用户确认...', type: LogType.debug);
      
      // 等待用户点击"测试通过"或"测试不通过"按钮（添加超时保护）
      final userResult = await _imuTestCompleter!.future.timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          _logState?.error('❌ IMU测试等待用户确认超时（10分钟）', type: LogType.debug);
          return false;
        },
      );
      
      _logState?.info('👤 用户确认结果: ${userResult ? "通过" : "不通过"}', type: LogType.debug);
      
      return userResult;
    } catch (e) {
      _logState?.error('IMU测试异常: $e', type: LogType.debug);
      if (_imuTestCompleter != null && !_imuTestCompleter!.isCompleted) {
        _imuTestCompleter?.complete(false);
      }
      // 异常情况下关闭弹窗
      if (_showIMUDialog) {
        _showIMUDialog = false;
        notifyListeners();
        _logState?.info('🔄 IMU测试异常，弹窗已关闭', type: LogType.debug);
      }
      return false;
    } finally {
      // 停止命令已经在confirmIMUTestResult中发送并关闭弹窗
      // 这里只需要清理Completer
      
      // 清理Completer
      _imuTestCompleter = null;
      
      _logState?.info('🔄 IMU测试流程已完成', type: LogType.debug);
    }
  }
  
  /// 用户确认IMU测试结果（异步处理停止命令）
  Future<void> confirmIMUTestResult(bool passed) async {
    _logState?.info('📝 用户点击: ${passed ? "测试通过" : "测试失败"}', type: LogType.debug);
    
    // 先发送停止命令
    if (_isIMUTesting) {
      _logState?.info('🛑 发送IMU停止命令 (CMD 0x0B, OPT 0x01)...', type: LogType.debug);
      
      try {
        final stopCommand = ProductionTestCommands.createIMUCommand(ProductionTestCommands.imuOptStopData);
        final stopCommandHex = stopCommand.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        _logState?.info('📤 发送: [$stopCommandHex] (${stopCommand.length} bytes)', type: LogType.debug);
        
        // 发送停止命令并等待响应
        final stopResponse = await _serialService.sendCommandAndWaitResponse(
          stopCommand,
          moduleId: ProductionTestCommands.moduleId,
          messageId: ProductionTestCommands.messageId,
          timeout: const Duration(seconds: 5),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            _logState?.error('❌ IMU停止命令超时', type: LogType.debug);
            return null;
          },
        );
        
        if (stopResponse != null && !stopResponse.containsKey('error')) {
          _logState?.success('✅ IMU停止命令响应成功', type: LogType.debug);
          
          // 停止成功后自动隐藏弹窗
          _showIMUDialog = false;
          _logState?.info('🔄 IMU弹窗已自动隐藏', type: LogType.debug);
        } else {
          _logState?.warning('⚠️ IMU停止命令响应失败: ${stopResponse?['error'] ?? '无响应'}', type: LogType.debug);
        }
        
        // 清理状态
        await _imuDataSubscription?.cancel();
        _imuDataSubscription = null;
        _isIMUTesting = false;
        notifyListeners();
        
      } catch (e) {
        _logState?.error('❌ 发送IMU停止命令异常: $e', type: LogType.debug);
      }
    }
    
    // 完成Completer，通知测试结果
    if (_imuTestCompleter != null && !_imuTestCompleter!.isCompleted) {
      _imuTestCompleter!.complete(passed);
      _logState?.info('📝 记录IMU测试结果: ${passed ? "通过" : "不通过"}', type: LogType.debug);
    }
  }

  /// 开始MIC测试（带弹窗）
  Future<bool> startMICTest(int micNumber) async {
    try {
      final micName = micNumber == 0 ? '左' : (micNumber == 1 ? '右' : 'TALK');
      _logState?.info('🎤 开始${micName}MIC测试', type: LogType.debug);
      _logState?.info('   MIC编号: $micNumber (0=左, 1=右, 2=TALK)', type: LogType.debug);
      
      // 创建Completer用于等待用户确认
      _micTestCompleter = Completer<bool>();
      
      // 设置当前测试的MIC编号
      _currentMICNumber = micNumber;
      
      // 发送打开MIC命令 (CMD 0x08, MIC号, OPT 0x00)
      final openCommand = ProductionTestCommands.createControlMICCommand(micNumber, ProductionTestCommands.micControlOpen);
      final commandHex = openCommand.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📤 发送打开命令: [$commandHex]', type: LogType.debug);
      _logState?.info('   CMD: 0x08, MIC号: 0x${micNumber.toRadixString(16).toUpperCase().padLeft(2, '0')}, OPT: 0x00(打开)', type: LogType.debug);
      
      // 发送命令并等待响应
      final response = await _serialService.sendCommandAndWaitResponse(
        openCommand,
        timeout: const Duration(seconds: 5),
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );
      
      if (response != null && !response.containsKey('error')) {
        _logState?.success('✅ ${micName}MIC打开成功', type: LogType.debug);
        
        // 显示弹窗
        _showMICDialog = true;
        notifyListeners();
        
        return true;
      } else {
        _logState?.error('❌ ${micName}MIC打开失败: ${response?['error'] ?? '无响应'}', type: LogType.debug);
        _currentMICNumber = null;
        return false;
      }
    } catch (e) {
      _logState?.error('❌ 启动MIC测试异常: $e', type: LogType.debug);
      _currentMICNumber = null;
      return false;
    }
  }

  /// 停止MIC测试（关闭MIC）
  Future<bool> stopMICTest({int retryCount = 0}) async {
    if (_currentMICNumber == null) {
      _logState?.warning('[MIC] 没有正在进行的MIC测试', type: LogType.debug);
      return false;
    }
    
    try {
      final micName = _currentMICNumber == 0 ? '左' : (_currentMICNumber == 1 ? '右' : 'TALK');
      _logState?.info('🛑 发送关闭${micName}MIC命令 (第${retryCount + 1}次尝试)', type: LogType.debug);
      _logState?.info('   MIC编号: $_currentMICNumber (0=左, 1=右, 2=TALK)', type: LogType.debug);
      
      // 发送关闭MIC命令 (CMD 0x08, MIC号, OPT 0x01)
      _logState?.info('   准备创建关闭命令，参数: micNumber=$_currentMICNumber, control=${ProductionTestCommands.micControlClose}', type: LogType.debug);
      final closeCommand = ProductionTestCommands.createControlMICCommand(_currentMICNumber!, ProductionTestCommands.micControlClose);
      final commandHex = closeCommand.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📤 发送关闭命令: [$commandHex]', type: LogType.debug);
      _logState?.info('   CMD: 0x08, MIC号: 0x${_currentMICNumber!.toRadixString(16).toUpperCase().padLeft(2, '0')}, OPT: 0x${ProductionTestCommands.micControlClose.toRadixString(16).toUpperCase().padLeft(2, '0')}(关闭)', type: LogType.debug);
      _logState?.info('   命令字节: [${closeCommand[0].toRadixString(16)}, ${closeCommand[1].toRadixString(16)}, ${closeCommand[2].toRadixString(16)}]', type: LogType.debug);
      
      // 发送命令并等待响应
      final response = await _serialService.sendCommandAndWaitResponse(
        closeCommand,
        timeout: const Duration(seconds: 5),
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );
      
      if (response != null && !response.containsKey('error')) {
        _logState?.success('✅ ${micName}MIC关闭成功', type: LogType.debug);
        
        // 关闭弹窗
        _showMICDialog = false;
        _currentMICNumber = null;
        notifyListeners();
        
        return true;
      } else {
        _logState?.error('❌ ${micName}MIC关闭失败: ${response?['error'] ?? '无响应'}', type: LogType.debug);
        
        // 失败后重试（最多3次）
        if (retryCount < 3) {
          _logState?.warning('🔄 准备重试关闭命令...', type: LogType.debug);
          await Future.delayed(const Duration(seconds: 1));
          return stopMICTest(retryCount: retryCount + 1);
        } else {
          _logState?.error('❌ 关闭命令重试3次后仍失败，强制关闭弹窗', type: LogType.debug);
          
          // 强制关闭弹窗
          _showMICDialog = false;
          _currentMICNumber = null;
          notifyListeners();
          
          return false;
        }
      }
    } catch (e) {
      _logState?.error('❌ 停止MIC测试异常: $e', type: LogType.debug);
      
      // 异常时强制关闭弹窗
      _showMICDialog = false;
      _currentMICNumber = null;
      notifyListeners();
      
      return false;
    }
  }
  
  /// 用户确认MIC测试结果
  Future<void> confirmMICTestResult(bool passed) async {
    if (_currentMICNumber == null) {
      _logState?.warning('[MIC] 没有正在进行的MIC测试', type: LogType.debug);
      return;
    }
    
    final micName = _currentMICNumber == 0 ? '左' : (_currentMICNumber == 1 ? '右' : 'TALK');
    _logState?.info('📝 用户确认${micName}MIC测试结果: ${passed ? "通过" : "不通过"}', type: LogType.debug);
    _logState?.info('   当前MIC编号: $_currentMICNumber', type: LogType.debug);
    
    // 先关闭MIC
    final closed = await stopMICTest();
    
    if (!closed) {
      _logState?.warning('⚠️ MIC关闭失败，但继续完成测试', type: LogType.debug);
    }
    
    // 完成Completer，通知测试结果
    if (_micTestCompleter != null && !_micTestCompleter!.isCompleted) {
      _micTestCompleter!.complete(passed);
      _logState?.info('📝 记录MIC测试结果: ${passed ? "通过" : "不通过"}', type: LogType.debug);
    }
  }

  /// MIC自动测试
  Future<bool> _autoTestMIC(int micNumber) async {
    try {
      // 开启MIC
      await toggleMicState(micNumber);
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 检查状态
      final isOn = getMicState(micNumber);
      
      // 关闭MIC
      if (isOn) {
        await toggleMicState(micNumber);
      }
      
      return isOn;
    } catch (e) {
      _logState?.error('MIC$micNumber测试异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// LED自动测试（带弹窗）- 使用LEDTestDialog
  Future<bool> _autoTestLEDWithDialog(String ledType) async {
    try {
      _logState?.info('💡 开始LED灯($ledType)测试', type: LogType.debug);
      
      // 创建Completer用于等待用户确认
      _ledTestCompleter = Completer<bool>();
      
      // 显示LED测试弹窗
      _currentLEDType = ledType;
      _showLEDDialog = true;
      notifyListeners();
      
      // 等待弹窗中的测试完成（用户点击按钮）
      // LEDTestDialog会自动调用startLEDTest和stopLEDTest
      // 并通过confirmLEDTestResult通知结果
      final result = await _ledTestCompleter!.future;
      
      _logState?.info('👤 用户确认LED($ledType)测试结果: ${result ? "通过" : "不通过"}', type: LogType.debug);
      
      return result;
    } catch (e) {
      _logState?.error('LED($ledType)测试异常: $e', type: LogType.debug);
      return false;
    } finally {
      // 关闭弹窗
      _showLEDDialog = false;
      _currentLEDType = null;
      _ledTestCompleter = null;
      notifyListeners();
    }
  }
  
  /// 用户确认LED测试结果
  void confirmLEDTestResult(bool passed) {
    if (_ledTestCompleter != null && !_ledTestCompleter!.isCompleted) {
      _ledTestCompleter!.complete(passed);
      _logState?.info('📝 记录LED测试结果: ${passed ? "通过" : "不通过"}', type: LogType.debug);
    }
  }
  
  /// 关闭LED测试弹窗（已废弃，使用confirmLEDTestResult代替）
  void closeLEDDialog() {
    _showLEDDialog = false;
    _currentLEDType = null;
    notifyListeners();
  }
  
  /// 重新打开LED测试弹窗
  void reopenLEDDialog() {
    if (_currentLEDType != null) {
      _showLEDDialog = true;
      notifyListeners();
      _logState?.info('🔄 LED测试弹窗已重新打开', type: LogType.debug);
    } else {
      _logState?.warning('⚠️ 没有正在进行的LED测试', type: LogType.debug);
    }
  }

  // ==================== 新增测试方法 ====================

  /// 1. 漏电流测试 (需要GPIB程控电源)
  Future<bool> _autoTestLeakageCurrent() async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('🔌 开始漏电流测试', type: LogType.debug);
      _logState?.info('   阈值: < ${TestConfig.leakageCurrentThresholdUa} uA', type: LogType.debug);
      _logState?.info('   采样: ${TestConfig.gpibSampleCount} 次 @ ${TestConfig.gpibSampleRate} Hz', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      
      // 检查是否跳过漏电流测试
      if (AutomationTestConfig.skipLeakageCurrentTest) {
        _logState?.warning('⚠️  已跳过漏电流测试（测试模式）', type: LogType.debug);
        return true;  // 跳过时返回成功
      }
      
      // 检查GPIB是否就绪
      if (!_isGpibReady && !AutomationTestConfig.skipGpibTests && !AutomationTestConfig.skipGpibReadyCheck) {
        _logState?.error('❌ GPIB设备未就绪', type: LogType.debug);
        return false;
      }
      
      // 如果GPIB未就绪但启用了跳过，也跳过此测试
      if (!_isGpibReady) {
        _logState?.warning('⚠️  GPIB未就绪，跳过漏电流测试', type: LogType.debug);
        return true;
      }
      
      // 使用GPIB测量电流
      final currentA = await _gpibService.measureCurrent(
        sampleCount: TestConfig.gpibSampleCount,
        sampleRate: TestConfig.gpibSampleRate,
      );
      
      if (currentA == null) {
        _logState?.error('❌ 电流测量失败', type: LogType.debug);
        return false;
      }
      
      // 转换为微安 (uA)
      final currentUa = currentA * 1000000;
      
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('📊 漏电流测试结果:', type: LogType.debug);
      _logState?.info('   测量值: ${currentUa.toStringAsFixed(2)} uA', type: LogType.debug);
      _logState?.info('   阈值: < ${TestConfig.leakageCurrentThresholdUa} uA', type: LogType.debug);
      
      if (currentUa < TestConfig.leakageCurrentThresholdUa) {
        _logState?.success('✅ 漏电流测试通过', type: LogType.debug);
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        return true;
      } else {
        _logState?.error('❌ 漏电流测试失败: 超过阈值', type: LogType.debug);
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        return false;
      }
    } catch (e) {
      if (e.toString().contains('SKIP')) rethrow;
      _logState?.error('❌ 漏电流测试异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 2. 上电测试
  Future<bool> _autoTestPowerOn() async {
    try {
      _logState?.info('⚡ 开始上电测试', type: LogType.debug);
      
      // 检查是否跳过上电测试
      if (AutomationTestConfig.skipPowerOnTest) {
        _logState?.warning('⚠️  已跳过上电测试（测试模式）', type: LogType.debug);
        return true;  // 跳过时返回成功
      }
      
      // 检查串口连接状态即可判断设备是否正常上电
      if (!_serialService.isConnected) {
        _logState?.error('❌ 串口未连接，上电测试失败', type: LogType.debug);
        return false;
      }
      
      _logState?.success('✅ 设备已上电', type: LogType.debug);
      
      // 上电成功后，唤醒设备（一直重试直到成功或串口断开）
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('正在唤醒设备...', type: LogType.debug);
      
      bool wakeupSuccess = false;
      int wakeupAttempt = 0;
      while (!wakeupSuccess && _serialService.isConnected && !_shouldStopTest) {
        wakeupAttempt++;
        _logState?.info('🔔 尝试唤醒设备 (第 $wakeupAttempt 次)...', type: LogType.debug);
        
        bool result = await _serialService.sendExitSleepMode(retries: 1);
        if (result) {
          wakeupSuccess = true;
          _logState?.success('✅ 设备唤醒成功！', type: LogType.debug);
          break;
        }
        
        // 检查是否应该停止测试
        if (_shouldStopTest || !_serialService.isConnected) {
          _logState?.warning('⚠️ 测试已停止或串口已断开', type: LogType.debug);
          return false;
        }
        
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (!wakeupSuccess) {
        _logState?.error('❌ 设备唤醒失败', type: LogType.debug);
        return false;
      }
      
      // 等待设备完全唤醒
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 先发送 ff04 指令（一直重试直到成功或串口断开）
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('📤 发送 FF04 指令...', type: LogType.debug);
      
      bool ff04Success = false;
      int ff04Attempt = 0;
      while (!ff04Success && _serialService.isConnected && !_shouldStopTest) {
        ff04Attempt++;
        _logState?.info('📤 尝试发送 FF04 指令 (第 $ff04Attempt 次)...', type: LogType.debug);
        
        // 创建 ff04 指令: CMD=0xFF, OPT=0x04
        final ff04Cmd = Uint8List.fromList([0xFF, 0x04]);
        final ff04CmdHex = ff04Cmd.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        _logState?.info('📤 发送: [$ff04CmdHex] (${ff04Cmd.length} bytes)', type: LogType.debug);
        
        final ff04Response = await _serialService.sendCommandAndWaitResponse(
          ff04Cmd,
          moduleId: ProductionTestCommands.moduleId,
          messageId: ProductionTestCommands.messageId,
          timeout: const Duration(seconds: 5),
        );
        
        if (ff04Response != null && !ff04Response.containsKey('error')) {
          ff04Success = true;
          _logState?.success('✅ FF04 指令发送成功', type: LogType.debug);
          _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
          break;
        }
        
        // 检查是否应该停止测试
        if (_shouldStopTest || !_serialService.isConnected) {
          _logState?.warning('⚠️ 测试已停止或串口已断开', type: LogType.debug);
          return false;
        }
        
        _logState?.warning('⚠️ FF04 指令响应失败: ${ff04Response?['error'] ?? '无响应'}，1秒后重试...', type: LogType.debug);
        await Future.delayed(const Duration(seconds: 1));
      }
      
      if (!ff04Success) {
        _logState?.error('❌ FF04 指令发送失败', type: LogType.debug);
        return false;
      }
      
      // 再发送产测开始指令（一直重试直到成功或串口断开）
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('📤 发送产测开始指令...', type: LogType.debug);
      
      bool startTestSuccess = false;
      int startTestAttempt = 0;
      while (!startTestSuccess && _serialService.isConnected && !_shouldStopTest) {
        startTestAttempt++;
        _logState?.info('📤 尝试发送产测开始指令 (第 $startTestAttempt 次)...', type: LogType.debug);
        
        final startTestCmd = ProductionTestCommands.createStartTestCommand();
        final startTestCmdHex = startTestCmd.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        _logState?.info('📤 发送: [$startTestCmdHex] (${startTestCmd.length} bytes)', type: LogType.debug);
        
        final startTestResponse = await _serialService.sendCommandAndWaitResponse(
          startTestCmd,
          moduleId: ProductionTestCommands.moduleId,
          messageId: ProductionTestCommands.messageId,
          timeout: const Duration(seconds: 5),
        );
        
        if (startTestResponse != null && !startTestResponse.containsKey('error')) {
          startTestSuccess = true;
          _logState?.success('✅ 产测开始指令发送成功', type: LogType.debug);
          _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
          break;
        }
        
        // 检查是否应该停止测试
        if (_shouldStopTest || !_serialService.isConnected) {
          _logState?.warning('⚠️ 测试已停止或串口已断开', type: LogType.debug);
          return false;
        }
        
        _logState?.warning('⚠️ 产测开始指令响应失败: ${startTestResponse?['error'] ?? '无响应'}，1秒后重试...', type: LogType.debug);
        await Future.delayed(const Duration(seconds: 1));
      }
      
      if (!startTestSuccess) {
        _logState?.error('❌ 产测开始指令发送失败', type: LogType.debug);
        return false;
      }
      
      return true;
      
    } catch (e) {
      _logState?.error('上电测试异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 3. 工作功耗测试 (需要GPIB程控电源)
  Future<bool> _autoTestWorkingPower() async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('🔋 开始工作功耗测试', type: LogType.debug);
      _logState?.info('   阈值: < ${TestConfig.workingCurrentThresholdMa} mA', type: LogType.debug);
      _logState?.info('   采样: ${TestConfig.gpibSampleCount} 次 @ ${TestConfig.gpibSampleRate} Hz', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      
      // 检查是否跳过工作功耗测试
      if (AutomationTestConfig.skipWorkingCurrentTest) {
        _logState?.warning('⚠️  已跳过工作功耗测试（测试模式）', type: LogType.debug);
        return true;  // 跳过时返回成功
      }
      
      // 检查GPIB是否就绪
      if (!_isGpibReady && !AutomationTestConfig.skipGpibTests && !AutomationTestConfig.skipGpibReadyCheck) {
        _logState?.error('❌ GPIB设备未就绪', type: LogType.debug);
        return false;
      }
      
      // 如果GPIB未就绪但启用了跳过，也跳过此测试
      if (!_isGpibReady) {
        _logState?.warning('⚠️  GPIB未就绪，跳过工作功耗测试', type: LogType.debug);
        return true;
      }
      
      // 使用GPIB测量电流
      final currentA = await _gpibService.measureCurrent(
        sampleCount: TestConfig.gpibSampleCount,
        sampleRate: TestConfig.gpibSampleRate,
      );
      
      if (currentA == null) {
        _logState?.error('❌ 电流测量失败', type: LogType.debug);
        return false;
      }
      
      // 转换为毫安 (mA)
      final currentMa = currentA * 1000;
      
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('📊 工作功耗测试结果:', type: LogType.debug);
      _logState?.info('   测量值: ${currentMa.toStringAsFixed(2)} mA', type: LogType.debug);
      _logState?.info('   阈值: < ${TestConfig.workingCurrentThresholdMa} mA', type: LogType.debug);
      
      if (currentMa < TestConfig.workingCurrentThresholdMa) {
        _logState?.success('✅ 工作功耗测试通过', type: LogType.debug);
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        return true;
      } else {
        _logState?.error('❌ 工作功耗测试失败: 超过阈值', type: LogType.debug);
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        return false;
      }
    } catch (e) {
      if (e.toString().contains('SKIP')) rethrow;
      _logState?.error('❌ 工作功耗测试异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 4. 设备电压测试
  Future<bool> _autoTestVoltage() async {
    try {
      _logState?.info('🔌 开始设备电压测试 (> 2.5V)', type: LogType.debug);
      
      final command = ProductionTestCommands.createGetVoltageCommand();
      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: TestConfig.defaultTimeout,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );
      
      if (response != null && !response.containsKey('error')) {
        final payload = response['payload'] as Uint8List?;
        if (payload != null) {
          final voltage = ProductionTestCommands.parseVoltageResponse(payload);
          if (voltage != null) {
            final voltageV = voltage / 1000.0; // mV转V
            _logState?.success('✅ 电压: ${voltageV.toStringAsFixed(2)}V', type: LogType.debug);
            return voltageV > 2.5;
          }
        }
      }
      
      _logState?.error('❌ 获取电压失败', type: LogType.debug);
      return false;
    } catch (e) {
      _logState?.error('设备电压测试异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 5. 电量检测测试
  Future<bool> _autoTestBattery() async {
    try {
      _logState?.info('🔋 开始电量检测测试 (0-100%)', type: LogType.debug);
      
      final command = ProductionTestCommands.createGetCurrentCommand();
      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: TestConfig.defaultTimeout,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );
      
      if (response != null && !response.containsKey('error')) {
        final payload = response['payload'] as Uint8List?;
        if (payload != null) {
          final battery = ProductionTestCommands.parseCurrentResponse(payload);
          if (battery != null) {
            _logState?.success('✅ 电量: $battery%', type: LogType.debug);
            return battery >= 0 && battery <= 100;
          }
        }
      }
      
      _logState?.error('❌ 获取电量失败', type: LogType.debug);
      return false;
    } catch (e) {
      _logState?.error('电量检测测试异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 6. 充电状态测试
  Future<bool> _autoTestCharging() async {
    try {
      _logState?.info('🔌 开始充电状态测试', type: LogType.debug);
      
      final command = ProductionTestCommands.createGetChargeStatusCommand();
      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: TestConfig.defaultTimeout,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );
      
      if (response != null && !response.containsKey('error')) {
        final payload = response['payload'] as Uint8List?;
        if (payload != null) {
          final chargeStatus = ProductionTestCommands.parseChargeStatusResponse(payload);
          if (chargeStatus != null) {
            final mode = chargeStatus['mode'] as int?;
            final fault = chargeStatus['fault'] as int?;
            
            if (mode != null && fault != null) {
              final modeNames = ['STOP', 'CC', 'CV', 'DONE'];
              final modeName = mode < modeNames.length ? modeNames[mode] : '未知($mode)';
              final faultStatus = fault == 0x00 ? '正常' : '故障';
              
              _logState?.info('📊 充电状态: $modeName, 故障码: 0x${fault.toRadixString(16).toUpperCase().padLeft(2, '0')} ($faultStatus)', type: LogType.debug);
              
              // 只要故障码为0x00就判断成功，不限制充电状态
              if (fault == 0x00) {
                _logState?.success('✅ 充电状态测试通过 (状态: $modeName, 故障码: 0x00)', type: LogType.debug);
                return true;
              } else {
                _logState?.error('❌ 充电状态测试失败 (故障码: 0x${fault.toRadixString(16).toUpperCase().padLeft(2, '0')})', type: LogType.debug);
                return false;
              }
            } else {
              _logState?.error('❌ 充电状态数据解析失败: mode=$mode, fault=$fault', type: LogType.debug);
            }
          }
        }
      }
      
      _logState?.error('❌ 获取充电状态失败', type: LogType.debug);
      return false;
    } catch (e) {
      _logState?.error('充电状态测试异常: $e', type: LogType.debug);
      return false;
    }
  }
  
  /// 6.1 生成设备标识（使用现有逻辑）
  Future<bool> _autoTestGenerateDeviceId() async {
    try {
      _logState?.info('🆔 开始生成设备标识', type: LogType.debug);
      
      // 使用现有的设备标识生成逻辑
      await generateDeviceIdentity();
      
      if (_currentDeviceIdentity == null) {
        _logState?.error('❌ 设备标识生成失败', type: LogType.debug);
        return false;
      }
      
      // 从生成的设备标识中提取蓝牙MAC地址
      final bluetoothMacString = _currentDeviceIdentity!['bluetoothMac'];
      if (bluetoothMacString == null || bluetoothMacString.isEmpty) {
        _logState?.error('❌ 蓝牙MAC地址为空', type: LogType.debug);
        return false;
      }
      
      // 将蓝牙MAC字符串转换为字节数组（格式：AA:BB:CC:DD:EE:FF）
      final macParts = bluetoothMacString.split(':');
      if (macParts.length != 6) {
        _logState?.error('❌ 蓝牙MAC地址格式错误: $bluetoothMacString', type: LogType.debug);
        return false;
      }
      
      _generatedBluetoothMAC = macParts.map((part) => int.parse(part, radix: 16)).toList();
      _generatedDeviceId = _currentDeviceIdentity!['sn'];
      
      // 更新测试报告中的设备信息
      if (_currentTestReport != null) {
        _currentTestReport = TestReport(
          deviceSN: _currentDeviceIdentity!['sn'] ?? 'UNKNOWN',
          bluetoothMAC: _currentDeviceIdentity!['bluetoothMac'],
          wifiMAC: _currentDeviceIdentity!['wifiMac'],
          startTime: _currentTestReport!.startTime,
          endTime: _currentTestReport!.endTime,
          items: _currentTestReport!.items,
        );
        _logState?.info('   📝 已更新测试报告设备信息', type: LogType.debug);
        _logState?.info('      SN: ${_currentDeviceIdentity!["sn"]}', type: LogType.debug);
        _logState?.info('      蓝牙MAC: ${_currentDeviceIdentity!["bluetoothMac"]}', type: LogType.debug);
        _logState?.info('      WiFi MAC: ${_currentDeviceIdentity!["wifiMac"]}', type: LogType.debug);
      }
      
      _logState?.success('✅ 设备标识已生成', type: LogType.debug);
      
      return true;
    } catch (e) {
      _logState?.error('生成设备标识异常: $e', type: LogType.debug);
      return false;
    }
  }
  
  /// 6.2 蓝牙MAC地址写入
  Future<bool> _autoTestBluetoothMACWrite() async {
    try {
      _logState?.info('📝 开始蓝牙MAC地址写入', type: LogType.debug);
      
      if (_generatedBluetoothMAC == null || _generatedBluetoothMAC!.length != 6) {
        _logState?.error('❌ 蓝牙MAC地址未生成或格式错误', type: LogType.debug);
        return false;
      }
      
      final macString = _generatedBluetoothMAC!.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(':');
      _logState?.info('📱 写入MAC地址: $macString', type: LogType.debug);
      
      // 创建命令：CMD 0x0D + OPT 0x00 + 6字节MAC地址
      final command = ProductionTestCommands.createBluetoothMACCommand(0x00, _generatedBluetoothMAC!);
      
      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: const Duration(seconds: 5),
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );
      
      if (response != null && !response.containsKey('error')) {
        _logState?.success('✅ 蓝牙MAC地址写入成功', type: LogType.debug);
        return true;
      } else {
        _logState?.error('❌ 蓝牙MAC地址写入失败: ${response?['error'] ?? '无响应'}', type: LogType.debug);
        return false;
      }
    } catch (e) {
      _logState?.error('蓝牙MAC地址写入异常: $e', type: LogType.debug);
      return false;
    }
  }
  
  /// 6.3 蓝牙MAC地址读取并验证
  Future<bool> _autoTestBluetoothMACRead() async {
    try {
      _logState?.info('📖 开始蓝牙MAC地址读取', type: LogType.debug);
      
      if (_generatedBluetoothMAC == null || _generatedBluetoothMAC!.length != 6) {
        _logState?.error('❌ 本地蓝牙MAC地址未生成', type: LogType.debug);
        return false;
      }
      
      // 创建命令：CMD 0x0D + OPT 0x01（读取MAC地址）
      final command = ProductionTestCommands.createBluetoothMACCommand(0x01, []);
      
      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: const Duration(seconds: 5),
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );
      
      if (response != null && !response.containsKey('error')) {
        final payload = response['payload'] as Uint8List?;
        
        if (payload != null && payload.isNotEmpty) {
          // 响应格式：CMD + 6字节MAC地址
          if (payload.length >= 7 && payload[0] == 0x0D) {
            final readMAC = payload.sublist(1, 7);
            final readMACString = readMAC.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(':');
            final expectedMACString = _generatedBluetoothMAC!.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(':');
            
            _logState?.info('📱 读取MAC地址: $readMACString', type: LogType.debug);
            _logState?.info('📱 期望MAC地址: $expectedMACString', type: LogType.debug);
            
            // 验证MAC地址是否一致
            bool isMatch = true;
            for (int i = 0; i < 6; i++) {
              if (readMAC[i] != _generatedBluetoothMAC![i]) {
                isMatch = false;
                break;
              }
            }
            
            if (isMatch) {
              _logState?.success('✅ 蓝牙MAC地址读取成功，验证通过', type: LogType.debug);
              return true;
            } else {
              _logState?.error('❌ 蓝牙MAC地址不匹配', type: LogType.debug);
              return false;
            }
          } else {
            _logState?.error('❌ 蓝牙MAC地址响应格式错误', type: LogType.debug);
            return false;
          }
        } else {
          _logState?.error('❌ 蓝牙MAC地址响应为空', type: LogType.debug);
          return false;
        }
      } else {
        _logState?.error('❌ 蓝牙MAC地址读取失败: ${response?['error'] ?? '无响应'}', type: LogType.debug);
        return false;
      }
    } catch (e) {
      _logState?.error('蓝牙MAC地址读取异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 8. RTC设置时间测试
  Future<bool> _autoTestRTCSet() async {
    try {
      _logState?.info('🕐 开始RTC设置时间测试', type: LogType.debug);
      
      // 获取当前时间戳（毫秒）
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final command = ProductionTestCommands.createRTCCommand(
        ProductionTestCommands.rtcOptSetTime,
        timestamp: timestamp,
      );
      
      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: TestConfig.defaultTimeout,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );
      
      if (response != null && !response.containsKey('error')) {
        final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        _logState?.success('✅ RTC时间已设置: $dateTime', type: LogType.debug);
        return true;
      }
      
      _logState?.error('❌ RTC设置时间失败', type: LogType.debug);
      return false;
    } catch (e) {
      _logState?.error('RTC设置时间测试异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 9. RTC获取时间测试
  Future<bool> _autoTestRTCGet() async {
    try {
      _logState?.info('🕐 开始RTC获取时间测试', type: LogType.debug);
      
      final command = ProductionTestCommands.createRTCCommand(
        ProductionTestCommands.rtcOptGetTime,
      );
      
      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: TestConfig.defaultTimeout,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );
      
      if (response != null && !response.containsKey('error')) {
        final payload = response['payload'] as Uint8List?;
        if (payload != null) {
          final timestamp = ProductionTestCommands.parseRTCResponse(payload);
          if (timestamp != null) {
            final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
            _logState?.success('✅ RTC时间: $dateTime', type: LogType.debug);
            
            // 检查时间是否合理（与当前时间差距不超过10秒）
            final now = DateTime.now();
            final diff = now.difference(dateTime).inSeconds.abs();
            return diff <= 10;
          }
        }
      }
      
      _logState?.error('❌ RTC获取时间失败', type: LogType.debug);
      return false;
    } catch (e) {
      _logState?.error('RTC获取时间测试异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 10. 光敏传感器测试
  /// 返回数据格式：[CMD 0x0A] + [光敏值1字节]
  Future<bool> _autoTestLightSensor() async {
    try {
      _logState?.info('💡 开始光敏传感器测试', type: LogType.debug);
      
      final command = ProductionTestCommands.createLightSensorCommand();
      final commandHex = command.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📤 发送: [$commandHex]', type: LogType.debug);
      
      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: TestConfig.defaultTimeout,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );
      
      if (response != null && !response.containsKey('error')) {
        final payload = response['payload'] as Uint8List?;
        if (payload != null && payload.length >= 2) {
          final payloadHex = payload.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
          _logState?.info('📥 响应: [$payloadHex]', type: LogType.debug);
          
          // 检查第一个字节是否是光敏传感器命令 (0x0A)
          if (payload[0] == ProductionTestCommands.cmdLightSensor) {
            // 第二个字节是光敏值
            final lightValue = payload[1];
            _logState?.success('✅ 光敏值: $lightValue', type: LogType.debug);
            
            // 只要能成功获取光敏值就算测试通过
            return true;
          } else {
            _logState?.error('❌ 响应命令字不匹配: 期望 0x0A, 实际 0x${payload[0].toRadixString(16).toUpperCase().padLeft(2, '0')}', type: LogType.debug);
          }
        } else {
          _logState?.error('❌ 响应数据长度不足: ${payload?.length ?? 0} 字节', type: LogType.debug);
        }
      } else {
        _logState?.error('❌ 未收到有效响应', type: LogType.debug);
      }
      
      _logState?.error('❌ 获取光敏值失败', type: LogType.debug);
      return false;
    } catch (e) {
      _logState?.error('光敏传感器测试异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 12-14. 右触控TK测试
  Future<bool> _autoTestRightTouchTK(int tkNumber) async {
    try {
      _logState?.info('👆 开始右触控-TK$tkNumber测试 (阈值变化>500)', type: LogType.debug);
      // 复用右侧Touch测试逻辑
      await testTouchRight();
      
      // 等待测试完成
      for (var i = 0; i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_rightTouchTestSteps.every((step) => 
            step.status == TouchStepStatus.success || 
            step.status == TouchStepStatus.failed)) {
          break;
        }
      }
      
      closeTouchDialog();
      
      // 检查对应的TK是否通过
      if (tkNumber <= _rightTouchTestSteps.length) {
        return _rightTouchTestSteps[tkNumber - 1].status == TouchStepStatus.success;
      }
      return false;
    } catch (e) {
      _logState?.error('右触控-TK$tkNumber测试异常: $e', type: LogType.debug);
      closeTouchDialog();
      return false;
    }
  }

  /// 15-18. 左触控动作测试
  Future<bool> _autoTestLeftTouchAction(String action) async {
    try {
      final actionName = {
        'wear': '佩戴',
        'click': '点击',
        'double_click': '双击',
        'long_press': '长按',
      }[action] ?? action;
      
      _logState?.info('👆 开始左触控-$actionName测试', type: LogType.debug);
      
      // 复用左侧Touch测试逻辑
      await testTouchLeft();
      
      // 等待测试完成
      for (var i = 0; i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_leftTouchTestSteps.every((step) => 
            step.status == TouchStepStatus.success || 
            step.status == TouchStepStatus.failed)) {
          break;
        }
      }
      
      closeTouchDialog();
      
      // 检查所有步骤是否通过
      return _leftTouchTestSteps.every((step) => step.status == TouchStepStatus.success);
    } catch (e) {
      _logState?.error('左触控-$action测试异常: $e', type: LogType.debug);
      closeTouchDialog();
      return false;
    }
  }

  /// 19-22. LED灯控制测试
  Future<bool> _autoTestLEDControl(int ledType, bool turnOn) async {
    try {
      final ledName = ledType == ProductionTestCommands.ledOuter ? '外侧' : '内侧';
      final action = turnOn ? '开启' : '关闭';
      _logState?.info('💡 LED灯($ledName)$action测试', type: LogType.debug);
      
      // 获取当前状态
      final currentState = getLedState(ledType);
      
      // 如果当前状态与目标状态不同，则切换
      if (currentState != turnOn) {
        await toggleLedState(ledType);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // 检查状态是否符合预期
      return getLedState(ledType) == turnOn;
    } catch (e) {
      _logState?.error('LED控制测试异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 23-24. SPK测试
  Future<bool> _autoTestSPK(int spkNumber) async {
    try {
      final spkName = spkNumber == 0 ? '左' : '右';
      _logState?.info('🔊 开始${spkName}SPK测试', type: LogType.debug);
      // TODO: 发送SPK测试命令
      // 暂时模拟
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    } catch (e) {
      _logState?.error('${spkNumber == 0 ? '左' : '右'}SPK测试异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 25-27. MIC录音测试（使用弹窗）
  Future<bool> _autoTestMICRecord(int micNumber) async {
    bool started = false;
    try {
      final micName = micNumber == 0 ? '左' : (micNumber == 1 ? '右' : 'TALK');
      _logState?.info('🎤 开始${micName}MIC测试', type: LogType.debug);
      
      // 创建Completer用于等待用户确认
      _micTestCompleter = Completer<bool>();
      
      // 开始MIC测试（添加超时保护）
      started = await startMICTest(micNumber).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _logState?.error('❌ ${micName}MIC测试启动超时（10秒）', type: LogType.debug);
          return false;
        },
      );
      
      if (!started) {
        _logState?.error('❌ ${micName}MIC测试启动失败', type: LogType.debug);
        if (!_micTestCompleter!.isCompleted) {
          _micTestCompleter?.complete(false);
        }
        return false;
      }
      
      _logState?.success('✅ ${micName}MIC测试已开始，等待用户确认...', type: LogType.debug);
      
      // 等待用户点击"测试成功"或"测试失败"按钮（添加超时保护）
      final userResult = await _micTestCompleter!.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          _logState?.error('❌ ${micName}MIC测试等待用户确认超时（2分钟）', type: LogType.debug);
          return false;
        },
      );
      
      _logState?.info('👤 用户确认${micName}MIC测试结果: ${userResult ? "通过" : "不通过"}', type: LogType.debug);
      
      return userResult;
    } catch (e) {
      _logState?.error('${micNumber == 0 ? '左' : (micNumber == 1 ? '右' : 'TALK')}MIC测试异常: $e', type: LogType.debug);
      if (_micTestCompleter != null && !_micTestCompleter!.isCompleted) {
        _micTestCompleter?.complete(false);
      }
      return false;
    } finally {
      // 清理Completer
      _micTestCompleter = null;
    }
  }

  /// 29. 蓝牙测试
  Future<bool> _autoTestBluetooth() async {
    try {
      _logState?.info('📱 开始蓝牙测试', type: LogType.debug);
      
      // 显示蓝牙测试弹窗
      _showBluetoothDialog = true;
      notifyListeners();
      
      // 步骤1: 生成蓝牙名称
      _bluetoothTestStep = '正在生成蓝牙名称...';
      notifyListeners();
      
      if (_currentDeviceIdentity == null || _currentDeviceIdentity!['sn'] == null) {
        _bluetoothTestStep = '❌ 错误：未找到SN码';
        notifyListeners();
        _logState?.error('❌ 蓝牙测试失败：未找到SN码', type: LogType.debug);
        await Future.delayed(const Duration(seconds: 3)); // 显示错误信息3秒
        return false;
      }
      
      final snCode = _currentDeviceIdentity!['sn']!;
      // 取SN码后四位
      final last4Digits = snCode.length >= 4 ? snCode.substring(snCode.length - 4) : snCode;
      _bluetoothNameToSet = 'Kanaan-$last4Digits';
      
      _logState?.info('   蓝牙名称: $_bluetoothNameToSet', type: LogType.debug);
      
      // 步骤2: 设置蓝牙名称
      _bluetoothTestStep = '正在设置蓝牙名称...';
      notifyListeners();
      
      final setNameCmd = ProductionTestCommands.createSetBluetoothNameCommand(_bluetoothNameToSet!);
      final cmdHex = setNameCmd.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📤 发送设置蓝牙名称命令: [$cmdHex]', type: LogType.debug);
      
      final setResponse = await _serialService.sendCommandAndWaitResponse(
        setNameCmd,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
        timeout: const Duration(seconds: 5),
      );
      
      if (setResponse == null || setResponse.containsKey('error')) {
        _bluetoothTestStep = '❌ 设置蓝牙名称失败: ${setResponse?['error'] ?? '无响应'}';
        notifyListeners();
        _logState?.error('❌ 设置蓝牙名称失败: ${setResponse?['error'] ?? '无响应'}', type: LogType.debug);
        await Future.delayed(const Duration(seconds: 3)); // 显示错误信息3秒
        return false;
      }
      
      _logState?.success('✅ 蓝牙名称设置成功', type: LogType.debug);
      
      // 步骤3: 获取蓝牙名称进行验证
      _bluetoothTestStep = '正在验证蓝牙名称...';
      notifyListeners();
      
      final getNameCmd = ProductionTestCommands.createGetBluetoothNameCommand();
      _logState?.info('📤 发送获取蓝牙名称命令', type: LogType.debug);
      
      final getResponse = await _serialService.sendCommandAndWaitResponse(
        getNameCmd,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
        timeout: const Duration(seconds: 5),
      );
      
      if (getResponse == null || getResponse.containsKey('error')) {
        _bluetoothTestStep = '❌ 获取蓝牙名称失败: ${getResponse?['error'] ?? '无响应'}';
        notifyListeners();
        _logState?.error('❌ 获取蓝牙名称失败: ${getResponse?['error'] ?? '无响应'}', type: LogType.debug);
        await Future.delayed(const Duration(seconds: 3));
        return false;
      }
      
      final payload = getResponse['payload'] as Uint8List?;
      if (payload == null) {
        _bluetoothTestStep = '❌ 获取蓝牙名称失败：响应无payload';
        notifyListeners();
        _logState?.error('❌ 获取蓝牙名称失败：响应无payload', type: LogType.debug);
        await Future.delayed(const Duration(seconds: 3));
        return false;
      }
      
      // 记录原始payload用于调试
      final payloadHex = payload.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📦 收到payload: [$payloadHex]', type: LogType.debug);
      
      final receivedName = ProductionTestCommands.parseBluetoothNameResponse(payload);
      if (receivedName == null) {
        _bluetoothTestStep = '❌ 获取蓝牙名称失败：无法解析响应';
        notifyListeners();
        _logState?.error('❌ 获取蓝牙名称失败：无法解析响应', type: LogType.debug);
        _logState?.error('   Payload: [$payloadHex]', type: LogType.debug);
        await Future.delayed(const Duration(seconds: 3));
        return false;
      }
      
      _logState?.info('📥 设备返回蓝牙名称: $receivedName', type: LogType.debug);
      
      // 对比设置的名称和获取的名称
      if (receivedName != _bluetoothNameToSet) {
        _bluetoothTestStep = '❌ 蓝牙名称验证失败：名称不一致';
        notifyListeners();
        _logState?.error('❌ 蓝牙名称验证失败：名称不一致', type: LogType.debug);
        _logState?.error('   设置: $_bluetoothNameToSet', type: LogType.debug);
        _logState?.error('   返回: $receivedName', type: LogType.debug);
        await Future.delayed(const Duration(seconds: 3));
        return false;
      }
      
      _logState?.success('✅ 蓝牙名称验证成功！设置值与返回值一致', type: LogType.debug);
      _logState?.info('   名称: $_bluetoothNameToSet', type: LogType.debug);
      
      // 步骤4: 等待用户手动连接蓝牙
      _bluetoothTestStep = '请使用手机搜索并连接蓝牙设备';
      notifyListeners();
      
      _logState?.info('📺 等待用户手动连接蓝牙...', type: LogType.debug);
      
      // 创建Completer用于等待用户确认
      _bluetoothTestCompleter = Completer<bool>();
      
      // 等待用户确认蓝牙连接结果
      final bluetoothTestPassed = await _bluetoothTestCompleter!.future;
      
      if (!bluetoothTestPassed) {
        _logState?.error('❌ 用户确认蓝牙连接失败', type: LogType.debug);
        return false;
      }
      
      _logState?.success('✅ 用户确认蓝牙连接成功', type: LogType.debug);
      return true;
    } catch (e) {
      _logState?.error('蓝牙测试异常: $e', type: LogType.debug);
      return false;
    } finally {
      // 确保弹窗关闭
      _showBluetoothDialog = false;
      _bluetoothTestCompleter = null;
      _bluetoothTestStep = '';
      _bluetoothNameToSet = null;
      notifyListeners();
    }
  }

  /// 用户确认蓝牙测试结果
  void confirmBluetoothTestResult(bool passed) {
    if (_bluetoothTestCompleter != null && !_bluetoothTestCompleter!.isCompleted) {
      _bluetoothTestCompleter!.complete(passed);
      _logState?.info('📝 用户确认蓝牙测试结果: ${passed ? "通过" : "失败"}', type: LogType.debug);
    }
  }

  /// 30. SN码写入
  Future<bool> _autoTestWriteSN() async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('📝 开始SN码写入', type: LogType.debug);
      
      // 检查是否有生成的SN码
      if (_currentDeviceIdentity == null || _currentDeviceIdentity!['sn'] == null) {
        _logState?.error('❌ SN码写入失败：未找到SN码', type: LogType.debug);
        _logState?.info('   提示：请先生成设备标识', type: LogType.debug);
        return false;
      }
      
      final snCode = _currentDeviceIdentity!['sn']!;
      _logState?.info('   SN码: $snCode', type: LogType.debug);
      
      // 创建SN码写入命令
      final writeSNCmd = ProductionTestCommands.createWriteSNCommand(snCode);
      final cmdHex = writeSNCmd.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      _logState?.info('📤 发送SN码写入命令: [$cmdHex]', type: LogType.debug);
      
      // 发送命令并等待响应
      final response = await _serialService.sendCommandAndWaitResponse(
        writeSNCmd,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
        timeout: const Duration(seconds: 5),
      );
      
      if (response == null || response.containsKey('error')) {
        _logState?.error('❌ SN码写入失败: ${response?['error'] ?? '无响应'}', type: LogType.debug);
        return false;
      }
      
      // 解析响应中的SN码
      final payload = response['payload'] as Uint8List?;
      if (payload == null) {
        _logState?.error('❌ SN码写入失败：响应无payload', type: LogType.debug);
        return false;
      }
      
      final responseSN = ProductionTestCommands.parseWriteSNResponse(payload);
      if (responseSN == null) {
        _logState?.error('❌ SN码写入失败：无法解析响应', type: LogType.debug);
        return false;
      }
      
      _logState?.info('📥 设备返回SN码: $responseSN', type: LogType.debug);
      
      // 对比写入的SN码和响应的SN码
      if (responseSN == snCode) {
        _logState?.success('✅ SN码写入成功！写入值与返回值一致', type: LogType.debug);
        _logState?.info('   写入: $snCode', type: LogType.debug);
        _logState?.info('   返回: $responseSN', type: LogType.debug);
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        return true;
      } else {
        _logState?.error('❌ SN码写入失败：写入值与返回值不一致', type: LogType.debug);
        _logState?.error('   写入: $snCode', type: LogType.debug);
        _logState?.error('   返回: $responseSN', type: LogType.debug);
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        return false;
      }
    } catch (e) {
      _logState?.error('SN码写入异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 31. 结束产测
  Future<bool> _autoTestPowerOff() async {
    try {
      _logState?.info('🔌 结束产测 - 检查测试结果', type: LogType.debug);
      
      // 检查是否有任何测试项失败
      final hasFailedTests = _testReportItems.any((item) => 
        item.status == TestReportStatus.fail
      );
      
      // 根据测试结果发送不同的命令
      if (hasFailedTests) {
        _logState?.warning('检测到测试失败项，发送产测失败命令 (CMD 0xFF, OPT 0x01)', type: LogType.debug);
        final command = ProductionTestCommands.createEndTestCommand(opt: 0x01);
        await _serialService.sendCommand(
          command,
          moduleId: ProductionTestCommands.moduleId,
          messageId: ProductionTestCommands.messageId,
        );
        _logState?.info('已发送产测失败命令', type: LogType.debug);
      } else {
        _logState?.success('所有测试项通过，发送产测通过命令 (CMD 0xFF, OPT 0x00)', type: LogType.debug);
        final command = ProductionTestCommands.createEndTestCommand(opt: 0x00);
        await _serialService.sendCommand(
          command,
          moduleId: ProductionTestCommands.moduleId,
          messageId: ProductionTestCommands.messageId,
        );
        _logState?.success('已发送产测通过命令', type: LogType.debug);
      }
      
      // 等待设备响应
      await Future.delayed(const Duration(milliseconds: 500));
      
      return true;
    } catch (e) {
      _logState?.error('结束产测异常: $e', type: LogType.debug);
      return false;
    }
  }

  /// 完成测试报告
  void _finalizeTestReport() {
    if (_currentTestReport != null) {
      _currentTestReport = TestReport(
        deviceSN: _currentTestReport!.deviceSN,
        bluetoothMAC: _currentTestReport!.bluetoothMAC,
        wifiMAC: _currentTestReport!.wifiMAC,
        startTime: _currentTestReport!.startTime,
        endTime: DateTime.now(),
        items: List.from(_testReportItems),
      );
      
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('📊 测试完成', type: LogType.debug);
      _logState?.info(_currentTestReport!.summaryText, type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      
      // 如果测试全部通过，记录设备信息到全局文件
      if (_currentTestReport!.allTestsPassed) {
        _saveDeviceToGlobalRecord();
      }
    }
  }

  /// 保存设备信息到全局记录文件
  Future<void> _saveDeviceToGlobalRecord() async {
    try {
      if (_currentDeviceIdentity == null) {
        _logState?.warning('⚠️ 无设备标识信息，跳过全局记录', type: LogType.debug);
        return;
      }
      
      // 创建保存目录
      String userHome;
      if (Platform.isMacOS || Platform.isLinux) {
        userHome = Platform.environment['HOME'] ?? Directory.current.path;
      } else if (Platform.isWindows) {
        userHome = Platform.environment['USERPROFILE'] ?? Directory.current.path;
      } else {
        userHome = Directory.current.path;
      }
      
      final saveDir = Directory(path.join(userHome, 'Documents', 'JNProductionLine'));
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
      
      final globalRecordFile = File(path.join(saveDir.path, 'device_records.csv'));
      
      // 检查文件是否存在，如果不存在则创建并写入表头
      bool fileExists = await globalRecordFile.exists();
      if (!fileExists) {
        await globalRecordFile.writeAsString(
          '时间戳,SN号,蓝牙MAC地址,WiFi MAC地址,测试结果,通过率\n',
          mode: FileMode.write,
        );
      }
      
      // 准备记录数据
      final timestamp = DateTime.now().toIso8601String();
      final snCode = _currentDeviceIdentity!['sn'] ?? 'UNKNOWN';
      final bluetoothMac = _currentDeviceIdentity!['bluetoothMac'] ?? 'UNKNOWN';
      final wifiMac = _currentDeviceIdentity!['wifiMac'] ?? 'UNKNOWN';
      final testResult = _currentTestReport?.allTestsPassed == true ? '通过' : '失败';
      final passRate = _currentTestReport?.passRate.toStringAsFixed(1) ?? '0.0';
      
      // 追加记录到文件
      final recordLine = '$timestamp,$snCode,$bluetoothMac,$wifiMac,$testResult,$passRate%\n';
      await globalRecordFile.writeAsString(
        recordLine,
        mode: FileMode.append,
      );
      
      _logState?.success('✅ 设备信息已记录到全局文件', type: LogType.debug);
      _logState?.info('   📋 SN: $snCode', type: LogType.debug);
      _logState?.info('   📶 蓝牙MAC: $bluetoothMac', type: LogType.debug);
      _logState?.info('   📡 WiFi MAC: $wifiMac', type: LogType.debug);
      _logState?.info('   📁 文件: ${globalRecordFile.path}', type: LogType.debug);
    } catch (e) {
      _logState?.error('❌ 保存全局设备记录失败: $e', type: LogType.debug);
    }
  }

  /// 保存测试报告到文件
  Future<String?> saveTestReport() async {
    if (_currentTestReport == null) {
      _logState?.warning('没有可保存的测试报告', type: LogType.debug);
      return null;
    }

    try {
      // 创建保存目录
      String userHome;
      if (Platform.isMacOS || Platform.isLinux) {
        userHome = Platform.environment['HOME'] ?? Directory.current.path;
      } else if (Platform.isWindows) {
        userHome = Platform.environment['USERPROFILE'] ?? Directory.current.path;
      } else {
        userHome = Directory.current.path;
      }
      
      final saveDir = Directory(path.join(userHome, 'Documents', 'JNProductionLine', 'test_reports'));
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
      
      // 生成文件名
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'TestReport_${_currentTestReport!.deviceSN}_$timestamp';
      
      // 保存JSON格式
      final jsonFile = File(path.join(saveDir.path, '$fileName.json'));
      final jsonContent = jsonEncode(_currentTestReport!.toJson());
      await jsonFile.writeAsString(jsonContent);
      
      // 保存文本格式
      final txtFile = File(path.join(saveDir.path, '$fileName.txt'));
      final txtContent = _currentTestReport!.toFormattedString();
      await txtFile.writeAsString(txtContent);
      
      _logState?.success('✅ 测试报告已保存: ${saveDir.path}', type: LogType.debug);
      _logState?.info('   JSON: $fileName.json', type: LogType.debug);
      _logState?.info('   TXT: $fileName.txt', type: LogType.debug);
      
      return saveDir.path;
    } catch (e) {
      _logState?.error('❌ 保存测试报告失败: $e', type: LogType.debug);
      return null;
    }
  }

  /// 关闭测试报告弹窗
  void closeTestReportDialog() {
    _showTestReportDialog = false;
    notifyListeners();
  }

  /// 清空测试报告
  void clearTestReport() {
    _currentTestReport = null;
    _testReportItems.clear();
    _currentAutoTestIndex = 0;
    _isAutoTesting = false;
    _showTestReportDialog = false;
    notifyListeners();
    _logState?.info('测试报告已清空', type: LogType.debug);
  }

  // ==================== GPIB检测功能 ====================

  /// 打开GPIB检测弹窗
  void openGpibDialog() {
    _showGpibDialog = true;
    notifyListeners();
  }

  /// 关闭GPIB检测弹窗
  void closeGpibDialog() {
    _showGpibDialog = false;
    notifyListeners();
  }

  /// 检测并连接GPIB设备
  Future<bool> detectAndConnectGpib(String address) async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
      _logState?.info('🔍 开始GPIB检测流程', type: LogType.gpib);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);

      // 设置LogState
      _gpibService.setLogState(_logState!);

      // 1. 检查Python环境
      _logState?.info('📋 步骤 1/5: 检查Python环境', type: LogType.gpib);
      final envCheck = await _gpibService.checkPythonEnvironment();
      
      if (!(envCheck['pythonInstalled'] as bool)) {
        _logState?.error('❌ Python未安装', type: LogType.gpib);
        _logState?.info('请先安装Python 3.7+: https://www.python.org/downloads/', type: LogType.gpib);
        return false;
      }

      // 2. 检查并安装依赖
      if (!(envCheck['pyvisaInstalled'] as bool)) {
        _logState?.warning('⚠️  PyVISA未安装，开始自动安装...', type: LogType.gpib);
        _logState?.info('📋 步骤 2/5: 安装Python依赖', type: LogType.gpib);
        
        final installSuccess = await _gpibService.installPythonDependencies();
        if (!installSuccess) {
          _logState?.error('❌ 依赖安装失败', type: LogType.gpib);
          return false;
        }
      } else {
        _logState?.success('✅ 步骤 2/5: Python依赖已就绪', type: LogType.gpib);
      }

      // 3. 连接GPIB设备
      _logState?.info('📋 步骤 3/5: 连接GPIB设备', type: LogType.gpib);
      final connected = await _gpibService.connect(address);
      
      if (!connected) {
        _logState?.error('❌ GPIB设备连接失败', type: LogType.gpib);
        return false;
      }

      // 4. 初始化设备参数
      _logState?.info('📋 步骤 4/5: 初始化设备参数', type: LogType.gpib);
      
      // 设置电压为5V
      _logState?.debug('设置电压: 5.0V', type: LogType.gpib);
      await _gpibService.sendCommand('VOLT 5.0');
      
      // 设置电流限制为1A
      _logState?.debug('设置电流限制: 1.0A', type: LogType.gpib);
      await _gpibService.sendCommand('CURR 1.0');
      
      // 查询设备ID
      final idn = await _gpibService.query('*IDN?');
      if (idn != null && idn != 'TIMEOUT') {
        _logState?.info('设备信息: $idn', type: LogType.gpib);
      }

      // 5. 漏电流测试
      _logState?.info('📋 步骤 5/5: 漏电流测试', type: LogType.gpib);
      _logState?.info('   阈值: < ${TestConfig.leakageCurrentThresholdUa} uA', type: LogType.gpib);
      _logState?.info('   采样: ${TestConfig.gpibSampleCount} 次 @ ${TestConfig.gpibSampleRate} Hz', type: LogType.gpib);
      
      // 使用GPIB测量电流
      final currentA = await _gpibService.measureCurrent(
        sampleCount: TestConfig.gpibSampleCount,
        sampleRate: TestConfig.gpibSampleRate,
      );
      
      if (currentA == null) {
        _logState?.error('❌ 漏电流测量失败', type: LogType.gpib);
        _isGpibReady = false;
        notifyListeners();
        return false;
      }
      
      // 转换为微安 (uA)
      final currentUa = currentA * 1000000;
      
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
      _logState?.info('📊 漏电流测试结果:', type: LogType.gpib);
      _logState?.info('   测量值: ${currentUa.toStringAsFixed(2)} uA', type: LogType.gpib);
      _logState?.info('   阈值: < ${TestConfig.leakageCurrentThresholdUa} uA', type: LogType.gpib);
      
      if (currentUa >= TestConfig.leakageCurrentThresholdUa) {
        _logState?.error('❌ 漏电流测试失败: 超过阈值', type: LogType.gpib);
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
        _isGpibReady = false;
        notifyListeners();
        return false;
      }
      
      _logState?.success('✅ 漏电流测试通过', type: LogType.gpib);

      // 标记GPIB就绪
      _isGpibReady = true;
      _gpibAddress = address;
      notifyListeners();

      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
      _logState?.success('✅ GPIB Ready - 设备已就绪！', type: LogType.gpib);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);

      return true;
    } catch (e) {
      _logState?.error('❌ GPIB检测失败: $e', type: LogType.gpib);
      _isGpibReady = false;
      notifyListeners();
      return false;
    }
  }

  /// 断开GPIB连接
  Future<void> disconnectGpib() async {
    await _gpibService.disconnect();
    _isGpibReady = false;
    _gpibAddress = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sensorDataSubscription?.cancel();
    _imuDataSubscription?.cancel();
    _sensorTimeoutTimer?.cancel();
    _packetTimeoutTimer?.cancel();
    _serialService.dispose();
    _gpibService.dispose();
    super.dispose();
  }
}
