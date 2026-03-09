import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';

/// SPK测试弹窗
/// 显示SPK测试状态，提供成功/失败按钮供用户确认
class SPKTestDialog extends StatelessWidget {
  const SPKTestDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, state, _) {
        final spkNumber = state.currentSPKNumber ?? 0;
        final spkName = spkNumber == 0 ? '左' : '右';
        
        return AlertDialog(
          backgroundColor: Colors.white,
          elevation: 8,
          title: Row(
            children: [
              const Icon(
                Icons.volume_up,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                '${spkName}SPK测试',
                style: const TextStyle(
                  color: Colors.orange,
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
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.speaker,
                        color: Colors.orange[600],
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${spkName}SPK测试中',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '请确认是否听到${spkName}侧扬声器的声音',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '确认SPK是否正常工作',
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
                            state.confirmSPKTestResult(false);
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
                            state.confirmSPKTestResult(true);
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
