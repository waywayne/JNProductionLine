import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/automation_test_state.dart';
import '../models/automation_test_config.dart';
import 'gpib_address_dialog.dart';

class AutomationTestWidget extends StatelessWidget {
  const AutomationTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AutomationTestState>(
      builder: (context, state, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题和控制按钮
              Row(
                children: [
                  Icon(
                    Icons.auto_mode,
                    color: Colors.blue.shade600,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '自动化测试',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _buildControlButtons(context, state),
                ],
              ),
              const SizedBox(height: 16),
              
              // 状态信息
              _buildStatusInfo(state),
              const SizedBox(height: 16),
              
              // 进度指示器
              if (state.testSteps.isNotEmpty) ...[
                _buildProgressIndicator(state),
                const SizedBox(height: 16),
              ],
              
              // 测试步骤列表
              Expanded(
                child: _buildTestStepsList(state),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildControlButtons(BuildContext context, AutomationTestState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!state.isRunning) ...[
          ElevatedButton.icon(
            onPressed: () => _showGpibDialog(context, state),
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始测试'),
          ),
        ] else ...[
          if (state.isPaused) ...[
            ElevatedButton.icon(
              onPressed: state.resumeTest,
              icon: const Icon(Icons.play_arrow),
              label: const Text('继续'),
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: state.pauseTest,
              icon: const Icon(Icons.pause),
              label: const Text('暂停'),
            ),
          ],
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: state.stopTest,
            icon: const Icon(Icons.stop),
            label: const Text('停止'),
          ),
        ],
      ],
    );
  }
  
  Widget _buildStatusInfo(AutomationTestState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // GPIB连接状态
          Row(
            children: [
              Icon(
                state.isGpibConnected ? Icons.link : Icons.link_off,
                color: state.isGpibConnected ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'GPIB: ${state.isGpibConnected ? "已连接" : "未连接"}',
                style: TextStyle(
                  fontSize: 12,
                  color: state.isGpibConnected ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          
          // 测试状态
          Row(
            children: [
              Icon(
                state.isRunning 
                    ? (state.isPaused ? Icons.pause_circle : Icons.play_circle)
                    : Icons.stop_circle,
                color: state.isRunning 
                    ? (state.isPaused ? Colors.orange : Colors.green)
                    : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                state.isRunning 
                    ? (state.isPaused ? '已暂停' : '运行中')
                    : '已停止',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          
          // 测试结果统计
          if (state.totalCount > 0) ...[
            _buildCountBadge('通过', state.passedCount, Colors.green),
            const SizedBox(width: 8),
            _buildCountBadge('失败', state.failedCount, Colors.red),
            const SizedBox(width: 8),
            _buildCountBadge('跳过', state.skippedCount, Colors.orange),
          ],
        ],
      ),
    );
  }
  
  Widget _buildCountBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _getShade700(color),
        ),
      ),
    );
  }
  
  Widget _buildProgressIndicator(AutomationTestState state) {
    final completedCount = state.passedCount + state.failedCount + state.skippedCount;
    final progress = state.totalCount > 0 ? completedCount / state.totalCount : 0.0;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '测试进度',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$completedCount / ${state.totalCount}',
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
  
  Widget _buildTestStepsList(AutomationTestState state) {
    if (state.testSteps.isEmpty) {
      return const Center(
        child: Text(
          '点击"开始测试"初始化测试步骤',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      );
    }
    
    return ListView.builder(
      itemCount: state.testSteps.length,
      itemBuilder: (context, index) {
        final step = state.testSteps[index];
        final isCurrentStep = index == state.currentStepIndex;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCurrentStep ? Colors.blue.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCurrentStep ? Colors.blue.shade300 : Colors.grey.shade200,
              width: isCurrentStep ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // 状态图标
              _buildStatusIcon(step.status),
              const SizedBox(width: 12),
              
              // 步骤信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${index + 1}. ${step.name}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildTypeChip(step.type),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (step.errorMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        step.errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // 执行时间
              if (step.duration != null)
                Text(
                  '${step.duration!.inMilliseconds}ms',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildStatusIcon(AutoTestStepStatus status) {
    switch (status) {
      case AutoTestStepStatus.waiting:
        return Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 20);
      case AutoTestStepStatus.running:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.blue.shade600,
          ),
        );
      case AutoTestStepStatus.success:
        return Icon(Icons.check_circle, color: Colors.green.shade600, size: 20);
      case AutoTestStepStatus.failed:
        return Icon(Icons.error, color: Colors.red.shade600, size: 20);
      case AutoTestStepStatus.skipped:
        return Icon(Icons.skip_next, color: Colors.orange.shade600, size: 20);
    }
  }
  
  Widget _buildTypeChip(AutoTestStepType type) {
    final isAuto = type == AutoTestStepType.automatic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAuto ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isAuto ? '自动' : '半自动',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: _getShade700(isAuto ? Colors.green : Colors.orange),
        ),
      ),
    );
  }
  
  Color _getShade700(Color color) {
    if (color == Colors.green) return Colors.green.shade700;
    if (color == Colors.red) return Colors.red.shade700;
    if (color == Colors.orange) return Colors.orange.shade700;
    return color;
  }
  
  void _showGpibDialog(BuildContext context, AutomationTestState state) async {
    final address = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => GpibAddressDialog(
        initialAddress: state.gpibAddress.isEmpty ? null : state.gpibAddress,
      ),
    );
    
    if (address != null && address.isNotEmpty) {
      state.setGpibAddress(address);
      state.initializeTestSteps();
      
      // 连接GPIB并开始测试
      final connected = await state.connectGpib();
      if (connected) {
        await state.startAutomationTest();
      }
    }
  }
}
