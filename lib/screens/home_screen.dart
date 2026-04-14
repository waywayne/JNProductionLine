import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../models/log_state.dart';
import '../models/ota_state.dart';
import '../widgets/menu_bar_widget.dart';
import '../widgets/factory_test_section.dart';
import '../widgets/serial_port_section.dart';
import '../widgets/log_console_section.dart';
import '../widgets/touch_test_dialog.dart';
import '../widgets/sensor_data_dialog.dart';
import '../widgets/imu_data_dialog.dart';
import '../widgets/led_test_dialog.dart';
import '../widgets/mic_test_dialog.dart';
import '../widgets/spk_test_dialog.dart';
import '../widgets/bluetooth_test_dialog.dart';
import '../widgets/wifi_test_steps_widget.dart';
import '../widgets/test_report_dialog.dart';
import '../widgets/gpib_detection_dialog.dart';
import '../widgets/image_quality_dialog.dart';
import '../widgets/test_mode_selector.dart';
import '../widgets/connection_selector.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  
  @override
  void initState() {
    super.initState();
    
    // 初始化时设置LogState和SN/MAC配置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final logState = context.read<LogState>();
      final testState = context.read<TestState>();
      final otaState = context.read<OTAState>();
      testState.setLogState(logState);
      testState.initializeSNMacConfig();
      
      // 初始化OTA状态
      otaState.setLogState(logState);
      otaState.setServices(testState.serialService, testState.linuxBtService);
      
      logState.info('应用启动');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, testState, child) {
        return Stack(
          children: [
            Scaffold(
              backgroundColor: Colors.white,
              body: Column(
                children: [
                  const MenuBarWidget(),
                  // 生产测试页面
                  Expanded(
                    child: _buildManualTestPage(),
                  ),
                ],
              ),
            ),
            
            // 测试报告弹窗（放在最底层）
            if (testState.showTestReportDialog)
              const TestReportDialog(),
            
            // GPIB检测弹窗
            if (testState.showGpibDialog)
              const GpibDetectionDialog(),
            
            // Touch测试弹窗（放在测试报告之上）
            if (testState.showTouchDialog)
              TouchTestDialog(
                isLeftTouch: testState.isLeftTouchDialog,
              ),
            
            // Sensor测试弹窗
            if (testState.showSensorDialog)
              const SensorDataDialog(),
            
            // 图片质量检测弹窗
            if (testState.showImageQualityDialog)
              const ImageQualityDialog(),
            
            // IMU测试弹窗
            if (testState.showIMUDialog)
              const IMUDataDialog(),
            
            // 佩戴检测提示弹窗
            if (testState.showWearDetectDialog)
              Dialog(
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app, color: Colors.orange, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        '佩戴检测',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '请用手指触摸左镜腿内侧的佩戴检测区域',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '检测到触摸后将自动通过',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => testState.cancelWearDetect(),
                        child: const Text('取消', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ),
            
            // LED测试弹窗
            if (testState.showLEDDialog && testState.currentLEDType != null)
              LEDTestDialog(
                ledType: testState.currentLEDType!,
                onTestPassed: () {
                  testState.closeLEDDialog();
                },
              ),
            
            // MIC测试弹窗
            if (testState.showMICDialog)
              const MICTestDialog(),
            
            // SPK测试弹窗
            if (testState.showSPKDialog)
              const SPKTestDialog(),
            
            // 蓝牙测试弹窗
            if (testState.showBluetoothDialog)
              const BluetoothTestDialog(),
            
            // WiFi测试弹窗
            if (testState.showWiFiDialog)
              Dialog(
                child: Container(
                  width: 600,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.wifi, color: Colors.blue, size: 32),
                          const SizedBox(width: 12),
                          const Text(
                            'WiFi测试进行中',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const WiFiTestStepsWidget(),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
  
  Widget _buildManualTestPage() {
    return Column(
      children: [
        // 顶部紧凑配置区
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Column(
            children: [
              // Test Mode Selector
              const TestModeSelector(),
              const SizedBox(height: 8),
              // Connection Selector (adapts based on test mode)
              const ConnectionSelector(),
            ],
          ),
        ),
        // 主要测试区域
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Factory Test Section (左侧)
                const Expanded(
                  flex: 3,
                  child: FactoryTestSection(),
                ),
                const SizedBox(width: 12),
                // Log Console Section (右侧)
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const LogConsoleSection(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  

}
