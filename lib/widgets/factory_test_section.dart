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
                  // 如果没有连接或没有测试组，显示提示信息
                  if (state.currentTestGroup == null) {
                    return Center(
                      child: Text(
                        '请先连接串口设备',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  }
                  
                  // 显示单个测试组
                  return Column(
                    children: [
                      Expanded(
                        child: _TestGroupWidget(
                          group: state.currentTestGroup!,
                          onStart: state.startTest,
                          testState: state,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
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
