import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../models/log_state.dart';
import '../services/product_sn_api.dart';
import '../services/production_test_commands.dart';
import '../services/byd_mes_service.dart';
import '../services/linux_bluetooth_spp_service.dart';
import '../config/wifi_config.dart';
import '../config/production_config.dart';
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
  BluetoothTestMethod _selectedMethod1 = BluetoothTestMethod.rfcommBind;
  
  // 工位3状态
  bool _isAutoTesting3 = false;
  int _currentStep3 = 0;
  final List<TestStepResult> _stepResults3 = [];
  ProductSNInfo? _productInfo3;
  BluetoothTestMethod _selectedMethod3 = BluetoothTestMethod.rfcommBind;
  final BydMesService _mesService3 = BydMesService(station: 'STATION3');
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
      TestStepResult(stepNumber: 2, name: '产测开始', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 3, name: 'WIFI连接热点并获取IP', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 4, name: '光敏传感器测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 5, name: 'IMU传感器测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 6, name: '摄像头棋盘格测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 7, name: '产测结束', status: TestStepStatus.pending),
    ]);
  }

  void _initializeSteps3() {
    _stepResults3.clear();
    _stepResults3.addAll([
      TestStepResult(stepNumber: 1, name: '蓝牙连接', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 2, name: '产测开始', status: TestStepStatus.pending),
      // TestStepResult(stepNumber: 3, name: '设备电压测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 3, name: '电量检测测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 4, name: '充电状态测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 5, name: 'LED灯(外侧)开启', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 6, name: 'LED灯(外侧)关闭', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 7, name: 'LED灯(内侧)开启', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 8, name: 'LED灯(内侧)关闭', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 9, name: '右触控-TK1测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 10, name: '右触控-TK2测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 11, name: '右触控-TK3测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 12, name: '左触控-佩戴测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 13, name: '左触控-点击测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 14, name: '左触控-双击测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 15, name: '左触控-长按测试', status: TestStepStatus.pending),
      TestStepResult(stepNumber: 16, name: '结束产测', status: TestStepStatus.pending),
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
    
    // 先弹窗输入SN号或MAC地址，并选择连接方案
    if (!mounted) return;
    final options = await showDialog<_AutoTestOptions>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AutoTestInputDialog(defaultMethod: _selectedMethod1),
    );
    
    if (options == null) {
      logState.warning('用户取消输入');
      return;
    }
    
    _productInfo1 = options.productInfo;
    _selectedMethod1 = options.method;
    
    logState.info('获取到设备信息: SN=${_productInfo1!.snCode}');
    logState.info('蓝牙地址: ${_productInfo1!.bluetoothAddress}');
    logState.info('WiFi MAC: ${_productInfo1!.macAddress}');
    logState.info('连接方案: ${_getMethodName(_selectedMethod1)}');
    
    setState(() {
      _isAutoTesting1 = true;
      _currentStep1 = 0;
      _initializeSteps1();
    });

    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('🔧 工位1: 射频图像测试');
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

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
          case 1: // 产测开始
            logState.info('步骤2: 产测开始');
            success = await _testProductionStart(state, logState);
            message = success ? '产测开始命令发送成功' : '产测开始命令失败';
            break;
          case 2: // WIFI连接热点并获取IP
            logState.info('步骤3: WIFI连接热点并获取IP');
            success = await _testWiFiConnectionWithIP(state, logState);
            message = success ? 'WiFi连接成功，IP: $_deviceIP1' : 'WiFi连接失败';
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

      if (!_isAutoTesting1) break;

      setState(() {
        _stepResults1[i].status = success ? TestStepStatus.passed : TestStepStatus.failed;
        _stepResults1[i].message = message;
      });

      if (!success) {
        logState.error('❌ 步骤${i + 1}失败: $message');
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
    
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    if (passedCount == totalCount) {
      logState.info('🎉 工位1测试全部通过！($passedCount/$totalCount)');
    } else {
      logState.warning('⚠️ 工位1测试完成，通过 $passedCount/$totalCount 项');
    }
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
    
    if (!mounted) return;
    final options = await showDialog<_AutoTestOptions>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AutoTestInputDialog(defaultMethod: _selectedMethod3),
    );
    
    if (options == null) {
      logState.warning('用户取消输入');
      return;
    }
    
    _productInfo3 = options.productInfo;
    _selectedMethod3 = options.method;
    
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('🔧 工位3: 电源外设测试');
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('SN: ${_productInfo3!.snCode}');
    logState.info('蓝牙地址: ${_productInfo3!.bluetoothAddress}');
    logState.info('连接方案: ${_getMethodName(_selectedMethod3)}');
    
    setState(() {
      _isAutoTesting3 = true;
      _currentStep3 = 0;
      _initializeSteps3();
    });

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
          case 1: // 产测开始
            success = await _testProductionStart(state, logState);
            message = success ? '产测开始成功' : '产测开始失败';
            break;
          // case N: // 设备电压测试（已注释）
          //   final result = await _testVoltage3(state, logState);
          //   success = result['success'] as bool;
          //   message = result['message'] as String?;
          //   break;
          case 2: // 电量检测测试
            final result = await _testBattery3(state, logState);
            success = result['success'] as bool;
            message = result['message'] as String?;
            break;
          case 3: // 充电状态测试
            final result = await _testChargeStatus3(state, logState);
            success = result['success'] as bool;
            message = result['message'] as String?;
            break;
          case 4: // LED灯(外侧)开启
            success = await _testLED3(state, logState, isOuter: true, turnOn: true);
            message = success ? 'LED外侧开启成功' : 'LED外侧开启失败';
            break;
          case 5: // LED灯(外侧)关闭
            success = await _testLED3(state, logState, isOuter: true, turnOn: false);
            message = success ? 'LED外侧关闭成功' : 'LED外侧关闭失败';
            break;
          case 6: // LED灯(内侧)开启
            success = await _testLED3(state, logState, isOuter: false, turnOn: true);
            message = success ? 'LED内侧开启成功' : 'LED内侧开启失败';
            break;
          case 7: // LED灯(内侧)关闭
            success = await _testLED3(state, logState, isOuter: false, turnOn: false);
            message = success ? 'LED内侧关闭成功' : 'LED内侧关闭失败';
            break;
          case 8: // 右触控-TK1测试
            success = await _testTouch3(state, logState, touchType: 'TK1');
            message = success ? 'TK1测试通过' : 'TK1测试失败';
            break;
          case 9: // 右触控-TK2测试
            success = await _testTouch3(state, logState, touchType: 'TK2');
            message = success ? 'TK2测试通过' : 'TK2测试失败';
            break;
          case 10: // 右触控-TK3测试
            success = await _testTouch3(state, logState, touchType: 'TK3');
            message = success ? 'TK3测试通过' : 'TK3测试失败';
            break;
          case 11: // 左触控-佩戴测试
            success = await _testLeftTouch3(state, logState, touchType: 'wear');
            message = success ? '佩戴检测通过' : '佩戴检测失败';
            break;
          case 12: // 左触控-点击测试
            success = await _testLeftTouch3(state, logState, touchType: 'click');
            message = success ? '点击检测通过' : '点击检测失败';
            break;
          case 13: // 左触控-双击测试
            success = await _testLeftTouch3(state, logState, touchType: 'double_click');
            message = success ? '双击检测通过' : '双击检测失败';
            break;
          case 14: // 左触控-长按测试
            success = await _testLeftTouch3(state, logState, touchType: 'long_press');
            message = success ? '长按检测通过' : '长按检测失败';
            break;
          case 15: // 结束产测
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
        // 蓝牙连接成功后调用 BYD MES start
        // logState.info('📤 调用 BYD MES start...');
        // _mesService3.printConfig();
        // final mesResult = await _mesService3.start(_productInfo3!.snCode);
        // if (mesResult['success'] == true) {
        //   logState.info('✅ MES start 成功');
        // } else {
        //   logState.warning('⚠️ MES start 失败: ${mesResult['error']}');
        // }
      }

      return success;
    } catch (e) {
      logState.error('蓝牙连接测试失败: $e');
      return false;
    }
  }

  // ========== 工位3: 电压测试 ==========
  Future<Map<String, dynamic>> _testVoltage3(TestState state, LogState logState) async {
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

    final payload = response['payload'];
    if (payload is List && payload.length >= 5) {
      final voltageBytes = payload.sublist(1, 5).cast<int>();
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

  // ========== 工位3: 右触控测试 ==========
  Future<bool> _testTouch3(TestState state, LogState logState, {required String touchType}) async {
    logState.info('👆 右触控-$touchType测试');
    
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
            Text('请按住$touchType区域，确认阈值变化量超过${_config.touchThreshold}'),
            const SizedBox(height: 8),
            const Text('确认测试通过后点击"通过"按钮', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
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

  // ========== 工位3: 左触控测试 ==========
  Future<bool> _testLeftTouch3(TestState state, LogState logState, {required String touchType}) async {
    final touchName = {'wear': '佩戴', 'click': '点击', 'double_click': '双击', 'long_press': '长按'}[touchType] ?? touchType;
    logState.info('👆 左触控-$touchName测试');
    
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.touch_app, color: Colors.orange),
            const SizedBox(width: 12),
            Text('左触控-$touchName测试'),
          ],
        ),
        content: Text('请执行$touchName操作，确认设备响应正确后点击"通过"'),
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

  // ========== 工位3: 结束产测 ==========
  Future<bool> _testProductionEnd3(TestState state, LogState logState) async {
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
    final mesResult = await _mesService3.complete(_productInfo3!.snCode);
    if (mesResult['success'] == true) {
      logState.info('✅ MES complete 成功');
    } else {
      logState.warning('⚠️ MES complete 失败: ${mesResult['error']}');
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
