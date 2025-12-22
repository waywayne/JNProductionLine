import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../models/touch_test_step.dart';

class TouchTestDialog extends StatelessWidget {
  final bool isLeftTouch;
  
  const TouchTestDialog({
    super.key,
    required this.isLeftTouch,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, state, child) {
        final steps = isLeftTouch ? state.leftTouchTestSteps : state.rightTouchTestSteps;
        final isTesting = isLeftTouch ? state.isLeftTouchTesting : state.isRightTouchTesting;
        
        if (!isTesting || steps.isEmpty) {
          return const SizedBox.shrink();
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                Row(
                  children: [
                    Icon(
                      Icons.touch_app,
                      color: Colors.blue.shade600,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${isLeftTouch ? '左' : '右'}Touch测试',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => state.closeTouchDialog(),
                      icon: const Icon(Icons.close),
                      tooltip: '关闭',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // 进度指示器
                _buildProgressIndicator(steps),
                const SizedBox(height: 24),
                
                // 当前步骤显示
                _buildCurrentStep(steps),
                const SizedBox(height: 24),
                
                // 步骤列表
                _buildStepsList(steps),
                const SizedBox(height: 24),
                
                // 底部按钮
                _buildBottomButtons(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator(List<TouchTestStep> steps) {
    final completedSteps = steps.where((step) => 
        step.status == TouchStepStatus.success || step.status == TouchStepStatus.skipped).length;
    final totalSteps = steps.length;
    final progress = totalSteps > 0 ? completedSteps / totalSteps : 0.0;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '测试进度',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              '$completedSteps / $totalSteps',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildCurrentStep(List<TouchTestStep> steps) {
    // 找到当前正在执行的步骤
    TouchTestStep? currentStep;
    int currentIndex = -1;
    
    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (step.status == TouchStepStatus.testing || 
          step.status == TouchStepStatus.userAction) {
        currentStep = step;
        currentIndex = i;
        break;
      }
    }
    
    if (currentStep == null) {
      // 如果没有正在执行的步骤，检查是否全部完成
      final allCompleted = steps.every((step) => step.status == TouchStepStatus.success);
      if (allCompleted) {
        return _buildCompletedCard();
      }
      return const SizedBox.shrink();
    }

    return _buildCurrentStepCard(currentStep, currentIndex);
  }

  Widget _buildCurrentStepCard(TouchTestStep step, int index) {
    Color cardColor;
    Color iconColor;
    IconData icon;
    String statusText;
    
    switch (step.status) {
      case TouchStepStatus.testing:
        cardColor = Colors.blue.shade50;
        iconColor = Colors.blue.shade600;
        icon = Icons.settings;
        statusText = '正在初始化...';
        break;
      case TouchStepStatus.userAction:
        cardColor = Colors.orange.shade50;
        iconColor = Colors.orange.shade600;
        icon = Icons.touch_app;
        statusText = '等待用户操作';
        break;
      default:
        cardColor = Colors.grey.shade50;
        iconColor = Colors.grey.shade600;
        icon = Icons.help_outline;
        statusText = '准备中...';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                child: step.status == TouchStepStatus.testing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '步骤 ${index + 1}: ${step.name}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // 用户操作提示
          if (step.status == TouchStepStatus.userAction) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    _getActionIcon(step.actionId, isLeftTouch),
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '请按照提示操作',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step.userPrompt,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '测试完成！',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '所有Touch功能测试已成功完成',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsList(List<TouchTestStep> steps) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: steps.length,
        itemBuilder: (context, index) {
          final step = steps[index];
          return Consumer<TestState>(
            builder: (context, state, child) {
              return _buildStepListItem(step, index, state);
            },
          );
        },
      ),
    );
  }

  Widget _buildStepListItem(TouchTestStep step, int index, TestState state) {
    Color statusColor;
    IconData statusIcon;
    
    switch (step.status) {
      case TouchStepStatus.waiting:
        statusColor = Colors.grey.shade400;
        statusIcon = Icons.radio_button_unchecked;
        break;
      case TouchStepStatus.testing:
        statusColor = Colors.blue.shade600;
        statusIcon = Icons.settings;
        break;
      case TouchStepStatus.userAction:
        statusColor = Colors.orange.shade600;
        statusIcon = Icons.touch_app;
        break;
      case TouchStepStatus.success:
        statusColor = Colors.green.shade600;
        statusIcon = Icons.check_circle;
        break;
      case TouchStepStatus.failed:
        statusColor = Colors.red.shade600;
        statusIcon = Icons.error;
        break;
      case TouchStepStatus.timeout:
        statusColor = Colors.orange.shade600;
        statusIcon = Icons.access_time;
        break;
      case TouchStepStatus.skipped:
        statusColor = Colors.grey.shade600;
        statusIcon = Icons.skip_next;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${index + 1}. ${step.name}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // CDC值和差值显示
          if (step.cdcValue != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'CDC: ${step.cdcValue}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (step.cdcDiff != null)
                  Text(
                    '差值: ${step.cdcDiff}',
                    style: TextStyle(
                      fontSize: 11,
                      color: step.cdcDiff! >= 500 ? Colors.green.shade600 : Colors.orange.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          
          // 重试和跳过按钮（在Touch失败时显示）
          if ((step.status == TouchStepStatus.failed || step.status == TouchStepStatus.timeout) &&
              (!isLeftTouch ? step.actionId != 0 : true)) // 右Touch不允许跳过基线步骤
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    final stepIndex = (isLeftTouch ? state.leftTouchTestSteps : state.rightTouchTestSteps)
                        .indexWhere((s) => s.actionId == step.actionId);
                    if (stepIndex >= 0) {
                      if (isLeftTouch) {
                        state.retryLeftTouchStep(stepIndex);
                      } else {
                        state.retryRightTouchStep(stepIndex);
                      }
                    }
                  },
                  icon: Icon(Icons.refresh, size: 16, color: Colors.blue.shade600),
                  tooltip: '重试',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
                IconButton(
                  onPressed: () {
                    final stepIndex = (isLeftTouch ? state.leftTouchTestSteps : state.rightTouchTestSteps)
                        .indexWhere((s) => s.actionId == step.actionId);
                    if (stepIndex >= 0) {
                      if (isLeftTouch) {
                        state.skipLeftTouchStep(stepIndex);
                      } else {
                        state.skipRightTouchStep(stepIndex);
                      }
                    }
                  },
                  icon: Icon(Icons.skip_next, size: 16, color: Colors.grey.shade600),
                  tooltip: '跳过',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context, TestState state) {
    final steps = isLeftTouch ? state.leftTouchTestSteps : state.rightTouchTestSteps;
    final allCompleted = steps.every((step) => 
        step.status == TouchStepStatus.success || step.status == TouchStepStatus.skipped);
    
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => state.closeTouchDialog(),
            child: const Text('关闭'),
          ),
        ),
        if (allCompleted) ...[
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => state.closeTouchDialog(),
              icon: const Icon(Icons.check),
              label: const Text('完成'),
            ),
          ),
        ],
      ],
    );
  }

  IconData _getActionIcon(int actionId, bool isLeft) {
    if (isLeft) {
      switch (actionId) {
        case 1: // 单击
          return Icons.touch_app;
        case 2: // 双击
          return Icons.double_arrow;
        case 3: // 长按
          return Icons.timer;
        case 4: // 佩戴检测
          return Icons.hearing;
        default:
          return Icons.touch_app;
      }
    } else {
      switch (actionId) {
        case 1: // TK1
          return Icons.looks_one;
        case 2: // TK2
          return Icons.looks_two;
        case 3: // TK3
          return Icons.looks_3;
        default:
          return Icons.touch_app;
      }
    }
  }
}
