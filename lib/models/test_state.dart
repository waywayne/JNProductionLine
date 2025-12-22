import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import '../services/serial_service.dart';
import '../services/production_test_commands.dart';
import '../services/gtp_protocol.dart';
import 'log_state.dart';
import '../config/test_config.dart';
import '../config/wifi_config.dart';
import '../config/sn_mac_config.dart';
import 'touch_test_step.dart';

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

  // 获取 MIC 状态
  bool getMicState(int micNumber) => _micStates[micNumber] ?? false;

  // 获取 LED 状态
  bool getLedState(int ledNumber) => _ledStates[ledNumber] ?? false;

  void setLogState(LogState logState) {
    _logState = logState;
    _serialService.setLogState(logState);
  }
  
  /// 关闭Touch测试弹窗
  void closeTouchDialog() {
    _showTouchDialog = false;
    notifyListeners();
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
    
    for (int retry = 0; retry <= maxRetries; retry++) {
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

      // 更新步骤状态
      _wifiTestSteps[stepIndex] = currentStep.copyWith(
        status: WiFiStepStatus.testing,
        currentRetry: retry,
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
            currentRetry: retry,
          );
          notifyListeners();
          return true;
        }
      } catch (e) {
        _logState?.error('WiFi步骤执行异常: $e', type: LogType.debug);
      }

      // 如果不是最后一次重试，继续
      if (retry < maxRetries) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }

    // 所有重试都失败了
    final finalStep = _wifiTestSteps[stepIndex];
    _wifiTestSteps[stepIndex] = finalStep.copyWith(
      status: WiFiStepStatus.failed,
      errorMessage: '重试 $maxRetries 次后仍然失败',
    );
    notifyListeners();
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
    
    // 如果正在运行测试，先停止测试
    if (_isRunningTest) {
      _logState?.warning('⚠️  检测到正在运行测试，自动停止...');
      stopTest();
    }
    
    await _serialService.disconnect();
    _selectedPort = null;
    _currentTestGroup = null; // 断开连接时清空测试组
    _logState?.info('串口已断开');
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
      for (int stepIndex = 0; stepIndex < _rightTouchTestSteps.length; stepIndex++) {
        if (_shouldStopTest) break;
        
        final success = await _executeRightTouchStep(stepIndex);
        if (!success) {
          _logState?.error('❌ 右Touch测试失败，停止测试', type: LogType.debug);
          break;
        }
        
        // 步骤间延迟
        await Future.delayed(const Duration(milliseconds: 500));
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
      for (int stepIndex = 0; stepIndex < _leftTouchTestSteps.length; stepIndex++) {
        if (_shouldStopTest) break;
        
        final success = await _executeLeftTouchStep(stepIndex);
        if (!success) {
          _logState?.error('❌ 左Touch测试失败，停止测试', type: LogType.debug);
          break;
        }
        
        // 步骤间延迟
        await Future.delayed(const Duration(milliseconds: 500));
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

  /// 初始化WiFi测试步骤
  void _initializeWiFiTestSteps() {
    // 准备连接热点的数据
    List<int>? apData;
    if (WiFiConfig.defaultSSID.isNotEmpty && WiFiConfig.defaultPassword.isNotEmpty) {
      List<int> ssidBytes = WiFiConfig.stringToBytes(WiFiConfig.defaultSSID);
      List<int> pwdBytes = WiFiConfig.stringToBytes(WiFiConfig.defaultPassword);
      apData = [...ssidBytes, ...pwdBytes];
    } else {
      apData = [0, 0]; // 空的SSID和PWD，都以\0结尾
    }

    _wifiTestSteps = List<WiFiTestStep>.from([
      WiFiTestStep(
        opt: WiFiConfig.optStartTest,
        name: '开始WiFi测试',
        description: '初始化WiFi测试模式',
      ),
      WiFiTestStep(
        opt: WiFiConfig.optConnectAP,
        name: '连接热点',
        description: 'SSID: "${WiFiConfig.defaultSSID}"',
        data: apData,
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

    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.info('🌐 开始WiFi多步骤测试流程', type: LogType.debug);
      _logState?.info('⏱️  开始时间: ${DateTime.now().toString()}', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);

      // 初始化WiFi测试步骤
      _initializeWiFiTestSteps();

      // 执行每个步骤
      for (int i = 0; i < _wifiTestSteps.length; i++) {
        // 检查是否需要停止测试
        if (_shouldStopTest) {
          _logState?.warning('🛑 WiFi测试已被用户停止');
          return false;
        }

        final step = _wifiTestSteps[i];
        final success = await _executeWiFiStepWithRetry(i);
        
        if (!success) {
          _logState?.error('❌ WiFi测试失败: ${step.name}');
          return false;
        }
      }

      _logState?.info('', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      _logState?.success('✅ WiFi多步骤测试完成', type: LogType.debug);
      _logState?.info('⏱️  结束时间: ${DateTime.now().toString()}', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      
      return true;
    } catch (e) {
      _logState?.error('WiFi测试异常: $e', type: LogType.debug);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
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

      // 发送命令并等待响应（5秒超时）
      final response = await _serialService.sendCommandAndWaitResponse(
        command,
        timeout: const Duration(seconds: 5), // 5秒超时
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
      TouchTestStep(
        touchId: TouchTestConfig.touchLeft,
        actionId: TouchTestConfig.leftActionSingleTap,
        name: '单击测试',
        description: '测试左侧Touch单击功能',
        userPrompt: TouchTestConfig.getLeftActionPrompt(TouchTestConfig.leftActionSingleTap),
      ),
      TouchTestStep(
        touchId: TouchTestConfig.touchLeft,
        actionId: TouchTestConfig.leftActionDoubleTap,
        name: '双击测试',
        description: '测试左侧Touch双击功能',
        userPrompt: TouchTestConfig.getLeftActionPrompt(TouchTestConfig.leftActionDoubleTap),
      ),
      TouchTestStep(
        touchId: TouchTestConfig.touchLeft,
        actionId: TouchTestConfig.leftActionLongPress,
        name: '长按测试',
        description: '测试左侧Touch长按功能',
        userPrompt: TouchTestConfig.getLeftActionPrompt(TouchTestConfig.leftActionLongPress),
      ),
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

  @override
  void dispose() {
    _serialService.dispose();
    super.dispose();
  }
}
