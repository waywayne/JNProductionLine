import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/log_state.dart';
import '../services/gpib_diagnostic_service.dart';
import '../widgets/gpib_log_console.dart';

/// GPIB诊断页面 - 多种方式测试GPIB连接
class GpibDiagnosticScreen extends StatefulWidget {
  const GpibDiagnosticScreen({super.key});

  @override
  State<GpibDiagnosticScreen> createState() => _GpibDiagnosticScreenState();
}

class _GpibDiagnosticScreenState extends State<GpibDiagnosticScreen> {
  final GpibDiagnosticService _diagnosticService = GpibDiagnosticService();
  final TextEditingController _addressController = TextEditingController(text: 'GPIB0::5::INSTR');
  
  bool _isRunning = false;
  Map<String, dynamic> _results = {};
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final logState = Provider.of<LogState>(context, listen: false);
      _diagnosticService.setLogState(logState);
    });
  }
  
  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }
  
  Future<void> _runAllTests() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      _showError('请输入GPIB地址');
      return;
    }
    
    setState(() {
      _isRunning = true;
      _results.clear();
    });
    
    final results = await _diagnosticService.runAllDiagnostics(address);
    
    setState(() {
      _isRunning = false;
      _results = results;
    });
  }
  
  Future<void> _runSingleTest(String testName, Future<Map<String, dynamic>> Function() testFunc) async {
    setState(() => _isRunning = true);
    
    final result = await testFunc();
    
    setState(() {
      _isRunning = false;
      _results[testName] = result;
    });
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPIB 诊断工具'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Row(
        children: [
          // 左侧控制面板
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAddressSection(),
                    const SizedBox(height: 16),
                    _buildQuickTestsSection(),
                    const SizedBox(height: 16),
                    _buildDetailedTestsSection(),
                    const SizedBox(height: 16),
                    _buildResultsSummary(),
                  ],
                ),
              ),
            ),
          ),
          
          // 右侧日志
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Colors.grey.shade300)),
              ),
              child: const GpibLogConsole(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAddressSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'GPIB 设备地址',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'GPIB 地址',
                hintText: 'GPIB0::5::INSTR',
                border: OutlineInputBorder(),
              ),
              enabled: !_isRunning,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickTestsSection() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  '快速测试',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _runAllTests,
              icon: _isRunning 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isRunning ? '测试中...' : '运行全部诊断'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailedTestsSection() {
    final address = _addressController.text.trim();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '单项测试',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTestButton(
              '方法1: 直接命令',
              '使用python -c执行单次命令',
              Icons.code,
              () => _runSingleTest('method1', () => _diagnosticService.testMethod1_DirectCommand(address)),
            ),
            _buildTestButton(
              '方法2: 脚本文件',
              '创建临时Python脚本执行',
              Icons.description,
              () => _runSingleTest('method2', () => _diagnosticService.testMethod2_ScriptFile(address)),
            ),
            _buildTestButton(
              '方法3: 资源列表',
              '扫描所有VISA资源',
              Icons.list,
              () => _runSingleTest('method3', () => _diagnosticService.testMethod3_ListResources()),
            ),
            _buildTestButton(
              '方法4: 仅写入',
              '测试写入命令（*CLS）',
              Icons.edit,
              () => _runSingleTest('method4', () => _diagnosticService.testMethod4_WriteOnly(address)),
            ),
            _buildTestButton(
              '方法5: 简单查询',
              '测试*OPC?查询',
              Icons.question_answer,
              () => _runSingleTest('method5', () => _diagnosticService.testMethod5_SimpleQuery(address)),
            ),
            _buildTestButton(
              '方法6: 终止符测试',
              '测试不同的终止符配置',
              Icons.settings_ethernet,
              () => _runSingleTest('method6', () => _diagnosticService.testMethod6_Terminators(address)),
            ),
            _buildTestButton(
              '方法7: 超时测试',
              '测试不同的超时配置',
              Icons.timer,
              () => _runSingleTest('method7', () => _diagnosticService.testMethod7_Timeouts(address)),
            ),
            _buildTestButton(
              '方法8: Linux诊断',
              '检查Linux权限和驱动',
              Icons.computer,
              () => _runSingleTest('method8', () => _diagnosticService.testMethod8_LinuxDiagnostics()),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTestButton(String title, String subtitle, IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: _isRunning ? null : onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(12),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResultsSummary() {
    if (_results.isEmpty) {
      return const SizedBox.shrink();
    }
    
    int successCount = 0;
    int totalCount = 0;
    
    _results.forEach((key, value) {
      if (value is Map && value.containsKey('success')) {
        totalCount++;
        if (value['success'] == true) {
          successCount++;
        }
      }
    });
    
    final successRate = totalCount > 0 ? (successCount / totalCount * 100).toStringAsFixed(0) : '0';
    
    return Card(
      color: successCount > 0 ? Colors.blue.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  successCount > 0 ? Icons.check_circle : Icons.error,
                  color: successCount > 0 ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                const Text(
                  '测试结果摘要',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '成功: $successCount / $totalCount ($successRate%)',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._results.entries.map((entry) {
              if (entry.value is! Map || !entry.value.containsKey('success')) {
                return const SizedBox.shrink();
              }
              
              final success = entry.value['success'] == true;
              final time = entry.value['time'];
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      success ? Icons.check : Icons.close,
                      size: 16,
                      color: success ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (time != null)
                      Text(
                        '${time}ms',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
