import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../services/production_test_commands.dart';
import 'led_test_dialog.dart';

/// Manual test section with individual buttons for each test
class ManualTestSection extends StatelessWidget {
  const ManualTestSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, state, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildTestButton(
                context,
                '唤醒设备',
                Icons.power_settings_new,
                () => state.runManualTest(
                  '唤醒设备',
                  ProductionTestCommands.createExitSleepModeCommand(),
                  moduleId: ProductionTestCommands.exitSleepModuleId,
                  messageId: ProductionTestCommands.exitSleepMessageId,
                ),
              ),
              _buildTestButton(
                context,
                '产测开始',
                Icons.play_arrow,
                () => state.runManualTest('产测开始', ProductionTestCommands.createStartTestCommand()),
              ),
              _buildTestButton(
                context,
                '获取设备电压',
                Icons.battery_charging_full,
                () => state.runManualTest('获取设备电压', ProductionTestCommands.createGetVoltageCommand()),
              ),
              _buildTestButton(
                context,
                '获取设备电量',
                Icons.battery_std,
                () => state.runManualTest('获取设备电量', ProductionTestCommands.createGetCurrentCommand()),
              ),
              _buildTestButton(
                context,
                '获取充电状态',
                Icons.power,
                () => state.runManualTest('获取充电状态', ProductionTestCommands.createGetChargeStatusCommand()),
              ),
              _buildTestButton(
                context,
                '控制WiFi',
                Icons.wifi,
                () => state.testWiFi(),
              ),
              _buildLEDTestButton(context, '外侧', Icons.lightbulb_outline),
              _buildLEDTestButton(context, '内侧', Icons.lightbulb),
              _buildTestButton(
                context,
                'SPK0',
                Icons.volume_up,
                () => state.runManualTest('SPK0', ProductionTestCommands.createControlSPKCommand(ProductionTestCommands.spk0)),
              ),
              _buildTestButton(
                context,
                'SPK1',
                Icons.speaker,
                () => state.runManualTest('SPK1', ProductionTestCommands.createControlSPKCommand(ProductionTestCommands.spk1)),
              ),
              _buildTestButton(
                context,
                'Touch左侧',
                Icons.touch_app,
                () => state.testTouchLeft(),
              ),
              _buildTestButton(
                context,
                'Touch右侧',
                Icons.touch_app,
                () => state.testTouchRight(),
              ),
              _buildMicToggleButton(context, state, 0, 'MIC0', Icons.mic),
              _buildMicToggleButton(context, state, 1, 'MIC1', Icons.mic_none),
              _buildMicToggleButton(context, state, 2, 'MIC2', Icons.mic_external_on),
              _buildTestButton(
                context,
                'RTC设置时间',
                Icons.update,
                () => state.setRTCTime(),
              ),
              _buildTestButton(
                context,
                'RTC获取时间',
                Icons.access_time,
                () => state.getRTCTime(),
              ),
              _buildTestButton(
                context,
                '光敏传感器',
                Icons.wb_sunny,
                () => state.runManualTest('光敏传感器', ProductionTestCommands.createLightSensorCommand()),
              ),
              _buildIMUToggleButton(context, state),
              _buildSensorToggleButton(context, state),
              _buildTestButton(
                context,
                '产测结束',
                Icons.stop,
                () => state.runManualTest('产测结束', ProductionTestCommands.createEndTestCommand()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTestButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed, {
    int? moduleId,
    int? messageId,
  }) {
    return SizedBox(
      width: 140,
      height: 80,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[300],
          foregroundColor: Colors.black87,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLEDTestButton(
    BuildContext context,
    String ledType,
    IconData icon,
  ) {
    return Consumer<TestState>(
      builder: (context, state, _) {
        final testResult = state.getLEDTestResult(ledType);
        
        // 根据测试结果确定按钮样式
        Color backgroundColor;
        Color foregroundColor;
        Color borderColor;
        String statusText;
        
        if (testResult == null) {
          // 未测试
          backgroundColor = Colors.amber[100]!;
          foregroundColor = Colors.amber[800]!;
          borderColor = Colors.amber[300]!;
          statusText = '点击测试';
        } else if (testResult) {
          // 测试通过
          backgroundColor = Colors.green[100]!;
          foregroundColor = Colors.green[800]!;
          borderColor = Colors.green[400]!;
          statusText = '测试通过';
        } else {
          // 测试未通过
          backgroundColor = Colors.red[100]!;
          foregroundColor = Colors.red[800]!;
          borderColor = Colors.red[400]!;
          statusText = '测试未通过';
        }
        
        return SizedBox(
          width: 140,
          height: 80,
          child: ElevatedButton(
            onPressed: () => _showLEDTestDialog(context, ledType),
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: borderColor, width: 1),
              ),
              padding: const EdgeInsets.all(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  testResult == null ? icon : 
                  testResult ? Icons.check_circle : Icons.cancel,
                  size: 28, 
                  color: foregroundColor,
                ),
                const SizedBox(height: 4),
                Text(
                  'LED灯($ledType)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLEDTestDialog(BuildContext context, String ledType) {
    showDialog(
      context: context,
      barrierDismissible: false, // 防止点击外部关闭
      builder: (context) => LEDTestDialog(
        ledType: ledType,
        onTestPassed: () {
          // 测试通过的回调 - 直接显示SnackBar即可
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('LED$ledType测试通过'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMicToggleButton(
    BuildContext context,
    TestState state,
    int micNumber,
    String label,
    IconData icon,
  ) {
    final isOn = state.getMicState(micNumber);
    final statusText = isOn ? '已开启' : '已关闭';
    
    return SizedBox(
      width: 140,
      height: 80,
      child: ElevatedButton(
        onPressed: () => state.toggleMicState(micNumber),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOn ? Colors.green[400] : Colors.grey[300],
          foregroundColor: isOn ? Colors.white : Colors.black87,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isOn ? BorderSide(color: Colors.green[700]!, width: 2) : BorderSide.none,
          ),
          padding: const EdgeInsets.all(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 9,
                color: isOn ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIMUToggleButton(BuildContext context, TestState state) {
    final isTesting = state.isIMUTesting;
    final statusText = isTesting ? '监听中' : '未开始';
    
    return SizedBox(
      width: 120,
      height: 80,
      child: ElevatedButton(
        onPressed: () async {
          if (isTesting) {
            await state.stopIMUDataStream();
          } else {
            await state.startIMUDataStream();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isTesting ? Colors.blue[400] : Colors.blue[50],
          foregroundColor: isTesting ? Colors.white : Colors.blue[700],
          elevation: isTesting ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isTesting ? Colors.blue[600]! : Colors.blue[300]!,
              width: 1,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isTesting ? Icons.sensors_outlined : Icons.sensors, size: 28),
            const SizedBox(height: 4),
            const Text(
              'IMU数据',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              statusText,
              style: const TextStyle(fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorToggleButton(BuildContext context, TestState state) {
    final isTesting = state.isSensorTesting;
    final statusText = isTesting ? '监听中' : '未开始';
    
    return SizedBox(
      width: 140,
      height: 80,
      child: ElevatedButton(
        onPressed: () async {
          if (isTesting) {
            await state.stopSensorTest();
          } else {
            await state.startSensorTest();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isTesting ? Colors.orange[400] : Colors.grey[300],
          foregroundColor: isTesting ? Colors.white : Colors.black87,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isTesting ? BorderSide(color: Colors.orange[700]!, width: 2) : BorderSide.none,
          ),
          padding: const EdgeInsets.all(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isTesting ? Icons.image_outlined : Icons.image, size: 28),
            const SizedBox(height: 4),
            const Text(
              'Sensor图片',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 9,
                color: isTesting ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
