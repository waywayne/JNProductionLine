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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // 初始化时设置LogState和SN/MAC配置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final logState = context.read<LogState>();
      final testState = context.read<TestState>();
      testState.setLogState(logState);
      testState.initializeSNMacConfig();
      logState.info('应用启动');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const MenuBarWidget(),
          Expanded(
            child: SingleChildScrollView(
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
