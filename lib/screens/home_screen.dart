import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/test_state.dart';
import '../models/log_state.dart';
import '../widgets/menu_bar_widget.dart';
import '../widgets/file_loader_section.dart';
import '../widgets/factory_test_section.dart';
import '../widgets/serial_port_section.dart';
import '../widgets/log_console_section.dart';
import '../widgets/sn_mac_config_section.dart';
import '../widgets/wifi_test_steps_widget.dart';
import '../widgets/touch_test_dialog.dart';
import '../widgets/automation_test_widget.dart';
import '../models/automation_test_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AutomationTestState? _automationTestState;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // 初始化时设置LogState和SN/MAC配置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final logState = context.read<LogState>();
      final testState = context.read<TestState>();
      testState.setLogState(logState);
      testState.initializeSNMacConfig();
      
      // 初始化自动化测试状态
      _automationTestState = AutomationTestState(testState);
      _automationTestState!.setLogState(logState);
      
      logState.info('应用启动');
      
      // 触发重建以更新UI
      if (mounted) {
        setState(() {});
      }
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _automationTestState?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, testState, child) {
        return Stack(
          children: [
            Scaffold(
              backgroundColor: Colors.white,
              body: Column(
                children: [
                  const MenuBarWidget(),
                  
                  // 选项卡标签
                  Container(
                    color: Colors.grey.shade100,
                    child: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.build),
                          text: '手动测试',
                        ),
                        Tab(
                          icon: Icon(Icons.auto_mode),
                          text: '自动化测试',
                        ),
                      ],
                    ),
                  ),
                  
                  // 选项卡内容
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // 手动测试页面
                        _buildManualTestPage(),
                        
                        // 自动化测试页面
                        _buildAutomationTestPage(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Touch测试弹窗
            if (testState.showTouchDialog)
              TouchTestDialog(
                isLeftTouch: testState.isLeftTouchDialog,
              ),
          ],
        );
      },
    );
  }
  
  Widget _buildManualTestPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer<TestState>(
              builder: (context, state, _) => FileLoaderSection(
                title: 'Load Test Script',
                path: state.testScriptPath,
                onLoad: () => _loadFile(context, true),
              ),
            ),
            const SizedBox(height: 16),
            Consumer<TestState>(
              builder: (context, state, _) => FileLoaderSection(
                title: 'Load Config File',
                path: state.configFilePath,
                onLoad: () => _loadFile(context, false),
              ),
            ),
            const SizedBox(height: 16),
            const SerialPortSection(),
            const SizedBox(height: 16),
            const SNMacConfigSection(),
            const SizedBox(height: 16),
            const WiFiTestStepsWidget(),
            const SizedBox(height: 16),
            SizedBox(
              height: 600,
              child: Row(
                children: [
                  // Factory Test Section (左侧)
                  const Expanded(
                    flex: 3,
                    child: FactoryTestSection(),
                  ),
                  const SizedBox(width: 16),
                  // Log Console Section (右侧)
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const LogConsoleSection(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAutomationTestPage() {
    if (_automationTestState == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // 自动化测试区域
          Expanded(
            flex: 3,
            child: ChangeNotifierProvider.value(
              value: _automationTestState!,
              child: const AutomationTestWidget(),
            ),
          ),
          const SizedBox(width: 16),
          // 日志区域
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: const LogConsoleSection(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadFile(BuildContext context, bool isTestScript) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['py'],
    );

    if (result != null && result.files.single.path != null) {
      final state = context.read<TestState>();
      if (isTestScript) {
        state.setTestScriptPath(result.files.single.path!);
      } else {
        state.setConfigFilePath(result.files.single.path!);
      }
    }
  }
}
