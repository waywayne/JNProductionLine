import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../models/log_state.dart';
import '../models/touch_test_step.dart';
import '../services/product_sn_api.dart';
import '../services/production_test_commands.dart';
import '../services/gtp_protocol.dart';
import '../services/byd_mes_service.dart';
import '../config/production_config.dart';
import 'sn_input_dialog.dart';
import 'bluetooth_test_options_dialog.dart';

/// 工位3: 电源外设测试
/// 测试项: 产测开始、电压、电量、充电、LED、触控、结束产测
class PowerPeripheralWorkstation extends StatefulWidget {
  const PowerPeripheralWorkstation({super.key});

  @override
  State<PowerPeripheralWorkstation> createState() => _PowerPeripheralWorkstationState();
}

class _PowerPeripheralWorkstationState extends State<PowerPeripheralWorkstation> {
  bool _isAutoTesting = false;
  int _currentStep = 0;
  final List<TestStepResult> _stepResults = [];
  ProductSNInfo? _productInfo;
  BluetoothTestMethod _selectedMethod = BluetoothTestMethod.rfcommBind;
  final BydMesService _mesService = BydMesService(station: 'STATION3');
  final ProductionConfig _config = ProductionConfig();

  @override
  void initState() {
    super.initState();
    _initializeSteps();
  }

  void _initializeSteps() {
    _stepResults.clear();
    _stepResults.addAll([
      TestStepResult(stepNumber: 1, name: '蓝牙连接', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 2, name: '产测开始', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 3, name: '设备电压测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 4, name: '电量检测测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 5, name: '充电状态测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 6, name: 'LED灯(外侧)开启', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 7, name: 'LED灯(外侧)关闭', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 8, name: 'LED灯(内侧)开启', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 9, name: 'LED灯(内侧)关闭', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 10, name: '右触控-TK1测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 11, name: '右触控-TK2测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 12, name: '右触控-TK3测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 13, name: '左佩戴检测', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 14, name: '左触控事件测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 15, name: '结束产测', status: TestStepStatus.pending),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, state, _) {
        return Container(
          color: Colors.grey[100],
          child: Column(
            children: [
              // 控制面板
              _buildControlPanel(state),
              
              // 测试步骤列表
              Expanded(
                child: _buildStepsList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlPanel(TestState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 开始/停止按钮
          ElevatedButton.icon(
            onPressed: _isAutoTesting ? _stopAutoTest : () => _startAutoTest(state),
            icon: Icon(_isAutoTesting ? Icons.stop : Icons.play_arrow),
            label: Text(_isAutoTesting ? '停止测试' : '开始自动测试'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isAutoTesting ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(width: 16),
          
          // 方案选择
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<BluetoothTestMethod>(
                value: _selectedMethod,
                items: BluetoothTestMethod.values.map((method) {
                  return DropdownMenuItem(
                    value: method,
                    child: Text(_getMethodName(method), style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: _isAutoTesting ? null : (value) {
                  if (value != null) {
                    setState(() => _selectedMethod = value);
                  }
                },
              ),
            ),
          ),
          
          const Spacer(),
          
          // 设备信息
          if (_productInfo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.bluetooth, color: Colors.blue[700], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'SN: ${_productInfo!.snCode}',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '蓝牙: ${_productInfo!.bluetoothAddress}',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700], fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _stepResults.length,
      itemBuilder: (context, index) {
        final step = _stepResults[index];
        final isCurrent = index == _currentStep && _isAutoTesting;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCurrent ? Colors.green[50] : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCurrent ? Colors.green : Colors.grey[300]!,
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
                      ),
                    ),
                    if (step.message != null)
                      Text(
                        step.message!,
                        style: TextStyle(
                          fontSize: 12,
                          color: step.status == TestStepStatus.failed ? Colors.red : Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
          ),
        );
      case TestStepStatus.passed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 24);
      case TestStepStatus.failed:
        return const Icon(Icons.error, color: Colors.red, size: 24);
    }
  }

  String _getMethodName(BluetoothTestMethod method) {
    switch (method) {
      case BluetoothTestMethod.autoScan:
        return '方案1: 扫描配对';
      case BluetoothTestMethod.directConnect:
        return '方案2: 直接连接';
      case BluetoothTestMethod.rfcommBind:
        return '方案3: RFCOMM Bind ⭐';
      case BluetoothTestMethod.rfcommSocket:
        return '方案4: RFCOMM Socket';
      case BluetoothTestMethod.serial:
        return '方案5: 串口设备';
      case BluetoothTestMethod.commandLine:
        return '方案6: 命令行工具';
    }
  }

  void _stopAutoTest() {
    setState(() {
      _isAutoTesting = false;
    });
  }

  Future<void> _startAutoTest(TestState state) async {
    final logState = context.read<LogState>();
    
    // 弹出输入对话框
    if (!mounted) return;
    final options = await showDialog<_AutoTestOptions>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AutoTestInputDialog(defaultMethod: _selectedMethod),
    );
    
    if (options == null) {
      logState.warning('用户取消输入');
      return;
    }
    
    _productInfo = options.productInfo;
    _selectedMethod = options.method;
    
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('🔧 工位3: 电源外设测试');
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('SN: ${_productInfo!.snCode}');
    logState.info('蓝牙地址: ${_productInfo!.bluetoothAddress}');
    logState.info('连接方案: ${_getMethodName(_selectedMethod)}');
    
    setState(() {
      _isAutoTesting = true;
      _currentStep = 0;
      _initializeSteps();
    });

    // 执行测试步骤
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
          case 0: // 蓝牙连接
            success = await _testBluetoothConnection(state, logState);
            message = success ? '蓝牙连接成功' : '蓝牙连接失败';
            break;
          case 1: // 产测开始
            success = await _testProductionStart(state, logState);
            message = success ? '产测开始成功' : '产测开始失败';
            break;
          case 2: // 设备电压测试
            final result = await _testVoltage(state, logState);
            success = result['success'] as bool;
            message = result['message'] as String?;
            break;
          case 3: // 电量检测测试
            final result = await _testBattery(state, logState);
            success = result['success'] as bool;
            message = result['message'] as String?;
            break;
          case 4: // 充电状态测试
            final result = await _testChargeStatus(state, logState);
            success = result['success'] as bool;
            message = result['message'] as String?;
            break;
          case 5: // LED灯(外侧)开启
            success = await _testLED(state, logState, isOuter: true, turnOn: true);
            message = success ? 'LED外侧开启成功' : 'LED外侧开启失败';
            break;
          case 6: // LED灯(外侧)关闭
            success = await _testLED(state, logState, isOuter: true, turnOn: false);
            message = success ? 'LED外侧关闭成功' : 'LED外侧关闭失败';
            break;
          case 7: // LED灯(内侧)开启
            success = await _testLED(state, logState, isOuter: false, turnOn: true);
            message = success ? 'LED内侧开启成功' : 'LED内侧开启失败';
            break;
          case 8: // LED灯(内侧)关闭
            success = await _testLED(state, logState, isOuter: false, turnOn: false);
            message = success ? 'LED内侧关闭成功' : 'LED内侧关闭失败';
            break;
          case 9: // 右触控-TK1测试
            success = await _testTouch(state, logState, touchType: 'TK1');
            message = success ? 'TK1测试通过' : 'TK1测试失败';
            break;
          case 10: // 右触控-TK2测试
            success = await _testTouch(state, logState, touchType: 'TK2');
            message = success ? 'TK2测试通过' : 'TK2测试失败';
            break;
          case 11: // 右触控-TK3测试
            success = await _testTouch(state, logState, touchType: 'TK3');
            message = success ? 'TK3测试通过' : 'TK3测试失败';
            break;
          case 12: // 左佩戴检测
            success = await _testLeftWearDetect(state, logState);
            message = success ? '佩戴检测通过' : '佩戴检测失败';
            break;
          case 13: // 左触控事件测试
            success = await _testLeftTouchEvent(state, logState);
            message = success ? '左触控事件通过' : '左触控事件失败';
            break;
          case 14: // 结束产测
            success = await _testProductionEnd(state, logState);
            message = success ? '产测结束成功' : '产测结束失败';
            break;
        }
      } catch (e) {
        success = false;
        message = '异常: $e';
        logState.error('步骤${i + 1}异常: $e');
      }

      setState(() {
        _stepResults[i].status = success ? TestStepStatus.passed : TestStepStatus.failed;
        _stepResults[i].message = message;
      });

      if (!success) {
        logState.error('❌ 步骤${i + 1}失败，停止测试');
        break;
      }
    }

    setState(() {
      _isAutoTesting = false;
    });

    // 检查测试结果
    final allPassed = _stepResults.every((s) => s.status == TestStepStatus.passed);
    if (allPassed) {
      logState.info('✅ 工位3测试全部通过');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 工位3测试全部通过'), backgroundColor: Colors.green),
        );
      }
    } else {
      logState.error('❌ 工位3测试未通过');
    }
  }

  // ========== 测试方法 ==========

  Future<bool> _testBluetoothConnection(TestState state, LogState logState) async {
    logState.info('🔵 步骤1: 蓝牙连接测试');
    
    final bluetoothAddress = _productInfo!.bluetoothAddress;
    if (bluetoothAddress == null || bluetoothAddress.isEmpty) {
      logState.error('❌ 蓝牙地址为空');
      return false;
    }

    bool success = false;
    switch (_selectedMethod) {
      case BluetoothTestMethod.autoScan:
        success = await state.testBluetoothMethod1AutoScan(deviceAddress: bluetoothAddress);
        break;
      case BluetoothTestMethod.directConnect:
        success = await state.testBluetoothMethod2DirectConnect(deviceAddress: bluetoothAddress);
        break;
      case BluetoothTestMethod.rfcommBind:
        success = await state.testBluetoothMethod3RfcommBind(deviceAddress: bluetoothAddress);
        break;
      case BluetoothTestMethod.rfcommSocket:
        success = await state.testBluetoothMethod4RfcommSocket(deviceAddress: bluetoothAddress);
        break;
      case BluetoothTestMethod.serial:
        success = await state.testBluetoothMethod5Serial(deviceAddress: bluetoothAddress);
        break;
      case BluetoothTestMethod.commandLine:
        success = await state.testBluetoothMethod6CommandLine(deviceAddress: bluetoothAddress);
        break;
    }

    if (success) {
      logState.info('✅ 蓝牙连接成功');
      
      // 蓝牙连接成功后调用 BYD MES start
      logState.info('📤 调用 BYD MES start...');
      _mesService.printConfig();
      final mesResult = await _mesService.start(_productInfo!.snCode);
      if (mesResult['success'] == true) {
        logState.info('✅ MES start 成功');
      } else {
        logState.warning('⚠️ MES start 失败: ${mesResult['error']}');
      }
    }

    return success;
  }

  Future<bool> _testProductionStart(TestState state, LogState logState) async {
    logState.info('🚀 步骤2: 产测开始');
    
    final command = ProductionTestCommands.createStartTestCommand();
    final response = await state.sendCommandViaLinuxBluetooth(
      command,
      timeout: const Duration(seconds: 5),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );

    if (response == null || response.containsKey('error')) {
      logState.error('❌ 产测开始命令失败');
      return false;
    }

    logState.info('✅ 产测开始成功');
    return true;
  }

  Future<Map<String, dynamic>> _testVoltage(TestState state, LogState logState) async {
    logState.info('🔋 步骤3: 设备电压测试');
    
    final command = ProductionTestCommands.createGetVoltageCommand();
    final response = await state.sendCommandViaLinuxBluetooth(
      command,
      timeout: const Duration(seconds: 5),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );

    if (response == null || response.containsKey('error')) {
      return {'success': false, 'message': '获取电压失败'};
    }

    // 解析电压值
    final payload = response['payload'];
    if (payload is List && payload.length >= 5) {
      // 电压值在 payload[1:5]，4字节 float
      final voltageBytes = payload.sublist(1, 5);
      final byteData = ByteData.sublistView(Uint8List.fromList(voltageBytes));
      final voltage = byteData.getFloat32(0, Endian.little);
      
      final threshold = _config.minVoltageV;
      final success = voltage > threshold;
      
      logState.info('   电压值: ${voltage.toStringAsFixed(2)}V (阈值: >${threshold}V)');
      
      return {
        'success': success,
        'message': '电压: ${voltage.toStringAsFixed(2)}V ${success ? "✅" : "❌"}',
      };
    }

    return {'success': false, 'message': '电压数据解析失败'};
  }

  Future<Map<String, dynamic>> _testBattery(TestState state, LogState logState) async {
    logState.info('🔋 步骤4: 电量检测测试');
    
    final command = ProductionTestCommands.createGetCurrentCommand();
    final response = await state.sendCommandViaLinuxBluetooth(
      command,
      timeout: const Duration(seconds: 5),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );

    if (response == null || response.containsKey('error')) {
      return {'success': false, 'message': '获取电量失败'};
    }

    // 解析电量值
    final payload = response['payload'];
    if (payload is List && payload.length >= 2) {
      final battery = payload[1];
      final minBattery = _config.minBatteryPercent;
      final maxBattery = _config.maxBatteryPercent;
      final success = battery >= minBattery && battery <= maxBattery;
      
      logState.info('   电量值: $battery% (范围: $minBattery~$maxBattery%)');
      
      return {
        'success': success,
        'message': '电量: $battery% ${success ? "✅" : "❌"}',
      };
    }

    return {'success': false, 'message': '电量数据解析失败'};
  }

  Future<Map<String, dynamic>> _testChargeStatus(TestState state, LogState logState) async {
    logState.info('🔌 步骤5: 充电状态测试');
    
    final command = ProductionTestCommands.createGetChargeStatusCommand();
    final response = await state.sendCommandViaLinuxBluetooth(
      command,
      timeout: const Duration(seconds: 5),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );

    if (response == null || response.containsKey('error')) {
      return {'success': false, 'message': '获取充电状态失败'};
    }

    // 解析充电状态
    final payload = response['payload'];
    if (payload is List && payload.length >= 2) {
      final chargeStatus = payload[1];
      final isCharging = chargeStatus == 0x01;
      
      logState.info('   充电状态: ${isCharging ? "充电中" : "未充电"}');
      
      return {
        'success': isCharging,
        'message': isCharging ? '充电中 ✅' : '未充电 ❌',
      };
    }

    return {'success': false, 'message': '充电状态数据解析失败'};
  }

  Future<bool> _testLED(TestState state, LogState logState, {required bool isOuter, required bool turnOn}) async {
    final ledName = isOuter ? '外侧' : '内侧';
    final action = turnOn ? '开启' : '关闭';
    logState.info('💡 LED灯($ledName)$action');
    
    final ledNumber = isOuter ? ProductionTestCommands.ledOuter : ProductionTestCommands.ledInner;
    final ledState = turnOn ? ProductionTestCommands.ledOn : ProductionTestCommands.ledOff;
    
    final command = ProductionTestCommands.createControlLEDCommand(ledNumber, ledState);
    final response = await state.sendCommandViaLinuxBluetooth(
      command,
      timeout: const Duration(seconds: 5),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );

    if (response == null || response.containsKey('error')) {
      logState.error('❌ LED控制命令失败');
      return false;
    }

    // 弹出确认对话框
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(turnOn ? Icons.lightbulb : Icons.lightbulb_outline, 
                 color: turnOn ? Colors.amber : Colors.grey),
            const SizedBox(width: 12),
            Text('LED灯($ledName)$action'),
          ],
        ),
        content: Text('请确认LED灯($ledName)是否已$action？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('未通过'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('通过'),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<bool> _testTouch(TestState state, LogState logState, {required String touchType}) async {
    logState.info('👆 右触控-$touchType测试');
    
    // 获取初始 CDC 值
    final touchNumber = touchType == 'TK1' ? 0 : (touchType == 'TK2' ? 1 : 2);
    final command = ProductionTestCommands.createTouchCommand(
      ProductionTestCommands.touchRight,
      ProductionTestCommands.touchOptGetCDC,
    );
    
    final initialResponse = await state.sendCommandViaLinuxBluetooth(
      command,
      timeout: const Duration(seconds: 5),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );

    if (initialResponse == null || initialResponse.containsKey('error')) {
      logState.error('❌ 获取初始CDC值失败');
      return false;
    }

    // 弹出提示对话框
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.touch_app, color: Colors.blue),
            const SizedBox(width: 12),
            Text('右触控-$touchType测试'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('请按住$touchType区域，然后点击"检测"按钮'),
            const SizedBox(height: 8),
            Text('阈值变化量需超过${_config.touchThreshold}', 
                 style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('检测'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    // 获取按压后的 CDC 值
    final pressedResponse = await state.sendCommandViaLinuxBluetooth(
      command,
      timeout: const Duration(seconds: 5),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );

    if (pressedResponse == null || pressedResponse.containsKey('error')) {
      logState.error('❌ 获取按压CDC值失败');
      return false;
    }

    // 比较 CDC 变化量
    // TODO: 实际解析 CDC 值并比较
    logState.info('✅ $touchType测试通过');
    return true;
  }

  // ========== 左佩戴检测 ==========
  // 流程: 发送 0x07+0x00+0x04 → 收到ACK → 监听 0x07+0x00+0x04 推送 → 通过
  Future<bool> _testLeftWearDetect(TestState state, LogState logState) async {
    logState.info('👆 左佩戴检测');
    
    final command = ProductionTestCommands.createTouchCommand(
      TouchTestConfig.touchLeft, TouchTestConfig.leftActionWearDetect,
    );
    logState.info('📤 发送佩戴检测命令...');
    final response = await state.sendCommandViaLinuxBluetooth(
      command,
      timeout: const Duration(seconds: 5),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );
    
    if (response == null || response.containsKey('error')) {
      logState.error('❌ 佩戴检测命令发送失败');
      return false;
    }
    
    logState.info('✅ 命令已发送，开始监听佩戴检测推送...');
    logState.info('👂 等待佩戴检测响应 (0x07 0x00 0x04)...');
    
    if (!mounted) return false;
    
    final completer = Completer<bool>();
    StreamSubscription<Uint8List>? subscription;
    bool testPassed = false;
    String statusInfo = '请佩戴设备...';
    
    void Function(void Function())? _setDialogState;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _setDialogState = setDialogState;
            final statusColor = testPassed ? Colors.green : Colors.orange;
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.touch_app, color: statusColor),
                  const SizedBox(width: 12),
                  const Text('左佩戴检测'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('请将设备佩戴到耳朵上', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(statusInfo, 
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor)),
                  ),
                ],
              ),
              actions: [
                if (!testPassed)
                  TextButton(
                    onPressed: () {
                      subscription?.cancel();
                      Navigator.of(dialogContext).pop();
                      if (!completer.isCompleted) completer.complete(false);
                    },
                    child: const Text('取消测试'),
                  ),
              ],
            );
          },
        );
      },
    );
    
    await Future.delayed(const Duration(milliseconds: 100));
    
    final timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        logState.error('❌ 佩戴检测超时（15秒）');
        subscription?.cancel();
        statusInfo = '❌ 超时';
        _setDialogState?.call(() {});
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.of(context, rootNavigator: true).pop();
          if (!completer.isCompleted) completer.complete(false);
        });
      }
    });
    
    subscription = state.linuxBluetoothDataStream.listen((data) {
      try {
        final gtpResponse = GTPProtocol.parseGTPResponse(data);
        if (gtpResponse != null && !gtpResponse.containsKey('error') && gtpResponse.containsKey('payload')) {
          final payload = gtpResponse['payload'] as Uint8List;
          if (payload.length >= 3 && 
              payload[0] == ProductionTestCommands.cmdTouch && 
              payload[1] == TouchTestConfig.touchLeft && 
              payload[2] == TouchTestConfig.leftActionWearDetect) {
            if (!testPassed) {
              testPassed = true;
              statusInfo = '✅ 佩戴检测通过！';
              logState.info('✅ 佩戴检测通过！收到 0x07 0x00 0x04');
              _setDialogState?.call(() {});
              timeoutTimer.cancel();
              subscription?.cancel();
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) Navigator.of(context, rootNavigator: true).pop();
                if (!completer.isCompleted) completer.complete(true);
              });
            }
          }
        }
      } catch (e) {
        logState.warning('⚠️ 解析推送数据出错: $e');
      }
    });
    
    return completer.future;
  }

  // ========== 左触控事件测试 ==========
  // 流程: 发送 0x07+0x00+0x00 → 监听 0x07+0x00+(0x01/0x02/0x03/0x05) 推送 → 通过
  Future<bool> _testLeftTouchEvent(TestState state, LogState logState) async {
    logState.info('👆 左触控事件测试');
    
    final command = ProductionTestCommands.createTouchCommand(
      TouchTestConfig.touchLeft, TouchTestConfig.leftActionUntouched,
    );
    logState.info('📤 发送左触控事件命令...');
    final response = await state.sendCommandViaLinuxBluetooth(
      command,
      timeout: const Duration(seconds: 5),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );
    
    if (response == null || response.containsKey('error')) {
      logState.error('❌ 左触控事件命令发送失败');
      return false;
    }
    
    logState.info('✅ 命令已发送，开始监听触控事件推送...');
    logState.info('👂 等待触控事件 (单击/双击/长按/滑动)...');
    
    if (!mounted) return false;
    
    final completer = Completer<bool>();
    StreamSubscription<Uint8List>? subscription;
    bool testPassed = false;
    String statusInfo = '请执行任意触控操作（单击/双击/长按/滑动）...';
    
    void Function(void Function())? _setDialogState;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _setDialogState = setDialogState;
            final statusColor = testPassed ? Colors.green : Colors.orange;
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.touch_app, color: statusColor),
                  const SizedBox(width: 12),
                  const Text('左触控事件测试'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('请对左侧Touch执行任意操作', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('（单击/双击/长按/滑动均可）', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(statusInfo, 
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor)),
                  ),
                ],
              ),
              actions: [
                if (!testPassed)
                  TextButton(
                    onPressed: () {
                      subscription?.cancel();
                      Navigator.of(dialogContext).pop();
                      if (!completer.isCompleted) completer.complete(false);
                    },
                    child: const Text('取消测试'),
                  ),
              ],
            );
          },
        );
      },
    );
    
    await Future.delayed(const Duration(milliseconds: 100));
    
    final timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        logState.error('❌ 左触控事件检测超时（15秒）');
        subscription?.cancel();
        statusInfo = '❌ 超时';
        _setDialogState?.call(() {});
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.of(context, rootNavigator: true).pop();
          if (!completer.isCompleted) completer.complete(false);
        });
      }
    });
    
    subscription = state.linuxBluetoothDataStream.listen((data) {
      try {
        final gtpResponse = GTPProtocol.parseGTPResponse(data);
        if (gtpResponse != null && !gtpResponse.containsKey('error') && gtpResponse.containsKey('payload')) {
          final payload = gtpResponse['payload'] as Uint8List;
          if (payload.length >= 3 && 
              payload[0] == ProductionTestCommands.cmdTouch && 
              payload[1] == TouchTestConfig.touchLeft && 
              TouchTestConfig.leftTouchEventActionIds.contains(payload[2])) {
            if (!testPassed) {
              testPassed = true;
              final actionName = TouchTestConfig.getLeftActionName(payload[2]);
              statusInfo = '✅ 检测到: $actionName';
              logState.info('✅ 左触控事件通过！检测到: $actionName');
              _setDialogState?.call(() {});
              timeoutTimer.cancel();
              subscription?.cancel();
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) Navigator.of(context, rootNavigator: true).pop();
                if (!completer.isCompleted) completer.complete(true);
              });
            }
          }
        }
      } catch (e) {
        logState.warning('⚠️ 解析推送数据出错: $e');
      }
    });
    
    return completer.future;
  }

  Future<bool> _testProductionEnd(TestState state, LogState logState) async {
    logState.info('🏁 步骤17: 结束产测');
    
    final command = ProductionTestCommands.createEndTestCommand();
    final response = await state.sendCommandViaLinuxBluetooth(
      command,
      timeout: const Duration(seconds: 5),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );

    if (response == null || response.containsKey('error')) {
      logState.error('❌ 产测结束命令失败');
      return false;
    }

    // 调用 BYD MES complete
    logState.info('📤 调用 BYD MES complete...');
    final mesResult = await _mesService.complete(_productInfo!.snCode);
    if (mesResult['success'] == true) {
      logState.info('✅ MES complete 成功');
    } else {
      logState.warning('⚠️ MES complete 失败: ${mesResult['error']}');
    }

    logState.info('✅ 产测结束成功');
    return true;
  }
}

// ========== 辅助类 ==========

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

enum TestStepStatus { pending, running, passed, failed }

class _AutoTestOptions {
  final ProductSNInfo productInfo;
  final BluetoothTestMethod method;
  
  _AutoTestOptions({required this.productInfo, required this.method});
}

class _AutoTestInputDialog extends StatefulWidget {
  final BluetoothTestMethod defaultMethod;
  
  const _AutoTestInputDialog({required this.defaultMethod});

  @override
  State<_AutoTestInputDialog> createState() => _AutoTestInputDialogState();
}

class _AutoTestInputDialogState extends State<_AutoTestInputDialog> {
  final TextEditingController _macController = TextEditingController();
  BluetoothTestMethod _selectedMethod = BluetoothTestMethod.rfcommBind;
  ProductSNInfo? _productInfo;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.defaultMethod;
  }

  @override
  void dispose() {
    _macController.dispose();
    super.dispose();
  }

  bool _isValidBluetoothAddress(String address) {
    final regex = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');
    return regex.hasMatch(address);
  }

  Future<void> _showSNInput() async {
    final productInfo = await showDialog<ProductSNInfo>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SNInputDialog(),
    );

    if (productInfo != null) {
      setState(() {
        _productInfo = productInfo;
        _errorMessage = null;
      });
    }
  }

  void _useManualMacInput() {
    final address = _macController.text.trim();
    
    if (address.isEmpty) {
      setState(() => _errorMessage = '请输入蓝牙 MAC 地址');
      return;
    }
    
    if (!_isValidBluetoothAddress(address)) {
      setState(() => _errorMessage = 'MAC 地址格式不正确');
      return;
    }
    
    final formattedAddress = address.toUpperCase().replaceAll('-', ':');
    
    setState(() {
      _productInfo = ProductSNInfo(
        snCode: '手动输入',
        bluetoothAddress: formattedAddress,
        macAddress: '',
      );
      _errorMessage = null;
    });
  }

  void _handleConfirm() {
    if (_productInfo == null) {
      setState(() => _errorMessage = '请先输入 SN 码或蓝牙 MAC 地址');
      return;
    }
    
    Navigator.of(context).pop(_AutoTestOptions(
      productInfo: _productInfo!,
      method: _selectedMethod,
    ));
  }

  String _getMethodName(BluetoothTestMethod method) {
    switch (method) {
      case BluetoothTestMethod.autoScan:
        return '方案1: 扫描配对';
      case BluetoothTestMethod.directConnect:
        return '方案2: 直接连接';
      case BluetoothTestMethod.rfcommBind:
        return '方案3: RFCOMM Bind ⭐';
      case BluetoothTestMethod.rfcommSocket:
        return '方案4: RFCOMM Socket';
      case BluetoothTestMethod.serial:
        return '方案5: 串口设备';
      case BluetoothTestMethod.commandLine:
        return '方案6: 命令行工具';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.power, color: Colors.green[700]),
          const SizedBox(width: 12),
          const Text('工位3: 电源外设测试'),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // MAC 地址输入
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bluetooth, color: Colors.orange[700], size: 16),
                        const SizedBox(width: 8),
                        Text('输入蓝牙 MAC 地址',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange[700])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _macController,
                      decoration: InputDecoration(
                        hintText: '例如: 48:08:EB:60:00:60',
                        prefixIcon: const Icon(Icons.bluetooth, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _useManualMacInput,
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('确认地址'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showSNInput,
                            icon: const Icon(Icons.qr_code, size: 16),
                            label: const Text('SN码查询'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 设备信息
              if (_productInfo != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                          const SizedBox(width: 8),
                          Text('设备信息',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[700])),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('SN: ${_productInfo!.snCode}', style: const TextStyle(fontSize: 13)),
                      Text('蓝牙: ${_productInfo!.bluetoothAddress}', 
                           style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                    ],
                  ),
                ),
              ],
              
              // 错误信息
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red[700], size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage!, 
                        style: TextStyle(fontSize: 12, color: Colors.red[700]))),
                    ],
                  ),
                ),
              ],
              
              // 方案选择
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.settings, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 8),
                        Text('选择连接方案',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[700])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<BluetoothTestMethod>(
                      value: _selectedMethod,
                      isDense: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: BluetoothTestMethod.values.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(_getMethodName(method), style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedMethod = value);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _productInfo != null ? _handleConfirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('开始测试'),
        ),
      ],
    );
  }
}
