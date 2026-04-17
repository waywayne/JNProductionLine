import 'dart:async';
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
import '../models/touch_test_step.dart';
import '../services/gtp_protocol.dart';
import 'sn_input_dialog.dart';
import 'bluetooth_test_options_dialog.dart';

/// 超声前整机产测自动测试组件 - 支持三个工位
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
  
  // 工位1状态
  bool _isAutoTesting1 = false;
  int _currentStep1 = 0;
  final List<TestStepResult> _stepResults1 = [];
  ProductSNInfo? _productInfo1;
  String? _deviceIP1;
  String? _scannedSN1;
  BluetoothTestMethod _selectedMethod1 = BluetoothTestMethod.rfcommBind;
  final BydMesService _mesService1 = BydMesService();
  
  // 工位3状态
  bool _isAutoTesting3 = false;
  int _currentStep3 = 0;
  final List<TestStepResult> _stepResults3 = [];
  ProductSNInfo? _productInfo3;
  String? _scannedSN3;
  BluetoothTestMethod _selectedMethod3 = BluetoothTestMethod.rfcommBind;
  final BydMesService _mesService3 = BydMesService();
  final ProductionConfig _config = ProductionConfig();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeSteps1();
    _initializeSteps3();
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
                          '超声前整机产测',
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
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.wifi),
                          text: '工位1: 射频图像',
                        ),
                        Tab(
                          icon: Icon(Icons.volume_up),
                          text: '工位2: 音频测试',
                        ),
                        Tab(
                          icon: Icon(Icons.power),
                          text: '工位3: 电源外设',
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
                    // 工位2: 音频测试（待实现）
                    _buildWorkstation2Content(state),
                    // 工位3: 电源外设测试
                    _buildWorkstation3Content(state),
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
          
          // 蓝牙测试方案按钮区域
          if (!_isAutoTesting1) ...[
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 调试模式开关
              Row(
                children: [
                  Icon(Icons.bug_report, color: _debugMode1 ? Colors.red : Colors.grey, size: 20),
                  const SizedBox(width: 4),
                  Text('调试模式', style: TextStyle(fontSize: 12, color: _debugMode1 ? Colors.red : Colors.grey)),
                  Switch(
                    value: _debugMode1,
                    onChanged: _isAutoTesting1 ? null : (value) => setState(() => _debugMode1 = value),
                    activeColor: Colors.red,
                  ),
                ],
              ),
              Row(
                children: [
              if (!_isAutoTesting1) ...[
                // 蓝牙方案选择
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<BluetoothTestMethod>(
                          value: _selectedMethod1,
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
                              setState(() => _selectedMethod1 = value);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
              // 调试模式开关
              Row(
                children: [
                  Icon(Icons.bug_report, color: _debugMode3 ? Colors.red : Colors.grey, size: 20),
                  const SizedBox(width: 4),
                  Text('调试模式', style: TextStyle(fontSize: 12, color: _debugMode3 ? Colors.red : Colors.grey)),
                  Switch(
                    value: _debugMode3,
                    onChanged: _isAutoTesting3 ? null : (value) => setState(() => _debugMode3 = value),
                    activeColor: Colors.red,
                  ),
                ],
              ),
              Row(
                children: [
              if (!_isAutoTesting3) ...[
                // 蓝牙方案选择
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<BluetoothTestMethod>(
                      value: _selectedMethod3,
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
                          setState(() => _selectedMethod3 = value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _startAutoTest3(state),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始自动测试'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ] else
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
      logState.info('🔵 目标蓝牙地址: $bluetoothAddress');
      logState.info('🔗 使用 ${_getMethodName(_selectedMethod1)}');
      
      bool success = false;
      
      switch (_selectedMethod1) {
        case BluetoothTestMethod.autoScan:
          success = await state.testBluetoothMethod1AutoScan(deviceAddress: bluetoothAddress, channel: 5, uuid: '7033');
          break;
        case BluetoothTestMethod.directConnect:
          success = await state.testBluetoothMethod2DirectConnect(deviceAddress: bluetoothAddress, channel: 5, uuid: '7033');
          break;
        case BluetoothTestMethod.rfcommBind:
          success = await state.testBluetoothMethod3RfcommBind(deviceAddress: bluetoothAddress, channel: 5, uuid: '7033');
          break;
        case BluetoothTestMethod.rfcommSocket:
          success = await state.testBluetoothMethod4RfcommSocket(deviceAddress: bluetoothAddress, channel: 5, uuid: '7033');
          break;
        case BluetoothTestMethod.serial:
          success = await state.testBluetoothMethod5Serial(deviceAddress: bluetoothAddress, channel: 5, uuid: '7033');
          break;
        case BluetoothTestMethod.commandLine:
          success = await state.testBluetoothMethod6CommandLine(deviceAddress: bluetoothAddress, channel: 5, uuid: '7033');
          break;
      }
      
      return success;
    } catch (e) {
      logState.error('蓝牙连接测试失败: $e');
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
            final currentResult = await _testChargingCurrent3(state, logState);
            success = currentResult['success'] as bool;
            message = currentResult['message'] as String?;
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
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  // ========== 工位3: 蓝牙连接测试（与工位1一致） ==========
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
      logState.info('🔗 使用 ${_getMethodName(_selectedMethod3)}');
      
      bool success = false;
      
      switch (_selectedMethod3) {
        case BluetoothTestMethod.autoScan:
          success = await state.testBluetoothMethod1AutoScan(deviceAddress: bluetoothAddress, channel: 5, uuid: '7033');
          break;
        case BluetoothTestMethod.directConnect:
          success = await state.testBluetoothMethod2DirectConnect(deviceAddress: bluetoothAddress, channel: 5, uuid: '7033');
          break;
        case BluetoothTestMethod.rfcommBind:
          success = await state.testBluetoothMethod3RfcommBind(deviceAddress: bluetoothAddress, channel: 5, uuid: '7033');
          break;
        case BluetoothTestMethod.rfcommSocket:
          success = await state.testBluetoothMethod4RfcommSocket(deviceAddress: bluetoothAddress, channel: 5, uuid: '7033');
          break;
        case BluetoothTestMethod.serial:
          success = await state.testBluetoothMethod5Serial(deviceAddress: bluetoothAddress, channel: 5, uuid: '7033');
          break;
        case BluetoothTestMethod.commandLine:
          success = await state.testBluetoothMethod6CommandLine(deviceAddress: bluetoothAddress, channel: 5, uuid: '7033');
          break;
      }

      if (success) {
        logState.info('✅ 蓝牙连接成功');
      }

      return success;
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

  // ========== 工位3: 充电电流测试 ==========
  Future<Map<String, dynamic>> _testChargingCurrent3(TestState state, LogState logState) async {
    logState.info('⚡ 充电电流测试');
    
    // 发送充电状态命令 (0x03)，设备返回格式：
    // [CMD 0x03] + [充电状态枚举] + [故障码] + [2字节充电电流 mA, little-endian]
    final command = ProductionTestCommands.createGetChargeStatusCommand();
    final response = await state.sendCommandViaLinuxBluetooth(
      command,
      timeout: const Duration(seconds: 5),
      moduleId: ProductionTestCommands.moduleId,
      messageId: ProductionTestCommands.messageId,
    );

    if (response == null || response.containsKey('error')) {
      return {'success': false, 'message': '获取充电电流失败'};
    }

    final payload = response['payload'];
    if (payload is List && payload.length >= 5) {
      // 扩展格式：[CMD] + [mode] + [fault] + [current_lo] + [current_hi]
      final payloadBytes = Uint8List.fromList(payload.cast<int>());
      final byteData = ByteData.sublistView(payloadBytes);
      final currentMa = byteData.getUint16(3, Endian.little).toDouble();
      
      final threshold = _config.minChargingCurrentMa;
      final success = currentMa >= threshold;
      
      logState.info('   充电电流: ${currentMa.toStringAsFixed(0)}mA (阈值: ≥${threshold.toStringAsFixed(0)}mA)');
      
      return {
        'success': success,
        'message': '充电电流: ${currentMa.toStringAsFixed(0)}mA ${success ? "✅" : "❌ <${threshold.toStringAsFixed(0)}mA"}',
      };
    } else if (payload is List && payload.length >= 3) {
      // 旧格式：[CMD] + [mode] + [fault]，无电流数据
      logState.warning('   充电状态响应中未包含电流数据 (payload长度: ${payload.length})');
      logState.info('   提示: 设备固件可能需要升级以支持充电电流上报');
      return {'success': false, 'message': '设备未返回充电电流数据 (需固件支持)'};
    }

    return {'success': false, 'message': '充电电流数据解析失败'};
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
class _SNScanDialog extends StatefulWidget {
  final String title;
  
  const _SNScanDialog({required this.title});

  @override
  State<_SNScanDialog> createState() => _SNScanDialogState();
}

class _SNScanDialogState extends State<_SNScanDialog> {
  final TextEditingController _snController = TextEditingController();
  final TextEditingController _macController = TextEditingController();
  bool _isMacMode = false;
  String? _errorMessage;

  @override
  void dispose() {
    _snController.dispose();
    _macController.dispose();
    super.dispose();
  }

  bool _isValidBluetoothAddress(String address) {
    final regex = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');
    return regex.hasMatch(address);
  }

  void _handleConfirm() {
    if (_isMacMode) {
      final mac = _macController.text.trim();
      if (mac.isEmpty) {
        setState(() => _errorMessage = '请输入蓝牙 MAC 地址');
        return;
      }
      if (!_isValidBluetoothAddress(mac)) {
        setState(() => _errorMessage = 'MAC 地址格式不正确，例如: 48:08:EB:60:00:60');
        return;
      }
      final formatted = mac.toUpperCase().replaceAll('-', ':');
      Navigator.of(context).pop(_SNScanResult.fromMAC(formatted));
    } else {
      final sn = _snController.text.trim();
      if (sn.isEmpty) {
        setState(() => _errorMessage = '请输入或扫描 SN 码');
        return;
      }
      Navigator.of(context).pop(_SNScanResult.fromSN(sn));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isMacMode ? Icons.bluetooth : Icons.qr_code_scanner,
                    size: 28,
                    color: Colors.orange[700],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isMacMode ? '输入蓝牙 MAC 地址直接连接' : '请扫描或输入设备 SN 码',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // 模式切换
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() { _isMacMode = false; _errorMessage = null; }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isMacMode ? Colors.orange : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner, size: 16,
                              color: !_isMacMode ? Colors.white : Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text('SN 码',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: !_isMacMode ? Colors.white : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() { _isMacMode = true; _errorMessage = null; }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isMacMode ? Colors.blue : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bluetooth, size: 16,
                              color: _isMacMode ? Colors.white : Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text('蓝牙 MAC',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _isMacMode ? Colors.white : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // 输入框
            if (_isMacMode)
              TextField(
                controller: _macController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '蓝牙 MAC 地址',
                  hintText: '例如: 48:08:EB:60:00:60',
                  prefixIcon: const Icon(Icons.bluetooth),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  errorText: _errorMessage,
                  helperText: '直接输入蓝牙 MAC 地址，跳过 SN 查询',
                ),
                onSubmitted: (_) => _handleConfirm(),
              )
            else
              TextField(
                controller: _snController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'SN 码',
                  hintText: '扫码枪扫描或手动输入',
                  prefixIcon: const Icon(Icons.tag),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  errorText: _errorMessage,
                  helperText: '输入 SN 码后将通过接口查询蓝牙地址',
                ),
                onSubmitted: (_) => _handleConfirm(),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _handleConfirm,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(_isMacMode ? '直接连接' : '开始测试'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isMacMode ? Colors.blue : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 自动测试选项
class _AutoTestOptions {
  final ProductSNInfo productInfo;
  final BluetoothTestMethod method;
  
  _AutoTestOptions({
    required this.productInfo,
    required this.method,
  });
}

// 自动测试输入对话框（支持 SN 或 MAC 地址输入 + 方案选择）
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
  bool _isLoading = false;
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
      setState(() => _errorMessage = 'MAC 地址格式不正确，例如: 48:08:EB:60:00:60');
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
          Icon(Icons.bluetooth, color: Colors.blue[700]),
          const SizedBox(width: 12),
          const Text('自动测试设置'),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 输入方式选择
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
                        Text(
                          '输入蓝牙 MAC 地址',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
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
              
              // 显示已获取的设备信息
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
                          Text(
                            '设备信息',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('SN: ${_productInfo!.snCode}', style: const TextStyle(fontSize: 13)),
                      Text('蓝牙: ${_productInfo!.bluetoothAddress}', style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                      if (_productInfo!.macAddress.isNotEmpty)
                        Text('WiFi: ${_productInfo!.macAddress}', style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
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
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(fontSize: 12, color: Colors.red[700]),
                        ),
                      ),
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
                        Text(
                          '选择连接方案',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
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
                        if (value != null) {
                          setState(() => _selectedMethod = value);
                        }
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
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('开始自动测试'),
        ),
      ],
    );
  }
}
