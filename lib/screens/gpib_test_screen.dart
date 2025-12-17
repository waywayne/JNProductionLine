import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/log_state.dart';
import '../services/gpib_service.dart';
import '../services/gpib_commands.dart';
import '../widgets/gpib_log_console.dart';
import 'dart:io';

/// GPIB 测试界面
class GpibTestScreen extends StatefulWidget {
  const GpibTestScreen({super.key});

  @override
  State<GpibTestScreen> createState() => _GpibTestScreenState();
}

class _GpibTestScreenState extends State<GpibTestScreen> {
  final GpibService _gpibService = GpibService();
  late GpibCommands _gpibCommands;
  
  final TextEditingController _addressController = TextEditingController(text: 'GPIB0::10::INSTR');
  final TextEditingController _voltageController = TextEditingController(text: '5.0');
  final TextEditingController _currentLimitController = TextEditingController(text: '1.5');
  final TextEditingController _currentRangeController = TextEditingController(text: '1.0');
  final TextEditingController _sampleCountController = TextEditingController(text: '100');
  final TextEditingController _sampleRateController = TextEditingController(text: '10');
  final TextEditingController _alertThresholdController = TextEditingController(text: '1.0');
  
  bool _isCollecting = false;
  List<Map<String, dynamic>> _collectedData = [];
  
  @override
  void initState() {
    super.initState();
    _gpibCommands = GpibCommands(_gpibService);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final logState = Provider.of<LogState>(context, listen: false);
      _gpibService.setLogState(logState);
      _gpibCommands.setLogState(logState);
    });
  }
  
  @override
  void dispose() {
    _gpibService.dispose();
    _addressController.dispose();
    _voltageController.dispose();
    _currentLimitController.dispose();
    _currentRangeController.dispose();
    _sampleCountController.dispose();
    _sampleRateController.dispose();
    _alertThresholdController.dispose();
    super.dispose();
  }
  
  Future<void> _connect() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      _showError('请输入 GPIB 地址');
      return;
    }
    
    final success = await _gpibService.connect(address);
    if (success) {
      setState(() {});
    }
  }
  
  Future<void> _disconnect() async {
    await _gpibService.disconnect();
    setState(() {});
  }
  
  Future<void> _checkEnvironment() async {
    final logState = Provider.of<LogState>(context, listen: false);
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('检查 Python 环境...');
    
    final envCheck = await _gpibService.checkPythonEnvironment();
    
    if (envCheck['pythonInstalled']) {
      logState.success('✅ Python 已安装: ${envCheck['pythonCommand']}');
    } else {
      logState.error('❌ Python 未安装');
      logState.info('请下载并安装 Python 3.7+: https://www.python.org/downloads/');
      logState.info('安装时请勾选 "Add Python to PATH"');
    }
    
    if (envCheck['pyvisaInstalled']) {
      logState.success('✅ PyVISA 已安装');
    } else {
      logState.warning('⚠️  PyVISA 未安装');
      logState.info('请点击"安装 Python 依赖"按钮进行安装');
    }
    
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
  
  Future<void> _installDependencies() async {
    final success = await _gpibService.installPythonDependencies();
    if (success) {
      setState(() {});
    }
  }
  
  Future<void> _scanDevices() async {
    await _gpibService.listResources();
  }
  
  Future<void> _identify() async {
    await _gpibCommands.identify();
  }
  
  Future<void> _initializePowerSupply() async {
    final voltage = double.tryParse(_voltageController.text) ?? 5.0;
    final currentLimit = double.tryParse(_currentLimitController.text) ?? 1.5;
    final currentRange = double.tryParse(_currentRangeController.text) ?? 1.0;
    
    await _gpibCommands.initializePowerSupply(
      voltage: voltage,
      currentLimit: currentLimit,
      currentRange: currentRange,
    );
  }
  
  Future<void> _startCollection() async {
    if (_isCollecting) return;
    
    final sampleCount = int.tryParse(_sampleCountController.text) ?? 100;
    final sampleRate = double.tryParse(_sampleRateController.text) ?? 10.0;
    final alertThreshold = double.tryParse(_alertThresholdController.text);
    
    setState(() {
      _isCollecting = true;
      _collectedData.clear();
    });
    
    await _gpibCommands.collectCurrentData(
      sampleCount: sampleCount,
      sampleRate: sampleRate,
      alertThreshold: alertThreshold,
      onData: (index, current, timestamp) {
        setState(() {
          _collectedData.add({
            'index': index,
            'current': current,
            'timestamp': timestamp,
          });
        });
      },
      onComplete: () {
        setState(() {
          _isCollecting = false;
        });
      },
    );
  }
  
  Future<void> _stopCollection() async {
    setState(() {
      _isCollecting = false;
    });
  }
  
  Future<void> _exportData() async {
    if (_collectedData.isEmpty) {
      _showError('没有数据可导出');
      return;
    }
    
    try {
      final timestamp = DateTime.now();
      final filename = 'PCBA电流采集数据_${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}${timestamp.second.toString().padLeft(2, '0')}.csv';
      
      final file = File(filename);
      final buffer = StringBuffer();
      
      // CSV 头部
      buffer.writeln('序号,时间戳,PCBA工作电流(A)');
      
      // 数据行
      for (final data in _collectedData) {
        final index = data['index'];
        final current = data['current'];
        final timestamp = data['timestamp'] as DateTime;
        final timeStr = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}';
        
        buffer.writeln('$index,$timeStr,$current');
      }
      
      await file.writeAsString(buffer.toString());
      
      final logState = Provider.of<LogState>(context, listen: false);
      logState.success('数据已导出到: $filename');
    } catch (e) {
      _showError('导出失败: $e');
    }
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
        title: const Text('GPIB 电流采集测试'),
        backgroundColor: Colors.blue,
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
                    _buildConnectionSection(),
                    const SizedBox(height: 16),
                    _buildPowerSupplySection(),
                    const SizedBox(height: 16),
                    _buildCollectionSection(),
                    const SizedBox(height: 16),
                    _buildDataSection(),
                  ],
                ),
              ),
            ),
          ),
          
          // 右侧 GPIB 专用日志查看器
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
  
  Widget _buildConnectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '1. GPIB 连接',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'GPIB 地址',
                hintText: 'GPIB0::10::INSTR',
                border: OutlineInputBorder(),
              ),
              enabled: !_gpibService.isConnected,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _checkEnvironment,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('检查环境'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _installDependencies,
                    icon: const Icon(Icons.download),
                    label: const Text('安装依赖'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _scanDevices,
              icon: const Icon(Icons.search),
              label: const Text('扫描 GPIB 设备'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _gpibService.isConnected ? null : _connect,
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
                    onPressed: _gpibService.isConnected ? _disconnect : null,
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
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _gpibService.isConnected ? _identify : null,
              icon: const Icon(Icons.info_outline),
              label: const Text('查询设备型号'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPowerSupplySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '2. 电源初始化',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _voltageController,
              decoration: const InputDecoration(
                labelText: '输出电压 (V)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _currentLimitController,
              decoration: const InputDecoration(
                labelText: '电流限制 (A)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _currentRangeController,
              decoration: const InputDecoration(
                labelText: '电流测量范围 (A)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _gpibService.isConnected ? _initializePowerSupply : null,
              icon: const Icon(Icons.power_settings_new),
              label: const Text('初始化电源'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCollectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '3. 电流采集',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sampleCountController,
                    decoration: const InputDecoration(
                      labelText: '采样次数',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _sampleRateController,
                    decoration: const InputDecoration(
                      labelText: '采样率 (Hz)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _alertThresholdController,
              decoration: const InputDecoration(
                labelText: '报警阈值 (A)',
                hintText: '超过此值将报警',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _gpibService.isConnected && !_isCollecting ? _startCollection : null,
              icon: Icon(_isCollecting ? Icons.hourglass_empty : Icons.play_arrow),
              label: Text(_isCollecting ? '采集中...' : '开始采集'),
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
  
  Widget _buildDataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '4. 采集数据',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_collectedData.length} 条',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _collectedData.isEmpty
                  ? const Center(child: Text('暂无数据'))
                  : ListView.builder(
                      itemCount: _collectedData.length,
                      itemBuilder: (context, index) {
                        final data = _collectedData[index];
                        final current = data['current'] as double;
                        final timestamp = data['timestamp'] as DateTime;
                        final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}';
                        
                        return ListTile(
                          dense: true,
                          leading: Text('#${index + 1}'),
                          title: Text('${current.toStringAsFixed(4)} A'),
                          trailing: Text(timeStr, style: const TextStyle(fontSize: 12)),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _collectedData.isNotEmpty ? _exportData : null,
              icon: const Icon(Icons.save),
              label: const Text('导出为 CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
