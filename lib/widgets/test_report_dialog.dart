import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../models/test_report.dart';

/// 测试报告弹窗
class TestReportDialog extends StatelessWidget {
  const TestReportDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, state, _) {
        final report = state.currentTestReport;
        
        if (report == null) {
          return const SizedBox.shrink();
        }

        return Dialog(
          backgroundColor: Colors.white,
          child: Container(
            width: 800,
            height: 700,
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 标题行
                Row(
            children: [
              Icon(
                report.allTestsPassed ? Icons.check_circle : Icons.error,
                color: report.allTestsPassed ? Colors.green : Colors.red,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '测试报告',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      report.allTestsPassed ? '全部通过' : '存在失败项',
                      style: TextStyle(
                        fontSize: 14,
                        color: report.allTestsPassed ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
                const SizedBox(height: 24),
                
                // 设备信息和统计
                _buildSummarySection(report),
                const SizedBox(height: 16),
                
                // 测试项列表
                Expanded(
                  child: _buildTestItemsList(report),
                ),
                
                const SizedBox(height: 16),
                
                // 操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
            TextButton.icon(
              onPressed: () async {
                final savedPath = await state.saveTestReport();
                if (savedPath != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('测试报告已保存到: $savedPath'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.save_alt),
              label: const Text('保存报告'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue[700],
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () async {
                // 清空报告（会自动关闭弹窗并重置状态）
                state.clearTestReport();
                // 等待UI更新
                await Future.delayed(const Duration(milliseconds: 200));
                // 重新开始测试
                await state.startAutoTest();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重新开始测试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: () {
                state.closeTestReportDialog();
              },
              icon: const Icon(Icons.close),
              label: const Text('关闭'),
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

  Widget _buildSummarySection(TestReport report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 设备信息
          Row(
            children: [
              const Icon(Icons.devices, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                '设备SN: ${report.deviceSN}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (report.deviceMAC != null) ...[
                const SizedBox(width: 20),
                const Icon(Icons.wifi, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'MAC: ${report.deviceMAC}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          
          // 时间信息
          Row(
            children: [
              const Icon(Icons.access_time, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                '开始: ${_formatTime(report.startTime)}',
                style: const TextStyle(fontSize: 12),
              ),
              if (report.endTime != null) ...[
                const SizedBox(width: 20),
                const Icon(Icons.timer, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '耗时: ${_formatDuration(report.totalDuration!)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
          const Divider(height: 24),
          
          // 统计信息
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('总计', report.totalTests.toString(), Colors.blue),
              _buildStatItem('通过', report.passedTests.toString(), Colors.green),
              _buildStatItem('失败', report.failedTests.toString(), Colors.red),
              _buildStatItem('通过率', '${report.passRate.toStringAsFixed(1)}%', 
                  report.passRate >= 80 ? Colors.green : Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTestItemsList(TestReport report) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        itemCount: report.items.length,
        itemBuilder: (context, index) {
          final item = report.items[index];
          return _buildTestItemTile(item, index);
        },
      ),
    );
  }

  Widget _buildTestItemTile(TestReportItem item, int index) {
    return Consumer<TestState>(
      builder: (context, state, _) {
        return Container(
          decoration: BoxDecoration(
            border: index > 0 ? Border(top: BorderSide(color: Colors.grey[200]!)) : null,
            color: item.status == TestReportStatus.fail ? Colors.red[50] : null,
          ),
          child: ListTile(
            dense: true,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: item.statusColor, width: 2),
              ),
              child: Center(
                child: Icon(
                  item.statusIcon,
                  color: item.statusColor,
                  size: 20,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.testName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: item.statusColor),
                  ),
                  child: Text(
                    item.statusText,
                    style: TextStyle(
                      fontSize: 11,
                      color: item.statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // 失败项添加重试按钮
                if (item.status == TestReportStatus.fail) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 28,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await state.retrySingleTest(index);
                      },
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('重试', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.testType,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                if (item.duration != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.timer, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDuration(item.duration!),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
            if (item.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                '错误: ${item.errorMessage}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red[700],
                ),
              ),
            ],
          ],
        ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    
    if (minutes > 0) {
      return '${minutes}分${seconds}秒';
    } else {
      return '${seconds}秒';
    }
  }
}
