import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/log_state.dart';
import '../services/gpib_service.dart';
import '../services/gpib_service_v2.dart';
import '../widgets/gpib_log_console.dart';

/// GPIB测试对比页面 - 对比V1和V2实现
class GpibTestComparisonScreen extends StatefulWidget {
  const GpibTestComparisonScreen({super.key});

  @override
  State<GpibTestComparisonScreen> createState() => _GpibTestComparisonScreenState();
}

class _GpibTestComparisonScreenState extends State<GpibTestComparisonScreen> {
  final GpibService _serviceV1 = GpibService();
  final GpibServiceV2 _serviceV2 = GpibServiceV2();
  
  final TextEditingController _addressController = TextEditingController(text: 'GPIB0::5::INSTR');
  final TextEditingController _commandController = TextEditingController(text: '*IDN?');
  
  String _selectedVersion = 'V2'; // 默认使用V2
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final logState = Provider.of<LogState>(context, listen: false);
      _serviceV1.setLogState(logState);
      _serviceV2.setLogState(logState);
    });
  }
  
  @override
  void dispose() {
    _serviceV1.dispose();
    _serviceV2.dispose();
    _addressController.dispose();
    _commandController.dispose();
    super.dispose();
  }
  
  Future<void> _connect() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      _showError('请输入GPIB地址');
      return;
    }
    
    final logState = Provider.of<LogState>(context, listen: false);
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
    logState.info('使用版本: $_selectedVersion', type: LogType.gpib);
    
    final stopwatch = Stopwatch()..start();
    
    bool success;
    if (_selectedVersion == 'V1') {
      success = await _serviceV1.connect(address);
    } else {
      success = await _serviceV2.connect(address);
    }
    
    stopwatch.stop();
    
    if (success) {
      logState.success('连接耗时: ${stopwatch.elapsedMilliseconds}ms', type: LogType.gpib);
      setState(() {});
    } else {
      logState.error('连接失败，耗时: ${stopwatch.elapsedMilliseconds}ms', type: LogType.gpib);
    }
  }
  
  Future<void> _disconnect() async {
    if (_selectedVersion == 'V1') {
      await _serviceV1.disconnect();
    } else {
      await _serviceV2.disconnect();
    }
    setState(() {});
  }
  
  Future<void> _sendCommand() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) {
      _showError('请输入命令');
      return;
    }
    
    final logState = Provider.of<LogState>(context, listen: false);
    logState.info('📤 发送: $command', type: LogType.gpib);
    
    final stopwatch = Stopwatch()..start();
    
    String? response;
    if (command.endsWith('?')) {
      if (_selectedVersion == 'V1') {
        response = await _serviceV1.query(command);
      } else {
        response = await _serviceV2.query(command);
      }
    } else {
      if (_selectedVersion == 'V1') {
        response = await _serviceV1.sendCommand(command);
      } else {
        response = await _serviceV2.sendCommand(command);
      }
    }
    
    stopwatch.stop();
    
    if (response != null && response != 'TIMEOUT') {
      logState.success('📥 响应 (${stopwatch.elapsedMilliseconds}ms): $response', type: LogType.gpib);
    } else {
      logState.error('❌ 超时或失败 (${stopwatch.elapsedMilliseconds}ms)', type: LogType.gpib);
    }
  }
  
  Future<void> _listResources() async {
    if (_selectedVersion == 'V1') {
      await _serviceV1.listResources();
    } else {
      await _serviceV2.listResources();
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  bool get _isConnected {
    return _selectedVersion == 'V1' ? _serviceV1.isConnected : _serviceV2.isConnected;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPIB 测试对比'),
        backgroundColor: Colors.purple,
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
                    _buildVersionSelector(),
                    const SizedBox(height: 16),
                    _buildConnectionSection(),
                    const SizedBox(height: 16),
                    _buildCommandSection(),
                    const SizedBox(height: 16),
                    _buildQuickTestSection(),
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
  
  Widget _buildVersionSelector() {
    return Card(
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '选择实现版本',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'V1',
                  label: Text('V1 (原版)'),
                  icon: Icon(Icons.looks_one),
                ),
                ButtonSegment(
                  value: 'V2',
                  label: Text('V2 (简化版)'),
                  icon: Icon(Icons.looks_two),
                ),
              ],
              selected: {_selectedVersion},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedVersion = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              _selectedVersion == 'V1' 
                  ? '原始实现：完整的后端选择和错误处理'
                  : '简化实现：直接使用pyvisa-py，更快速',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConnectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'GPIB 连接',
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
              enabled: !_isConnected,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _listResources,
              icon: const Icon(Icons.search),
              label: const Text('扫描设备'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected ? null : _connect,
                    icon: const Icon(Icons.link),
                    label: const Text('连接'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected ? _disconnect : null,
                    icon: const Icon(Icons.link_off),
                    label: const Text('断开'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCommandSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '手动命令',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commandController,
              decoration: const InputDecoration(
                labelText: 'SCPI 命令',
                hintText: '*IDN? 或 :READ[1]?',
                border: OutlineInputBorder(),
              ),
              enabled: _isConnected,
              onSubmitted: (_) => _sendCommand(),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isConnected ? _sendCommand : null,
              icon: const Icon(Icons.send),
              label: const Text('发送命令'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickTestSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '快速测试',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickTestButton('*IDN?', '设备识别'),
                _buildQuickTestButton('*RST', '复位'),
                _buildQuickTestButton(':READ[1]?', '读取电流'),
                _buildQuickTestButton(':OUTPut1:STATe?', '查询输出'),
                _buildQuickTestButton(':SOURce1:VOLTage?', '查询电压'),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickTestButton(String command, String label) {
    return ElevatedButton(
      onPressed: _isConnected ? () {
        _commandController.text = command;
        _sendCommand();
      } : null,
      child: Text(label),
    );
  }
}
