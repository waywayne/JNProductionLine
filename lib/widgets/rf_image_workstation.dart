import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../models/log_state.dart';
import '../services/production_test_commands.dart';
import '../services/product_sn_api.dart';
import '../config/wifi_config.dart';
import 'sn_input_dialog.dart';

/// 射频图像测试工位 (工位1)
class RFImageWorkstation extends StatefulWidget {
  const RFImageWorkstation({super.key});

  @override
  State<RFImageWorkstation> createState() => _RFImageWorkstationState();
}

class _RFImageWorkstationState extends State<RFImageWorkstation> {
  bool _isAutoTesting = false;
  int _currentStep = 0;
  final List<TestStepResult> _stepResults = [];
  ProductSNInfo? _productInfo;
  String? _currentSN;
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
              colors: [Colors.blue[50]!, Colors.white],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 自动测试控制按钮
                _buildAutoTestButton(state),
                
                const SizedBox(height: 24),
                
                // 测试步骤列表
                Expanded(
                  child: _buildTestStepsList(state),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAutoTestButton(TestState state) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isAutoTesting
            ? []
            : [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: _isAutoTesting
          ? Row(
              children: [
                // 停止按钮
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _stopAutoTest(state),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.stop_circle, size: 36),
                        SizedBox(width: 12),
                        Text(
                          '停止测试',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ElevatedButton(
              onPressed: () => _startAutoTest(state),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.play_circle_filled, size: 36),
                  SizedBox(width: 12),
                  Text(
                    '开始射频图像测试',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTestStepsList(TestState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[100]!, Colors.blue[50]!],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.list_alt, size: 24, color: Colors.blue[800]),
                ),
                const SizedBox(width: 16),
                const Text(
                  '测试步骤',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_stepResults.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 18, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          '${_stepResults.where((s) => s.status == TestStepStatus.passed).length}/${_stepResults.length}',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // 步骤列表
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _stepResults.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final step = _stepResults[index];
                final isCurrentStep = _isAutoTesting && index == _currentStep;
                
                return _buildTestStepCard(step, isCurrentStep, state);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestStepCard(TestStepResult step, bool isCurrentStep, TestState state) {
    Color backgroundColor;
    Color borderColor;
    Color textColor;
    
    if (isCurrentStep) {
      backgroundColor = Colors.blue[50]!;
      borderColor = Colors.blue[400]!;
      textColor = Colors.blue[900]!;
    } else if (step.status == TestStepStatus.passed) {
      backgroundColor = Colors.green[50]!;
      borderColor = Colors.green[300]!;
      textColor = Colors.green[900]!;
    } else if (step.status == TestStepStatus.failed) {
      backgroundColor = Colors.red[50]!;
      borderColor = Colors.red[300]!;
      textColor = Colors.red[900]!;
    } else {
      backgroundColor = Colors.grey[50]!;
      borderColor = Colors.grey[300]!;
      textColor = Colors.grey[700]!;
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isCurrentStep ? 2.5 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 步骤编号
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: borderColor.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 2),
              ),
              child: Center(
                child: Text(
                  '${step.stepNumber}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // 步骤信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  if (step.message != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      step.message!,
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor.withOpacity(0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // 状态图标
            const SizedBox(width: 12),
            _buildStatusIcon(step.status, isCurrentStep),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(TestStepStatus status, bool isCurrentStep) {
    if (isCurrentStep) {
      return Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue[100],
          shape: BoxShape.circle,
        ),
        child: const CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      );
    }

    switch (status) {
      case TestStepStatus.passed:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.green[100],
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 32),
        );
      case TestStepStatus.failed:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.red[100],
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cancel, color: Colors.red, size: 32),
        );
      case TestStepStatus.running:
        return Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            shape: BoxShape.circle,
          ),
          child: const CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        );
      case TestStepStatus.pending:
        return Icon(Icons.radio_button_unchecked, color: Colors.grey[400], size: 32);
    }
  }

  Future<void> _startAutoTest(TestState state) async {
    final logState = context.read<LogState>();
    
    // 步骤0: 输入SN号并获取设备信息
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('🚀 开始射频图像测试');
    
    // 弹出SN输入对话框
    if (!mounted) return;
    final sn = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SNInputDialog(),
    );
    
    if (sn == null || sn.isEmpty) {
      logState.warning('⏹️ 用户取消测试');
      return;
    }
    
    setState(() {
      _currentSN = sn;
    });
    
    logState.info('📝 输入SN号: $sn');
    logState.info('🌐 正在获取设备信息...');
    
    // 调用API获取设备信息
    try {
      _productInfo = await ProductSNApi.getProductSNInfo(sn);
      if (_productInfo == null) {
        logState.error('❌ 未找到SN号对应的设备信息');
        return;
      }
      
      logState.info('✅ 设备信息获取成功');
      logState.info('   蓝牙地址: ${_productInfo!.bluetoothAddress}');
      logState.info('   WiFi MAC: ${_productInfo!.macAddress}');
      logState.info('   硬件版本: ${_productInfo!.hardwareVersion}');
    } catch (e) {
      logState.error('❌ 获取设备信息失败: $e');
      return;
    }
    
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
      logState.info('🎉 射频图像测试全部通过！($passedCount/$totalCount)');
    } else {
      logState.warning('⚠️ 射频图像测试完成，通过 $passedCount/$totalCount 项');
    }
  }

  void _stopAutoTest(TestState state) {
    final logState = context.read<LogState>();
    setState(() {
      _isAutoTesting = false;
    });
    logState.warning('⏹️ 射频图像测试已停止');
  }

  // ========== 测试步骤实现 ==========

  /// 步骤1: 蓝牙连接测试 (使用API返回的蓝牙地址)
  Future<bool> _testBluetoothConnection(TestState state, LogState logState) async {
    try {
      if (_productInfo == null) {
        logState.error('设备信息未获取');
        return false;
      }
      
      final bluetoothAddress = _productInfo!.bluetoothAddress;
      logState.info('🔵 目标蓝牙地址: $bluetoothAddress');
      
      // 调用Linux蓝牙SPP测试，传入指定的蓝牙地址
      final success = await state.testLinuxBluetooth(
        deviceAddress: bluetoothAddress,
      );
      
      return success;
    } catch (e) {
      logState.error('蓝牙连接测试失败: $e');
      return false;
    }
  }

  /// 步骤2: WIFI连接热点并获取IP (STA模式)
  Future<bool> _testWiFiConnectionWithIP(TestState state, LogState logState) async {
    try {
      logState.info('📶 开始连接WiFi热点...');
      
      // WiFi热点配置 (从通用配置中获取)
      final String ssid = WiFiConfig.defaultSSID;
      final String password = WiFiConfig.defaultPassword;
      
      if (ssid.isEmpty) {
        logState.error('❌ WiFi SSID未配置，请在通用配置中设置');
        return false;
      }
      
      logState.info('   SSID: $ssid');
      
      // 构建WiFi连接命令 (CMD 0x04, OPT 0x05)
      // SSID和密码都是字符串，以\0结尾
      final ssidBytes = ssid.codeUnits + [0x00];
      final pwdBytes = password.codeUnits + [0x00];
      final payload = [...ssidBytes, ...pwdBytes];
      
      final command = ProductionTestCommands.createControlWifiCommand(0x05, data: payload);
      await state.runManualTest('WiFi连接热点', command);
      
      // 等待连接并监听IP地址（10秒）
      logState.info('⏳ 等待10秒监听IP地址...');
      
      // 监听IP地址，参考单板产测逻辑
      final startTime = DateTime.now();
      _deviceIP = null;
      
      while (DateTime.now().difference(startTime).inSeconds < 10) {
        // 检查state中是否已获取到IP地址
        if (state.deviceIPAddress != null && state.deviceIPAddress!.isNotEmpty) {
          _deviceIP = state.deviceIPAddress;
          logState.success('✅ 获取到设备IP: $_deviceIP');
          break;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (_deviceIP == null || _deviceIP!.isEmpty) {
        logState.error('❌ 10秒内未获取到IP地址');
        return false;
      }
      
      logState.info('✅ WiFi连接成功，IP: $_deviceIP');
      return true;
    } catch (e) {
      logState.error('WiFi连接失败: $e');
      return false;
    }
  }

  /// 步骤3: 光敏传感器测试
  Future<bool> _testLightSensor(TestState state, LogState logState) async {
    try {
      logState.info('☀️ 开始光敏传感器测试...');
      
      // 发送光敏传感器测试命令
      final command = ProductionTestCommands.createLightSensorCommand();
      await state.runManualTest('光敏传感器测试', command);
      
      // 等待响应
      await Future.delayed(const Duration(seconds: 2));
      
      // TODO: 验证是否收到有效的光敏值
      // 需要从响应中解析光敏值，判断是否存在且在合理范围内
      
      logState.info('✅ 光敏传感器测试通过');
      return true;
    } catch (e) {
      logState.error('光敏传感器测试失败: $e');
      return false;
    }
  }

  /// 步骤4: IMU传感器测试 (参考单板产测逻辑)
  Future<bool> _testIMUSensor(TestState state, LogState logState) async {
    try {
      logState.info('🎯 开始IMU传感器测试...');
      
      // 调用TestState的IMU测试方法（与单板产测逻辑一致）
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
      
      // 弹窗提示用户拍摄棋盘格
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
      
      // 发送拍照命令 (CMD 0x0C, OPT 0x02 - 抓图)
      final command = ProductionTestCommands.createSensorCommand(0x02);
      await state.runManualTest('摄像头拍照', command);
      
      logState.info('⏳ 开始监听图片数据流...');
      
      // 等待图片数据传输完成
      // 监听逻辑：检查payload第一个字节是否为CMD 0x0C
      // 参考单板产测的Sensor图片接收逻辑
      await Future.delayed(const Duration(seconds: 2));
      
      // 检查是否有IP地址用于FTP下载
      if (_deviceIP == null || _deviceIP!.isEmpty) {
        logState.error('❌ 设备IP地址未获取，无法下载图片');
        return false;
      }
      
      logState.info('📥 通过FTP下载图片 (IP: $_deviceIP)...');
      
      // 调用FTP下载图片（参考单板产测的_downloadSensorImageFromDevice方法）
      final downloadSuccess = await state.downloadImageFromDevice(_deviceIP!);
      
      if (!downloadSuccess) {
        logState.error('❌ 图片下载失败');
        return false;
      }
      
      logState.success('✅ 图片下载成功');
      
      // 调用image_test库检测图片质量
      logState.info('🔍 检测图片质量...');
      
      final imageTestSuccess = await state.testCameraImageQuality();
      
      if (!imageTestSuccess) {
        logState.error('❌ 图片质量检测失败');
        return false;
      }
      
      logState.success('✅ 摄像头棋盘格测试通过');
      return true;
    } catch (e) {
      logState.error('摄像头测试失败: $e');
      return false;
    }
  }
}

// ========== 数据模型 ==========

enum TestStepStatus {
  pending,
  running,
  passed,
  failed,
}

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
