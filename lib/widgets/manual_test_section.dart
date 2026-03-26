import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../services/production_test_commands.dart';
import '../services/product_sn_api.dart';
import 'led_test_dialog.dart';
import 'linux_bluetooth_scan_dialog.dart';
import 'sn_input_dialog.dart';
import 'manual_bluetooth_test_dialog.dart';

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
              // 蓝牙测试按钮（最前面）
              _buildBluetoothTestButton(context, state),
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
                '漏电流测试',
                Icons.electric_bolt,
                () async {
                  final success = await state.testLeakageCurrent();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? '✅ 漏电流测试通过' : '❌ 漏电流测试失败'),
                        backgroundColor: success ? Colors.green : Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                color: Colors.purple,
              ),
              _buildTestButton(
                context,
                '物奇功耗测试',
                Icons.power,
                () async {
                  final success = await state.testWuqiPower();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? '✅ 物奇功耗测试通过' : '❌ 物奇功耗测试失败'),
                        backgroundColor: success ? Colors.green : Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                color: Colors.teal,
              ),
              _buildTestButton(
                context,
                'ISP工作功耗测试',
                Icons.memory,
                () async {
                  final success = await state.testIspWorkingPower();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? '✅ ISP工作功耗测试通过' : '❌ ISP工作功耗测试失败'),
                        backgroundColor: success ? Colors.green : Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                color: Colors.indigo,
              ),
              _buildTestButton(
                context,
                'EMMC容量检测',
                Icons.storage,
                () async {
                  final success = await state.testEMMCCapacity();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? '✅ EMMC容量检测通过' : '❌ EMMC容量检测失败'),
                        backgroundColor: success ? Colors.green : Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                color: Colors.brown,
              ),
              // 已禁用：完整功耗测试（开启物奇、ISP和WIFI）
              // _buildTestButton(
              //   context,
              //   '完整功耗测试',
              //   Icons.power_settings_new,
              //   () async {
              //     final success = await state.testFullPower();
              //     if (context.mounted) {
              //       ScaffoldMessenger.of(context).showSnackBar(
              //         SnackBar(
              //           content: Text(success ? '✅ 完整功耗测试通过' : '❌ 完整功耗测试失败'),
              //           backgroundColor: success ? Colors.green : Colors.red,
              //           duration: const Duration(seconds: 3),
              //         ),
              //       );
              //     }
              //   },
              //   color: Colors.deepOrange,
              // ),
              // 已禁用：ISP休眠功耗测试（开启物奇、ISP休眠状态）
              // _buildTestButton(
              //   context,
              //   'ISP休眠功耗测试',
              //   Icons.bedtime,
              //   () async {
              //     final success = await state.testIspSleepPower();
              //     if (context.mounted) {
              //       ScaffoldMessenger.of(context).showSnackBar(
              //         SnackBar(
              //           content: Text(success ? '✅ ISP休眠功耗测试通过' : '❌ ISP休眠功耗测试失败'),
              //           backgroundColor: success ? Colors.green : Colors.red,
              //           duration: const Duration(seconds: 3),
              //         ),
              //       );
              //     }
              //   },
              //   color: Colors.blueGrey,
              // ),
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
              _buildTestButton(
                context,
                'SPP蓝牙测试',
                Icons.bluetooth,
                () async {
                  final success = await state.testSppBluetooth();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? '✅ SPP蓝牙测试通过' : '❌ SPP蓝牙测试失败'),
                        backgroundColor: success ? Colors.green : Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                color: Colors.blue,
              ),
              _buildTestButton(
                context,
                'Python蓝牙测试',
                Icons.bluetooth_searching,
                () async {
                  final success = await state.testPythonBluetooth();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? '✅ Python蓝牙测试通过' : '❌ Python蓝牙测试失败'),
                        backgroundColor: success ? Colors.green : Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                color: Colors.deepPurple,
              ),
              _buildLinuxBluetoothButton(context, state),
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
    Color? color,
  }) {
    final buttonColor = color ?? Colors.grey[300]!;
    final textColor = color != null ? Colors.white : Colors.black87;
    
    return SizedBox(
      width: 140,
      height: 80,
      child: Consumer<TestState>(
        builder: (context, state, _) {
          return ElevatedButton(
            onPressed: () => _handleTestButtonPress(context, state, label, onPressed),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: textColor,
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
          );
        },
      ),
    );
  }

  /// 处理测试按钮点击，先检查SPP连接
  Future<void> _handleTestButtonPress(
    BuildContext context,
    TestState state,
    String testName,
    VoidCallback onPressed,
  ) async {
    // 检查是否已连接Linux蓝牙SPP
    if (!state.isLinuxBluetoothConnected) {
      // 未连接，弹窗提示并输入SN
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.bluetooth_disabled, color: Colors.orange),
              SizedBox(width: 12),
              Text('蓝牙未连接'),
            ],
          ),
          content: const Text('执行手动测试前需要先连接蓝牙SPP。\n\n请输入SN码以获取设备信息并连接蓝牙。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('输入SN'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // 显示SN输入对话框
      final productInfo = await showDialog<ProductSNInfo>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const SNInputDialog(),
      );

      if (productInfo == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ 未获取到设备信息，无法执行测试'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 连接蓝牙SPP
      final bluetoothAddress = productInfo.bluetoothAddress;
      if (bluetoothAddress == null || bluetoothAddress.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ 设备信息中无蓝牙地址'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 使用 Linux 蓝牙 SPP 连接
      final connected = await state.testLinuxBluetooth(
        deviceAddress: bluetoothAddress,
      );

      if (!connected) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ 蓝牙连接失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // SPP已连接，执行测试
    onPressed();
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

  Widget _buildLinuxBluetoothButton(BuildContext context, TestState state) {
    final isConnected = state.isLinuxBluetoothConnected;
    final deviceName = state.linuxBluetoothDeviceName ?? '未连接';
    
    return SizedBox(
      width: 140,
      height: 80,
      child: ElevatedButton(
        onPressed: () async {
          if (isConnected) {
            // 已连接，显示断开选项
            final shouldDisconnect = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Linux 蓝牙连接'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前已连接到: $deviceName'),
                    const SizedBox(height: 8),
                    Text(
                      '地址: ${state.linuxBluetoothDeviceAddress ?? "未知"}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('断开连接'),
                  ),
                ],
              ),
            );
            
            if (shouldDisconnect == true) {
              await state.disconnectLinuxBluetooth();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔌 已断开 Linux 蓝牙连接'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }
          } else {
            // 未连接，显示扫描对话框
            final result = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => const LinuxBluetoothScanDialog(),
            );
            
            // result 为 true 表示连接成功，已在 dialog 中显示 SnackBar
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isConnected ? Colors.green[400] : Colors.teal[400],
          foregroundColor: Colors.white,
          elevation: isConnected ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isConnected 
                ? BorderSide(color: Colors.green[700]!, width: 2) 
                : BorderSide.none,
          ),
          padding: const EdgeInsets.all(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              isConnected ? 'Linux蓝牙' : 'Linux蓝牙',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              isConnected ? '已连接' : '点击连接',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建蓝牙测试按钮
  Widget _buildBluetoothTestButton(BuildContext context, TestState state) {
    final isConnected = state.isLinuxBluetoothConnected;
    
    return SizedBox(
      width: 140,
      height: 80,
      child: ElevatedButton(
        onPressed: () async {
          if (isConnected) {
            // 已连接，显示断开选项
            final shouldDisconnect = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('蓝牙已连接'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前已连接到: ${state.linuxBluetoothDeviceName ?? "未知"}'),
                    const SizedBox(height: 8),
                    Text(
                      '地址: ${state.linuxBluetoothDeviceAddress ?? "未知"}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('断开连接'),
                  ),
                ],
              ),
            );
            
            if (shouldDisconnect == true) {
              await state.disconnectLinuxBluetooth();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔌 已断开蓝牙连接'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }
          } else {
            // 未连接，显示蓝牙测试对话框
            final connected = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => const ManualBluetoothTestDialog(),
            );
            
            if (connected == true && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ 蓝牙连接成功，可以开始手动测试'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isConnected ? Colors.green[400] : Colors.blue[600],
          foregroundColor: Colors.white,
          elevation: isConnected ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isConnected 
                ? BorderSide(color: Colors.green[700]!, width: 2) 
                : BorderSide.none,
          ),
          padding: const EdgeInsets.all(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              size: 32,
            ),
            const SizedBox(height: 4),
            const Text(
              '蓝牙测试',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              isConnected ? '已连接' : '点击连接',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
