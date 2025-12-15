import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    // 初始化时刷新串口列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPorts();
    });
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
        
        return Container(
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
                            if (!success && mounted) {
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
        );
      },
    );
  }
}
