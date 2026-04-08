import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../models/log_state.dart';
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
      testState.setLogState(logState);
      testState.initializeSNMacConfig();
      
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
