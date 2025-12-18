import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import '../services/serial_service.dart';
import '../services/production_test_commands.dart';
import 'log_state.dart';

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

  String get testScriptPath => _testScriptPath;
  String get configFilePath => _configFilePath;
  TestGroup? get currentTestGroup => _currentTestGroup;
  bool get isConnected => _serialService.isConnected;
  String? get selectedPort => _selectedPort;
  bool get isRunningTest => _isRunningTest;

  List<String> get availablePorts => SerialService.getAvailablePorts();

  // 获取 MIC 状态
  bool getMicState(int micNumber) => _micStates[micNumber] ?? false;

  // 获取 LED 状态
  bool getLedState(int ledNumber) => _ledStates[ledNumber] ?? false;

  void setLogState(LogState logState) {
    _logState = logState;
    _serialService.setLogState(logState);
  }

  void setTestScriptPath(String path) {
    _testScriptPath = path;
    notifyListeners();
  }

  void setConfigFilePath(String path) {
    _configFilePath = path;
    notifyListeners();
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
          'cmd': ProductionTestCommands.createControlWifiCommand(),
          'cmdCode': ProductionTestCommands.cmdControlWifi
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
          'cmd': ProductionTestCommands.createTouchCommand(
              ProductionTestCommands.touchLeft),
          'cmdCode': ProductionTestCommands.cmdTouch
        },
        {
          'name': 'Touch右侧',
          'cmd': ProductionTestCommands.createTouchCommand(
              ProductionTestCommands.touchRight),
          'cmdCode': ProductionTestCommands.cmdTouch
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
          'cmd': null,
          'cmdCode': ProductionTestCommands.cmdRTC,
          'customAction': 'getRTC'
        },
        {
          'name': '光敏传感器',
          'cmd': ProductionTestCommands.createLightSensorCommand(),
          'cmdCode': ProductionTestCommands.cmdLightSensor
        },
        {
          'name': 'IMU数据',
          'cmd': ProductionTestCommands.createIMUCommand(
              ProductionTestCommands.imuOptGetData),
          'cmdCode': ProductionTestCommands.cmdIMU
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
                await setRTCTime();
                response = {
                  'success': true
                }; // Assume success for custom actions
                break;
              case 'getRTC':
                await getRTCTime();
                response = {
                  'success': true
                }; // Assume success for custom actions
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
              timeout: const Duration(seconds: 10),
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

                case ProductionTestCommands.cmdTouch:
                  final touchValue = ProductionTestCommands.parseTouchResponse(
                      response['payload']);
                  result =
                      touchValue != null ? 'Pass (CDC: $touchValue)' : 'Fail';
                  status =
                      touchValue != null ? TestStatus.pass : TestStatus.fail;
                  if (touchValue == null) errorMsg = '无法解析Touch数据';
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
    notifyListeners();

    debugPrint('Starting test for: ${_currentTestGroup!.name}');
    await _runProductionTestSequence();

    _isRunningTest = false;
    notifyListeners();
  }

  /// Set RTC time to current UTC time
  Future<void> setRTCTime() async {
    if (!_serialService.isConnected) {
      _logState?.error('[RTC] 串口未连接', type: LogType.debug);
      return;
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
        timeout: const Duration(seconds: 10),
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
        }
      } else {
        _logState?.error('❌ RTC 时间设置失败: ${response?['error'] ?? '无响应'}',
            type: LogType.debug);
      }

      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
    } catch (e) {
      _logState?.error('RTC 设置时间异常: $e', type: LogType.debug);
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
        timeout: const Duration(seconds: 10),
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
          if (payload.length == 8) {
            _logState?.info('   - 格式: 直接8字节时间戳 (little endian)',
                type: LogType.debug);
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
                '⚠️  响应长度异常: ${payload.length} bytes (期望: 8 bytes)',
                type: LogType.debug);
            _logState?.info('   - 格式: 非标准长度', type: LogType.debug);

            // 尝试解析非标准长度的响应
            if (payload.length >= 8) {
              _logState?.info('   - 尝试解析前8字节...', type: LogType.debug);
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
        timeout: const Duration(seconds: 10),
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
        timeout: const Duration(seconds: 10),
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
        timeout: const Duration(seconds: 10),
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

  @override
  void dispose() {
    _serialService.dispose();
    super.dispose();
  }
}
