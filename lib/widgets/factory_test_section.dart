import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import 'manual_test_section.dart';

/// Show error dialog
void _showErrorDialog(BuildContext context, String testName, String errorMessage) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('测试失败: $testName'),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      );
    },
  );
}

class FactoryTestSection extends StatefulWidget {
  const FactoryTestSection({super.key});

  @override
  State<FactoryTestSection> createState() => _FactoryTestSectionState();
}

class _FactoryTestSectionState extends State<FactoryTestSection> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab bar
        TabBar(
          controller: _tabController,
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blue,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(text: '自动测试'),
            Tab(text: '手动测试'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: 自动测试
              Consumer<TestState>(
                builder: (context, state, _) {
                  return _buildAutoTestTab(context, state);
                },
              ),
              // Tab 2: 手动测试
              const ManualTestSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAutoTestTab(BuildContext context, TestState state) {
    if (!state.isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cable, size: 64, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              '请先连接串口设备',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '连接设备后即可开始自动化测试',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[50]!, Colors.white],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 设备信息卡片 - 优化样式
            if (state.currentDeviceIdentity != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[400]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.devices, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '当前测试设备',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SN: ${state.currentDeviceIdentity!['sn'] ?? 'N/A'}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (state.currentDeviceIdentity!['mac'] != null)
                            Text(
                              'MAC: ${state.currentDeviceIdentity!['mac']}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),
            
            // 自动化测试按钮 - 优化样式
            Container(
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: state.isAutoTesting
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: ElevatedButton(
                onPressed: state.isAutoTesting ? null : () => state.startAutoTest(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: state.isAutoTesting ? Colors.grey[400] : Colors.green[600],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (state.isAutoTesting)
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else
                      const Icon(Icons.play_circle_filled, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      state.isAutoTesting ? '测试进行中...' : '开始自动化测试',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
          
          // 测试进度显示 - 优化样式
          if (state.isAutoTesting || state.testReportItems.isNotEmpty)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 进度标题 - 优化样式
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.grey[100]!, Colors.grey[50]!],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.assignment, size: 20, color: Colors.blue[700]),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '测试进度',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (state.testReportItems.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${state.testReportItems.where((item) => item.status.toString().contains('pass')).length}/${state.testReportItems.length}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // 测试项列表 - 优化样式
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: state.testReportItems.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final item = state.testReportItems[index];
                          final isCurrentTest = state.isAutoTesting && index == state.currentAutoTestIndex;
                          
                          return Container(
                            decoration: BoxDecoration(
                              color: isCurrentTest ? Colors.blue[50] : Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCurrentTest ? Colors.blue[300]! : Colors.grey[200]!,
                                width: isCurrentTest ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: _buildStatusIcon(item.status, isCurrentTest),
                              title: Text(
                                item.testName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isCurrentTest ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: item.errorMessage != null
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        item.errorMessage!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.red[700],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  : null,
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(item.status).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _getStatusColor(item.status),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  item.statusText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _getStatusColor(item.status),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(dynamic status, bool isCurrentTest) {
    if (isCurrentTest) {
      return Container(
        width: 28,
        height: 28,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.blue[100],
          shape: BoxShape.circle,
        ),
        child: const CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      );
    }

    final statusStr = status.toString();
    if (statusStr.contains('pass')) {
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.green[50],
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
      );
    } else if (statusStr.contains('fail')) {
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.red[50],
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.cancel, color: Colors.red, size: 24),
      );
    } else if (statusStr.contains('skip')) {
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.skip_next, color: Colors.orange[700], size: 24),
      );
    } else if (statusStr.contains('running')) {
      return Container(
        width: 28,
        height: 28,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.blue[100],
          shape: BoxShape.circle,
        ),
        child: const CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      );
    } else {
      return Icon(Icons.radio_button_unchecked, color: Colors.grey[400], size: 24);
    }
  }

  Color _getStatusColor(dynamic status) {
    final statusStr = status.toString();
    if (statusStr.contains('pass')) {
      return Colors.green;
    } else if (statusStr.contains('fail')) {
      return Colors.red;
    } else if (statusStr.contains('skip')) {
      return Colors.orange;
    } else if (statusStr.contains('running')) {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }
}

class _TestGroupWidget extends StatelessWidget {
  final TestGroup group;
  final VoidCallback onStart;
  final TestState testState;

  const _TestGroupWidget({
    required this.group,
    required this.onStart,
    required this.testState,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Group name input
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            group.name,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
        // Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[400]!),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _TableCell('Test-Item', isHeader: true),
                      ),
                      Expanded(
                        flex: 2,
                        child: _TableCell('T-Method', isHeader: true),
                      ),
                      Expanded(
                        flex: 2,
                        child: _TableCell('T-Result', isHeader: true),
                      ),
                    ],
                  ),
                ),
                // Items
                Expanded(
                  child: ListView.builder(
                    itemCount: group.items.length,
                    itemBuilder: (context, index) {
                      final item = group.items[index];
                      return Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: item.backgroundColor,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey[400]!,
                              width: index < group.items.length - 1 ? 1 : 0,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _TableCell(item.name),
                            ),
                            Expanded(
                              flex: 2,
                              child: _TableCell(item.method),
                            ),
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _TableCell(item.result),
                                  ),
                                  // Status indicator
                                  if (item.status == TestStatus.pass)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: Icon(Icons.check_circle, color: Colors.green, size: 16),
                                    )
                                  else if (item.status == TestStatus.fail || 
                                           item.status == TestStatus.error ||
                                           item.status == TestStatus.timeout)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(right: 2),
                                          child: Icon(Icons.error, color: Colors.red, size: 16),
                                        ),
                                        // Error info button
                                        if (item.errorMessage != null)
                                          InkWell(
                                            onTap: () => _showErrorDialog(context, item.name, item.errorMessage!),
                                            child: const Padding(
                                              padding: EdgeInsets.only(right: 2),
                                              child: Icon(Icons.info_outline, color: Colors.blue, size: 16),
                                            ),
                                          ),
                                        // Retry button
                                        Consumer<TestState>(
                                          builder: (context, state, _) {
                                            return InkWell(
                                              onTap: state.isRunningTest ? null : () {
                                                state.retryTest(index);
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.only(right: 4),
                                                child: Icon(
                                                  Icons.refresh, 
                                                  color: state.isRunningTest ? Colors.grey : Colors.orange, 
                                                  size: 16,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    )
                                  else if (item.status == TestStatus.testing)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Start/Stop button
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton(
            onPressed: group.name.isNotEmpty 
                ? (testState.isRunningTest ? testState.stopTest : onStart)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: testState.isRunningTest 
                  ? Colors.red[400] 
                  : Colors.grey[400],
              foregroundColor: testState.isRunningTest 
                  ? Colors.white 
                  : Colors.black87,
              disabledBackgroundColor: Colors.grey[300],
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Text(
              testState.isRunningTest ? 'Stop' : 'Start',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool isHeader;

  const _TableCell(this.text, {this.isHeader = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey[400]!),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.w500 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
