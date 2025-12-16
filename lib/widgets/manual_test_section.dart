import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../services/production_test_commands.dart';

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
                () => state.runManualTest('控制WiFi', ProductionTestCommands.createControlWifiCommand()),
              ),
              _buildTestButton(
                context,
                'LED灯(外侧)',
                Icons.lightbulb_outline,
                () => state.runManualTest('LED灯(外侧)', ProductionTestCommands.createControlLEDCommand(ProductionTestCommands.ledOuter)),
              ),
              _buildTestButton(
                context,
                'LED灯(内侧)',
                Icons.lightbulb,
                () => state.runManualTest('LED灯(内侧)', ProductionTestCommands.createControlLEDCommand(ProductionTestCommands.ledInner)),
              ),
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
                () => state.runManualTest('Touch左侧', ProductionTestCommands.createTouchCommand(ProductionTestCommands.touchLeft)),
              ),
              _buildTestButton(
                context,
                'Touch右侧',
                Icons.touch_app,
                () => state.runManualTest('Touch右侧', ProductionTestCommands.createTouchCommand(ProductionTestCommands.touchRight)),
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
              _buildTestButton(
                context,
                'IMU数据',
                Icons.sensors,
                () => state.runManualTest('IMU数据', ProductionTestCommands.createIMUCommand(ProductionTestCommands.imuOptGetData)),
              ),
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
}
