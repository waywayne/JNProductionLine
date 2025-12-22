import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../models/touch_test_step.dart';

class TouchTestStepsWidget extends StatelessWidget {
  const TouchTestStepsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, state, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Touch测试步骤',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // 左Touch测试步骤
                if (state.leftTouchTestSteps.isNotEmpty) ...[
                  _buildTouchSection(
                    '左Touch测试',
                    state.leftTouchTestSteps,
                    state.isLeftTouchTesting,
                    () => state.testTouchLeft(),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // 右Touch测试步骤
                if (state.rightTouchTestSteps.isNotEmpty) ...[
                  _buildTouchSection(
                    '右Touch测试',
                    state.rightTouchTestSteps,
                    state.isRightTouchTesting,
                    () => state.testTouchRight(),
                  ),
                ],
                
                // 如果没有测试步骤，显示提示
                if (state.leftTouchTestSteps.isEmpty && state.rightTouchTestSteps.isEmpty)
                  const Text(
                    '点击开始Touch测试以查看步骤进度',
                    style: TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTouchSection(
    String title,
    List<TouchTestStep> steps,
    bool isTesting,
    VoidCallback onStart,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (!isTesting)
              ElevatedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('开始测试'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              )
            else
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('测试中...', style: TextStyle(color: Colors.blue)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          return _buildStepItem(step, index);
        }).toList(),
      ],
    );
  }

  Widget _buildStepItem(TouchTestStep step, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: _getStepBackgroundColor(step.status),
      ),
      child: Row(
        children: [
          // 步骤图标
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStepIconColor(step.status),
            ),
            child: Center(
              child: _getStepIcon(step.status),
            ),
          ),
          const SizedBox(width: 12),
          
          // 步骤信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}. ${step.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                
                // 用户提示（当状态为等待用户操作时显示）
                if (step.status == TouchStepStatus.userAction) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: Colors.orange.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            step.userPrompt,
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // CDC值显示
                if (step.cdcValue != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'CDC值: ${step.cdcValue}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                
                // 错误信息
                if (step.errorMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '错误: ${step.errorMessage}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // 状态文本
          Text(
            _getStatusText(step.status),
            style: TextStyle(
              color: _getStatusTextColor(step.status),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStepBackgroundColor(TouchStepStatus status) {
    switch (status) {
      case TouchStepStatus.waiting:
        return Colors.grey.shade50;
      case TouchStepStatus.testing:
        return Colors.blue.shade50;
      case TouchStepStatus.userAction:
        return Colors.orange.shade50;
      case TouchStepStatus.success:
        return Colors.green.shade50;
      case TouchStepStatus.failed:
        return Colors.red.shade50;
      case TouchStepStatus.timeout:
        return Colors.orange.shade50;
    }
  }

  Color _getStepIconColor(TouchStepStatus status) {
    switch (status) {
      case TouchStepStatus.waiting:
        return Colors.grey.shade300;
      case TouchStepStatus.testing:
        return Colors.blue.shade300;
      case TouchStepStatus.userAction:
        return Colors.orange.shade300;
      case TouchStepStatus.success:
        return Colors.green.shade300;
      case TouchStepStatus.failed:
        return Colors.red.shade300;
      case TouchStepStatus.timeout:
        return Colors.orange.shade300;
    }
  }

  Widget _getStepIcon(TouchStepStatus status) {
    switch (status) {
      case TouchStepStatus.waiting:
        return Icon(Icons.radio_button_unchecked, color: Colors.grey.shade600, size: 16);
      case TouchStepStatus.testing:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
        );
      case TouchStepStatus.userAction:
        return Icon(Icons.touch_app, color: Colors.orange.shade700, size: 16);
      case TouchStepStatus.success:
        return Icon(Icons.check, color: Colors.green.shade700, size: 16);
      case TouchStepStatus.failed:
        return Icon(Icons.close, color: Colors.red.shade700, size: 16);
      case TouchStepStatus.timeout:
        return Icon(Icons.access_time, color: Colors.orange.shade700, size: 16);
    }
  }

  String _getStatusText(TouchStepStatus status) {
    switch (status) {
      case TouchStepStatus.waiting:
        return '等待';
      case TouchStepStatus.testing:
        return '测试中';
      case TouchStepStatus.userAction:
        return '等待操作';
      case TouchStepStatus.success:
        return '成功';
      case TouchStepStatus.failed:
        return '失败';
      case TouchStepStatus.timeout:
        return '超时';
    }
  }

  Color _getStatusTextColor(TouchStepStatus status) {
    switch (status) {
      case TouchStepStatus.waiting:
        return Colors.grey.shade600;
      case TouchStepStatus.testing:
        return Colors.blue.shade700;
      case TouchStepStatus.userAction:
        return Colors.orange.shade700;
      case TouchStepStatus.success:
        return Colors.green.shade700;
      case TouchStepStatus.failed:
        return Colors.red.shade700;
      case TouchStepStatus.timeout:
        return Colors.orange.shade700;
    }
  }
}
