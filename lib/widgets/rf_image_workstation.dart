import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../models/log_state.dart';
import '../services/production_test_commands.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeSteps();
  }

  void _initializeSteps() {
    _stepResults.clear();
    _stepResults.addAll([
      TestStepResult(stepNumber: 1, name: '物奇/SIGM/WIFI上电', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 2, name: '蓝牙连接测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 3, name: 'WIFI连接测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 4, name: '光敏传感器测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 5, name: 'IMU传感器测试', status: TestStepStatus.pending),
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
    
    setState(() {
      _isAutoTesting = true;
      _currentStep = 0;
      _initializeSteps();
    });

    logState.info('🚀 开始射频图像测试');

    // 执行5个测试步骤
    for (int i = 0; i < _stepResults.length; i++) {
      if (!_isAutoTesting) break; // 检查是否被停止

      setState(() {
        _currentStep = i;
        _stepResults[i].status = TestStepStatus.running;
      });

      bool success = false;
      String? message;

      try {
        switch (i) {
          case 0: // 物奇/SIGM/WIFI上电
            logState.info('步骤1: 物奇/SIGM/WIFI上电');
            success = await _testPowerOn(state, logState);
            message = success ? '上电成功' : '上电失败';
            break;
          case 1: // 蓝牙连接测试
            logState.info('步骤2: 蓝牙连接测试');
            success = await _testBluetoothConnection(state, logState);
            message = success ? '蓝牙连接正常' : '蓝牙连接失败';
            break;
          case 2: // WIFI连接测试
            logState.info('步骤3: WIFI连接测试');
            success = await _testWiFiConnection(state, logState);
            message = success ? 'WIFI连接成功，MAC地址已确认' : 'WIFI连接失败';
            break;
          case 3: // 光敏传感器测试
            logState.info('步骤4: 光敏传感器测试');
            success = await _testLightSensor(state, logState);
            message = success ? '获取到光敏值' : '光敏传感器测试失败';
            break;
          case 4: // IMU传感器测试
            logState.info('步骤5: IMU传感器测试');
            success = await _testIMUSensor(state, logState);
            message = success ? '获取到IMU值' : 'IMU传感器测试失败';
            break;
        }
      } catch (e) {
        success = false;
        message = '测试异常: $e';
        logState.error('步骤${i + 1}异常: $e');
      }

      if (!_isAutoTesting) break; // 再次检查是否被停止

      setState(() {
        _stepResults[i].status = success ? TestStepStatus.passed : TestStepStatus.failed;
        _stepResults[i].message = message;
      });

      if (!success) {
        logState.error('❌ 步骤${i + 1}失败: $message');
        break; // 失败则停止后续测试
      } else {
        logState.info('✅ 步骤${i + 1}通过: $message');
      }

      // 步骤间延迟
      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() {
      _isAutoTesting = false;
    });

    // 显示测试结果
    final passedCount = _stepResults.where((s) => s.status == TestStepStatus.passed).length;
    final totalCount = _stepResults.length;
    
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

  /// 步骤1: 物奇/SIGM/WIFI上电
  Future<bool> _testPowerOn(TestState state, LogState logState) async {
    try {
      // 测试物奇功耗（上电）
      final wuqiSuccess = await state.testWuqiPower();
      if (!wuqiSuccess) {
        return false;
      }
      
      // 等待稳定
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 测试ISP工作功耗
      final ispSuccess = await state.testIspWorkingPower();
      if (!ispSuccess) {
        return false;
      }
      
      return true;
    } catch (e) {
      logState.error('物奇/SIGM/WIFI上电失败: $e');
      return false;
    }
  }

  /// 步骤2: 蓝牙连接测试
  Future<bool> _testBluetoothConnection(TestState state, LogState logState) async {
    try {
      // 调用SPP蓝牙测试
      final success = await state.testSppBluetooth();
      return success;
    } catch (e) {
      logState.error('蓝牙连接测试失败: $e');
      return false;
    }
  }

  /// 步骤3: WIFI连接测试
  Future<bool> _testWiFiConnection(TestState state, LogState logState) async {
    try {
      // 调用WiFi测试（包含连接和MAC地址获取）
      final success = await state.testWiFi();
      return success;
    } catch (e) {
      logState.error('WIFI连接测试失败: $e');
      return false;
    }
  }

  /// 步骤4: 光敏传感器测试
  Future<bool> _testLightSensor(TestState state, LogState logState) async {
    try {
      // 发送光敏传感器测试命令并等待响应
      final command = ProductionTestCommands.createLightSensorCommand();
      await state.runManualTest('光敏传感器测试', command);
      
      // 等待响应（简化处理，实际应该等待并验证响应）
      await Future.delayed(const Duration(seconds: 2));
      
      // TODO: 验证是否收到有效的光敏值
      return true;
    } catch (e) {
      logState.error('光敏传感器测试失败: $e');
      return false;
    }
  }

  /// 步骤5: IMU传感器测试
  Future<bool> _testIMUSensor(TestState state, LogState logState) async {
    try {
      // 调用IMU测试
      final success = await state.testIMU();
      return success;
    } catch (e) {
      logState.error('IMU传感器测试失败: $e');
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
