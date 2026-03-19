import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../models/log_state.dart';
import '../services/product_sn_api.dart';
import '../services/production_test_commands.dart';
import '../config/wifi_config.dart';
import 'sn_input_dialog.dart';

/// 超声前整机产测自动测试组件
class PreUltrasoundAutoTest extends StatefulWidget {
  const PreUltrasoundAutoTest({super.key});

  @override
  State<PreUltrasoundAutoTest> createState() => _PreUltrasoundAutoTestState();
}

class _PreUltrasoundAutoTestState extends State<PreUltrasoundAutoTest> {
  bool _isAutoTesting = false;
  int _currentStep = 0;
  final List<TestStepResult> _stepResults = [];
  ProductSNInfo? _productInfo;
  String? _deviceIP;

  @override
  void initState() {
    super.initState();
    _initializeSteps();
  }

  void _initializeSteps() {
    _stepResults.clear();
    _stepResults.addAll([
      TestStepResult(stepNumber: 1, name: '蓝牙连接测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 2, name: 'WIFI连接热点并获取IP', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 3, name: '光敏传感器测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 4, name: 'IMU传感器测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 5, name: '摄像头棋盘格测试', status: TestStepStatus.pending),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, state, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.orange.shade50, Colors.white],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Icon(Icons.devices_other, color: Colors.orange.shade700, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    '超声前整机产测',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const Spacer(),
                  if (_isAutoTesting)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '测试进行中...',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              
              // 测试步骤列表
              Expanded(
                child: ListView.builder(
                  itemCount: _stepResults.length,
                  itemBuilder: (context, index) {
                    final step = _stepResults[index];
                    return _buildStepCard(step, index == _currentStep);
                  },
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 控制按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!_isAutoTesting)
                    ElevatedButton.icon(
                      onPressed: () => _startAutoTest(state),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('开始自动测试'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => _stopAutoTest(state),
                      icon: const Icon(Icons.stop),
                      label: const Text('停止测试'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepCard(TestStepResult step, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.orange.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent ? Colors.orange : Colors.grey.shade300,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          _getStepStatusIcon(step.status),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '步骤${step.stepNumber}: ${step.name}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: Colors.black87,
                  ),
                ),
                if (step.message != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    step.message!,
                    style: TextStyle(
                      fontSize: 12,
                      color: step.status == TestStepStatus.failed
                          ? Colors.red
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getStepStatusIcon(TestStepStatus status) {
    switch (status) {
      case TestStepStatus.pending:
        return Icon(Icons.radio_button_unchecked, color: Colors.grey[400], size: 24);
      case TestStepStatus.running:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
          ),
        );
      case TestStepStatus.passed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 24);
      case TestStepStatus.failed:
        return const Icon(Icons.error, color: Colors.red, size: 24);
    }
  }

  Future<void> _startAutoTest(TestState state) async {
    final logState = context.read<LogState>();
    
    // 先弹窗输入SN号
    if (!mounted) return;
    final snResult = await showDialog<ProductSNInfo>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SNInputDialog(),
    );
    
    if (snResult == null) {
      logState.warning('用户取消SN输入');
      return;
    }
    
    _productInfo = snResult;
    logState.info('获取到设备信息: SN=${_productInfo!.snCode}');
    logState.info('蓝牙地址: ${_productInfo!.bluetoothAddress}');
    logState.info('WiFi MAC: ${_productInfo!.macAddress}');
    
    setState(() {
      _isAutoTesting = true;
      _currentStep = 0;
      _initializeSteps();
    });

    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // 执行5个测试步骤
    for (int i = 0; i < _stepResults.length; i++) {
      if (!_isAutoTesting) break;

      setState(() {
        _currentStep = i;
        _stepResults[i].status = TestStepStatus.running;
      });

      bool success = false;
      String? message;

      try {
        switch (i) {
          case 0: // 蓝牙连接测试
            logState.info('步骤1: 蓝牙连接测试');
            success = await _testBluetoothConnection(state, logState);
            message = success ? '蓝牙连接正常' : '蓝牙连接失败';
            break;
          case 1: // WIFI连接热点并获取IP
            logState.info('步骤2: WIFI连接热点并获取IP');
            success = await _testWiFiConnectionWithIP(state, logState);
            message = success ? 'WiFi连接成功，IP: $_deviceIP' : 'WiFi连接失败';
            break;
          case 2: // 光敏传感器测试
            logState.info('步骤3: 光敏传感器测试');
            success = await _testLightSensor(state, logState);
            message = success ? '获取到光敏值' : '光敏传感器测试失败';
            break;
          case 3: // IMU传感器测试
            logState.info('步骤4: IMU传感器测试');
            success = await _testIMUSensor(state, logState);
            message = success ? '获取到IMU值' : 'IMU传感器测试失败';
            break;
          case 4: // 摄像头棋盘格测试
            logState.info('步骤5: 摄像头棋盘格测试');
            success = await _testCameraChessboard(state, logState);
            message = success ? '摄像头测试通过' : '摄像头测试失败';
            break;
        }
      } catch (e) {
        success = false;
        message = '测试异常: $e';
        logState.error('步骤${i + 1}异常: $e');
      }

      if (!_isAutoTesting) break;

      setState(() {
        _stepResults[i].status = success ? TestStepStatus.passed : TestStepStatus.failed;
        _stepResults[i].message = message;
      });

      if (!success) {
        logState.error('❌ 步骤${i + 1}失败: $message');
        break;
      } else {
        logState.info('✅ 步骤${i + 1}通过: $message');
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() {
      _isAutoTesting = false;
    });

    final passedCount = _stepResults.where((s) => s.status == TestStepStatus.passed).length;
    final totalCount = _stepResults.length;
    
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    if (passedCount == totalCount) {
      logState.info('🎉 超声前整机产测全部通过！($passedCount/$totalCount)');
    } else {
      logState.warning('⚠️ 超声前整机产测完成，通过 $passedCount/$totalCount 项');
    }
  }

  void _stopAutoTest(TestState state) {
    final logState = context.read<LogState>();
    setState(() {
      _isAutoTesting = false;
    });
    logState.warning('⏹️ 超声前整机产测已停止');
  }

  // ========== 测试步骤实现 ==========

  /// 步骤1: 蓝牙连接测试
  Future<bool> _testBluetoothConnection(TestState state, LogState logState) async {
    try {
      if (_productInfo == null) {
        logState.error('设备信息未获取');
        return false;
      }
      
      final bluetoothAddress = _productInfo!.bluetoothAddress;
      logState.info('🔵 目标蓝牙地址: $bluetoothAddress');
      logState.info('🔍 使用 UUID: 7033 查找 RFCOMM 通道');
      
      final success = await state.testLinuxBluetooth(
        deviceAddress: bluetoothAddress,
        uuid: '7033',  // 使用UUID 7033查找RFCOMM通道
      );
      
      return success;
    } catch (e) {
      logState.error('蓝牙连接测试失败: $e');
      return false;
    }
  }

  /// 步骤2: WIFI连接热点并获取IP
  Future<bool> _testWiFiConnectionWithIP(TestState state, LogState logState) async {
    try {
      logState.info('📶 开始连接WiFi热点...');
      
      final String ssid = WiFiConfig.defaultSSID;
      final String password = WiFiConfig.defaultPassword;
      
      if (ssid.isEmpty) {
        logState.error('❌ WiFi SSID未配置，请在通用配置中设置');
        return false;
      }
      
      logState.info('   SSID: $ssid');
      
      final ssidBytes = ssid.codeUnits + [0x00];
      final pwdBytes = password.codeUnits + [0x00];
      final payload = [...ssidBytes, ...pwdBytes];
      
      final command = ProductionTestCommands.createControlWifiCommand(0x05, data: payload);
      
      // 重试机制：最多尝试3次，每次超时10秒
      _deviceIP = null;
      
      for (int retry = 0; retry < 3; retry++) {
        if (retry > 0) {
          logState.info('   重试 ($retry/3)...');
          await Future.delayed(const Duration(seconds: 2));
        }
        
        logState.info('📤 发送WiFi连接命令 (0x05)...');
        
        try {
          // 发送命令并等待响应（10秒超时）
          final response = await state.sendCommandViaLinuxBluetooth(
            command,
            timeout: const Duration(seconds: 10),
            moduleId: ProductionTestCommands.moduleId,
            messageId: ProductionTestCommands.messageId,
          );
          
          if (response != null && !response.containsKey('error')) {
            // 显示响应数据
            if (response.containsKey('payload') && response['payload'] != null) {
              final responsePayload = response['payload'] as Uint8List;
              final payloadHex = responsePayload
                  .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
                  .join(' ');
              logState.info('📥 响应: [$payloadHex] (${responsePayload.length} bytes)');
              
              // 解析WiFi响应，传入opt 0x05
              final wifiResult = ProductionTestCommands.parseWifiResponse(responsePayload, 0x05);
              
              if (wifiResult != null && wifiResult['success'] == true) {
                if (wifiResult.containsKey('ip')) {
                  _deviceIP = wifiResult['ip'];
                  logState.success('✅ 获取到设备IP: $_deviceIP');
                  logState.info('✅ WiFi连接成功');
                  return true;
                } else {
                  logState.warning('⚠️ 响应成功但未包含IP地址');
                }
              } else {
                logState.warning('⚠️ WiFi响应解析失败或返回失败');
              }
            } else {
              logState.warning('⚠️ 响应中无payload数据');
            }
          } else {
            final errorMsg = response?['error'] ?? '未知错误';
            logState.warning('⚠️ 命令响应失败: $errorMsg');
          }
        } catch (e) {
          logState.warning('⚠️ 发送命令异常: $e');
        }
      }
      
      // 3次重试后仍未获取到IP
      logState.error('❌ 3次重试后仍未获取到IP地址');
      return false;
    } catch (e) {
      logState.error('WiFi连接失败: $e');
      return false;
    }
  }

  /// 步骤3: 光敏传感器测试
  Future<bool> _testLightSensor(TestState state, LogState logState) async {
    try {
      logState.info('☀️ 开始光敏传感器测试...');
      
      final command = ProductionTestCommands.createLightSensorCommand();
      await state.runManualTest('光敏传感器测试', command);
      
      await Future.delayed(const Duration(seconds: 2));
      
      logState.info('✅ 光敏传感器测试通过');
      return true;
    } catch (e) {
      logState.error('光敏传感器测试失败: $e');
      return false;
    }
  }

  /// 步骤4: IMU传感器测试
  Future<bool> _testIMUSensor(TestState state, LogState logState) async {
    try {
      logState.info('🎯 开始IMU传感器测试...');
      
      final success = await state.testIMU();
      
      if (success) {
        logState.info('✅ IMU传感器测试通过');
      } else {
        logState.error('❌ IMU传感器测试失败');
      }
      
      return success;
    } catch (e) {
      logState.error('IMU传感器测试失败: $e');
      return false;
    }
  }

  /// 步骤5: 摄像头棋盘格测试
  Future<bool> _testCameraChessboard(TestState state, LogState logState) async {
    try {
      logState.info('📷 开始摄像头棋盘格测试...');
      
      if (!mounted) return false;
      final userConfirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.camera_alt, color: Colors.blue),
              SizedBox(width: 12),
              Text('摄像头测试'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('请将棋盘格放置在摄像头前方'),
              SizedBox(height: 8),
              Text('确保棋盘格清晰可见且光线充足'),
              SizedBox(height: 16),
              Text(
                '点击"确定"开始拍摄',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      
      if (userConfirmed != true) {
        logState.warning('用户取消摄像头测试');
        return false;
      }
      
      logState.info('📸 发送拍照命令...');
      
      final command = ProductionTestCommands.createSensorCommand(0x02);
      await state.runManualTest('摄像头拍照', command);
      
      logState.info('⏳ 开始监听图片数据流...');
      await Future.delayed(const Duration(seconds: 2));
      
      if (_deviceIP == null || _deviceIP!.isEmpty) {
        logState.error('❌ 无法下载图片：设备IP地址为空');
        return false;
      }
      
      logState.info('📥 开始FTP下载图片...');
      final downloadSuccess = await state.downloadImageFromDevice(_deviceIP!);
      
      if (!downloadSuccess) {
        logState.error('❌ 图片下载失败');
        return false;
      }
      
      logState.info('🔍 开始图片质量检测...');
      final qualitySuccess = await state.testCameraImageQuality();
      
      if (!qualitySuccess) {
        logState.error('❌ 图片质量检测失败');
        return false;
      }
      
      logState.info('✅ 摄像头测试通过');
      return true;
    } catch (e) {
      logState.error('摄像头测试失败: $e');
      return false;
    }
  }
}

// 测试步骤状态枚举
enum TestStepStatus {
  pending,
  running,
  passed,
  failed,
}

// 测试步骤结果
class TestStepResult {
  final int stepNumber;
  final String name;
  TestStepStatus status;
  String? message;

  TestStepResult({
    required this.stepNumber,
    required this.name,
    required this.status,
    this.message,
  });
}
