import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';

/// MIC测试弹窗
/// 显示MIC测试状态，提供成功/失败按钮供用户确认
class MICTestDialog extends StatelessWidget {
  const MICTestDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, state, _) {
        final micNumber = state.currentMICNumber ?? 0;
        final micName = micNumber == 0 ? '左' : (micNumber == 1 ? '右' : 'TALK');
        
        return AlertDialog(
          backgroundColor: Colors.white,
          elevation: 8,
          title: Row(
            children: [
              const Icon(
                Icons.mic,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                '${micName}MIC测试',
                style: const TextStyle(
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 状态信息
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.mic_external_on,
                        color: Colors.blue[600],
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${micName}MIC已打开',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '请对着${micName}MIC说话测试',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '确认MIC是否正常工作',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // 测试结果按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 测试失败按钮
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            state.confirmMICTestResult(false);
                          },
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text('测试失败'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[400],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ),
                    // 测试成功按钮
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            state.confirmMICTestResult(true);
                          },
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('测试成功'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
