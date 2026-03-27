import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../models/log_state.dart';
import '../services/product_sn_api.dart';
import '../services/production_test_commands.dart';
import '../config/wifi_config.dart';
import 'sn_input_dialog.dart';
import 'bluetooth_test_options_dialog.dart';

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
  BluetoothTestMethod _selectedMethod = BluetoothTestMethod.rfcommBind; // 默认使用方案3

  @override
  void initState() {
    super.initState();
    _initializeSteps();
  }

  void _initializeSteps() {
    _stepResults.clear();
    _stepResults.addAll([
      TestStepResult(stepNumber: 1, name: '蓝牙连接测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 2, name: '产测开始', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 3, name: 'WIFI连接热点并获取IP', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 4, name: '光敏传感器测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 5, name: 'IMU传感器测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 6, name: '摄像头棋盘格测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 7, name: '产测结束', status: TestStepStatus.pending),
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
              
              // 蓝牙测试方案按钮区域
              if (!_isAutoTesting) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bluetooth, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '蓝牙连接测试方案',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildMethodButton(
                            label: '方案1: 扫描配对',
                            color: Colors.blue,
                            icon: Icons.search,
                            onPressed: () => _testSingleMethod(state, BluetoothTestMethod.autoScan),
                          ),
                          _buildMethodButton(
                            label: '方案2: 直接连接',
                            color: Colors.green,
                            icon: Icons.link,
                            onPressed: () => _testSingleMethod(state, BluetoothTestMethod.directConnect),
                          ),
                          _buildMethodButton(
                            label: '方案3: RFCOMM Bind',
                            color: Colors.orange,
                            icon: Icons.cable,
                            onPressed: () => _testSingleMethod(state, BluetoothTestMethod.rfcommBind),
                          ),
                          _buildMethodButton(
                            label: '方案4: RFCOMM Socket',
                            color: Colors.purple,
                            icon: Icons.code,
                            onPressed: () => _testSingleMethod(state, BluetoothTestMethod.rfcommSocket),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // 控制按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!_isAutoTesting) ...[
                    // 蓝牙方案选择
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<BluetoothTestMethod>(
                          value: _selectedMethod,
                          isDense: true,
                          items: const [
                            DropdownMenuItem(
                              value: BluetoothTestMethod.autoScan,
                              child: Text('方案1: 扫描配对', style: TextStyle(fontSize: 12)),
                            ),
                            DropdownMenuItem(
                              value: BluetoothTestMethod.directConnect,
                              child: Text('方案2: 直接连接', style: TextStyle(fontSize: 12)),
                            ),
                            DropdownMenuItem(
                              value: BluetoothTestMethod.rfcommBind,
                              child: Text('方案3: RFCOMM Bind ⭐', style: TextStyle(fontSize: 12)),
                            ),
                            DropdownMenuItem(
                              value: BluetoothTestMethod.rfcommSocket,
                              child: Text('方案4: RFCOMM Socket', style: TextStyle(fontSize: 12)),
                            ),
                            DropdownMenuItem(
                              value: BluetoothTestMethod.serial,
                              child: Text('方案5: 串口设备', style: TextStyle(fontSize: 12)),
                            ),
                            DropdownMenuItem(
                              value: BluetoothTestMethod.commandLine,
                              child: Text('方案6: 命令行工具', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedMethod = value);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _startAutoTest(state),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('开始自动测试'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ] else
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
          case 1: // 产测开始
            logState.info('步骤2: 产测开始');
            success = await _testProductionStart(state, logState);
            message = success ? '产测开始命令发送成功' : '产测开始命令失败';
            break;
          case 2: // WIFI连接热点并获取IP
            logState.info('步骤3: WIFI连接热点并获取IP');
            success = await _testWiFiConnectionWithIP(state, logState);
            message = success ? 'WiFi连接成功，IP: $_deviceIP' : 'WiFi连接失败';
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
          case 5: // 摄像头棋盘格测试
            logState.info('步骤6: 摄像头棋盘格测试');
            success = await _testCameraChessboard(state, logState);
            message = success ? '摄像头测试通过' : '摄像头测试失败';
            break;
          case 6: // 产测结束
            logState.info('步骤7: 产测结束');
            success = await _testProductionEnd(state, logState);
            message = success ? '产测结束命令发送成功' : '产测结束命令失败';
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

  /// 构建方案测试按钮
  Widget _buildMethodButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// 单独测试某个蓝牙连接方案
  Future<void> _testSingleMethod(TestState state, BluetoothTestMethod method) async {
    final logState = context.read<LogState>();
    
    // 弹出简单的地址输入对话框
    if (!mounted) return;
    final result = await showDialog<BluetoothTestOptions>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SimpleBluetoothInputDialog(method: method),
    );
    
    if (result == null) {
      logState.warning('用户取消测试');
      return;
    }
    
    final bluetoothAddress = result.productInfo.bluetoothAddress;
    final channel = result.channel;
    final uuid = result.uuid;
    
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('🔵 ${_getMethodName(method)}');
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('   蓝牙地址: $bluetoothAddress');
    logState.info('   RFCOMM Channel: $channel');
    logState.info('   UUID: $uuid');
    
    bool success = false;
    
    switch (method) {
      case BluetoothTestMethod.autoScan:
        success = await state.testBluetoothMethod1AutoScan(
          deviceAddress: bluetoothAddress, channel: channel, uuid: uuid,
        );
        break;
      case BluetoothTestMethod.directConnect:
        success = await state.testBluetoothMethod2DirectConnect(
          deviceAddress: bluetoothAddress, channel: channel, uuid: uuid,
        );
        break;
      case BluetoothTestMethod.rfcommBind:
        success = await state.testBluetoothMethod3RfcommBind(
          deviceAddress: bluetoothAddress, channel: channel, uuid: uuid,
        );
        break;
      case BluetoothTestMethod.rfcommSocket:
        success = await state.testBluetoothMethod4RfcommSocket(
          deviceAddress: bluetoothAddress, channel: channel, uuid: uuid,
        );
        break;
    }
    
    if (success) {
      logState.info('✅ ${_getMethodName(method)} 连接成功！');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${_getMethodName(method)} 连接成功！'), backgroundColor: Colors.green),
        );
      }
    } else {
      logState.error('❌ ${_getMethodName(method)} 连接失败');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${_getMethodName(method)} 连接失败'), backgroundColor: Colors.red),
        );
      }
    }
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  /// 蓝牙连接方案测试
  /// 支持多种连接方式测试，方便排查问题
  Future<void> _startBluetoothMethodTest(TestState state) async {
    final logState = context.read<LogState>();
    
    if (!mounted) return;
    final result = await showDialog<BluetoothTestOptions>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const BluetoothTestOptionsDialog(),
    );
    
    if (result == null) {
      logState.warning('用户取消蓝牙方案测试');
      return;
    }
    
    final bluetoothAddress = result.productInfo.bluetoothAddress;
    final method = result.method;
    final channel = result.channel;
    final uuid = result.uuid;
    
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('🔵 蓝牙连接方案测试');
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('   蓝牙地址: $bluetoothAddress');
    logState.info('   RFCOMM Channel: $channel');
    logState.info('   UUID: $uuid');
    logState.info('   测试方案: ${_getMethodName(method)}');
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    bool success = false;
    
    switch (method) {
      case BluetoothTestMethod.autoScan:
        logState.info('🔵 执行方案 1: 自动扫描配对连接');
        success = await state.testBluetoothMethod1AutoScan(
          deviceAddress: bluetoothAddress,
          channel: channel,
          uuid: uuid,
        );
        break;
      case BluetoothTestMethod.directConnect:
        logState.info('🟢 执行方案 2: 直接连接（已配对）');
        success = await state.testBluetoothMethod2DirectConnect(
          deviceAddress: bluetoothAddress,
          channel: channel,
          uuid: uuid,
        );
        break;
      case BluetoothTestMethod.rfcommBind:
        logState.info('🟠 执行方案 3: RFCOMM Bind 模式');
        success = await state.testBluetoothMethod3RfcommBind(
          deviceAddress: bluetoothAddress,
          channel: channel,
          uuid: uuid,
        );
        break;
      case BluetoothTestMethod.rfcommSocket:
        logState.info('🟣 执行方案 4: RFCOMM Socket 模式');
        success = await state.testBluetoothMethod4RfcommSocket(
          deviceAddress: bluetoothAddress,
          channel: channel,
          uuid: uuid,
        );
        break;
    }
    
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    if (success) {
      logState.info('✅ ${_getMethodName(method)} 连接成功！');
      logState.info('   连接已保持，可以进行后续测试');
      
      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_getMethodName(method)} 连接成功！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      logState.error('❌ ${_getMethodName(method)} 连接失败');
      
      // 显示失败提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${_getMethodName(method)} 连接失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
  
  String _getMethodName(BluetoothTestMethod method) {
    switch (method) {
      case BluetoothTestMethod.autoScan:
        return '方案1: 自动扫描配对连接';
      case BluetoothTestMethod.directConnect:
        return '方案2: 直接连接';
      case BluetoothTestMethod.rfcommBind:
        return '方案3: RFCOMM Bind';
      case BluetoothTestMethod.rfcommSocket:
        return '方案4: RFCOMM Socket';
      case BluetoothTestMethod.serial:
        return '方案5: 串口设备';
      case BluetoothTestMethod.commandLine:
        return '方案6: 命令行工具';
    }
  }

  // ========== 测试步骤实现 ==========

  /// 步骤1: 蓝牙连接测试
  /// 根据选择的方案使用不同的蓝牙连接方式
  Future<bool> _testBluetoothConnection(TestState state, LogState logState) async {
    try {
      if (_productInfo == null) {
        logState.error('设备信息未获取');
        return false;
      }
      
      final bluetoothAddress = _productInfo!.bluetoothAddress;
      logState.info('🔵 目标蓝牙地址: $bluetoothAddress');
      logState.info('🔗 使用 ${_getMethodName(_selectedMethod)}');
      
      bool success = false;
      
      // 根据选择的方案使用不同的连接方式
      switch (_selectedMethod) {
        case BluetoothTestMethod.autoScan:
          success = await state.testBluetoothMethod1AutoScan(
            deviceAddress: bluetoothAddress,
            channel: 5,
            uuid: '7033',
          );
          break;
        case BluetoothTestMethod.directConnect:
          success = await state.testBluetoothMethod2DirectConnect(
            deviceAddress: bluetoothAddress,
            channel: 5,
            uuid: '7033',
          );
          break;
        case BluetoothTestMethod.rfcommBind:
          success = await state.testBluetoothMethod3RfcommBind(
            deviceAddress: bluetoothAddress,
            channel: 5,
            uuid: '7033',
          );
          break;
        case BluetoothTestMethod.rfcommSocket:
          success = await state.testBluetoothMethod4RfcommSocket(
            deviceAddress: bluetoothAddress,
            channel: 5,
            uuid: '7033',
          );
          break;
        case BluetoothTestMethod.serial:
          success = await state.testBluetoothMethod5Serial(
            deviceAddress: bluetoothAddress,
            channel: 5,
            uuid: '7033',
          );
          break;
        case BluetoothTestMethod.commandLine:
          success = await state.testBluetoothMethod6CommandLine(
            deviceAddress: bluetoothAddress,
            channel: 5,
            uuid: '7033',
          );
          break;
      }
      
      return success;
    } catch (e) {
      logState.error('蓝牙连接测试失败: $e');
      return false;
    }
  }

  /// 旧的蓝牙连接方法（保留作为备用）
  Future<bool> _testBluetoothConnectionLegacy(TestState state, LogState logState) async {
    try {
      if (_productInfo == null) {
        logState.error('设备信息未获取');
        return false;
      }
      
      final bluetoothAddress = _productInfo!.bluetoothAddress;
      logState.info('🔵 目标蓝牙地址: $bluetoothAddress');
      logState.info('🔗 使用 Linux 蓝牙 SPP 连接（旧方法）');
      
      // 使用 Linux 蓝牙 SPP 连接（基于 bluetoothctl + rfcomm）
      final success = await state.testLinuxBluetooth(
        deviceAddress: bluetoothAddress,
      );
      
      return success;
    } catch (e) {
      logState.error('蓝牙连接测试失败: $e');
      return false;
    }
  }

  /// 步骤2: 产测开始
  Future<bool> _testProductionStart(TestState state, LogState logState) async {
    try {
      logState.info('🚀 发送产测开始命令...');
      
      final command = ProductionTestCommands.createStartTestCommand();
      final commandHex = command.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      logState.info('📤 发送: [$commandHex] (${command.length} bytes)');
      
      // 重试机制：最多尝试3次
      for (int retry = 0; retry < 3; retry++) {
        if (retry > 0) {
          logState.info('   重试 ($retry/3)...');
          await Future.delayed(const Duration(seconds: 2));
        }
        
        try {
          // 使用 Linux 蓝牙发送命令
          final response = await state.sendCommandViaLinuxBluetooth(
            command,
            timeout: const Duration(seconds: 5),
            moduleId: ProductionTestCommands.moduleId,
            messageId: ProductionTestCommands.messageId,
          );
          
          if (response != null && !response.containsKey('error')) {
            logState.success('✅ 产测开始命令发送成功');
            return true;
          } else {
            final errorMsg = response?['error'] ?? '未知错误';
            logState.warning('⚠️ 产测开始命令失败: $errorMsg');
          }
        } catch (e) {
          logState.warning('⚠️ 发送命令异常: $e');
        }
      }
      
      // 3次重试后仍失败
      logState.error('❌ 3次重试后产测开始命令仍失败');
      return false;
    } catch (e) {
      logState.error('产测开始异常: $e');
      return false;
    }
  }

  /// 步骤3: WIFI连接热点并获取IP
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
          // 使用 Linux 蓝牙发送命令并等待响应（10秒超时）
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

  /// 步骤4: 光敏传感器测试
  Future<bool> _testLightSensor(TestState state, LogState logState) async {
    try {
      logState.info('☀️ 开始光敏传感器测试...');
      
      final command = ProductionTestCommands.createLightSensorCommand();
      final commandHex = command.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      logState.info('📤 发送: [$commandHex] (${command.length} bytes)');
      
      // 重试机制：最多尝试3次
      for (int retry = 0; retry < 3; retry++) {
        if (retry > 0) {
          logState.info('   重试 ($retry/3)...');
          await Future.delayed(const Duration(seconds: 2));
        }
        
        try {
          // 使用 Linux 蓝牙发送命令
          final response = await state.sendCommandViaLinuxBluetooth(
            command,
            timeout: const Duration(seconds: 5),
            moduleId: ProductionTestCommands.moduleId,
            messageId: ProductionTestCommands.messageId,
          );
          
          if (response != null && !response.containsKey('error')) {
            if (response.containsKey('payload') && response['payload'] != null) {
              final payload = response['payload'] as Uint8List;
              final lightValue = ProductionTestCommands.parseLightSensorResponse(payload);
              
              if (lightValue != null) {
                logState.success('✅ 光敏传感器测试通过，光敏值: $lightValue');
                return true;
              } else {
                logState.warning('⚠️ 光敏值解析失败');
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
      
      // 3次重试后仍失败
      logState.error('❌ 3次重试后光敏传感器测试仍失败');
      return false;
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

  /// 步骤7: 产测结束
  Future<bool> _testProductionEnd(TestState state, LogState logState) async {
    try {
      logState.info('🏁 发送产测结束命令...');
      
      // 判断所有测试是否通过（除了最后一步产测结束）
      final passedCount = _stepResults.take(_stepResults.length - 1)
          .where((s) => s.status == TestStepStatus.passed).length;
      final totalCount = _stepResults.length - 1;
      final allPassed = passedCount == totalCount;
      
      // 0x00=产测通过, 0x01=产测失败
      final opt = allPassed ? 0x00 : 0x01;
      final command = ProductionTestCommands.createEndTestCommand(opt: opt);
      final commandHex = command.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      logState.info('📤 发送: [$commandHex] (${command.length} bytes)');
      logState.info('   测试结果: ${allPassed ? "通过" : "失败"} ($passedCount/$totalCount)');
      
      // 重试机制：最多尝试3次
      for (int retry = 0; retry < 3; retry++) {
        if (retry > 0) {
          logState.info('   重试 ($retry/3)...');
          await Future.delayed(const Duration(seconds: 2));
        }
        
        try {
          // 使用 Linux 蓝牙发送命令
          final response = await state.sendCommandViaLinuxBluetooth(
            command,
            timeout: const Duration(seconds: 5),
            moduleId: ProductionTestCommands.moduleId,
            messageId: ProductionTestCommands.messageId,
          );
          
          if (response != null && !response.containsKey('error')) {
            logState.success('✅ 产测结束命令发送成功');
            return true;
          } else {
            final errorMsg = response?['error'] ?? '未知错误';
            logState.warning('⚠️ 产测结束命令失败: $errorMsg');
          }
        } catch (e) {
          logState.warning('⚠️ 发送命令异常: $e');
        }
      }
      
      // 3次重试后仍失败
      logState.error('❌ 3次重试后产测结束命令仍失败');
      return false;
    } catch (e) {
      logState.error('产测结束异常: $e');
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

/// 简单的蓝牙地址输入对话框（用于单独测试某个方案）
class _SimpleBluetoothInputDialog extends StatefulWidget {
  final BluetoothTestMethod method;
  
  const _SimpleBluetoothInputDialog({required this.method});

  @override
  State<_SimpleBluetoothInputDialog> createState() => _SimpleBluetoothInputDialogState();
}

class _SimpleBluetoothInputDialogState extends State<_SimpleBluetoothInputDialog> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _channelController = TextEditingController(text: '5');
  final TextEditingController _uuidController = TextEditingController(text: '7033');
  String? _errorMessage;

  String get _methodName {
    switch (widget.method) {
      case BluetoothTestMethod.autoScan:
        return '方案1: 扫描配对连接';
      case BluetoothTestMethod.directConnect:
        return '方案2: 直接连接';
      case BluetoothTestMethod.rfcommBind:
        return '方案3: RFCOMM Bind';
      case BluetoothTestMethod.rfcommSocket:
        return '方案4: RFCOMM Socket';
      case BluetoothTestMethod.serial:
        return '方案5: 串口设备';
      case BluetoothTestMethod.commandLine:
        return '方案6: 命令行工具';
    }
  }

  Color get _methodColor {
    switch (widget.method) {
      case BluetoothTestMethod.autoScan:
        return Colors.blue;
      case BluetoothTestMethod.directConnect:
        return Colors.green;
      case BluetoothTestMethod.rfcommBind:
        return Colors.orange;
      case BluetoothTestMethod.rfcommSocket:
        return Colors.purple;
      case BluetoothTestMethod.serial:
        return Colors.brown;
      case BluetoothTestMethod.commandLine:
        return Colors.grey;
    }
  }

  bool _isValidBluetoothAddress(String address) {
    final regex = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');
    return regex.hasMatch(address);
  }

  void _handleConfirm() {
    final address = _addressController.text.trim();
    
    if (address.isEmpty) {
      setState(() => _errorMessage = '请输入蓝牙 MAC 地址');
      return;
    }
    
    if (!_isValidBluetoothAddress(address)) {
      setState(() => _errorMessage = '蓝牙地址格式不正确');
      return;
    }
    
    final formattedAddress = address.toUpperCase().replaceAll('-', ':');
    final channel = int.tryParse(_channelController.text.trim()) ?? 5;
    final uuid = _uuidController.text.trim().isEmpty ? '7033' : _uuidController.text.trim();
    
    final result = BluetoothTestOptions(
      productInfo: ProductSNInfo(
        snCode: '手动输入',
        bluetoothAddress: formattedAddress,
        macAddress: '',
      ),
      method: widget.method,
      channel: channel,
      uuid: uuid,
    );
    
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _methodColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.bluetooth, color: _methodColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _methodName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _methodColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 蓝牙地址输入
            TextField(
              controller: _addressController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '蓝牙 MAC 地址',
                hintText: '例如: 48:08:EB:60:00:60',
                prefixIcon: const Icon(Icons.bluetooth),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                errorText: _errorMessage,
              ),
              onSubmitted: (_) => _handleConfirm(),
            ),
            const SizedBox(height: 12),
            
            // Channel 和 UUID
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _channelController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Channel',
                      hintText: '5',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _uuidController,
                    decoration: InputDecoration(
                      labelText: 'UUID',
                      hintText: '7033',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // 按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _methodColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('开始测试'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
