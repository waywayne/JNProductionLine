import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';

/// 蓝牙测试弹窗
/// 引导用户使用手机搜索蓝牙设备并尝试连接
class BluetoothTestDialog extends StatelessWidget {
  const BluetoothTestDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, state, _) {
        // 获取蓝牙MAC地址和名称
        final bluetoothMac = state.currentDeviceIdentity?['bluetoothMac'] ?? '未知';
        final bluetoothName = state.bluetoothNameToSet ?? '未设置';
        final testStep = state.bluetoothTestStep;
        
        // 判断是否可以进行手动连接测试
        final canManualTest = testStep.contains('请使用手机');
        // 判断是否有错误
        final hasError = testStep.contains('❌');
        
        return AlertDialog(
          backgroundColor: Colors.white,
          elevation: 8,
          title: Row(
            children: [
              Icon(
                Icons.bluetooth,
                color: Colors.blue[600],
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                '蓝牙连接测试',
                style: TextStyle(
                  color: Colors.blue[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 测试进度显示
                if (testStep.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: hasError 
                          ? Colors.red[50] 
                          : (canManualTest ? Colors.green[50] : Colors.orange[50]),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasError 
                            ? Colors.red[200]! 
                            : (canManualTest ? Colors.green[200]! : Colors.orange[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (hasError)
                          Icon(
                            Icons.error,
                            color: Colors.red[600],
                            size: 20,
                          ),
                        if (!hasError && !canManualTest)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[600]!),
                            ),
                          ),
                        if (!hasError && canManualTest)
                          Icon(
                            Icons.check_circle,
                            color: Colors.green[600],
                            size: 20,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            testStep,
                            style: TextStyle(
                              fontSize: 14,
                              color: hasError 
                                  ? Colors.red[800] 
                                  : (canManualTest ? Colors.green[800] : Colors.orange[800]),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // 提示信息
                Container(
                  padding: const EdgeInsets.all(16),
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
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '测试步骤',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildStep('1', '打开手机蓝牙设置'),
                      const SizedBox(height: 8),
                      _buildStep('2', '搜索附近的蓝牙设备'),
                      const SizedBox(height: 8),
                      _buildStep('3', '查找并尝试连接设备'),
                      const SizedBox(height: 8),
                      _buildStep('4', '确认是否能成功连接'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // 设备信息
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      // 蓝牙名称
                      Row(
                        children: [
                          Icon(
                            Icons.bluetooth_searching,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '蓝牙名称',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bluetoothName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: Colors.grey[300], height: 1),
                      const SizedBox(height: 12),
                      // 蓝牙MAC地址
                      Row(
                        children: [
                          Icon(
                            Icons.devices,
                            color: Colors.grey[700],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '蓝牙MAC地址',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bluetoothMac,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // 提示文字
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange[700],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '请确认手机能够搜索到并成功连接蓝牙设备',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // 测试失败按钮
            ElevatedButton.icon(
              onPressed: canManualTest ? () {
                state.confirmBluetoothTestResult(false);
              } : null,
              icon: const Icon(Icons.cancel, size: 18),
              label: const Text('连接失败'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[500],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(width: 8),
            // 测试通过按钮
            ElevatedButton.icon(
              onPressed: canManualTest ? () {
                state.confirmBluetoothTestResult(true);
              } : null,
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('连接成功'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[500],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue[600],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}
