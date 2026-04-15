import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../models/log_state.dart';
import '../config/wifi_config.dart';
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
                '左佩戴检测',
                Icons.touch_app,
                () => state.testLeftWearDetect(),
              ),
              _buildTestButton(
                context,
                '左Touch事件',
                Icons.touch_app,
                () => state.testLeftTouchEvent(),
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
              _buildTestButton(
                context,
                'IMU校准',
                Icons.compass_calibration,
                () => _testIMUCalibration(context, state),
                color: Colors.deepOrange,
              ),
              _buildTestButton(
                context,
                '摄像头棋盘格',
                Icons.grid_on,
                () => _testCameraChessboard(context, state),
                color: Colors.cyan,
              ),
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

  /// 处理测试按钮点击：串口已连接则直接执行，否则检查蓝牙SPP，未连接则弹窗扫描SN→查询蓝牙MAC→连接蓝牙
  Future<void> _handleTestButtonPress(
    BuildContext context,
    TestState state,
    String testName,
    VoidCallback onPressed,
  ) async {
    // 1. 串口已连接 → 直接执行
    if (state.serialService.isConnected) {
      onPressed();
      return;
    }
    
    // 2. 蓝牙SPP已连接 → 直接执行
    if (state.isLinuxBluetoothConnected) {
      onPressed();
      return;
    }
    
    // 3. 均未连接 → 弹窗扫描SN，查询蓝牙MAC后连接
    final connected = await _ensureConnection(context, state);
    if (!connected) return;

    // 连接成功，执行测试
    onPressed();
  }
  
  /// 确保设备已连接（弹窗扫描SN → 查询蓝牙MAC → 连接蓝牙）
  /// 返回 true 表示连接成功
  Future<bool> _ensureConnection(BuildContext context, TestState state) async {
    // 再次检查（可能在等待期间已连接）
    if (state.serialService.isConnected || state.isLinuxBluetoothConnected) {
      return true;
    }
    
    // 弹窗扫描SN
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
      return false;
    }

    // 获取蓝牙MAC地址
    final bluetoothAddress = productInfo.bluetoothAddress;
    if (bluetoothAddress.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ 设备蓝牙地址为空，无法连接'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    // 提示正在连接
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔵 正在连接蓝牙 $bluetoothAddress ...'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
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
      return false;
    }
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 蓝牙连接成功'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
    return true;
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
            onPressed: () => _handleTestButtonPress(context, state, 'LED灯($ledType)', () => _showLEDTestDialog(context, ledType)),
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
        onPressed: () => _handleTestButtonPress(context, state, label, () => state.toggleMicState(micNumber)),
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
        onPressed: () => _handleTestButtonPress(context, state, 'IMU数据', () async {
          if (isTesting) {
            await state.stopIMUDataStream();
          } else {
            await state.startIMUDataStream();
          }
        }),
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
        onPressed: () => _handleTestButtonPress(context, state, 'Sensor图片', () async {
          if (isTesting) {
            await state.stopSensorTest();
          } else {
            await state.startSensorTest();
          }
        }),
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

  /// IMU校准测试
  /// 发送0x10命令后持续监听设备状态：0x00启动中→0x01朝向检测→0x02校准中→0x03校准完成
  Future<void> _testIMUCalibration(BuildContext context, TestState state) async {
    final logState = context.read<LogState>();

    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
    logState.info('🔧 IMU校准测试开始', type: LogType.debug);

    // 确定通信方式
    final useLinuxBluetooth = state.isLinuxBluetoothConnected;
    final useSerial = state.serialService.isConnected;

    if (!useLinuxBluetooth && !useSerial) {
      logState.error('❌ 未连接（串口或蓝牙）', type: LogType.debug);
      return;
    }

    final connectionType = useLinuxBluetooth ? 'Linux 蓝牙 SPP' : '串口';
    logState.info('📡 通信方式: $connectionType', type: LogType.debug);

    final command = ProductionTestCommands.createIMUCalibrationCommand();

    // 弹窗显示校准进度
    if (!context.mounted) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _IMUCalibrationDialog(
          state: state,
          logState: logState,
          command: command,
          useLinuxBluetooth: useLinuxBluetooth,
        );
      },
    );

    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
  }

  /// 摄像头棋盘格测试
  Future<void> _testCameraChessboard(BuildContext context, TestState state) async {
    final logState = context.read<LogState>();

    // ========== 步骤1: 确保设备已连接（串口优先，否则SN扫码→蓝牙连接） ==========
    if (!state.serialService.isConnected && !state.isLinuxBluetoothConnected) {
      final connected = await _ensureConnection(context, state);
      if (!connected) return;
    }

    // ========== 步骤2: 连接WiFi获取设备IP ==========
    logState.info('📶 手动棋盘格测试: 连接WiFi热点...', type: LogType.debug);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📶 正在连接WiFi热点...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }

    String? deviceIP;

    final String ssid = WiFiConfig.defaultSSID;
    final String password = WiFiConfig.defaultPassword;

    if (ssid.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ WiFi SSID未配置，请在通用配置中设置'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    logState.info('   SSID: $ssid', type: LogType.debug);

    final ssidBytes = ssid.codeUnits + [0x00];
    final pwdBytes = password.codeUnits + [0x00];
    final wifiPayload = [...ssidBytes, ...pwdBytes];
    final wifiCommand = ProductionTestCommands.createControlWifiCommand(0x05, data: wifiPayload);

    for (int retry = 0; retry < 3; retry++) {
      if (retry > 0) {
        logState.info('   WiFi重试 ($retry/3)...', type: LogType.debug);
        await Future.delayed(const Duration(seconds: 2));
      }

      try {
        final response = await state.sendCommandViaLinuxBluetooth(
          wifiCommand,
          timeout: const Duration(seconds: 10),
          moduleId: ProductionTestCommands.moduleId,
          messageId: ProductionTestCommands.messageId,
        );

        if (response != null && !response.containsKey('error')) {
          if (response.containsKey('payload') && response['payload'] != null) {
            final responsePayload = response['payload'] as Uint8List;
            final wifiResult = ProductionTestCommands.parseWifiResponse(responsePayload, 0x05);

            if (wifiResult != null && wifiResult['success'] == true && wifiResult.containsKey('ip')) {
              deviceIP = wifiResult['ip'];
              logState.success('✅ 获取到设备IP: $deviceIP', type: LogType.debug);
              break;
            }
          }
        }
      } catch (e) {
        logState.warning('⚠️ WiFi连接异常: $e', type: LogType.debug);
      }
    }

    if (deviceIP == null || deviceIP.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ WiFi连接失败，未获取到设备IP'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ WiFi已连接，设备IP: $deviceIP'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }

    // ========== 步骤3: 弹窗确认开始拍摄 ==========
    if (!context.mounted) return;
    final userConfirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.blue),
            SizedBox(width: 12),
            Text('摄像头棋盘格测试'),
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

    if (userConfirmed != true) return;

    // ========== 步骤4: 发送拍照命令 ==========
    final command = ProductionTestCommands.createSensorCommand(0x02);
    
    try {
      final response = await state.sendCommandViaLinuxBluetooth(
        command,
        timeout: const Duration(seconds: 10),
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );

      if (response == null || response.containsKey('error')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ 拍照命令失败: ${response?['error'] ?? '超时'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // ========== 步骤5: 下载图片 ==========
      logState.info('📥 开始FTP下载图片 (IP: $deviceIP)...', type: LogType.debug);
      final downloadSuccess = await state.downloadImageFromDevice(deviceIP);
      if (!downloadSuccess) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ 图片下载失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // ========== 步骤6: 图片质量检测 ==========
      final qualitySuccess = await state.testCameraImageQuality();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(qualitySuccess ? '✅ 摄像头棋盘格测试通过' : '❌ 图片质量检测失败'),
            backgroundColor: qualitySuccess ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 测试异常: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// IMU校准进度弹窗
class _IMUCalibrationDialog extends StatefulWidget {
  final TestState state;
  final LogState logState;
  final Uint8List command;
  final bool useLinuxBluetooth;

  const _IMUCalibrationDialog({
    required this.state,
    required this.logState,
    required this.command,
    required this.useLinuxBluetooth,
  });

  @override
  State<_IMUCalibrationDialog> createState() => _IMUCalibrationDialogState();
}

class _IMUCalibrationDialogState extends State<_IMUCalibrationDialog> {
  int _currentStatus = -1; // -1=未开始
  String _statusText = '正在发送校准命令...';
  bool _isRunning = true;
  bool _isSuccess = false;
  bool _isFailed = false;
  int? _calibResult;

  static const _statusSteps = [
    {'status': 0x00, 'label': '设备IMU启动中', 'icon': Icons.power_settings_new},
    {'status': 0x01, 'label': '设备朝向检测中', 'icon': Icons.screen_rotation},
    {'status': 0x02, 'label': '设备校准中', 'icon': Icons.tune},
    {'status': 0x03, 'label': '设备校准完成', 'icon': Icons.check_circle},
  ];

  @override
  void initState() {
    super.initState();
    _startCalibration();
  }

  Future<Map<String, dynamic>?> _sendAndWait() async {
    if (widget.useLinuxBluetooth) {
      return await widget.state.sendCommandViaLinuxBluetooth(
        widget.command,
        timeout: const Duration(seconds: 30),
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );
    } else {
      return await widget.state.serialService.sendCommandAndWaitResponse(
        widget.command,
        timeout: const Duration(seconds: 30),
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );
    }
  }

  Future<void> _startCalibration() async {
    widget.logState.info('📤 发送IMU校准命令(0x10)', type: LogType.debug);

    // 持续发送/轮询直到收到0x03或超时
    const maxAttempts = 20;
    for (int i = 0; i < maxAttempts && _isRunning; i++) {
      try {
        final response = await _sendAndWait();

        if (!_isRunning) break;

        if (response == null) {
          widget.logState.warning('⏱️  IMU校准: 等待响应超时 (${i + 1}/$maxAttempts)', type: LogType.debug);
          if (mounted) {
            setState(() => _statusText = '等待设备响应... (${i + 1}/$maxAttempts)');
          }
          continue;
        }

        if (response.containsKey('error')) {
          widget.logState.error('❌ IMU校准: ${response['error']}', type: LogType.debug);
          continue;
        }

        // 解析响应
        if (response.containsKey('payload') && response['payload'] != null) {
          final payload = response['payload'] as Uint8List;
          final payloadHex = payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
          widget.logState.info('📦 IMU校准响应: [$payloadHex]', type: LogType.debug);

          final parsed = ProductionTestCommands.parseIMUCalibrationResponse(payload);
          if (parsed != null) {
            final status = parsed['status'] as int;
            final statusName = parsed['statusName'] as String;
            widget.logState.info('📊 IMU状态: $statusName (0x${status.toRadixString(16)})', type: LogType.debug);

            if (mounted) {
              setState(() {
                _currentStatus = status;
                _statusText = statusName;
              });
            }

            if (status == ProductionTestCommands.imuCalibStatusComplete) {
              _calibResult = parsed['calibResult'] as int?;
              final success = parsed['success'] == true;
              widget.logState.info(
                success
                    ? '✅ IMU校准完成，校准结果: ${_calibResult != null ? "0x${_calibResult!.toRadixString(16).toUpperCase()}" : "无"}'
                    : '❌ IMU校准完成，但校准失败 (结果: ${_calibResult != null ? "0x${_calibResult!.toRadixString(16).toUpperCase()}" : "无"})',
                type: LogType.debug,
              );
              if (mounted) {
                setState(() {
                  _isRunning = false;
                  _isSuccess = success;
                  _isFailed = !success;
                  _statusText = success ? '✅ 校准成功' : '❌ 校准失败';
                });
              }
              return;
            }
          }
        }

        // 短暂延迟后继续轮询
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        widget.logState.error('❌ IMU校准异常: $e', type: LogType.debug);
        if (mounted) {
          setState(() => _statusText = '异常: $e');
        }
      }
    }

    // 超过最大轮询次数
    if (_isRunning && mounted) {
      widget.logState.error('❌ IMU校准: 轮询超时', type: LogType.debug);
      setState(() {
        _isRunning = false;
        _isFailed = true;
        _statusText = '❌ 校准超时';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isSuccess ? Icons.check_circle : (_isFailed ? Icons.error : Icons.compass_calibration),
            color: _isSuccess ? Colors.green : (_isFailed ? Colors.red : Colors.deepOrange),
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text('IMU校准'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 状态步骤指示
            ..._statusSteps.map((step) {
              final stepStatus = step['status'] as int;
              final label = step['label'] as String;
              final icon = step['icon'] as IconData;
              final isActive = stepStatus == _currentStatus;
              final isDone = _currentStatus > stepStatus ||
                  (_currentStatus == ProductionTestCommands.imuCalibStatusComplete && stepStatus == _currentStatus);
              final isPending = _currentStatus < stepStatus;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    // 状态图标
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDone
                            ? Colors.green[50]
                            : (isActive ? Colors.deepOrange[50] : Colors.grey[100]),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone
                              ? Colors.green
                              : (isActive ? Colors.deepOrange : Colors.grey[300]!),
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check, color: Colors.green, size: 20)
                            : (isActive
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.deepOrange[600],
                                    ),
                                  )
                                : Icon(icon, color: Colors.grey[400], size: 18)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isDone
                            ? Colors.green[700]
                            : (isActive ? Colors.deepOrange[800] : (isPending ? Colors.grey[400] : Colors.black87)),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),

            // 校准结果
            if (_isSuccess || _isFailed)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isSuccess ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _isSuccess ? Colors.green : Colors.red),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle : Icons.cancel,
                      color: _isSuccess ? Colors.green[700] : Colors.red[700],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSuccess ? '校准成功' : '校准失败',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isSuccess ? Colors.green[800] : Colors.red[800],
                            ),
                          ),
                          if (_calibResult != null)
                            Text(
                              '校准结果: 0x${_calibResult!.toRadixString(16).toUpperCase().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                                color: _isSuccess ? Colors.green[700] : Colors.red[700],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // 进行中提示
            if (_isRunning)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _statusText,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (_isRunning)
          TextButton(
            onPressed: () {
              setState(() {
                _isRunning = false;
                _isFailed = true;
                _statusText = '已取消';
              });
              widget.logState.warning('⚠️ IMU校准: 用户取消', type: LogType.debug);
              Navigator.of(context).pop(false);
            },
            child: const Text('取消', style: TextStyle(color: Colors.red)),
          ),
        if (!_isRunning)
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_isSuccess),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSuccess ? Colors.green : Colors.grey,
              foregroundColor: Colors.white,
            ),
            child: const Text('关闭'),
          ),
      ],
    );
  }
}
