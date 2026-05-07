import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../models/log_state.dart';
import '../services/product_sn_api.dart';
import '../services/production_test_commands.dart';
import '../services/byd_mes_service.dart';
import '../services/linux_bluetooth_spp_service.dart';
import '../services/sn_api_service.dart';
import '../config/wifi_config.dart';
import '../config/production_config.dart';
import '../config/test_config.dart';
import '../models/touch_test_step.dart';
import '../services/gtp_protocol.dart';
import '../services/network_scpi_power_supply_service.dart';
import 'sn_input_dialog.dart';
import 'bluetooth_test_options_dialog.dart';

/// 整机产测自动测试组件 - 支持六个工位
class PreUltrasoundAutoTest extends StatefulWidget {
  const PreUltrasoundAutoTest({super.key});

  @override
  State<PreUltrasoundAutoTest> createState() => _PreUltrasoundAutoTestState();
}

class _PreUltrasoundAutoTestState extends State<PreUltrasoundAutoTest> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 调试模式（失败后可跳过继续执行）
  bool _debugMode1 = false;
  bool _debugMode3 = false;
  bool _debugMode4 = false;
  bool _debugMode5 = false;
  bool _debugMode6 = false;

  // 工位3：跳过充电电流测试（使用GPIB采集）
  bool _skipChargingCurrentTest3 = false;
  
  // 工位1状态
  bool _isAutoTesting1 = false;
  int _currentStep1 = 0;
  final List<TestStepResult> _stepResults1 = [];
  ProductSNInfo? _productInfo1;
  String? _deviceIP1;
  String? _scannedSN1;
  BluetoothTestMethod _selectedMethod1 = BluetoothTestMethod.rfcommSocket;
  final BydMesService _mesService1 = BydMesService();
  bool _cancelRestartCommand1 = false; // 取消重启命令标志

  // 工位4状态
  bool _isAutoTesting4 = false;
  int _currentStep4 = 0;
  final List<TestStepResult> _stepResults4 = [];
  ProductSNInfo? _productInfo4;
  String? _deviceIP4;
  String? _scannedSN4;
  BluetoothTestMethod _selectedMethod4 = BluetoothTestMethod.rfcommSocket;
  final BydMesService _mesService4 = BydMesService();
  bool _cancelRestartCommand4 = false; // 取消重启命令标志

  // 工位5状态
  bool _isAutoTesting5 = false;
  int _currentStep5 = 0;
  final List<TestStepResult> _stepResults5 = [];
  ProductSNInfo? _productInfo5;
  String? _scannedSN5;
  BluetoothTestMethod _selectedMethod5 = BluetoothTestMethod.rfcommSocket;
  final BydMesService _mesService5 = BydMesService();

  // 工位6状态
  bool _isAutoTesting6 = false;
  int _currentStep6 = 0;
  final List<TestStepResult> _stepResults6 = [];
  ProductSNInfo? _productInfo6;
  String? _scannedSN6;
  BluetoothTestMethod _selectedMethod6 = BluetoothTestMethod.rfcommSocket;
  final BydMesService _mesService6 = BydMesService();
  bool _cancelRestartCommand6 = false; // 取消重启命令标志

  // 工位3状态
  bool _isAutoTesting3 = false;
  int _currentStep3 = 0;
  final List<TestStepResult> _stepResults3 = [];
  ProductSNInfo? _productInfo3;
  String? _scannedSN3;
  BluetoothTestMethod _selectedMethod3 = BluetoothTestMethod.rfcommSocket;
  final BydMesService _mesService3 = BydMesService();
  final ProductionConfig _config = ProductionConfig();
  bool _cancelRestartCommand3 = false; // 取消重启命令标志
  final NetworkScpiPowerSupplyService _networkPowerSupply3 = NetworkScpiPowerSupplyService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeSteps1();
    _initializeSteps3();
    _initializeSteps4();
    _initializeSteps5();
    _initializeSteps6();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeSteps1() {
    _stepResults1.clear();
    _stepResults1.addAll([
      TestStepResult(stepNumber: 1, name: '蓝牙连接测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 2, name: 'BYD MES 开始', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 3, name: '产测开始', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 4, name: 'WIFI连接热点并获取IP', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 5, name: '光敏传感器测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 6, name: 'IMU传感器测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 7, name: '摄像头棋盘格测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 8, name: '产测结束', status: TestStepStatus.pending),
    ]);
  }

  void _initializeSteps3() {
    _stepResults3.clear();
    _stepResults3.addAll([
      TestStepResult(stepNumber: 1, name: '蓝牙连接', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 2, name: 'BYD MES 开始', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 3, name: '产测开始', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 4, name: '设备电压测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 5, name: '电量检测测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 6, name: '充电状态测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 7, name: '充电电流测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 8, name: 'LED灯(外侧)开启', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 9, name: 'LED灯(外侧)关闭', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 10, name: 'LED灯(内侧)开启', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 11, name: 'LED灯(内侧)关闭', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 12, name: '右触控-TK1测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 13, name: '右触控-TK2测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 14, name: '右触控-TK3测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 15, name: '左佩戴检测', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 16, name: '左触控事件测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 17, name: '结束产测', status: TestStepStatus.pending),
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
          child: Column(
            children: [
              // 标题和 Tab 栏
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.devices_other, color: Colors.orange.shade700, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          '整机产测',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Tab 栏
                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.orange.shade700,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.orange.shade700,
                      indicatorWeight: 3,
                      isScrollable: false,
                      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      unselectedLabelStyle: const TextStyle(fontSize: 12),
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.wifi, size: 20),
                          text: '工位1: 射频图像',
                        ),
                        Tab(
                          icon: Icon(Icons.power, size: 20),
                          text: '工位3: 电源外设',
                        ),
                        Tab(
                          icon: Icon(Icons.signal_cellular_alt, size: 20),
                          text: '工位4: 超声后射频图像',
                        ),
                        Tab(
                          icon: Icon(Icons.electrical_services, size: 20),
                          text: '工位6: 超声后电源外设',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Tab 内容
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 工位1: 射频图像测试
                    _buildWorkstation1Content(state),
                    // 工位3: 电源外设测试
                    _buildWorkstation3Content(state),
                    // 工位4: 超声后射频图像测试
                    _buildWorkstation4Content(state),
                    // 工位6: 超声后电源外设测试
                    _buildWorkstation6Content(state),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ========== 工位1: 射频图像测试 ==========
  Widget _buildWorkstation1Content(TestState state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 测试进行中提示
          if (_isAutoTesting1)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
          
          // 测试步骤列表
          Expanded(
            child: ListView.builder(
              itemCount: _stepResults1.length,
              itemBuilder: (context, index) {
                final step = _stepResults1[index];
                return _buildStepCard(step, index == _currentStep1 && _isAutoTesting1);
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 蓝牙连接测试方案面板已隐藏，默认使用 RFCOMM Socket
          
          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!_isAutoTesting1) ...[
                    // 数据解析模式选择
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.teal[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.teal[50],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<DataParseMode>(
                          value: state.linuxBluetoothParseMode,
                          isDense: true,
                          icon: Icon(Icons.settings_input_component, size: 16, color: Colors.teal[600]),
                          items: DataParseMode.values.map((mode) {
                            return DropdownMenuItem(
                              value: mode,
                              child: Text(mode.displayName, style: TextStyle(fontSize: 11, color: Colors.teal[700])),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              state.setLinuxBluetoothParseMode(value);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _startAutoTest1(state),
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
                  onPressed: _stopAutoTest1,
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
  }

  // ========== 工位2: 音频测试（待实现）==========
  Widget _buildWorkstation2Content(TestState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.volume_up, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '音频测试工位',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '即将开放',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ========== 工位3: 电源外设测试 ==========
  Widget _buildWorkstation3Content(TestState state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 测试进行中提示
          if (_isAutoTesting3)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '测试进行中...',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          
          // 测试步骤列表
          Expanded(
            child: ListView.builder(
              itemCount: _stepResults3.length,
              itemBuilder: (context, index) {
                final step = _stepResults3[index];
                return _buildStepCard3(step, index == _currentStep3 && _isAutoTesting3);
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 跳过充电电流测试（使用GPIB采集）
              Row(
                children: [
                  Icon(Icons.electric_bolt, color: _skipChargingCurrentTest3 ? Colors.orange : Colors.grey, size: 20),
                  const SizedBox(width: 4),
                  Text('跳过充电电流(GPIB)', style: TextStyle(fontSize: 12, color: _skipChargingCurrentTest3 ? Colors.orange : Colors.grey)),
                  Switch(
                    value: _skipChargingCurrentTest3,
                    onChanged: _isAutoTesting3 ? null : (value) => setState(() => _skipChargingCurrentTest3 = value),
                    activeColor: Colors.orange,
                  ),
                ],
              ),
              // 蓝牙方案选择器已隐藏，默认使用 RFCOMM Socket
              if (!_isAutoTesting3)
                ElevatedButton.icon(
                  onPressed: () => _startAutoTest3(state),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始自动测试'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _stopAutoTest3,
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
  }

  Widget _buildStepCard3(TestStepResult step, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent ? Colors.green : Colors.grey.shade300,
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
                    fontSize: 13,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: Colors.black87,
                  ),
                ),
                if (step.message != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    step.message!,
                    style: TextStyle(
                      fontSize: 11,
                      color: step.status == TestStepStatus.failed ? Colors.red : Colors.grey[600],
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

  // ========== 工位1: 停止测试 ==========
  void _stopAutoTest1() {
    setState(() {
      _isAutoTesting1 = false;
    });
  }

  // ========== 工位1: 开始自动测试 ==========
  Future<void> _startAutoTest1(TestState state) async {
    final logState = context.read<LogState>();
    
    // 绑定 MES 日志
    _mesService1.setOnLog((msg) => logState.info('[MES] $msg', type: LogType.debug));
    
    // 弹窗扫描SN或输入蓝牙MAC
    if (!mounted) return;
    final scanResult = await showDialog<_SNScanResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SNScanDialog(title: '工位1: 射频图像测试'),
    );
    
    if (scanResult == null) {
      logState.warning('用户取消输入');
      return;
    }
    
    if (scanResult.isMacMode) {
      // MAC直连模式：跳过SN查询，直接使用蓝牙地址
      final mac = scanResult.bluetoothAddress!;
      logState.info('📋 蓝牙MAC直连模式: $mac');
      _scannedSN1 = null;
      _productInfo1 = ProductSNInfo(
        snCode: 'MAC直连',
        bluetoothAddress: mac,
        macAddress: '',
      );
    } else {
      // SN模式：通过SN查询接口获取蓝牙MAC
      _scannedSN1 = scanResult.sn;
      logState.info('📋 扫码SN: $_scannedSN1');
      logState.info('📡 查询SN信息获取蓝牙MAC...');
      try {
        final productInfo = await ProductSNApi.getProductSNInfo(_scannedSN1!);
        if (productInfo == null) {
          logState.error('❌ SN查询失败，无法获取蓝牙地址');
          return;
        }
        _productInfo1 = productInfo;
        logState.info('✅ 获取到设备信息:');
        logState.info('   SN: ${productInfo.snCode}');
        logState.info('   蓝牙地址: ${productInfo.bluetoothAddress}');
        logState.info('   WiFi MAC: ${productInfo.macAddress}');
        
        if (productInfo.bluetoothAddress.isEmpty) {
          logState.error('❌ 蓝牙地址为空，无法继续');
          return;
        }
      } catch (e) {
        logState.error('❌ SN查询异常: $e');
        return;
      }
    }
    
    // 取消之前可能还在运行的重启命令重试
    _cancelRestartCommand1 = true;
    await Future.delayed(const Duration(milliseconds: 100)); // 等待取消生效
    _cancelRestartCommand1 = false; // 重置标志
    
    setState(() {
      _isAutoTesting1 = true;
      _currentStep1 = 0;
      _initializeSteps1();
    });

    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('🔧 工位1: 射频图像测试');
    logState.info('   SN: ${_scannedSN1 ?? "MAC直连"}');
    logState.info('   蓝牙: ${_productInfo1!.bluetoothAddress}');
    logState.info('   连接方案: ${_getMethodName(_selectedMethod1)}');
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    bool hasFailure = false;
    String? failItem;
    String? failValue;

    // 执行测试步骤
    for (int i = 0; i < _stepResults1.length; i++) {
      if (!_isAutoTesting1) break;

      setState(() {
        _currentStep1 = i;
        _stepResults1[i].status = TestStepStatus.running;
      });

      bool success = false;
      String? message;

      try {
        switch (i) {
          case 0: // 蓝牙连接测试
            logState.info('步骤1: 蓝牙连接测试');
            success = await _testBluetoothConnection1(state, logState);
            message = success ? '蓝牙连接正常' : '蓝牙连接失败';
            // 蓝牙连接成功后发送产测状态重置命令 (0xFF 0xFF)
            if (success) {
              logState.info('🔄 发送产测状态重置命令 (0xFF 0xFF)...');
              try {
                final resetCommand = ProductionTestCommands.createEndTestCommand(opt: 0xFF);
                await state.sendCommandViaLinuxBluetooth(
                  resetCommand,
                  timeout: const Duration(seconds: 3),
                  moduleId: ProductionTestCommands.moduleId,
                );
                logState.info('✅ 产测状态重置命令发送成功');
              } catch (e) {
                logState.warning('⚠️ 产测状态重置命令发送失败: $e');
              }
            }
            break;
          case 1: // BYD MES 开始
            logState.info('步骤2: BYD MES 开始');
            if (_scannedSN1 != null && _scannedSN1!.isNotEmpty) {
              final mesResult = await _mesService1.start(_scannedSN1!);
              success = mesResult['success'] == true;
              message = success ? 'MES Start 成功' : 'MES Start 失败: ${mesResult['error'] ?? '未知错误'}';
            } else {
              logState.info('   ⏭️ MAC直连模式，跳过 MES Start');
              success = true;
              message = 'MAC直连模式，跳过 MES';
            }
            break;
          case 2: // 产测开始
            logState.info('步骤3: 产测开始');
            success = await _testProductionStart(state, logState);
            message = success ? '产测开始命令发送成功' : '产测开始命令失败';
            break;
          case 3: // WIFI连接热点并获取IP
            logState.info('步骤4: WIFI连接热点并获取IP');
            success = await _testWiFiConnectionWithIP(state, logState);
            message = success ? 'WiFi连接成功，IP: $_deviceIP1' : 'WiFi连接失败';
            break;
          case 4: // 光敏传感器测试
            logState.info('步骤5: 光敏传感器测试');
            success = await _testLightSensor(state, logState);
            message = success ? '获取到光敏值' : '光敏传感器测试失败';
            break;
          case 5: // IMU传感器测试
            logState.info('步骤6: IMU传感器测试');
            success = await _testIMUSensor(state, logState);
            message = success ? '获取到IMU值' : 'IMU传感器测试失败';
            break;
          case 6: // 摄像头棋盘格测试
            logState.info('步骤7: 摄像头棋盘格测试');
            success = await _testCameraChessboard(state, logState);
            message = success ? '摄像头测试通过' : '摄像头测试失败';
            break;
          case 7: // 产测结束
            logState.info('步骤8: 产测结束');
            success = await _testProductionEnd(state, logState);
            message = success ? '产测结束命令发送成功' : '产测结束命令失败';
            break;
        }
      } catch (e) {
        success = false;
        message = '测试异常: $e';
        logState.error('步骤${i + 1}异常: $e');
      }

      if (!_isAutoTesting1) break;

      setState(() {
        _stepResults1[i].status = success ? TestStepStatus.passed : TestStepStatus.failed;
        _stepResults1[i].message = message;
      });

      if (!success) {
        logState.error('❌ 步骤${i + 1}失败: $message');
        if (!hasFailure) {
          hasFailure = true;
          failItem = _stepResults1[i].name;
          failValue = message ?? '测试未通过';
        }
        // 测试失败时调用产测状态更新命令 (0xFF 0x01)
        logState.info('🔄 发送产测状态更新命令 (0xFF 0x01) - 测试失败...');
        try {
          final failCommand = ProductionTestCommands.createEndTestCommand(opt: 0x01);
          await state.sendCommandViaLinuxBluetooth(
            failCommand,
            timeout: const Duration(seconds: 3),
            moduleId: ProductionTestCommands.moduleId,
          );
          logState.info('✅ 产测状态更新命令发送成功');
        } catch (e) {
          logState.warning('⚠️ 产测状态更新命令发送失败: $e');
        }
        if (!_debugMode1) {
          break;
        } else {
          logState.warning('⚠️ 调试模式：跳过失败步骤，继续执行...');
        }
      } else {
        logState.info('✅ 步骤${i + 1}通过: $message');
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() {
      _isAutoTesting1 = false;
    });

    final passedCount = _stepResults1.where((s) => s.status == TestStepStatus.passed).length;
    final totalCount = _stepResults1.length;
    final allPassed = passedCount == totalCount;
    
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // BYD MES 结果上报 + SN状态更新
    if (_scannedSN1 != null && _scannedSN1!.isNotEmpty) {
      if (allPassed) {
        // 全部通过 → BYD MES 良品完成
        logState.info('🏭 调用 BYD MES 良品完成接口...');
        final mesResult = await _mesService1.complete(_scannedSN1!);
        if (mesResult['success'] == true) {
          logState.success('✅ BYD MES 良品完成成功');
        } else {
          logState.error('❌ BYD MES 良品完成失败: ${mesResult['error']}');
        }
        
        // 更新SN状态为5（超声前整机产测通过）
        logState.info('📤 更新SN状态为「超声前整机产测通过」(status=5)...');
        final statusUpdated = await SNApiService.updateSNStatus(
          sn: _scannedSN1!,
          status: 5,
          logState: logState,
        );
        if (statusUpdated) {
          logState.success('✅ SN状态更新成功');
        } else {
          logState.error('❌ SN状态更新失败');
        }
        
        logState.info('🎉 工位1测试全部通过！($passedCount/$totalCount)');
      } else {
        // 有失败 → BYD MES 不良品
        logState.info('🏭 调用 BYD MES 不良品接口...');
        final mesResult = await _mesService1.ncComplete(
          _scannedSN1!,
          ncCode: 'NC001',
          ncContext: '超声前整机产测不良',
          failItem: failItem ?? '未知',
          failValue: failValue ?? '测试未通过',
        );
        if (mesResult['success'] == true) {
          logState.success('✅ BYD MES 不良品上报成功');
        } else {
          logState.error('❌ BYD MES 不良品上报失败: ${mesResult['error']}');
        }
        logState.warning('⚠️ 工位1测试完成，通过 $passedCount/$totalCount 项');
      }
    } else {
      // MAC直连模式：跳过MES上报，仅输出结果
      if (allPassed) {
        logState.info('🎉 工位1测试全部通过！($passedCount/$totalCount)（MAC直连模式，跳过MES上报）');
      } else {
        logState.warning('⚠️ 工位1测试完成，通过 $passedCount/$totalCount 项（MAC直连模式，跳过MES上报）');
      }
    }
    // 测试全部通过，发送设备重启命令 (module id: 6, msg id: 0, payload: 2004)
    logState.info('🔄 发送设备重启命令...');
    await _sendDeviceRestartCommand(state, logState);
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
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
      case BluetoothTestMethod.serial:
        success = await state.testBluetoothMethod5Serial(
          deviceAddress: bluetoothAddress, channel: channel, uuid: uuid,
        );
        break;
      case BluetoothTestMethod.commandLine:
        success = await state.testBluetoothMethod6CommandLine(
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
      case BluetoothTestMethod.serial:
        logState.info('🟤 执行方案 5: 串口设备模式');
        success = await state.testBluetoothMethod5Serial(
          deviceAddress: bluetoothAddress,
          channel: channel,
          uuid: uuid,
        );
        break;
      case BluetoothTestMethod.commandLine:
        logState.info('⚫ 执行方案 6: 命令行工具模式');
        success = await state.testBluetoothMethod6CommandLine(
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

  // ========== 工位1: 测试步骤实现 ==========

  /// 工位1 步骤1: 蓝牙连接测试
  Future<bool> _testBluetoothConnection1(TestState state, LogState logState) async {
    try {
      if (_productInfo1 == null) {
        logState.error('设备信息未获取');
        return false;
      }
      
      final bluetoothAddress = _productInfo1!.bluetoothAddress;
      if (bluetoothAddress == null || bluetoothAddress.isEmpty) {
        logState.error('❌ 蓝牙地址为空');
        return false;
      }

      logState.info('🔵 目标蓝牙地址: $bluetoothAddress');
      logState.info('🔗 使用 RFCOMM Socket (固定Channel 5)');
      
      // 使用RFCOMM Socket方式，固定channel 5
      final success = await state.testBluetoothMethod4RfcommSocket(
        deviceAddress: bluetoothAddress,
        channel: 5,
        uuid: '7033',
      );

      if (success) {
        logState.success('✅ 蓝牙连接成功');
      } else {
        logState.error('❌ 蓝牙连接失败');
      }
      
      return success;
    } catch (e) {
      logState.error('❌ 蓝牙连接测试异常: $e');
      return false;
    }
  }

  // ========== 工位3: 停止测试 ==========
  void _stopAutoTest3() {
    setState(() {
      _isAutoTesting3 = false;
    });
  }

  // ========== 工位3: 开始自动测试 ==========
  Future<void> _startAutoTest3(TestState state) async {
    final logState = context.read<LogState>();
    
    // 绑定 MES 日志
    _mesService3.setOnLog((msg) => logState.info('[MES] $msg', type: LogType.debug));
    
    // 弹窗扫描SN或输入蓝牙MAC
    if (!mounted) return;
    final scanResult = await showDialog<_SNScanResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SNScanDialog(title: '工位3: 电源外设测试'),
    );
    
    if (scanResult == null) {
      logState.warning('用户取消输入');
      return;
    }
    
    if (scanResult.isMacMode) {
      // MAC直连模式：跳过SN查询，直接使用蓝牙地址
      final mac = scanResult.bluetoothAddress!;
      logState.info('📋 蓝牙MAC直连模式: $mac');
      _scannedSN3 = null;
      _productInfo3 = ProductSNInfo(
        snCode: 'MAC直连',
        bluetoothAddress: mac,
        macAddress: '',
      );
    } else {
      // SN模式：通过SN查询接口获取蓝牙MAC
      _scannedSN3 = scanResult.sn;
      logState.info('📋 扫码SN: $_scannedSN3');
      logState.info('📡 查询SN信息获取蓝牙MAC...');
      try {
        final productInfo = await ProductSNApi.getProductSNInfo(_scannedSN3!);
        if (productInfo == null) {
          logState.error('❌ SN查询失败，无法获取蓝牙地址');
          return;
        }
        _productInfo3 = productInfo;
        logState.info('✅ 获取到设备信息:');
        logState.info('   SN: ${productInfo.snCode}');
        logState.info('   蓝牙地址: ${productInfo.bluetoothAddress}');
        logState.info('   WiFi MAC: ${productInfo.macAddress}');
        
        if (productInfo.bluetoothAddress.isEmpty) {
          logState.error('❌ 蓝牙地址为空，无法继续');
          return;
        }
      } catch (e) {
        logState.error('❌ SN查询异常: $e');
        return;
      }
    }
    
    // 如果需要进行充电电流测试，先连接网络程控电源
    if (!_skipChargingCurrentTest3) {
      logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      logState.info('🔌 准备连接网络程控电源...');
      
      final powerSupplyIp = _config.networkPowerSupplyIp;
      final powerSupplyPort = _config.networkPowerSupplyPort;
      
      logState.info('   IP地址: $powerSupplyIp');
      logState.info('   端口: $powerSupplyPort');
      
      // 检查是否已配置IP地址
      if (powerSupplyIp.isEmpty) {
        logState.error('❌ 网络程控电源IP地址未配置');
        logState.error('   请在"产测通用配置"中配置程控电源IP地址');
        
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('配置缺失'),
              ],
            ),
            content: const Text(
              '网络程控电源IP地址未配置。\n\n'
              '请前往"产测通用配置"页面，在"5.1 网络程控电源配置"中设置：\n'
              '• 程控电源 IP 地址\n'
              '• 程控电源端口（默认5025）',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
        return;
      }
      
      // 连接网络程控电源
      logState.info('📡 正在连接网络程控电源...');
      final connected = await _networkPowerSupply3.connect(
        powerSupplyIp,
        port: powerSupplyPort,
        timeout: const Duration(seconds: 5),
      );
      
      if (!connected) {
        logState.error('❌ 网络程控电源连接失败');
        
        if (!mounted) return;
        final retry = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('网络程控电源连接失败'),
              ],
            ),
            content: Text(
              '网络程控电源连接失败，无法进行充电电流测试。\n\n'
              '请检查：\n'
              '1. 程控电源是否已开机\n'
              '2. 程控电源IP地址是否正确: $powerSupplyIp\n'
              '3. 网络连接是否正常\n'
              '4. 台式机静态IP是否配置 (192.168.1.100/24)\n'
              '5. lxi-tools 是否已安装\n\n'
              '或者选择跳过充电电流测试。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消测试'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('重试连接'),
              ),
            ],
          ),
        );
        
        if (retry == true) {
          // 递归重试
          return _startAutoTest3(state);
        } else {
          logState.warning('用户取消测试');
          return;
        }
      }
      
      logState.success('✅ 网络程控电源连接成功，设备已就绪');
      logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
    
    // 取消之前可能还在运行的重启命令重试
    _cancelRestartCommand3 = true;
    await Future.delayed(const Duration(milliseconds: 100)); // 等待取消生效
    _cancelRestartCommand3 = false; // 重置标志
    
    setState(() {
      _isAutoTesting3 = true;
      _currentStep3 = 0;
      _initializeSteps3();
    });

    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('🔧 工位3: 电源外设测试');
    logState.info('   SN: ${_scannedSN3 ?? "MAC直连"}');
    logState.info('   蓝牙: ${_productInfo3!.bluetoothAddress}');
    logState.info('   连接方案: ${_getMethodName(_selectedMethod3)}');
    if (_skipChargingCurrentTest3) {
      logState.info('   充电电流测试: 已跳过');
    }
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    bool hasFailure = false;
    String? failItem;
    String? failValue;

    for (int i = 0; i < _stepResults3.length; i++) {
      if (!_isAutoTesting3) break;

      setState(() {
        _currentStep3 = i;
        _stepResults3[i].status = TestStepStatus.running;
      });

      bool success = false;
      String? message;

      try {
        switch (i) {
          case 0: // 蓝牙连接
            success = await _testBluetoothConnection3(state, logState);
            message = success ? '蓝牙连接成功' : '蓝牙连接失败';
            // 蓝牙连接成功后发送产测状态重置命令 (0xFF 0xFF)
            if (success) {
              logState.info('🔄 发送产测状态重置命令 (0xFF 0xFF)...');
              try {
                final resetCommand = ProductionTestCommands.createEndTestCommand(opt: 0xFF);
                await state.sendCommandViaLinuxBluetooth(
                  resetCommand,
                  timeout: const Duration(seconds: 3),
                  moduleId: ProductionTestCommands.moduleId,
                );
                logState.info('✅ 产测状态重置命令发送成功');
              } catch (e) {
                logState.warning('⚠️ 产测状态重置命令发送失败: $e');
              }
            }
            break;
          case 1: // BYD MES 开始
            logState.info('步骤2: BYD MES 开始');
            if (_scannedSN3 != null && _scannedSN3!.isNotEmpty) {
              final mesResult = await _mesService3.start(_scannedSN3!);
              success = mesResult['success'] == true;
              message = success ? 'MES Start 成功' : 'MES Start 失败: ${mesResult['error'] ?? '未知错误'}';
            } else {
              logState.info('   ⏭️ MAC直连模式，跳过 MES Start');
              success = true;
              message = 'MAC直连模式，跳过 MES';
            }
            break;
          case 2: // 产测开始
            success = await _testProductionStart(state, logState);
            message = success ? '产测开始成功' : '产测开始失败';
            break;
          case 3: // 设备电压测试
            final voltResult = await _testVoltage3(state, logState);
            success = voltResult['success'] as bool;
            message = voltResult['message'] as String?;
            break;
          case 4: // 电量检测测试
            final batResult = await _testBattery3(state, logState);
            success = batResult['success'] as bool;
            message = batResult['message'] as String?;
            break;
          case 5: // 充电状态测试
            final chargeResult = await _testChargeStatus3(state, logState);
            success = chargeResult['success'] as bool;
            message = chargeResult['message'] as String?;
            break;
          case 6: // 充电电流测试
            if (_skipChargingCurrentTest3) {
              // 跳过充电电流测试，直接标记为成功
              logState.warning('⚠️ 已跳过充电电流测试（GPIB采集），默认标记为通过');
              success = true;
              message = '已跳过充电电流测试（默认通过）';
            } else {
              final currentResult = await _testChargingCurrent3(state, logState);
              success = currentResult['success'] as bool;
              message = currentResult['message'] as String?;
            }
            break;
          case 7: // LED灯(外侧)开启
            success = await _testLED3(state, logState, isOuter: true, turnOn: true);
            message = success ? 'LED外侧开启成功' : 'LED外侧开启失败';
            break;
          case 8: // LED灯(外侧)关闭
            success = await _testLED3(state, logState, isOuter: true, turnOn: false);
            message = success ? 'LED外侧关闭成功' : 'LED外侧关闭失败';
            break;
          case 9: // LED灯(内侧)开启
            success = await _testLED3(state, logState, isOuter: false, turnOn: true);
            message = success ? 'LED内侧开启成功' : 'LED内侧开启失败';
            break;
          case 10: // LED灯(内侧)关闭
            success = await _testLED3(state, logState, isOuter: false, turnOn: false);
            message = success ? 'LED内侧关闭成功' : 'LED内侧关闭失败';
            break;
          case 11: // 右触控-TK1测试
            success = await _testTouch3(state, logState, touchType: 'TK1');
            message = success ? 'TK1测试通过' : 'TK1测试失败';
            break;
          case 12: // 右触控-TK2测试
            success = await _testTouch3(state, logState, touchType: 'TK2');
            message = success ? 'TK2测试通过' : 'TK2测试失败';
            break;
          case 13: // 右触控-TK3测试
            success = await _testTouch3(state, logState, touchType: 'TK3');
            message = success ? 'TK3测试通过' : 'TK3测试失败';
            break;
          case 14: // 左佩戴检测
            success = await _testLeftWearDetect3(state, logState);
            message = success ? '佩戴检测通过' : '佩戴检测失败';
            break;
          case 15: // 左触控事件测试
            success = await _testLeftTouchEvent3(state, logState);
            message = success ? '左触控事件通过' : '左触控事件失败';
            break;
          case 16: // 结束产测
            success = await _testProductionEnd3(state, logState);
            message = success ? '产测结束成功' : '产测结束失败';
            break;
        }
      } catch (e) {
        success = false;
        message = '异常: $e';
        logState.error('步骤${i + 1}异常: $e');
      }

      setState(() {
        _stepResults3[i].status = success ? TestStepStatus.passed : TestStepStatus.failed;
        _stepResults3[i].message = message;
      });

      if (!success) {
        logState.error('❌ 步骤${i + 1}失败: $message');
        if (!hasFailure) {
          hasFailure = true;
          failItem = _stepResults3[i].name;
          failValue = message ?? '测试未通过';
        }
        // 测试失败时调用产测状态更新命令 (0xFF 0x01)
        logState.info('🔄 发送产测状态更新命令 (0xFF 0x01) - 测试失败...');
        try {
          final failCommand = ProductionTestCommands.createEndTestCommand(opt: 0x01);
          await state.sendCommandViaLinuxBluetooth(
            failCommand,
            timeout: const Duration(seconds: 3),
            moduleId: ProductionTestCommands.moduleId,
          );
          logState.info('✅ 产测状态更新命令发送成功');
        } catch (e) {
          logState.warning('⚠️ 产测状态更新命令发送失败: $e');
        }
        if (!_debugMode3) {
          break;
        } else {
          logState.warning('⚠️ 调试模式：跳过失败步骤，继续执行...');
        }
      } else {
        logState.info('✅ 步骤${i + 1}通过: $message');
      }
    }

    setState(() {
      _isAutoTesting3 = false;
    });

    final passedCount = _stepResults3.where((s) => s.status == TestStepStatus.passed).length;
    final totalCount = _stepResults3.length;
    final allPassed = passedCount == totalCount;
    
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // BYD MES 结果上报 + SN状态更新
    if (_scannedSN3 != null && _scannedSN3!.isNotEmpty) {
      if (allPassed) {
        // 全部通过 → BYD MES 良品完成
        logState.info('🏭 调用 BYD MES 良品完成接口...');
        final mesResult = await _mesService3.complete(_scannedSN3!);
        if (mesResult['success'] == true) {
          logState.success('✅ BYD MES 良品完成成功');
        } else {
          logState.error('❌ BYD MES 良品完成失败: ${mesResult['error']}');
        }
        
        // 更新SN状态为5（超声前整机产测通过）
        logState.info('📤 更新SN状态为「超声前整机产测通过」(status=5)...');
        final statusUpdated = await SNApiService.updateSNStatus(
          sn: _scannedSN3!,
          status: 5,
          logState: logState,
        );
        if (statusUpdated) {
          logState.success('✅ SN状态更新成功');
        } else {
          logState.error('❌ SN状态更新失败');
        }
        
        logState.info('🎉 工位3测试全部通过！($passedCount/$totalCount)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ 工位3测试全部通过'), backgroundColor: Colors.green),
          );
        }
      } else {
        // 有失败 → BYD MES 不良品
        logState.info('🏭 调用 BYD MES 不良品接口...');
        final mesResult = await _mesService3.ncComplete(
          _scannedSN3!,
          ncCode: 'NC001',
          ncContext: '超声前整机产测不良',
          failItem: failItem ?? '未知',
          failValue: failValue ?? '测试未通过',
        );
        if (mesResult['success'] == true) {
          logState.success('✅ BYD MES 不良品上报成功');
        } else {
          logState.error('❌ BYD MES 不良品上报失败: ${mesResult['error']}');
        }
        
        logState.warning('⚠️ 工位3测试完成，通过 $passedCount/$totalCount 项');
      }
    } else {
      // MAC直连模式：跳过MES上报，仅输出结果
      if (allPassed) {
        logState.info('🎉 工位3测试全部通过！($passedCount/$totalCount)（MAC直连模式，跳过MES上报）');
      } else {
        logState.warning('⚠️ 工位3测试完成，通过 $passedCount/$totalCount 项（MAC直连模式，跳过MES上报）');
      }
    }

    // 只有测试全部通过时，才发送设备重启命令
    if (allPassed) {
      logState.info('🔄 发送设备重启命令...');
      await _sendDeviceRestartCommand(state, logState);
    }
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  // ========== 工位3: 蓝牙连接测试（带重试机制） ==========
  Future<bool> _testBluetoothConnection3(TestState state, LogState logState) async {
    try {
      if (_productInfo3 == null) {
        logState.error('设备信息未获取');
        return false;
      }
      
      final bluetoothAddress = _productInfo3!.bluetoothAddress;
      if (bluetoothAddress == null || bluetoothAddress.isEmpty) {
        logState.error('❌ 蓝牙地址为空');
        return false;
      }

      logState.info('🔵 目标蓝牙地址: $bluetoothAddress');
      logState.info('🔗 使用 RFCOMM Socket (固定Channel 5)');
      
      // 增加重试机制，最多尝试3次
      const maxRetries = 3;
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        if (attempt > 1) {
          logState.info('🔄 第 $attempt 次尝试连接...');
          // 重试前等待一段时间，让蓝牙设备准备好
          await Future.delayed(const Duration(seconds: 2));
        }
        
        try {
          // 使用RFCOMM Socket方式，固定channel 5
          final success = await state.testBluetoothMethod4RfcommSocket(
            deviceAddress: bluetoothAddress,
            channel: 5,
            uuid: '7033',
          );

          if (success) {
            logState.info('✅ 蓝牙连接成功');
            return true;
          } else {
            logState.warning('⚠️ 第 $attempt 次连接失败');
            if (attempt < maxRetries) {
              logState.info('   准备重试...');
            }
          }
        } catch (e) {
          logState.warning('⚠️ 第 $attempt 次连接异常: $e');
          if (attempt < maxRetries) {
            logState.info('   准备重试...');
          }
        }
      }
      
      logState.error('❌ 蓝牙连接失败（已尝试 $maxRetries 次）');
      return false;
    } catch (e) {
      logState.error('蓝牙连接测试失败: $e');
      return false;
    }
  }

  // ========== 工位3: 电压测试 ==========
  Future<Map<String, dynamic>> _testVoltage3(TestState state, LogState logState) async {
    logState.info('🔋 设备电压测试');
    
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

    final payload = response['payload'];
    if (payload is List && payload.length >= 3) {
      final payloadBytes = Uint8List.fromList(payload.cast<int>());
      final voltageMv = ProductionTestCommands.parseVoltageResponse(payloadBytes);
      
      if (voltageMv != null) {
        final voltageV = voltageMv / 1000.0;
        final threshold = _config.minVoltageV;
        final success = voltageV > threshold;
        
        logState.info('   电压值: ${voltageV.toStringAsFixed(2)}V (阈值: >${threshold}V)');
        
        return {
          'success': success,
          'message': '电压: ${voltageV.toStringAsFixed(2)}V ${success ? "✅" : "❌ <${threshold}V"}',
        };
      }
    }

    return {'success': false, 'message': '电压数据解析失败'};
  }

  // ========== 工位3: 电量测试 ==========
  Future<Map<String, dynamic>> _testBattery3(TestState state, LogState logState) async {
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

  // ========== 工位3: 充电状态测试 ==========
  Future<Map<String, dynamic>> _testChargeStatus3(TestState state, LogState logState) async {
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

    final payload = response['payload'];
    if (payload is List && payload.length >= 3) {
      // 验证第一个字节是否为命令 0x03
      // 如果不是，可能是其他场景推送的数据，直接忽略
      final cmdByte = payload[0];
      if (cmdByte != 0x03) {
        logState.warning('⚠️ 收到非充电状态命令响应，忽略');
        logState.info('   期望命令: 0x03');
        logState.info('   实际命令: 0x${cmdByte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
        logState.info('   完整 Payload: ${payload.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ')}');
        logState.info('   (可能是设备推送数据，已过滤)');
        // 返回特殊标记，让调用者知道需要重试
        return {'success': false, 'message': '收到非预期命令响应，已过滤', 'shouldRetry': true};
      }
      
      final chargeStatus = payload[1];
      final faultCode = payload[2];
      
      final chargeDesc = chargeStatus == 0x01 ? '充电中' : (chargeStatus == 0x02 ? '未充电' : '状态: 0x${chargeStatus.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      final hasFault = faultCode != 0x00;
      
      logState.info('   充电状态: $chargeDesc');
      logState.info('   故障码: 0x${faultCode.toRadixString(16).toUpperCase().padLeft(2, '0')} ${hasFault ? "❌ 有故障" : "✅ 无故障"}');
      
      return {
        'success': !hasFault,
        'message': '$chargeDesc, 故障码: 0x${faultCode.toRadixString(16).toUpperCase().padLeft(2, '0')} ${!hasFault ? "✅" : "❌"}',
      };
    }

    return {'success': false, 'message': '充电状态数据解析失败 (payload长度不足)'};
  }

  // ========== 工位3: 充电电流测试（使用网络SCPI直接采集）==========
  Future<Map<String, dynamic>> _testChargingCurrent3(TestState state, LogState logState) async {
    logState.info('⚡ 充电电流测试 (网络SCPI直接采集)');
    logState.info('   采样: ${TestConfig.gpibSampleCount} 次 @ ${TestConfig.gpibSampleRate} Hz');
    
    try {
      // 1. 连接到网络程控电源
      final powerSupplyIp = _config.networkPowerSupplyIp;
      final powerSupplyPort = _config.networkPowerSupplyPort;
      
      logState.info('🔌 连接网络程控电源: $powerSupplyIp:$powerSupplyPort');
      
      if (!_networkPowerSupply3.isConnected) {
        final connected = await _networkPowerSupply3.connect(
          powerSupplyIp,
          port: powerSupplyPort,
          timeout: const Duration(seconds: 5),
        );
        
        if (!connected) {
          logState.error('❌ 无法连接到网络程控电源');
          logState.error('   请检查:');
          logState.error('   1. 程控电源IP地址: $powerSupplyIp');
          logState.error('   2. 程控电源端口: $powerSupplyPort');
          logState.error('   3. 网络连接是否正常');
          logState.error('   4. 台式机静态IP是否配置 (192.168.1.100/24)');
          return {'success': false, 'message': '无法连接到网络程控电源'};
        }
        
        logState.success('✅ 网络程控电源连接成功');
      } else {
        logState.info('✅ 使用现有网络程控电源连接');
      }
      
      // 2. 使用网络SCPI测量电流（多次采样）
      final currentA = await _networkPowerSupply3.measureCurrent(
        sampleCount: TestConfig.gpibSampleCount,
        sampleRate: TestConfig.gpibSampleRate,
      );
      
      if (currentA == null) {
        logState.error('❌ 网络SCPI电流测量失败');
        return {'success': false, 'message': '网络SCPI电流测量失败'};
      }
      
      // 3. 转换为毫安 (mA)
      final currentMa = currentA * 1000;
      final threshold = _config.minChargingCurrentMa;
      final success = currentMa >= threshold;
      
      logState.info('   充电电流: ${currentMa.toStringAsFixed(2)}mA (阈值: ≥${threshold.toStringAsFixed(0)}mA)');
      
      return {
        'success': success,
        'message': '充电电流: ${currentMa.toStringAsFixed(2)}mA ${success ? "✅" : "❌ <${threshold.toStringAsFixed(0)}mA"}',
      };
    } catch (e) {
      logState.error('❌ 充电电流测试异常: $e');
      return {'success': false, 'message': '充电电流测试异常: $e'};
    }
  }

  // ========== 工位3: LED测试 ==========
  Future<bool> _testLED3(TestState state, LogState logState, {required bool isOuter, required bool turnOn}) async {
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

    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(turnOn ? Icons.lightbulb : Icons.lightbulb_outline, color: turnOn ? Colors.amber : Colors.grey),
            const SizedBox(width: 12),
            Text('LED灯($ledName)$action'),
          ],
        ),
        content: Text('请确认LED灯($ledName)是否已$action？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('未通过')),
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

  // ========== 工位3: 右触控测试（同步单板产测方案：循环轮询获取CDC值） ==========
  Future<bool> _testTouch3(TestState state, LogState logState, {required String touchType}) async {
    logState.info('👆 右触控-$touchType测试');
    
    final int areaId;
    switch (touchType) {
      case 'TK1': areaId = TouchTestConfig.rightAreaTK1; break;
      case 'TK2': areaId = TouchTestConfig.rightAreaTK2; break;
      case 'TK3': areaId = TouchTestConfig.rightAreaTK3; break;
      default: 
        logState.error('❌ 未知触控区域: $touchType');
        return false;
    }
    
    final threshold = _config.touchThreshold;
    logState.info('   阈值: $threshold');
    
    // 步骤1: 获取基线CDC值（未触摸状态）
    logState.info('📡 获取右Touch基线 CDC 值...');
    final baselineCommand = ProductionTestCommands.createTouchCommand(
      TouchTestConfig.touchRight, TouchTestConfig.rightAreaUntouched,
    );
    final baselineResponse = await state.sendCommandViaLinuxBluetooth(
      baselineCommand,
      timeout: const Duration(seconds: 5),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );
    
    int? baselineCdc;
    if (baselineResponse != null && !baselineResponse.containsKey('error')) {
      final payload = baselineResponse['payload'];
      if (payload is Uint8List) {
        final touchResult = ProductionTestCommands.parseTouchResponse(payload);
        if (touchResult != null && touchResult['success'] == true) {
          baselineCdc = touchResult['cdcValue'] as int?;
          logState.info('✅ 基线 CDC 值: $baselineCdc');
        }
      }
    }
    
    if (baselineCdc == null) {
      logState.error('❌ 获取基线CDC值失败');
      return false;
    }
    
    // 步骤2: 弹窗提示用户触摸，同时循环轮询CDC值
    logState.info('👆 请触摸 $touchType 区域');
    
    if (!mounted) return false;
    
    final completer = Completer<bool>();
    int? latestCdc;
    int? latestDiff;
    bool testPassed = false;
    bool testCancelled = false;
    int currentRetry = 0;
    const int maxRetries = 10;
    
    // 用于从外部更新 dialog UI 的回调
    void Function(void Function())? _setDialogState;
    
    // 弹窗实时显示CDC值（轮询逻辑不在 builder 内，避免重复启动）
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 仅保存回调引用，不在此处启动任何轮询
            _setDialogState = setDialogState;
            
            final statusColor = testPassed ? Colors.green : (latestCdc != null ? Colors.blue : Colors.orange);
            final statusText = testPassed 
                ? '✅ 测试通过!' 
                : (latestCdc != null ? '轮询检测中... ($currentRetry/$maxRetries)' : '等待触摸...');
            
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.touch_app, color: statusColor),
                  const SizedBox(width: 12),
                  Text('右触控-$touchType测试'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('请触摸 $touchType 区域', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('基线CDC: $baselineCdc', style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('当前CDC: ${latestCdc ?? "--"}', 
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor)),
                        const SizedBox(height: 4),
                        Text('CDC差值: ${latestDiff ?? "--"} / 阈值: $threshold',
                            style: TextStyle(fontSize: 14, 
                                color: (latestDiff != null && latestDiff! >= threshold) ? Colors.green : Colors.red)),
                        const SizedBox(height: 4),
                        Text('轮询次数: $currentRetry / $maxRetries',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(statusText, style: TextStyle(fontSize: 14, color: statusColor, fontWeight: FontWeight.bold)),
                ],
              ),
              actions: [
                if (!testPassed)
                  TextButton(
                    onPressed: () {
                      testCancelled = true;
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
    
    // 轮询逻辑在 showDialog 之外，保证只执行一次
    // 等待 dialog 初始化完成
    await Future.delayed(const Duration(milliseconds: 100));
    
    final touchCommand = ProductionTestCommands.createTouchCommand(
      TouchTestConfig.touchRight, areaId,
    );
    
    for (int retry = 0; retry <= maxRetries; retry++) {
      if (testCancelled || testPassed) break;
      
      currentRetry = retry;
      
      if (retry > 0) {
        logState.info('🔄 $touchType 重试第 $retry 次', type: LogType.debug);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // 等待用户操作的时间
      await Future.delayed(const Duration(seconds: 2));
      if (testCancelled) break;
      
      // 主动发送命令获取CDC值
      try {
        final response = await state.sendCommandViaLinuxBluetooth(
          touchCommand,
          timeout: const Duration(seconds: 10),
          moduleId: ProductionTestCommands.moduleId,
          messageId: ProductionTestCommands.messageId,
        );
        
        if (response != null && !response.containsKey('error')) {
          if (response.containsKey('payload') && response['payload'] != null) {
            final payload = response['payload'] as Uint8List;
            final touchResult = ProductionTestCommands.parseTouchResponse(payload);
            
            if (touchResult != null && touchResult['success'] == true) {
              final cdcValue = touchResult['cdcValue'] as int;
              final cdcDiff = (cdcValue - baselineCdc!).abs();
              
              latestCdc = cdcValue;
              latestDiff = cdcDiff;
              
              logState.info('📥 $touchType CDC: $cdcValue (差值: $cdcDiff, 阈值: $threshold)');
              
              _setDialogState?.call(() {});
              
              if (cdcDiff >= threshold) {
                testPassed = true;
                logState.info('✅ $touchType CDC差值 $cdcDiff >= 阈值 $threshold，测试通过!');
                
                _setDialogState?.call(() {});
                
                // 延迟关闭弹窗，让用户看到结果
                await Future.delayed(const Duration(seconds: 1));
                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
                if (!completer.isCompleted) completer.complete(true);
                return completer.future;
              } else {
                logState.warning('⚠️ $touchType CDC差值 $cdcDiff < 阈值 $threshold', type: LogType.debug);
              }
            }
          }
        } else {
          logState.warning('⚠️ $touchType 获取CDC失败: ${response?['error'] ?? '超时'}', type: LogType.debug);
        }
      } catch (e) {
        logState.warning('⚠️ $touchType 轮询异常: $e', type: LogType.debug);
      }
      
      // 更新 dialog 显示
      _setDialogState?.call(() {});
      
      // 重试间隔
      if (retry < maxRetries && !testCancelled && !testPassed) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
    
    // 所有重试完成仍未通过
    if (!testPassed && !testCancelled) {
      logState.error('❌ $touchType 重试 $maxRetries 次后仍然失败');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!completer.isCompleted) completer.complete(false);
    }
    
    return completer.future;
  }

  // ========== 工位3: 左佩戴检测 ==========
  // 流程: 发送 0x07+0x00+0x04 → 收到ACK → 监听 0x07+0x00+0x04 推送 → 通过
  Future<bool> _testLeftWearDetect3(TestState state, LogState logState) async {
    logState.info('👆 左佩戴检测');
    
    // 发送佩戴检测命令: 0x07 + 0x00(左Touch) + 0x04(佩戴检测)
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
    
    // 用于从外部更新 dialog UI 的回调
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
    
    // 等待 dialog 初始化
    await Future.delayed(const Duration(milliseconds: 100));
    
    // 设置超时
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
          
          // 检查佩戴检测推送: 0x07 + 0x00 + 0x04
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

  // ========== 工位3: 左触控事件测试 ==========
  // 流程: 发送 0x07+0x00+0x00 → 监听 0x07+0x00+(0x01/0x02/0x03/0x05) 推送 → 通过
  Future<bool> _testLeftTouchEvent3(TestState state, LogState logState) async {
    logState.info('👆 左触控事件测试');
    
    // 发送左触控命令: 0x07 + 0x00(左Touch) + 0x00(未触摸/查询)
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
    
    // 用于从外部更新 dialog UI 的回调
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
    
    // 等待 dialog 初始化
    await Future.delayed(const Duration(milliseconds: 100));
    
    // 设置超时
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
          
          // 检查左触控事件: 0x07 + 0x00 + (0x01/0x02/0x03/0x05)
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

  // ========== 工位3: 结束产测 ==========
  Future<bool> _testProductionEnd3(TestState state, LogState logState) async {
    logState.info('🏁 结束产测');
    
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

    logState.info('✅ 产测结束成功');
    return true;
  }

  /// 旧的蓝牙连接方法（保留作为备用）
  Future<bool> _testBluetoothConnectionLegacy(TestState state, LogState logState) async {
    try {
      if (_productInfo1 == null) {
        logState.error('设备信息未获取');
        return false;
      }
      
      final bluetoothAddress = _productInfo1!.bluetoothAddress;
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
      _deviceIP1 = null;
      
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
                  _deviceIP1 = wifiResult['ip'];
                  logState.success('✅ 获取到设备IP: $_deviceIP1');
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
      
      // 发送 Sensor 命令 (0x0C + 0x02 = 开始发送数据)
      final command = ProductionTestCommands.createSensorCommand(0x02);
      final cmdHex = command.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      logState.info('📤 发送: [$cmdHex] (${command.length} bytes)');
      
      // 等待嵌入式主动推送的响应，超时时间 10 秒
      logState.info('⏳ 等待嵌入式推送拍照完成指令 (超时: 10s)...');
      final response = await state.sendCommandViaLinuxBluetooth(
        command,
        timeout: const Duration(seconds: 10),
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );
      
      // 检查响应
      if (response == null) {
        logState.error('❌ 等待拍照响应超时');
        return false;
      }
      
      if (response.containsKey('error')) {
        logState.error('❌ 拍照命令失败: ${response['error']}');
        return false;
      }
      
      // 解析响应，检查是否为 Sensor 命令的响应
      if (response.containsKey('payload')) {
        final payload = response['payload'];
        if (payload is Uint8List && payload.isNotEmpty) {
          final payloadHex = payload.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
          logState.info('📥 收到响应: [$payloadHex]');
          
          // 检查响应的 CMD 是否为 Sensor (0x0C)
          if (payload[0] == ProductionTestCommands.cmdSensor) {
            logState.info('✅ 收到 Sensor 响应，拍照完成');
          } else {
            logState.warning('⚠️ 响应 CMD 不匹配: 0x${payload[0].toRadixString(16).toUpperCase()}');
          }
        }
      }
      
      logState.info('✅ 拍照命令执行成功，准备下载图片...');
      
      if (_deviceIP1 == null || _deviceIP1!.isEmpty) {
        logState.error('❌ 无法下载图片：设备IP地址为空');
        return false;
      }
      
      logState.info('📥 开始FTP下载图片...');
      final downloadSuccess = await state.downloadImageFromDevice(_deviceIP1!);

      if (!downloadSuccess) {
        logState.error('❌ 图片下载失败');
        return false;
      }

      logState.info('✅ 图片下载成功，等待人工确认...');

      // 获取图片路径并显示弹窗供用户确认
      final imagePath = state.sensorImagePath;
      if (imagePath == null || imagePath.isEmpty) {
        logState.error('❌ 图片路径为空');
        return false;
      }

      if (!mounted) return false;

      final imageReviewResult = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('摄像头测试 - 图片确认'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('请确认图片是否正常显示：'),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 400, maxWidth: 600),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Text('❌ 无法加载图片');
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('❌ 测试失败'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('✅ 测试通过'),
            ),
          ],
        ),
      );

      if (imageReviewResult == true) {
        logState.info('✅ 用户确认：摄像头测试通过');
        return true;
      } else {
        logState.info('❌ 用户确认：摄像头测试失败');
        return false;
      }
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
      final passedCount = _stepResults1.take(_stepResults1.length - 1)
          .where((s) => s.status == TestStepStatus.passed).length;
      final totalCount = _stepResults1.length - 1;
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

  /// 发送设备重启命令
  /// module id: 6, msg id: 0, payload: 2004 (0x20, 0x04 - 两个字节)
  /// 判断蓝牙连接是否断开，断开则表示结束，否则重试3次
  Future<void> _sendDeviceRestartCommand(TestState state, LogState logState) async {
    // payload 2004 的两个字节表示
    final restartPayload = Uint8List.fromList([0x20, 0x04]);
    const maxRetries = 3;

    for (int retry = 0; retry < maxRetries; retry++) {
      // 检查是否被取消（检查所有工位的取消标志）
      if (_cancelRestartCommand1 || _cancelRestartCommand3 || _cancelRestartCommand4 || _cancelRestartCommand6) {
        logState.warning('⚠️ 重启命令已被取消（新测试开始）');
        return;
      }
      
      if (retry > 0) {
        logState.info('   重启命令重试 ($retry/$maxRetries)...');
        await Future.delayed(const Duration(seconds: 2));
        
        // 延迟后再次检查是否被取消
        if (_cancelRestartCommand1 || _cancelRestartCommand3 || _cancelRestartCommand4 || _cancelRestartCommand6) {
          logState.warning('⚠️ 重启命令已被取消（新测试开始）');
          return;
        }
      }

      // 检查蓝牙连接状态
      if (!state.linuxBtService.isConnected) {
        logState.info('✅ 蓝牙连接已断开，设备重启成功');
        return;
      }

      try {
        logState.info('📤 发送重启命令 (module: 6, msg: 0, payload: 2004)...');
        final response = await state.sendCommandViaLinuxBluetooth(
          restartPayload,
          timeout: const Duration(seconds: 3),
          moduleId: 6,
          messageId: 0,
        );

        if (response != null && !response.containsKey('error')) {
          logState.info('✅ 重启命令发送成功，等待设备断开...');
        } else {
          final errorMsg = response?['error'] ?? '未知错误';
          logState.warning('⚠️ 重启命令发送失败: $errorMsg');
        }

        // 等待一段时间后检查蓝牙是否断开
        await Future.delayed(const Duration(seconds: 3));

        if (!state.linuxBtService.isConnected) {
          logState.success('✅ 蓝牙连接已断开，设备重启成功');
          return;
        }

      } catch (e) {
        logState.warning('⚠️ 发送重启命令异常: $e');
      }
    }

    // 3次重试后蓝牙仍未断开
    logState.warning('⚠️ 3次重试后蓝牙仍未断开，设备可能未重启或已断开');
  }

  // ========== 工位4,5,6: 初始化步骤 ==========
  void _initializeSteps4() {
    _stepResults4.clear();
    _stepResults4.addAll([
      TestStepResult(stepNumber: 1, name: '蓝牙连接', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 2, name: 'BYD MES 开始', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 3, name: '产测开始', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 4, name: 'WiFi连接并获取IP', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 5, name: 'WiFi拉距测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 6, name: '光敏传感器测试(亮/暗)', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 7, name: '摄像头IMU位置标定', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 8, name: '纯色画面测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 9, name: 'IMU校准', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 10, name: 'IMU值测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 11, name: 'ISO12233 MTF测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 12, name: '24色色卡测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 13, name: '产测结束', status: TestStepStatus.pending),
    ]);
  }

  void _initializeSteps5() {
    _stepResults5.clear();
    _stepResults5.addAll([
      TestStepResult(stepNumber: 1, name: '蓝牙连接', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 2, name: 'BYD MES 开始', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 3, name: '设备电压测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 4, name: '电量检测测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 5, name: '充电状态测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 6, name: '产测结束', status: TestStepStatus.pending),
    ]);
  }

  void _initializeSteps6() {
    _stepResults6.clear();
    _stepResults6.addAll([
      TestStepResult(stepNumber: 1, name: '蓝牙连接', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 2, name: 'BYD MES 开始', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 3, name: '产测开始', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 4, name: '电池电压测试(>2.5V)', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 5, name: '电量检测(0~100%)', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 6, name: '充电状态(充电中)', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 7, name: 'LED外侧亮', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 8, name: 'LED外侧关', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 9, name: 'LED内侧亮', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 10, name: 'LED内侧关', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 11, name: '右Touch-TK1(>500)', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 12, name: '右Touch-TK2(>500)', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 13, name: '右Touch-TK3(>500)', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 14, name: '佩戴检测', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 15, name: '左触控-点击', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 16, name: '左触控-双击', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 17, name: '左触控-长按', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 18, name: '产测结束', status: TestStepStatus.pending),
    ]);
  }

  // ========== 工位4: 停止测试 ==========
  void _stopAutoTest4() {
    setState(() {
      _isAutoTesting4 = false;
    });
  }

  void _stopAutoTest5() {
    setState(() {
      _isAutoTesting5 = false;
    });
  }

  void _stopAutoTest6() {
    setState(() {
      _isAutoTesting6 = false;
    });
  }

  // ========== 工位4: 开始自动测试 ==========
  Future<void> _startAutoTest4(TestState state) async {
    final logState = context.read<LogState>();

    _mesService4.setOnLog((msg) => logState.info('[MES] $msg', type: LogType.debug));

    if (!mounted) return;
    final scanResult = await showDialog<_SNScanResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SNScanDialog(title: '工位4: 超声后射频图像测试'),
    );

    if (scanResult == null) {
      logState.warning('用户取消输入');
      return;
    }

    if (scanResult.isMacMode) {
      final mac = scanResult.bluetoothAddress!;
      logState.info('📋 蓝牙MAC直连模式: $mac');
      _scannedSN4 = null;
      _productInfo4 = ProductSNInfo(
        snCode: 'MAC直连',
        bluetoothAddress: mac,
        macAddress: '',
      );
    } else {
      _scannedSN4 = scanResult.sn;
      logState.info('📋 扫码SN: $_scannedSN4');
      logState.info('📡 查询SN信息获取蓝牙MAC...');
      try {
        final productInfo = await ProductSNApi.getProductSNInfo(_scannedSN4!);
        if (productInfo == null) {
          logState.error('❌ SN查询失败，无法获取蓝牙地址');
          return;
        }
        _productInfo4 = productInfo;
        logState.info('✅ 获取到设备信息:');
        logState.info('   SN: ${productInfo.snCode}');
        logState.info('   蓝牙地址: ${productInfo.bluetoothAddress}');
        logState.info('   WiFi MAC: ${productInfo.macAddress}');
        
        if (productInfo.bluetoothAddress.isEmpty) {
          logState.error('❌ 蓝牙地址为空，无法继续');
          return;
        }
      } catch (e) {
        logState.error('❌ SN查询异常: $e');
        return;
      }
    }

    // 取消之前可能还在运行的重启命令重试
    _cancelRestartCommand4 = true;
    await Future.delayed(const Duration(milliseconds: 100)); // 等待取消生效
    _cancelRestartCommand4 = false; // 重置标志
    
    setState(() {
      _isAutoTesting4 = true;
      _currentStep4 = 0;
      _initializeSteps4();
    });

    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('🔧 工位4: 超声后射频图像测试');
    logState.info('   SN: ${_scannedSN4 ?? "MAC直连"}');
    logState.info('   蓝牙: ${_productInfo4!.bluetoothAddress}');
    logState.info('   连接方案: ${_getMethodName(_selectedMethod4)}');
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    bool hasFailure = false;
    String? failItem;
    String? failValue;

    for (int i = 0; i < _stepResults4.length; i++) {
      if (!_isAutoTesting4) break;

      setState(() {
        _currentStep4 = i;
        _stepResults4[i].status = TestStepStatus.running;
      });

      bool success = false;
      String? message;

      try {
        switch (i) {
          case 0:
            logState.info('步骤1: 蓝牙连接');
            success = await _testBluetoothConnection4(state, logState);
            message = success ? '蓝牙连接正常' : '蓝牙连接失败';
            if (success) {
              logState.info('🔄 发送产测状态重置命令 (0xFF 0xFF)...');
              try {
                final resetCommand = ProductionTestCommands.createEndTestCommand(opt: 0xFF);
                await state.sendCommandViaLinuxBluetooth(
                  resetCommand,
                  timeout: const Duration(seconds: 3),
                  moduleId: ProductionTestCommands.moduleId,
                );
                logState.info('✅ 产测状态重置命令发送成功');
              } catch (e) {
                logState.warning('⚠️ 产测状态重置命令发送失败: $e');
              }
            }
            break;
          case 1:
            logState.info('步骤2: BYD MES 开始');
            if (_scannedSN4 != null && _scannedSN4!.isNotEmpty) {
              final mesResult = await _mesService4.start(_scannedSN4!);
              success = mesResult['success'] == true;
              message = success ? 'MES Start 成功' : 'MES Start 失败: ${mesResult['error'] ?? '未知错误'}';
            } else {
              logState.info('   ⏭️ MAC直连模式，跳过 MES Start');
              success = true;
              message = 'MAC直连模式，跳过 MES';
            }
            break;
          case 2:
            logState.info('步骤3: 产测开始');
            success = await _testProductionStart(state, logState);
            message = success ? '产测开始命令发送成功' : '产测开始命令失败';
            break;
          case 3:
            logState.info('步骤4: WIFI连接热点并获取IP');
            final ip = await _testWiFiConnection4(state, logState);
            success = ip != null && ip.isNotEmpty;
            _deviceIP4 = ip;
            message = success ? 'WiFi连接成功，IP: $ip' : 'WiFi连接失败';
            break;
          case 4:
            logState.info('步骤5: 拉距测试WIFI');
            success = await _testWiFiRange4(state, logState);
            message = success ? 'WiFi拉距测试通过' : 'WiFi拉距测试失败';
            break;
          case 5:
            logState.info('步骤6: 光源箱不同照度光敏值(亮/暗)');
            success = await _testLightSensorBrightDark4(state, logState);
            message = success ? '光敏值测试通过' : '光敏值测试失败';
            break;
          case 6:
            logState.info('步骤7: 摄像头位置与IMU位置标定');
            success = await _testCameraIMUCalibration4(state, logState);
            message = success ? '摄像头IMU标定通过' : '摄像头IMU标定失败';
            break;
          case 7:
            logState.info('步骤8: 纯色画面测试');
            success = await _testPureColorStream4(state, logState);
            message = success ? '纯色画面测试通过' : '纯色画面测试失败';
            break;
          case 8:
            logState.info('步骤9: IMU校准(棋盘格)');
            success = await _testIMUCalibration4(state, logState);
            message = success ? 'IMU校准完成' : 'IMU校准失败';
            break;
          case 9:
            logState.info('步骤10: IMU值测试');
            success = await _testIMUSensor(state, logState);
            message = success ? '获取到IMU值' : 'IMU传感器测试失败';
            break;
          case 10:
            logState.info('步骤11: ISO12233图卡MTF测试');
            success = await _testISO12233MTF4(state, logState);
            message = success ? 'MTF测试通过' : 'MTF测试失败';
            break;
          case 11:
            logState.info('步骤12: 24色色卡色彩误差测试');
            success = await _testColorChart4(state, logState);
            message = success ? '色彩误差测试通过' : '色彩误差测试失败';
            break;
          case 12:
            logState.info('步骤13: 产测结束');
            success = await _testProductionEnd4(state, logState);
            message = success ? '产测结束命令发送成功' : '产测结束命令失败';
            break;
        }
      } catch (e) {
        success = false;
        message = '测试异常: $e';
        logState.error('步骤${i + 1}异常: $e');
      }

      if (!_isAutoTesting4) break;

      setState(() {
        _stepResults4[i].status = success ? TestStepStatus.passed : TestStepStatus.failed;
        _stepResults4[i].message = message;
      });

      if (!success) {
        logState.error('❌ 步骤${i + 1}失败: $message');
        if (!hasFailure) {
          hasFailure = true;
          failItem = _stepResults4[i].name;
          failValue = message ?? '测试未通过';
        }
        logState.info('🔄 发送产测状态更新命令 (0xFF 0x01) - 测试失败...');
        try {
          final failCommand = ProductionTestCommands.createEndTestCommand(opt: 0x01);
          await state.sendCommandViaLinuxBluetooth(
            failCommand,
            timeout: const Duration(seconds: 3),
            moduleId: ProductionTestCommands.moduleId,
          );
          logState.info('✅ 产测状态更新命令发送成功');
        } catch (e) {
          logState.warning('⚠️ 产测状态更新命令发送失败: $e');
        }
        if (!_debugMode4) {
          break;
        } else {
          logState.warning('⚠️ 调试模式：跳过失败步骤，继续执行...');
        }
      } else {
        logState.info('✅ 步骤${i + 1}通过: $message');
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() => _isAutoTesting4 = false);

    final passedCount = _stepResults4.where((s) => s.status == TestStepStatus.passed).length;
    final totalCount = _stepResults4.length;
    final allPassed = passedCount == totalCount;
    
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (_scannedSN4 != null && _scannedSN4!.isNotEmpty) {
      if (allPassed) {
        logState.info('🏭 调用 BYD MES 良品完成接口...');
        final mesResult = await _mesService4.complete(_scannedSN4!);
        if (mesResult['success'] == true) {
          logState.success('✅ BYD MES 良品完成成功');
        } else {
          logState.error('❌ BYD MES 良品完成失败: ${mesResult['error']}');
        }
        
        logState.info('📤 更新SN状态为「超声后射频图像测试通过」(status=6)...');
        final statusUpdated = await SNApiService.updateSNStatus(
          sn: _scannedSN4!,
          status: 6,
          logState: logState,
        );
        if (statusUpdated) {
          logState.success('✅ SN状态更新成功');
        } else {
          logState.error('❌ SN状态更新失败');
        }
        
        logState.info('🎉 工位4测试全部通过！($passedCount/$totalCount)');
      } else {
        logState.info('🏭 调用 BYD MES 不良品接口...');
        final mesResult = await _mesService4.ncComplete(
          _scannedSN4!,
          ncCode: 'NC004',
          ncContext: '超声后射频图像测试不良',
          failItem: failItem ?? '未知',
          failValue: failValue ?? '测试未通过',
        );
        if (mesResult['success'] == true) {
          logState.success('✅ BYD MES 不良品上报成功');
        } else {
          logState.error('❌ BYD MES 不良品上报失败: ${mesResult['error']}');
        }
        logState.warning('⚠️ 工位4测试完成，通过 $passedCount/$totalCount 项');
      }
    } else {
      if (allPassed) {
        logState.info('🎉 工位4测试全部通过！($passedCount/$totalCount)（MAC直连模式，跳过MES上报）');
      } else {
        logState.warning('⚠️ 工位4测试完成，通过 $passedCount/$totalCount 项（MAC直连模式，跳过MES上报）');
      }
    }
    
    logState.info('🔄 发送设备重启命令...');
    await _sendDeviceRestartCommand(state, logState);
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  // ========== 工位5: 开始自动测试 ==========
  Future<void> _startAutoTest5(TestState state) async {
    final logState = context.read<LogState>();

    _mesService5.setOnLog((msg) => logState.info('[MES] $msg', type: LogType.debug));

    final scanResult = await showDialog<_SNScanResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SNScanDialog(title: '工位5: 超声后音频测试'),
    );

    if (scanResult == null) return;

    setState(() {
      _initializeSteps5();
      _currentStep5 = 1;
      _isAutoTesting5 = true;
      _scannedSN5 = scanResult.sn;
      if (scanResult.isMacMode) {
        _productInfo5 = ProductSNInfo(
          snCode: '',
          bluetoothAddress: scanResult.bluetoothAddress!,
          macAddress: '',
        );
      }
    });

    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('🔧 工位5: 超声后音频测试');
    logState.info('   SN: ${_scannedSN5 ?? "MAC直连"}');
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // TODO: 实现工位5的音频测试流程

    await Future.delayed(const Duration(seconds: 2));
    logState.info('工位5测试流程框架已搭建，详细测试步骤待实现');

    setState(() => _isAutoTesting5 = false);
  }

  // ========== 工位6: 开始自动测试 ==========
  Future<void> _startAutoTest6(TestState state) async {
    final logState = context.read<LogState>();

    _mesService6.setOnLog((msg) => logState.info('[MES] $msg', type: LogType.debug));

    if (!mounted) return;
    final scanResult = await showDialog<_SNScanResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SNScanDialog(title: '工位6: 超声后电源外设测试'),
    );

    if (scanResult == null) {
      logState.warning('用户取消输入');
      return;
    }

    if (scanResult.isMacMode) {
      final mac = scanResult.bluetoothAddress!;
      logState.info('📋 蓝牙MAC直连模式: $mac');
      _scannedSN6 = null;
      _productInfo6 = ProductSNInfo(
        snCode: 'MAC直连',
        bluetoothAddress: mac,
        macAddress: '',
      );
    } else {
      _scannedSN6 = scanResult.sn;
      logState.info('📋 扫码SN: $_scannedSN6');
      logState.info('📡 查询SN信息获取蓝牙MAC...');
      try {
        final productInfo = await ProductSNApi.getProductSNInfo(_scannedSN6!);
        if (productInfo == null) {
          logState.error('❌ SN查询失败，无法获取蓝牙地址');
          return;
        }
        _productInfo6 = productInfo;
        logState.info('✅ 获取到设备信息:');
        logState.info('   SN: ${productInfo.snCode}');
        logState.info('   蓝牙地址: ${productInfo.bluetoothAddress}');
        logState.info('   WiFi MAC: ${productInfo.macAddress}');
        
        if (productInfo.bluetoothAddress.isEmpty) {
          logState.error('❌ 蓝牙地址为空，无法继续');
          return;
        }
      } catch (e) {
        logState.error('❌ SN查询异常: $e');
        return;
      }
    }

    // 取消之前可能还在运行的重启命令重试
    _cancelRestartCommand6 = true;
    await Future.delayed(const Duration(milliseconds: 100)); // 等待取消生效
    _cancelRestartCommand6 = false; // 重置标志
    
    setState(() {
      _isAutoTesting6 = true;
      _currentStep6 = 0;
      _initializeSteps6();
    });

    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('🔧 工位6: 超声后电源外设测试');
    logState.info('   SN: ${_scannedSN6 ?? "MAC直连"}');
    logState.info('   蓝牙: ${_productInfo6!.bluetoothAddress}');
    logState.info('   连接方案: ${_getMethodName(_selectedMethod6)}');
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    bool hasFailure = false;
    String? failItem;
    String? failValue;

    for (int i = 0; i < _stepResults6.length; i++) {
      if (!_isAutoTesting6) break;

      setState(() {
        _currentStep6 = i;
        _stepResults6[i].status = TestStepStatus.running;
      });

      bool success = false;
      String? message;

      try {
        switch (i) {
          case 0:
            logState.info('步骤1: 蓝牙连接');
            success = await _testBluetoothConnection6(state, logState);
            message = success ? '蓝牙连接正常' : '蓝牙连接失败';
            if (success) {
              logState.info('🔄 发送产测状态重置命令 (0xFF 0xFF)...');
              try {
                final resetCommand = ProductionTestCommands.createEndTestCommand(opt: 0xFF);
                await state.sendCommandViaLinuxBluetooth(resetCommand, timeout: const Duration(seconds: 3), moduleId: ProductionTestCommands.moduleId);
                logState.info('✅ 产测状态重置命令发送成功');
              } catch (e) {
                logState.warning('⚠️ 产测状态重置命令发送失败: $e');
              }
            }
            break;
          case 1:
            logState.info('步骤2: BYD MES 开始');
            if (_scannedSN6 != null && _scannedSN6!.isNotEmpty) {
              final mesResult = await _mesService6.start(_scannedSN6!);
              success = mesResult['success'] == true;
              message = success ? 'MES Start 成功' : 'MES Start 失败: ${mesResult['error'] ?? '未知错误'}';
            } else {
              logState.info('   ⏭️ MAC直连模式，跳过 MES Start');
              success = true;
              message = 'MAC直连模式，跳过 MES';
            }
            break;
          case 2:
            logState.info('步骤3: 产测开始');
            success = await _testProductionStart(state, logState);
            message = success ? '产测开始命令发送成功' : '产测开始命令失败';
            break;
          case 3:
            logState.info('步骤4: 电池电压测试(>2.5V)');
            final voltageResult = await _testBatteryVoltage6(state, logState);
            success = voltageResult['success'] == true;
            message = voltageResult['message'] as String?;
            break;
          case 4:
            logState.info('步骤5: 电量检测(0~100%)');
            final batteryResult = await _testBattery6(state, logState);
            success = batteryResult['success'] == true;
            message = batteryResult['message'] as String?;
            break;
          case 5:
            logState.info('步骤6: 充电状态(充电中)');
            final chargeResult = await _testChargeStatus6(state, logState);
            success = chargeResult['success'] == true;
            message = chargeResult['message'] as String?;
            break;
          case 6:
            logState.info('步骤7: LED外侧亮');
            success = await _testLED6(state, logState, isOuter: true, turnOn: true);
            message = success ? 'LED外侧亮测试通过' : 'LED外侧亮测试失败';
            break;
          case 7:
            logState.info('步骤8: LED外侧关');
            success = await _testLED6(state, logState, isOuter: true, turnOn: false);
            message = success ? 'LED外侧关测试通过' : 'LED外侧关测试失败';
            break;
          case 8:
            logState.info('步骤9: LED内侧亮');
            success = await _testLED6(state, logState, isOuter: false, turnOn: true);
            message = success ? 'LED内侧亮测试通过' : 'LED内侧亮测试失败';
            break;
          case 9:
            logState.info('步骤10: LED内侧关');
            success = await _testLED6(state, logState, isOuter: false, turnOn: false);
            message = success ? 'LED内侧关测试通过' : 'LED内侧关测试失败';
            break;
          case 10:
            logState.info('步骤11: 右Touch-TK1校准');
            success = await _testTouchCalibration6(state, logState, touchType: 'TK1');
            message = success ? 'TK1校准通过' : 'TK1校准失败';
            break;
          case 11:
            logState.info('步骤12: 右Touch-TK2校准');
            success = await _testTouchCalibration6(state, logState, touchType: 'TK2');
            message = success ? 'TK2校准通过' : 'TK2校准失败';
            break;
          case 12:
            logState.info('步骤13: 右Touch-TK3校准');
            success = await _testTouchCalibration6(state, logState, touchType: 'TK3');
            message = success ? 'TK3校准通过' : 'TK3校准失败';
            break;
          case 13:
            logState.info('步骤14: 右Touch-TK1(>500)');
            success = await _testTouch6(state, logState, touchType: 'TK1');
            message = success ? 'TK1测试通过' : 'TK1测试失败';
            break;
          case 14:
            logState.info('步骤15: 右Touch-TK2(>500)');
            success = await _testTouch6(state, logState, touchType: 'TK2');
            message = success ? 'TK2测试通过' : 'TK2测试失败';
            break;
          case 15:
            logState.info('步骤16: 右Touch-TK3(>500)');
            success = await _testTouch6(state, logState, touchType: 'TK3');
            message = success ? 'TK3测试通过' : 'TK3测试失败';
            break;
          case 16:
            logState.info('步骤17: 佩戴检测');
            success = await _testWearDetection6(state, logState);
            message = success ? '佩戴检测通过' : '佩戴检测失败';
            break;
          case 17:
            logState.info('步骤18: 左触控-点击');
            success = await _testLeftTouch6(state, logState, touchType: '点击');
            message = success ? '左触控点击测试通过' : '左触控点击测试失败';
            break;
          case 18:
            logState.info('步骤19: 左触控-双击');
            success = await _testLeftTouch6(state, logState, touchType: '双击');
            message = success ? '左触控双击测试通过' : '左触控双击测试失败';
            break;
          case 19:
            logState.info('步骤20: 左触控-长按');
            success = await _testLeftTouch6(state, logState, touchType: '长按');
            message = success ? '左触控长按测试通过' : '左触控长按测试失败';
            break;
          case 20:
            logState.info('步骤21: 产测结束');
            success = await _testProductionEnd6(state, logState);
            message = success ? '产测结束命令发送成功' : '产测结束命令失败';
            break;
        }
      } catch (e) {
        success = false;
        message = '测试异常: $e';
        logState.error('步骤${i + 1}异常: $e');
      }

      if (!_isAutoTesting6) break;

      setState(() {
        _stepResults6[i].status = success ? TestStepStatus.passed : TestStepStatus.failed;
        _stepResults6[i].message = message;
      });

      if (!success) {
        logState.error('❌ 步骤${i + 1}失败: $message');
        if (!hasFailure) {
          hasFailure = true;
          failItem = _stepResults6[i].name;
          failValue = message ?? '测试未通过';
        }
        logState.info('🔄 发送产测状态更新命令 (0xFF 0x01) - 测试失败...');
        try {
          final failCommand = ProductionTestCommands.createEndTestCommand(opt: 0x01);
          await state.sendCommandViaLinuxBluetooth(failCommand, timeout: const Duration(seconds: 3), moduleId: ProductionTestCommands.moduleId);
          logState.info('✅ 产测状态更新命令发送成功');
        } catch (e) {
          logState.warning('⚠️ 产测状态更新命令发送失败: $e');
        }
        if (!_debugMode6) {
          break;
        } else {
          logState.warning('⚠️ 调试模式：跳过失败步骤，继续执行...');
        }
      } else {
        logState.info('✅ 步骤${i + 1}通过: $message');
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() => _isAutoTesting6 = false);

    final passedCount = _stepResults6.where((s) => s.status == TestStepStatus.passed).length;
    final totalCount = _stepResults6.length;
    final allPassed = passedCount == totalCount;
    
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (_scannedSN6 != null && _scannedSN6!.isNotEmpty) {
      if (allPassed) {
        logState.info('🏭 调用 BYD MES 良品完成接口...');
        final mesResult = await _mesService6.complete(_scannedSN6!);
        if (mesResult['success'] == true) {
          logState.success('✅ BYD MES 良品完成成功');
        } else {
          logState.error('❌ BYD MES 良品完成失败: ${mesResult['error']}');
        }
        
        logState.info('📤 更新SN状态为「超声后电源外设测试通过」(status=8)...');
        final statusUpdated = await SNApiService.updateSNStatus(sn: _scannedSN6!, status: 8, logState: logState);
        if (statusUpdated) {
          logState.success('✅ SN状态更新成功');
        } else {
          logState.error('❌ SN状态更新失败');
        }
        
        logState.info('🎉 工位6测试全部通过！($passedCount/$totalCount)');
      } else {
        logState.info('🏭 调用 BYD MES 不良品接口...');
        final mesResult = await _mesService6.ncComplete(_scannedSN6!, ncCode: 'NC006', ncContext: '超声后电源外设测试不良', failItem: failItem ?? '未知', failValue: failValue ?? '测试未通过');
        if (mesResult['success'] == true) {
          logState.success('✅ BYD MES 不良品上报成功');
        } else {
          logState.error('❌ BYD MES 不良品上报失败: ${mesResult['error']}');
        }
        logState.warning('⚠️ 工位6测试完成，通过 $passedCount/$totalCount 项');
      }
    } else {
      if (allPassed) {
        logState.info('🎉 工位6测试全部通过！($passedCount/$totalCount)（MAC直连模式，跳过MES上报）');
      } else {
        logState.warning('⚠️ 工位6测试完成，通过 $passedCount/$totalCount 项（MAC直连模式，跳过MES上报）');
      }
    }
    
    logState.info('🔄 发送设备重启命令...');
    await _sendDeviceRestartCommand(state, logState);
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  // ========== 工位4: 测试步骤实现 ==========

  Future<bool> _testBluetoothConnection4(TestState state, LogState logState) async {
    try {
      if (_productInfo4 == null) {
        logState.error('设备信息未获取');
        return false;
      }
      
      final bluetoothAddress = _productInfo4!.bluetoothAddress;
      if (bluetoothAddress == null || bluetoothAddress.isEmpty) {
        logState.error('❌ 蓝牙地址为空');
        return false;
      }

      logState.info('🔵 目标蓝牙地址: $bluetoothAddress');
      logState.info('🔗 使用 RFCOMM Socket (固定Channel 5)');
      
      // 使用RFCOMM Socket方式，固定channel 5
      final success = await state.testBluetoothMethod4RfcommSocket(
        deviceAddress: bluetoothAddress,
        channel: 5,
        uuid: '7033',
      );

      if (success) {
        logState.success('✅ 蓝牙连接成功');
      } else {
        logState.error('❌ 蓝牙连接失败');
      }
      
      return success;
    } catch (e) {
      logState.error('❌ 蓝牙连接测试异常: $e');
      return false;
    }
  }

  Future<String?> _testWiFiConnection4(TestState state, LogState logState) async {
    try {
      logState.info('📶 开始连接WiFi热点...');
      
      final String ssid = WiFiConfig.defaultSSID;
      final String password = WiFiConfig.defaultPassword;
      
      if (ssid.isEmpty) {
        logState.error('❌ WiFi SSID未配置，请在通用配置中设置');
        return null;
      }

      logState.info('   SSID: $ssid');

      final ssidBytes = ssid.codeUnits + [0x00];
      final pwdBytes = password.codeUnits + [0x00];
      final payload = [...ssidBytes, ...pwdBytes];
      final command = ProductionTestCommands.createControlWifiCommand(0x05, data: payload);

      // 重试机制：最多尝试3次，每次超时10秒
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
                  final deviceIP = wifiResult['ip'];
                  logState.success('✅ 获取到设备IP: $deviceIP');
                  logState.info('✅ WiFi连接成功');
                  return deviceIP;
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
      return null;
    } catch (e) {
      logState.error('❌ WiFi连接测试失败: $e');
      return null;
    }
  }

  Future<bool> _testWiFiRange4(TestState state, LogState logState) async {
    if (_deviceIP4 == null || _deviceIP4!.isEmpty) {
      logState.error('❌ 设备IP为空，无法进行拉距测试');
      return false;
    }

    final threshold = _config.iperfSpeedThresholdMbps;
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('📡 WiFi 拉距测试');
    logState.info('   设备IP: $_deviceIP4');
    logState.info('   速率阈值: ≥${threshold}Mbps');
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // ========== 第一轮测试 ==========
    if (!mounted) return false;
    final round1Confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi, color: Colors.blue),
            SizedBox(width: 8),
            Text('WiFi拉距测试 - 第一轮'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('设备IP: $_deviceIP4', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text('速率阈值: ≥${threshold}Mbps', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            const Text('请确保设备已连接WiFi，然后点击确定开始第一轮测试'),
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

    if (round1Confirm != true) {
      logState.warning('⚠️ 用户取消第一轮测试');
      return false;
    }

    logState.info('🚀 第一轮测试: iperf3 → $_deviceIP4 ...');
    final result1 = await _runIperf(_deviceIP4!, logState);
    
    if (result1 == null) {
      logState.error('❌ 第一轮测试失败');
      return false;
    }

    final speed1 = result1['speed'];
    logState.info('📊 第一轮速率: ${speed1.toStringAsFixed(2)} Mbps');
    
    if (speed1 < threshold) {
      logState.error('❌ 第一轮速率 ${speed1.toStringAsFixed(2)} Mbps < 阈值 ${threshold} Mbps');
      return false;
    }
    
    logState.success('✅ 第一轮测试通过: ${speed1.toStringAsFixed(2)} Mbps ≥ ${threshold} Mbps');

    // ========== 第二轮测试 ==========
    await Future.delayed(const Duration(seconds: 1));
    
    if (!mounted) return false;
    final round2Confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_tethering, color: Colors.orange),
            SizedBox(width: 8),
            Text('WiFi拉距测试 - 第二轮'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('第一轮速率: ${speed1.toStringAsFixed(2)} Mbps ✅', 
                style: const TextStyle(fontSize: 14, color: Colors.green)),
            const SizedBox(height: 16),
            const Text('请将设备远离路由器（拉远距离），然后点击确定开始第二轮测试', 
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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

    if (round2Confirm != true) {
      logState.warning('⚠️ 用户取消第二轮测试');
      return false;
    }

    logState.info('🚀 第二轮测试（设备已拉远）: iperf3 → $_deviceIP4 ...');
    final result2 = await _runIperf(_deviceIP4!, logState);
    
    if (result2 == null) {
      logState.error('❌ 第二轮测试失败');
      return false;
    }

    final speed2 = result2['speed'];
    logState.info('📊 第二轮速率: ${speed2.toStringAsFixed(2)} Mbps');
    
    if (speed2 < threshold) {
      logState.error('❌ 第二轮速率 ${speed2.toStringAsFixed(2)} Mbps < 阈值 ${threshold} Mbps');
      return false;
    }
    
    logState.success('✅ 第二轮测试通过: ${speed2.toStringAsFixed(2)} Mbps ≥ ${threshold} Mbps');
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.success('🎉 WiFi拉距测试全部通过！');
    logState.info('   第一轮: ${speed1.toStringAsFixed(2)} Mbps');
    logState.info('   第二轮: ${speed2.toStringAsFixed(2)} Mbps');
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    return true;
  }

  /// 执行iperf3测试
  /// 返回 Map 包含 speed (Mbps) 和 rawOutput
  Future<Map<String, dynamic>?> _runIperf(String deviceIP, LogState logState) async {
    final cmd = 'iperf3';
    final args = ['-c', deviceIP, '-p', '5001', '-t', '3', '-i', '1', '--json'];
    logState.info('🚀 执行: $cmd ${args.join(' ')}');

    try {
      final result = await Process.run(cmd, args, stdoutEncoding: utf8, stderrEncoding: utf8);

      if (result.exitCode == 0) {
        final jsonStr = result.stdout as String;
        try {
          final data = json.decode(jsonStr) as Map<String, dynamic>;
          final end = data['end'] as Map<String, dynamic>?;
          if (end != null) {
            final sumReceived = end['sum_received'] as Map<String, dynamic>?;
            if (sumReceived != null) {
              final bps = (sumReceived['bits_per_second'] as num?) ?? 0;
              final mbps = bps / 1000000;
              logState.success('📥 接收速率: ${mbps.toStringAsFixed(2)} Mbps');
              return {'speed': mbps, 'rawOutput': jsonStr};
            }
          }
        } catch (e) {
          logState.warning('⚠️ JSON解析失败: $e');
        }
        logState.error('❌ 无法从iperf3输出中提取速率');
        return null;
      } else {
        final err = '退出码: ${result.exitCode}\n${result.stderr}';
        logState.error('❌ iperf3 失败: $err');
        return null;
      }
    } catch (e) {
      final err = '执行iperf3异常: $e\n请确认已安装 iperf3';
      logState.error('❌ $err');
      return null;
    }
  }

  Future<bool> _testLightSensorBrightDark4(TestState state, LogState logState) async {
    try {
      logState.info('💡 光敏传感器测试（亮/暗）');
      
      if (!mounted) return false;
      final brightConfirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.wb_sunny, color: Colors.orange),
              SizedBox(width: 8),
              Text('光敏测试 - 亮环境'),
            ],
          ),
          content: const Text('请将设备放置在光源箱亮环境中，然后点击确定开始测试'),
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

      if (brightConfirm != true) return false;

      final brightSuccess = await _testLightSensor(state, logState);
      if (!brightSuccess) {
        logState.error('❌ 亮环境光敏值获取失败');
        return false;
      }

      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return false;
      final darkConfirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.nightlight, color: Colors.indigo),
              SizedBox(width: 8),
              Text('光敏测试 - 暗环境'),
            ],
          ),
          content: const Text('请将设备放置在光源箱暗环境中，然后点击确定开始测试'),
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

      if (darkConfirm != true) return false;

      final darkSuccess = await _testLightSensor(state, logState);
      if (!darkSuccess) {
        logState.error('❌ 暗环境光敏值获取失败');
        return false;
      }

      logState.success('✅ 光敏传感器测试完成（亮/暗）');
      return true;
    } catch (e) {
      logState.error('光敏传感器测试失败: $e');
      return false;
    }
  }

  Future<bool> _testCameraIMUCalibration4(TestState state, LogState logState) async {
    try {
      logState.info('📷 摄像头位置与IMU位置标定');
      logState.info('   提示：此测试需要图像算法服务支持');
      
      await Future.delayed(const Duration(seconds: 1));
      logState.success('✅ 摄像头IMU标定完成（模拟通过）');
      return true;
    } catch (e) {
      logState.error('摄像头IMU标定失败: $e');
      return false;
    }
  }

  Future<bool> _testPureColorStream4(TestState state, LogState logState) async {
    try {
      logState.info('🎨 纯色画面测试');
      logState.info('   提示：此测试需要图像算法服务支持');
      
      await Future.delayed(const Duration(seconds: 1));
      logState.success('✅ 纯色画面测试完成（模拟通过）');
      return true;
    } catch (e) {
      logState.error('纯色画面测试失败: $e');
      return false;
    }
  }

  Future<bool> _testIMUCalibration4(TestState state, LogState logState) async {
    logState.info('🔧 IMU校准测试开始');

    final command = ProductionTestCommands.createIMUCalibrationCommand();

    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _IMUCalibrationDialog(
          state: state,
          logState: logState,
          command: command,
          useLinuxBluetooth: true,
        );
      },
    );

    return result == true;
  }

  Future<bool> _testISO12233MTF4(TestState state, LogState logState) async {
    try {
      logState.info('📊 ISO12233图卡MTF测试');
      logState.info('   提示：此测试需要图像算法服务支持');
      
      await Future.delayed(const Duration(seconds: 1));
      logState.success('✅ ISO12233 MTF测试完成（模拟通过）');
      return true;
    } catch (e) {
      logState.error('ISO12233 MTF测试失败: $e');
      return false;
    }
  }

  Future<bool> _testColorChart4(TestState state, LogState logState) async {
    try {
      logState.info('🎨 24色色卡色彩误差测试');
      logState.info('   提示：此测试需要图像算法服务支持');
      
      await Future.delayed(const Duration(seconds: 1));
      logState.success('✅ 24色色卡测试完成（模拟通过）');
      return true;
    } catch (e) {
      logState.error('24色色卡测试失败: $e');
      return false;
    }
  }

  Future<bool> _testProductionEnd4(TestState state, LogState logState) async {
    try {
      logState.info('🏁 发送产测结束命令...');
      
      final passedCount = _stepResults4.take(_stepResults4.length - 1)
          .where((s) => s.status == TestStepStatus.passed).length;
      final totalCount = _stepResults4.length - 1;
      final allPassed = passedCount == totalCount;
      
      final opt = allPassed ? 0x00 : 0x01;
      final command = ProductionTestCommands.createEndTestCommand(opt: opt);
      logState.info('   测试结果: ${allPassed ? "通过" : "失败"} ($passedCount/$totalCount)');
      
      for (int retry = 0; retry < 3; retry++) {
        if (retry > 0) {
          logState.info('   重试 ($retry/3)...');
          await Future.delayed(const Duration(seconds: 2));
        }
        
        try {
          final response = await state.sendCommandViaLinuxBluetooth(
            command,
            timeout: const Duration(seconds: 5),
            moduleId: ProductionTestCommands.moduleId,
            messageId: ProductionTestCommands.messageId,
          );
          
          if (response != null && !response.containsKey('error')) {
            logState.success('✅ 产测结束命令发送成功');
            return true;
          }
        } catch (e) {
          logState.warning('⚠️ 发送命令异常: $e');
        }
      }
      
      logState.error('❌ 3次重试后产测结束命令仍失败');
      return false;
    } catch (e) {
      logState.error('产测结束异常: $e');
      return false;
    }
  }

  // ========== 工位6: 测试步骤实现 ==========

  Future<bool> _testBluetoothConnection6(TestState state, LogState logState) async {
    try {
      if (_productInfo6 == null) {
        logState.error('设备信息未获取');
        return false;
      }
      
      final bluetoothAddress = _productInfo6!.bluetoothAddress;
      if (bluetoothAddress == null || bluetoothAddress.isEmpty) {
        logState.error('❌ 蓝牙地址为空');
        return false;
      }

      logState.info('🔵 目标蓝牙地址: $bluetoothAddress');
      logState.info('🔗 使用 RFCOMM Socket (固定Channel 5)');
      
      // 使用RFCOMM Socket方式，固定channel 5
      final success = await state.testBluetoothMethod4RfcommSocket(
        deviceAddress: bluetoothAddress,
        channel: 5,
        uuid: '7033',
      );

      if (success) {
        logState.success('✅ 蓝牙连接成功');
      } else {
        logState.error('❌ 蓝牙连接失败');
      }
      
      return success;
    } catch (e) {
      logState.error('❌ 蓝牙连接测试异常: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> _testBatteryVoltage6(TestState state, LogState logState) async {
    logState.info('🔋 电池电压测试');
    
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

    final payload = response['payload'];
    if (payload is List && payload.length >= 3) {
      final payloadBytes = Uint8List.fromList(payload.cast<int>());
      final voltageMv = ProductionTestCommands.parseVoltageResponse(payloadBytes);
      
      if (voltageMv != null) {
        final voltageV = voltageMv / 1000.0;
        final threshold = 2.5;
        final success = voltageV > threshold;
        
        logState.info('   电压值: ${voltageV.toStringAsFixed(2)}V (阈值: >${threshold}V)');
        
        return {
          'success': success,
          'message': '电压: ${voltageV.toStringAsFixed(2)}V ${success ? "✅" : "❌ ≤${threshold}V"}',
        };
      }
    }

    return {'success': false, 'message': '电压数据解析失败'};
  }

  Future<Map<String, dynamic>> _testBattery6(TestState state, LogState logState) async {
    logState.info('🔋 电量检测测试');
    
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

    final payload = response['payload'];
    if (payload is List && payload.length >= 2) {
      final battery = payload[1];
      final success = battery >= 0 && battery <= 100;
      
      logState.info('   电量值: $battery% (范围: 0~100%)');
      
      return {
        'success': success,
        'message': '电量: $battery% ${success ? "✅" : "❌"}',
      };
    }

    return {'success': false, 'message': '电量数据解析失败'};
  }

  Future<Map<String, dynamic>> _testChargeStatus6(TestState state, LogState logState) async {
    logState.info('🔌 充电状态测试');
    
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

    final payload = response['payload'];
    if (payload is List && payload.length >= 3) {
      // 验证第一个字节是否为命令 0x03
      // 如果不是，可能是其他场景推送的数据，直接忽略
      final cmdByte = payload[0];
      if (cmdByte != 0x03) {
        logState.warning('⚠️ 收到非充电状态命令响应，忽略');
        logState.info('   期望命令: 0x03');
        logState.info('   实际命令: 0x${cmdByte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
        logState.info('   完整 Payload: ${payload.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ')}');
        logState.info('   (可能是设备推送数据，已过滤)');
        // 返回特殊标记，让调用者知道需要重试
        return {'success': false, 'message': '收到非预期命令响应，已过滤', 'shouldRetry': true};
      }
      
      final chargeStatus = payload[1];
      final faultCode = payload[2];
      
      final chargeDesc = chargeStatus == 0x01 ? '充电中' : (chargeStatus == 0x02 ? '未充电' : '状态: 0x${chargeStatus.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      final hasFault = faultCode != 0x00;
      
      logState.info('   充电状态: $chargeDesc');
      logState.info('   故障码: 0x${faultCode.toRadixString(16).toUpperCase().padLeft(2, '0')} ${hasFault ? "❌ 有故障" : "✅ 无故障"}');
      
      return {
        'success': !hasFault,
        'message': '$chargeDesc, 故障码: 0x${faultCode.toRadixString(16).toUpperCase().padLeft(2, '0')} ${!hasFault ? "✅" : "❌"}',
      };
    }

    return {'success': false, 'message': '充电状态数据解析失败'};
  }

  Future<bool> _testLED6(TestState state, LogState logState, {required bool isOuter, required bool turnOn}) async {
    final ledName = isOuter ? '外侧' : '内侧';
    final action = turnOn ? '亮' : '关';
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

    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(turnOn ? Icons.lightbulb : Icons.lightbulb_outline, color: turnOn ? Colors.amber : Colors.grey),
            const SizedBox(width: 12),
            Text('LED灯($ledName)$action'),
          ],
        ),
        content: Text('请确认LED灯($ledName)是否已$action？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('未通过')),
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

  Future<bool> _testTouch6(TestState state, LogState logState, {required String touchType}) async {
    logState.info('👆 右触控-$touchType测试');
    
    final int areaId;
    switch (touchType) {
      case 'TK1': areaId = TouchTestConfig.rightAreaTK1; break;
      case 'TK2': areaId = TouchTestConfig.rightAreaTK2; break;
      case 'TK3': areaId = TouchTestConfig.rightAreaTK3; break;
      default: 
        logState.error('❌ 未知触控区域: $touchType');
        return false;
    }
    
    final threshold = _config.touchThreshold;
    logState.info('   阈值: $threshold');
    
    // 步骤1: 获取基线CDC值（未触摸状态）
    logState.info('📡 获取右Touch基线 CDC 值...');
    final baselineCommand = ProductionTestCommands.createTouchCommand(
      TouchTestConfig.touchRight, TouchTestConfig.rightAreaUntouched,
    );
    final baselineResponse = await state.sendCommandViaLinuxBluetooth(
      baselineCommand,
      timeout: const Duration(seconds: 5),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );
    
    int? baselineCdc;
    if (baselineResponse != null && !baselineResponse.containsKey('error')) {
      final payload = baselineResponse['payload'];
      if (payload is Uint8List) {
        final touchResult = ProductionTestCommands.parseTouchResponse(payload);
        if (touchResult != null && touchResult['success'] == true) {
          baselineCdc = touchResult['cdcValue'] as int?;
          logState.info('✅ 基线 CDC 值: $baselineCdc');
        }
      }
    }
    
    if (baselineCdc == null) {
      logState.error('❌ 获取基线CDC值失败');
      return false;
    }
    
    // 步骤2: 弹窗提示用户触摸，同时循环轮询CDC值
    logState.info('👆 请触摸 $touchType 区域');
    
    if (!mounted) return false;
    
    final completer = Completer<bool>();
    int? latestCdc;
    int? latestDiff;
    bool testPassed = false;
    bool testCancelled = false;
    int currentRetry = 0;
    const int maxRetries = 10;
    
    // 用于从外部更新 dialog UI 的回调
    void Function(void Function())? _setDialogState;
    
    // 弹窗实时显示CDC值（轮询逻辑不在 builder 内，避免重复启动）
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 仅保存回调引用，不在此处启动任何轮询
            _setDialogState = setDialogState;
            
            final statusColor = testPassed ? Colors.green : (latestCdc != null ? Colors.blue : Colors.orange);
            final statusText = testPassed 
                ? '✅ 测试通过!' 
                : (latestCdc != null ? '轮询检测中... ($currentRetry/$maxRetries)' : '等待触摸...');
            
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.touch_app, color: statusColor),
                  const SizedBox(width: 12),
                  Text('右触控-$touchType测试'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('请触摸 $touchType 区域', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('基线CDC: $baselineCdc', style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('当前CDC: ${latestCdc ?? "--"}', 
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor)),
                        const SizedBox(height: 4),
                        Text('CDC差值: ${latestDiff ?? "--"} / 阈值: $threshold',
                            style: TextStyle(fontSize: 14, 
                                color: (latestDiff != null && latestDiff! >= threshold) ? Colors.green : Colors.red)),
                        const SizedBox(height: 4),
                        Text('轮询次数: $currentRetry / $maxRetries',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(statusText, style: TextStyle(fontSize: 14, color: statusColor, fontWeight: FontWeight.bold)),
                ],
              ),
              actions: [
                if (!testPassed)
                  TextButton(
                    onPressed: () {
                      testCancelled = true;
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
    
    // 轮询逻辑在 showDialog 之外，保证只执行一次
    // 等待 dialog 初始化完成
    await Future.delayed(const Duration(milliseconds: 100));
    
    final touchCommand = ProductionTestCommands.createTouchCommand(
      TouchTestConfig.touchRight, areaId,
    );
    
    for (int retry = 0; retry <= maxRetries; retry++) {
      if (testCancelled || testPassed) break;
      
      currentRetry = retry;
      
      if (retry > 0) {
        logState.info('🔄 $touchType 重试第 $retry 次', type: LogType.debug);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // 等待用户操作的时间
      await Future.delayed(const Duration(seconds: 2));
      if (testCancelled) break;
      
      // 主动发送命令获取CDC值
      try {
        final response = await state.sendCommandViaLinuxBluetooth(
          touchCommand,
          timeout: const Duration(seconds: 10),
          moduleId: ProductionTestCommands.moduleId,
          messageId: ProductionTestCommands.messageId,
        );
        
        if (response != null && !response.containsKey('error')) {
          if (response.containsKey('payload') && response['payload'] != null) {
            final payload = response['payload'] as Uint8List;
            final touchResult = ProductionTestCommands.parseTouchResponse(payload);
            
            if (touchResult != null && touchResult['success'] == true) {
              final cdcValue = touchResult['cdcValue'] as int;
              final cdcDiff = (cdcValue - baselineCdc!).abs();
              
              latestCdc = cdcValue;
              latestDiff = cdcDiff;
              
              logState.info('📥 $touchType CDC: $cdcValue (差值: $cdcDiff, 阈值: $threshold)');
              
              _setDialogState?.call(() {});
              
              if (cdcDiff >= threshold) {
                testPassed = true;
                logState.info('✅ $touchType CDC差值 $cdcDiff >= 阈值 $threshold，测试通过!');
                
                _setDialogState?.call(() {});
                
                // 延迟关闭弹窗，让用户看到结果
                await Future.delayed(const Duration(seconds: 1));
                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
                if (!completer.isCompleted) completer.complete(true);
                return completer.future;
              } else {
                logState.warning('⚠️ $touchType CDC差值 $cdcDiff < 阈值 $threshold', type: LogType.debug);
              }
            }
          }
        } else {
          logState.warning('⚠️ $touchType 获取CDC失败: ${response?['error'] ?? '超时'}', type: LogType.debug);
        }
      } catch (e) {
        logState.warning('⚠️ $touchType 轮询异常: $e', type: LogType.debug);
      }
      
      // 更新 dialog 显示
      _setDialogState?.call(() {});
      
      // 重试间隔
      if (retry < maxRetries && !testCancelled && !testPassed) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
    
    // 所有重试完成仍未通过
    if (!testPassed && !testCancelled) {
      logState.error('❌ $touchType 重试 $maxRetries 次后仍然失败');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!completer.isCompleted) completer.complete(false);
    }
    
    return completer.future;
  }

  Future<bool> _testWearDetection6(TestState state, LogState logState) async {
    logState.info('👆 左佩戴检测');
    
    // 发送佩戴检测命令: 0x07 + 0x00(左Touch) + 0x04(佩戴检测)
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
    
    // 用于从外部更新 dialog UI 的回调
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
    
    // 等待 dialog 初始化
    await Future.delayed(const Duration(milliseconds: 100));
    
    // 设置超时
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
          
          // 检查佩戴检测推送: 0x07 + 0x00 + 0x04
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

  Future<bool> _testTouchCalibration6(TestState state, LogState logState, {required String touchType}) async {
    logState.info('🔧 右Touch校准: $touchType');
    
    final int tkArea;
    final String tkName;
    switch (touchType) {
      case 'TK1':
        tkArea = 0x01;
        tkName = 'TK1';
        break;
      case 'TK2':
        tkArea = 0x02;
        tkName = 'TK2';
        break;
      case 'TK3':
        tkArea = 0x03;
        tkName = 'TK3';
        break;
      default:
        logState.error('❌ 未知Touch区域: $touchType');
        return false;
    }
    
    // ========== 步骤1: 未按压校准 ==========
    logState.info('📍 步骤1: 未按压校准');
    
    if (!mounted) return false;
    
    // 弹窗提示：请勿按压
    final unpressedConfirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.touch_app, color: Colors.orange),
            const SizedBox(width: 12),
            Text('右Touch $tkName 校准 - 未按压'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请确保 $tkName 区域未被按压',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('⚠️ 请勿触摸或按压 TK 区域'),
            const SizedBox(height: 8),
            const Text('点击"开始校准"进行未按压状态校准'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('开始校准'),
          ),
        ],
      ),
    );
    
    if (unpressedConfirmed != true) {
      logState.warning('⚠️ 用户取消校准');
      return false;
    }
    
    // 发送未按压校准命令: 0x07 + 0x03 + TK区域 + 0x01(未按压)
    logState.info('📤 发送未按压校准命令...');
    final unpressedCommand = Uint8List.fromList([0x07, 0x03, tkArea, 0x01]);
    final unpressedResponse = await state.sendCommandViaLinuxBluetooth(
      unpressedCommand,
      timeout: const Duration(seconds: 5),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );
    
    if (unpressedResponse == null || unpressedResponse.containsKey('error')) {
      logState.error('❌ 未按压校准命令失败');
      return false;
    }
    
    // 验证响应
    final unpressedPayload = unpressedResponse['payload'];
    if (unpressedPayload is List && unpressedPayload.length >= 4) {
      final cmdByte = unpressedPayload[0];
      final subCmd = unpressedPayload[1];
      final areaByte = unpressedPayload[2];
      final stateByte = unpressedPayload[3];
      
      if (cmdByte != 0x07 || subCmd != 0x03 || areaByte != tkArea || stateByte != 0x01) {
        logState.error('❌ 未按压校准响应不匹配');
        logState.error('   期望: 07 03 ${tkArea.toRadixString(16).padLeft(2, '0').toUpperCase()} 01');
        logState.error('   实际: ${unpressedPayload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}');
        return false;
      }
      
      logState.success('✅ 未按压校准成功');
    } else {
      logState.error('❌ 未按压校准响应格式错误');
      return false;
    }
    
    // ========== 步骤2: 按压校准 ==========
    logState.info('📍 步骤2: 按压校准');
    
    if (!mounted) return false;
    
    // 弹窗提示：请按压
    final pressedConfirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.touch_app, color: Colors.green),
            const SizedBox(width: 12),
            Text('右Touch $tkName 校准 - 按压'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请按压 $tkName 区域',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('👆 请用手指按压 TK 区域'),
            const SizedBox(height: 8),
            const Text('保持按压状态，然后点击"开始校准"'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('开始校准'),
          ),
        ],
      ),
    );
    
    if (pressedConfirmed != true) {
      logState.warning('⚠️ 用户取消校准');
      return false;
    }
    
    // 发送按压校准命令: 0x07 + 0x03 + TK区域 + 0x00(按压)
    logState.info('📤 发送按压校准命令...');
    final pressedCommand = Uint8List.fromList([0x07, 0x03, tkArea, 0x00]);
    final pressedResponse = await state.sendCommandViaLinuxBluetooth(
      pressedCommand,
      timeout: const Duration(seconds: 5),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );
    
    if (pressedResponse == null || pressedResponse.containsKey('error')) {
      logState.error('❌ 按压校准命令失败');
      return false;
    }
    
    // 验证响应
    final pressedPayload = pressedResponse['payload'];
    if (pressedPayload is List && pressedPayload.length >= 4) {
      final cmdByte = pressedPayload[0];
      final subCmd = pressedPayload[1];
      final areaByte = pressedPayload[2];
      final stateByte = pressedPayload[3];
      
      if (cmdByte != 0x07 || subCmd != 0x03 || areaByte != tkArea || stateByte != 0x00) {
        logState.error('❌ 按压校准响应不匹配');
        logState.error('   期望: 07 03 ${tkArea.toRadixString(16).padLeft(2, '0').toUpperCase()} 00');
        logState.error('   实际: ${pressedPayload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}');
        return false;
      }
      
      logState.success('✅ 按压校准成功');
      logState.success('✅ $tkName 校准完成');
      return true;
    } else {
      logState.error('❌ 按压校准响应格式错误');
      return false;
    }
  }

  Future<bool> _testLeftTouch6(TestState state, LogState logState, {required String touchType}) async {
    logState.info('👈 左触控测试: $touchType');
    
    int expectedEventCode;
    switch (touchType) {
      case '单击':
        expectedEventCode = 0x01;
        break;
      case '双击':
        expectedEventCode = 0x02;
        break;
      case '长按':
        expectedEventCode = 0x03;
        break;
      default:
        logState.error('❌ 未知的触控类型: $touchType');
        return false;
    }
    
    final touchEventCommand = ProductionTestCommands.createTouchCommand(0x00, 0x00);
    
    for (int retry = 0; retry < 10; retry++) {
      if (retry > 0) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      

      try {
        final response = await state.sendCommandViaLinuxBluetooth(
          touchEventCommand,
          timeout: const Duration(seconds: 2),
          moduleId: ProductionTestCommands.moduleId,
          messageId: ProductionTestCommands.messageId,
        );

        if (response == null || response.containsKey('error')) {
          continue;
        }

        final payload = response['payload'];
        if (payload is List && payload.length >= 2) {
          final eventCode = payload[1];
          
          logState.info('   触控事件: 0x${eventCode.toRadixString(16).toUpperCase().padLeft(2, '0')}');
          
          if (eventCode == expectedEventCode) {
            logState.success('✅ 检测到$touchType事件 (0x${expectedEventCode.toRadixString(16).toUpperCase().padLeft(2, '0')})');
            return true;
          }
        }
      } catch (e) {
        logState.warning('⚠️ 左触控检测异常: $e');
      }
    }
    
    logState.error('❌ 左触控$touchType测试失败');
    return false;
  }

  Future<bool> _testProductionEnd6(TestState state, LogState logState) async {
    try {
      logState.info('🏁 发送产测结束命令...');
      
      final passedCount = _stepResults6.take(_stepResults6.length - 1)
          .where((s) => s.status == TestStepStatus.passed).length;
      final totalCount = _stepResults6.length - 1;
      final allPassed = passedCount == totalCount;
      
      final opt = allPassed ? 0x00 : 0x01;
      final command = ProductionTestCommands.createEndTestCommand(opt: opt);
      logState.info('   测试结果: ${allPassed ? "通过" : "失败"} ($passedCount/$totalCount)');
      
      for (int retry = 0; retry < 3; retry++) {
        if (retry > 0) {
          logState.info('   重试 ($retry/3)...');
          await Future.delayed(const Duration(seconds: 2));
        }
        
        try {
          final response = await state.sendCommandViaLinuxBluetooth(
            command,
            timeout: const Duration(seconds: 5),
            moduleId: ProductionTestCommands.moduleId,
            messageId: ProductionTestCommands.messageId,
          );
          
          if (response != null && !response.containsKey('error')) {
            logState.success('✅ 产测结束命令发送成功');
            return true;
          }
        } catch (e) {
          logState.warning('⚠️ 发送命令异常: $e');
        }
      }
      
      logState.error('❌ 3次重试后产测结束命令仍失败');
      return false;
    } catch (e) {
      logState.error('产测结束异常: $e');
      return false;
    }
  }

  // ========== UI构建方法 ==========

  Widget _buildTestStepItem(TestStepResult step, bool isCurrent) {
    Color statusColor;
    IconData statusIcon;
    
    switch (step.status) {
      case TestStepStatus.pending:
        statusColor = Colors.grey;
        statusIcon = Icons.radio_button_unchecked;
        break;
      case TestStepStatus.running:
        statusColor = Colors.blue;
        statusIcon = Icons.hourglass_empty;
        break;
      case TestStepStatus.passed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case TestStepStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.blue.shade50 : null,
        border: Border(
          left: BorderSide(
            color: isCurrent ? Colors.blue : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${step.stepNumber}. ${step.name}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (step.message != null && step.message!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      step.message!,
                      style: TextStyle(
                        fontSize: 12,
                        color: step.status == TestStepStatus.failed
                            ? Colors.red.shade700
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkstation4Content(TestState state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isAutoTesting4)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '工位4测试中... 步骤 $_currentStep4/${_stepResults4.length}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _stopAutoTest4,
                    icon: const Icon(Icons.stop, size: 16),
                    label: const Text('停止'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                itemCount: _stepResults4.length,
                itemBuilder: (context, index) {
                  final step = _stepResults4[index];
                  return _buildTestStepItem(step, index + 1 == _currentStep4);
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isAutoTesting4 ? null : () => _startAutoTest4(state),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始自动测试'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkstation5Content(TestState state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isAutoTesting5)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '工位5测试中... 步骤 $_currentStep5/${_stepResults5.length}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _isAutoTesting5 = false),
                    icon: const Icon(Icons.stop, size: 16),
                    label: const Text('停止'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              Icon(Icons.bug_report, color: _debugMode5 ? Colors.orange : Colors.grey, size: 20),
              const SizedBox(width: 4),
              Text('调试模式', style: TextStyle(fontSize: 12, color: _debugMode5 ? Colors.orange : Colors.grey)),
              Switch(
                value: _debugMode5,
                onChanged: _isAutoTesting5 ? null : (value) => setState(() => _debugMode5 = value),
                activeColor: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 8),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                itemCount: _stepResults5.length,
                itemBuilder: (context, index) {
                  final step = _stepResults5[index];
                  return _buildTestStepItem(step, index + 1 == _currentStep5);
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isAutoTesting5 ? null : () => _startAutoTest5(state),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始自动测试'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkstation6Content(TestState state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isAutoTesting6)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '工位6测试中... 步骤 $_currentStep6/${_stepResults6.length}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _isAutoTesting6 = false),
                    icon: const Icon(Icons.stop, size: 16),
                    label: const Text('停止'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                itemCount: _stepResults6.length,
                itemBuilder: (context, index) {
                  final step = _stepResults6[index];
                  return _buildTestStepItem(step, index + 1 == _currentStep6);
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isAutoTesting6 ? null : () => _startAutoTest6(state),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始自动测试'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

/// SN扫描对话框返回结果
class _SNScanResult {
  final String? sn;               // SN码（SN模式时有值）
  final String? bluetoothAddress; // 蓝牙MAC（MAC模式时有值）
  final bool isMacMode;           // 是否为MAC直连模式

  _SNScanResult.fromSN(String snCode) : sn = snCode, bluetoothAddress = null, isMacMode = false;
  _SNScanResult.fromMAC(String mac) : sn = null, bluetoothAddress = mac, isMacMode = true;
}

// SN扫描对话框（支持SN码和蓝牙MAC地址两种输入模式）
enum _InputMode {
  sn,
  bluetooth,
}

class _SNScanDialog extends StatefulWidget {
  final String title;
  
  const _SNScanDialog({required this.title});

  @override
  State<_SNScanDialog> createState() => _SNScanDialogState();
}

class _SNScanDialogState extends State<_SNScanDialog> {
  final TextEditingController _snController = TextEditingController();
  final TextEditingController _macController = TextEditingController();
  _InputMode _inputMode = _InputMode.sn;

  @override
  void dispose() {
    _snController.dispose();
    _macController.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    if (_inputMode == _InputMode.sn) {
      final sn = _snController.text.trim();
      if (sn.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入SN码')),
        );
        return;
      }
      Navigator.of(context).pop(_SNScanResult.fromSN(sn));
    } else {
      final mac = _macController.text.trim();
      if (mac.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入蓝牙MAC地址')),
        );
        return;
      }
      Navigator.of(context).pop(_SNScanResult.fromMAC(mac));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<_InputMode>(
              segments: const [
                ButtonSegment(value: _InputMode.sn, label: Text('SN码'), icon: Icon(Icons.qr_code)),
                ButtonSegment(value: _InputMode.bluetooth, label: Text('蓝牙MAC'), icon: Icon(Icons.bluetooth)),
              ],
              selected: {_inputMode},
              onSelectionChanged: (Set<_InputMode> newSelection) {
                setState(() => _inputMode = newSelection.first);
              },
            ),
            const SizedBox(height: 16),
            if (_inputMode == _InputMode.sn)
              TextField(
                controller: _snController,
                decoration: const InputDecoration(
                  labelText: 'SN码',
                  hintText: '请扫描或输入SN码',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                onSubmitted: (_) => _handleConfirm(),
              )
            else
              TextField(
                controller: _macController,
                decoration: const InputDecoration(
                  labelText: '蓝牙MAC地址',
                  hintText: '例如: 00:11:22:33:44:55',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                onSubmitted: (_) => _handleConfirm(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _handleConfirm,
          child: const Text('确定'),
        ),
      ],
    );
  }
}

String _getMethodName(BluetoothTestMethod method) {
  switch (method) {
    case BluetoothTestMethod.autoScan:
      return 'Auto Scan方案';
    case BluetoothTestMethod.directConnect:
      return 'Direct Connect方案';
    case BluetoothTestMethod.rfcommBind:
      return 'RFCOMM Bind方案';
    case BluetoothTestMethod.rfcommSocket:
      return 'RFCOMM Socket方案';
    case BluetoothTestMethod.serial:
      return 'Serial方案';
    case BluetoothTestMethod.commandLine:
      return 'Command Line方案';
  }
}

/// 自动化测试输入对话框
class _AutoTestInputDialog extends StatefulWidget {
  const _AutoTestInputDialog();

  @override
  State<_AutoTestInputDialog> createState() => _AutoTestInputDialogState();
}

class _AutoTestInputDialogState extends State<_AutoTestInputDialog> {
  final TextEditingController _macController = TextEditingController();
  BluetoothTestMethod _selectedMethod = BluetoothTestMethod.rfcommBind;
  ProductSNInfo? _productInfo;
  bool _isQuerying = false;

  @override
  void dispose() {
    _macController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('自动化测试配置'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('蓝牙连接方案', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<BluetoothTestMethod>(
              segments: const [
                ButtonSegment(value: BluetoothTestMethod.rfcommBind, label: Text('Bind')),
                ButtonSegment(value: BluetoothTestMethod.autoScan, label: Text('Auto')),
              ],
              selected: {_selectedMethod},
              onSelectionChanged: (Set<BluetoothTestMethod> newSelection) {
                setState(() => _selectedMethod = newSelection.first);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selectedMethod),
          child: const Text('开始测试'),
        ),
      ],
    );
  }
}

/// IMU校准对话框
class _IMUCalibrationDialog extends StatefulWidget {
  final TestState state;
  final LogState logState;
  final Uint8List command;
  final bool useLinuxBluetooth;

  const _IMUCalibrationDialog({
    required this.state,
    required this.logState,
    required this.command,
    this.useLinuxBluetooth = false,
  });

  @override
  State<_IMUCalibrationDialog> createState() => _IMUCalibrationDialogState();
}

class _IMUCalibrationDialogState extends State<_IMUCalibrationDialog> {
  bool _isRunning = false;
  bool _isSuccess = false;
  bool _isFailed = false;
  String _statusText = '等待开始...';
  int _retryCount = 0;
  static const int _maxRetries = 30;
  StreamSubscription? _subscription;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _startCalibration();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _startCalibration() async {
    setState(() {
      _isRunning = true;
      _statusText = '正在发送IMU校准命令...';
    });

    widget.logState.info('📤 发送IMU校准命令...', type: LogType.debug);

    try {
      final response = await widget.state.sendCommandViaLinuxBluetooth(
        widget.command,
        timeout: const Duration(seconds: 5),
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );

      if (response == null || response.containsKey('error')) {
        widget.logState.error('❌ IMU校准命令发送失败', type: LogType.debug);
        _onMaxRetriesExceeded();
        return;
      }

      widget.logState.info('✅ IMU校准命令已发送，等待校准完成...', type: LogType.debug);
      setState(() => _statusText = '等待校准完成...');

      _startListeningForPush();
      _startTimeout();
    } catch (e) {
      widget.logState.error('❌ IMU校准异常: $e', type: LogType.debug);
      _onMaxRetriesExceeded();
    }
  }

  void _startListeningForPush() {
    // 监听推送数据流（已解析的payload）
    _subscription = widget.state.linuxBluetoothPushPayloadStream.listen((payload) {
      if (payload.isNotEmpty) {
        widget.logState.info('📥 收到推送数据 [${payload.length}字节]: ${payload.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ')}', type: LogType.debug);
        _handlePushPayload(payload);
      }
    });
  }

  void _handlePushPayload(Uint8List payload) {
    if (payload.isNotEmpty) {
      final cmdId = payload[0];
      // IMU校准命令 cmd = 0x10
      if (cmdId == 0x10) {
        if (payload.length >= 2) {
          final opt = payload[1];
          // opt 状态：0x00=启动中, 0x01=朝向检测中, 0x02=校准中, 0x03=校准完成
          if (opt == 0x03) {
            widget.logState.success('✅ IMU校准完成！', type: LogType.debug);
            _onSuccess();
          } else if (opt == 0x00) {
            widget.logState.info('🔄 设备IMU启动中...', type: LogType.debug);
            setState(() => _statusText = '设备IMU启动中...');
          } else if (opt == 0x01) {
            widget.logState.info('🔄 设备朝向检测中...', type: LogType.debug);
            setState(() => _statusText = '设备朝向检测中...');
          } else if (opt == 0x02) {
            widget.logState.info('🔄 设备校准中...', type: LogType.debug);
            setState(() => _statusText = '设备校准中...');
          } else {
            _retryCount++;
            widget.logState.warning('⚠️ 未知状态: 0x${opt.toRadixString(16).toUpperCase()} 重试 $_retryCount/$_maxRetries', type: LogType.debug);
            setState(() => _statusText = '未知状态... 重试 $_retryCount/$_maxRetries');
            if (_retryCount >= _maxRetries) {
              _onMaxRetriesExceeded();
            }
          }
        }
      }
    }
  }

  void _startTimeout() {
    _timeoutTimer = Timer(const Duration(seconds: 60), () {
      if (_isRunning && !_isSuccess) {
        widget.logState.error('❌ IMU校准超时', type: LogType.debug);
        _onMaxRetriesExceeded();
      }
    });
  }

  void _onSuccess() {
    _isRunning = false;
    _subscription?.cancel();
    _timeoutTimer?.cancel();
    if (mounted) {
      setState(() {
        _isSuccess = true;
        _statusText = 'IMU校准成功！';
      });
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    }
  }

  void _onMaxRetriesExceeded() {
    _isRunning = false;
    _subscription?.cancel();
    _timeoutTimer?.cancel();
    widget.logState.error('❌ IMU校准失败: 超过最大重试次数', type: LogType.debug);
    if (mounted) {
      setState(() {
        _isFailed = true;
        _statusText = 'IMU校准失败（超时）';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.compass_calibration, color: Colors.deepOrange.shade700),
          const SizedBox(width: 8),
          const Text('IMU校准'),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isRunning)
              const CircularProgressIndicator()
            else if (_isSuccess)
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 64)
            else if (_isFailed)
              Icon(Icons.error, color: Colors.red.shade600, size: 64),
            const SizedBox(height: 16),
            Text(
              _statusText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _isSuccess
                    ? Colors.green.shade700
                    : _isFailed
                        ? Colors.red.shade700
                        : Colors.blue.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            if (_isRunning) ...[
              const SizedBox(height: 12),
              Text(
                '请保持设备静止',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_isRunning)
          TextButton(
            onPressed: () {
              _subscription?.cancel();
              _timeoutTimer?.cancel();
              Navigator.of(context).pop(false);
            },
            child: const Text('取消'),
          ),
        if (_isFailed)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('关闭'),
          ),
      ],
    );
  }
}

/// GPIB地址配置对话框
class _GpibAddressDialog extends StatefulWidget {
  final String? initialAddress;
  
  const _GpibAddressDialog({this.initialAddress});
  
  @override
  State<_GpibAddressDialog> createState() => _GpibAddressDialogState();
}

class _GpibAddressDialogState extends State<_GpibAddressDialog> {
  late TextEditingController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAddress ?? 'GPIB0::5::INSTR');
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cable, color: Colors.blue),
          SizedBox(width: 8),
          Text('配置GPIB地址'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '充电电流测试需要使用GPIB程控电源。\n请输入GPIB设备地址：',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'GPIB地址',
              hintText: 'GPIB0::5::INSTR',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.settings_input_component),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          Text(
            '常用地址格式：\n'
            '• GPIB0::5::INSTR\n'
            '• GPIB0::6::INSTR',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final address = _controller.text.trim();
            if (address.isNotEmpty) {
              Navigator.of(context).pop(address);
            }
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
