import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/test_state.dart';
import '../models/log_state.dart';

/// Serial port connection section widget
class SerialPortSection extends StatefulWidget {
  const SerialPortSection({super.key});

  @override
  State<SerialPortSection> createState() => _SerialPortSectionState();
}

class _SerialPortSectionState extends State<SerialPortSection> {
  String? _selectedPort;
  
  @override
  void initState() {
    super.initState();
    // 初始化时刷新串口列表并加载上次选择的串口
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLastSelectedPort();
      _refreshPorts();
    });
  }

  Future<void> _loadLastSelectedPort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPort = prefs.getString('last_selected_port');
      if (lastPort != null) {
        final testState = context.read<TestState>();
        final availablePorts = testState.availablePorts;
        
        // 检查上次选择的串口是否仍然可用
        if (availablePorts.contains(lastPort)) {
          setState(() {
            _selectedPort = lastPort;
          });
          
          // 自动连接到上次选择的串口
          final logState = context.read<LogState>();
          logState.info('检测到上次使用的串口: $lastPort，正在自动连接...');
          
          await testState.connectToPort(lastPort);
        }
      }
    } catch (e) {
      // 忽略加载错误
      debugPrint('加载上次选择的串口失败: $e');
    }
  }

  Future<void> _saveSelectedPort(String port) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_selected_port', port);
    } catch (e) {
      debugPrint('保存串口选择失败: $e');
    }
  }
  
  void _refreshPorts() {
    setState(() {
      // 触发重建以刷新串口列表
      _selectedPort = null; // 清空选择
    });
    
    // 显示刷新提示
    final ports = context.read<TestState>().availablePorts;
    final logState = context.read<LogState>();
    
    logState.info('刷新串口列表');
    logState.info('找到 ${ports.length} 个串口设备');
    for (var port in ports) {
      logState.debug('  - $port');
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('找到 ${ports.length} 个串口设备'),
          duration: const Duration(seconds: 2),
          backgroundColor: ports.isEmpty ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, state, _) {
        final availablePorts = state.availablePorts;
        final isConnected = state.isConnected;
        
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
              const Text(
                'Serial Port:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPort,
                      hint: Text(
                        availablePorts.isEmpty ? 'No ports available' : 'Select Port',
                        style: TextStyle(
                          fontSize: 13,
                          color: availablePorts.isEmpty ? Colors.grey : null,
                        ),
                      ),
                      isExpanded: true,
                      items: availablePorts.isEmpty
                          ? null
                          : availablePorts.map((port) {
                              return DropdownMenuItem<String>(
                                value: port,
                                child: Row(
                                  children: [
                                    const Icon(Icons.usb, size: 16, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        port,
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      onChanged: isConnected ? null : (value) {
                        setState(() {
                          _selectedPort = value;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                height: 32,
                child: ElevatedButton(
                  onPressed: _selectedPort != null
                      ? () async {
                          if (isConnected) {
                            await state.disconnect();
                            setState(() {
                              _selectedPort = null;
                            });
                          } else {
                            bool success = await state.connectToPort(_selectedPort!);
                            if (success) {
                              // 连接成功时保存串口选择
                              await _saveSelectedPort(_selectedPort!);
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to connect to $_selectedPort'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected ? Colors.red[400] : Colors.green[600],
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(
                    isConnected ? 'Disconnect' : 'Connect',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                height: 32,
                child: ElevatedButton(
                  onPressed: isConnected ? null : _refreshPorts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[400],
                    foregroundColor: Colors.black87,
                    disabledBackgroundColor: Colors.grey[300],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'Refresh',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isConnected ? 'Connected' : 'Disconnected',
                style: TextStyle(
                  fontSize: 12,
                  color: isConnected ? Colors.green[700] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // GPIB 检测按钮
            _buildGpibDetectionButton(context, state),
          ],
        );
      },
    );
  }

  Widget _buildGpibDetectionButton(BuildContext context, TestState state) {
    final isReady = state.isGpibReady;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReady ? Colors.green[50] : Colors.purple[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isReady ? Colors.green[300]! : Colors.purple[300]!,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isReady ? Colors.green[100] : Colors.purple[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isReady ? Icons.check_circle : Icons.settings_input_component,
              color: isReady ? Colors.green[700] : Colors.purple[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GPIB 程控电源',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isReady ? Colors.green[900] : Colors.purple[900],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isReady 
                      ? '✓ GPIB Ready - 设备已就绪 (${state.gpibAddress})' 
                      : '未检测 - 点击右侧按钮进行检测',
                  style: TextStyle(
                    fontSize: 12,
                    color: isReady ? Colors.green[700] : Colors.purple[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            height: 36,
            child: ElevatedButton(
              onPressed: () => state.openGpibDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: isReady ? Colors.green[600] : Colors.purple[600],
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                isReady ? '已连接' : '检测',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
