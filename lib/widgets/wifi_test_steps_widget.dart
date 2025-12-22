import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';

/// WiFi测试步骤展示组件
class WiFiTestStepsWidget extends StatelessWidget {
  const WiFiTestStepsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, testState, child) {
        final steps = testState.wifiTestSteps;
        
        if (steps.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'WiFi测试步骤未初始化',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WiFi测试步骤',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...steps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final step = entry.value;
                  return _buildStepItem(context, testState, index, step);
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepItem(BuildContext context, TestState testState, int index, WiFiTestStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _getStepBorderColor(step.status)),
        borderRadius: BorderRadius.circular(8),
        color: _getStepBackgroundColor(step.status),
      ),
      child: Row(
        children: [
          // 状态图标
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStepIconColor(step.status),
            ),
            child: _getStepIcon(step.status),
          ),
          const SizedBox(width: 12),
          
          // 步骤信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      step.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(0x${step.opt.toRadixString(16).toUpperCase().padLeft(2, '0')})',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  step.description,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
                if (step.status == WiFiStepStatus.testing && step.currentRetry > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '重试 ${step.currentRetry}/${step.maxRetries}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (step.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '错误: ${step.errorMessage}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                      ),
                    ),
                  ),
                if (step.result != null && step.result!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatStepResult(step),
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // 重试按钮
          if (step.status == WiFiStepStatus.failed)
            SizedBox(
              width: 60,
              height: 28,
              child: ElevatedButton(
                onPressed: testState.isRunningTest 
                    ? null 
                    : () => testState.retryWiFiStep(index),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 10),
                ),
                child: const Text('重试'),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStepBorderColor(WiFiStepStatus status) {
    switch (status) {
      case WiFiStepStatus.waiting:
        return Colors.grey[300]!;
      case WiFiStepStatus.testing:
        return Colors.blue[300]!;
      case WiFiStepStatus.success:
        return Colors.green[300]!;
      case WiFiStepStatus.failed:
        return Colors.red[300]!;
      case WiFiStepStatus.timeout:
        return Colors.orange[300]!;
    }
  }

  Color _getStepBackgroundColor(WiFiStepStatus status) {
    switch (status) {
      case WiFiStepStatus.waiting:
        return Colors.grey[50]!;
      case WiFiStepStatus.testing:
        return Colors.blue[50]!;
      case WiFiStepStatus.success:
        return Colors.green[50]!;
      case WiFiStepStatus.failed:
        return Colors.red[50]!;
      case WiFiStepStatus.timeout:
        return Colors.orange[50]!;
    }
  }

  Color _getStepIconColor(WiFiStepStatus status) {
    switch (status) {
      case WiFiStepStatus.waiting:
        return Colors.grey[400]!;
      case WiFiStepStatus.testing:
        return Colors.blue[400]!;
      case WiFiStepStatus.success:
        return Colors.green[400]!;
      case WiFiStepStatus.failed:
        return Colors.red[400]!;
      case WiFiStepStatus.timeout:
        return Colors.orange[400]!;
    }
  }

  Widget _getStepIcon(WiFiStepStatus status) {
    switch (status) {
      case WiFiStepStatus.waiting:
        return const Icon(Icons.schedule, color: Colors.white, size: 16);
      case WiFiStepStatus.testing:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case WiFiStepStatus.success:
        return const Icon(Icons.check, color: Colors.white, size: 16);
      case WiFiStepStatus.failed:
        return const Icon(Icons.close, color: Colors.white, size: 16);
      case WiFiStepStatus.timeout:
        return const Icon(Icons.access_time, color: Colors.white, size: 16);
    }
  }

  String _formatStepResult(WiFiTestStep step) {
    final result = step.result!;
    final parts = <String>[];
    
    if (result.containsKey('rssi')) {
      parts.add('RSSI: ${result['rssi']}dBm');
    }
    if (result.containsKey('mac')) {
      parts.add('MAC: ${result['mac']}');
    }
    if (result.containsKey('status')) {
      parts.add('状态: ${result['status']}');
    }
    
    return parts.isEmpty ? '成功' : parts.join(', ');
  }
}
