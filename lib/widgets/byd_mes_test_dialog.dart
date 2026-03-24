import 'package:flutter/material.dart';
import '../services/byd_mes_service.dart';

/// BYD MES 系统测试对话框
class BydMesTestDialog extends StatefulWidget {
  final String? initialMesIp;
  final String? initialClientId;
  final String? initialStation;
  
  const BydMesTestDialog({
    Key? key,
    this.initialMesIp,
    this.initialClientId,
    this.initialStation,
  }) : super(key: key);
  
  @override
  State<BydMesTestDialog> createState() => _BydMesTestDialogState();
}

class _BydMesTestDialogState extends State<BydMesTestDialog> {
  late TextEditingController _mesIpController;
  late TextEditingController _clientIdController;
  late TextEditingController _stationController;
  late TextEditingController _snController;
  late TextEditingController _ncCodeController;
  late TextEditingController _ncContextController;
  late TextEditingController _failItemController;
  late TextEditingController _failValueController;
  
  late BydMesService _mesService;
  
  final List<String> _logs = [];
  bool _isLoading = false;
  String _selectedAction = 'start';
  
  @override
  void initState() {
    super.initState();
    
    _mesIpController = TextEditingController(text: widget.initialMesIp ?? '192.168.1.100');
    _clientIdController = TextEditingController(text: widget.initialClientId ?? 'DEFAULT_CLIENT');
    _stationController = TextEditingController(text: widget.initialStation ?? 'STATION1');
    _snController = TextEditingController();
    _ncCodeController = TextEditingController(text: 'NC001');
    _ncContextController = TextEditingController(text: '测试不良');
    _failItemController = TextEditingController(text: '测试项');
    _failValueController = TextEditingController(text: '失败值');
    
    _mesService = BydMesService(
      mesIp: _mesIpController.text,
      clientId: _clientIdController.text,
      station: _stationController.text,
      onLog: _addLog,
    );
  }
  
  @override
  void dispose() {
    _mesIpController.dispose();
    _clientIdController.dispose();
    _stationController.dispose();
    _snController.dispose();
    _ncCodeController.dispose();
    _ncContextController.dispose();
    _failItemController.dispose();
    _failValueController.dispose();
    super.dispose();
  }
  
  void _addLog(String message) {
    setState(() {
      _logs.add(message);
    });
  }
  
  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }
  
  void _updateMesConfig() {
    _mesService.updateConfig(
      mesIp: _mesIpController.text,
      clientId: _clientIdController.text,
      station: _stationController.text,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('MES 配置已更新')),
    );
  }
  
  Future<void> _executeMesAction() async {
    if (_snController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 SN')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      Map<String, dynamic> result;
      
      switch (_selectedAction) {
        case 'start':
          result = await _mesService.start(_snController.text);
          break;
          
        case 'complete':
          result = await _mesService.complete(_snController.text);
          break;
          
        case 'nccomplete':
          result = await _mesService.ncComplete(
            _snController.text,
            ncCode: _ncCodeController.text,
            ncContext: _ncContextController.text,
            failItem: _failItemController.text,
            failValue: _failValueController.text,
          );
          break;
          
        default:
          result = {'success': false, 'error': '未知操作'};
      }
      
      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ MES 操作成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ MES 操作失败: ${result['error'] ?? '未知错误'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _testConnection() async {
    if (_snController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入测试 SN')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _mesService.testConnection(_snController.text);
      
      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ MES 连接测试成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ MES 连接测试失败: ${result['error'] ?? '未知错误'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                const Icon(Icons.cloud_sync, size: 32, color: Colors.blue),
                const SizedBox(width: 12),
                const Text(
                  'BYD MES 系统测试',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 32),
            
            // 配置区域
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧：配置和操作
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // MES 配置
                          const Text(
                            'MES 配置',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          
                          _buildTextField('MES IP', _mesIpController, '192.168.1.100'),
                          const SizedBox(height: 12),
                          _buildTextField('Client ID', _clientIdController, 'DEFAULT_CLIENT'),
                          const SizedBox(height: 12),
                          _buildTextField('工站名称', _stationController, 'STATION1'),
                          const SizedBox(height: 16),
                          
                          ElevatedButton.icon(
                            onPressed: _updateMesConfig,
                            icon: const Icon(Icons.refresh),
                            label: const Text('更新配置'),
                          ),
                          
                          const Divider(height: 32),
                          
                          // 测试操作
                          const Text(
                            '测试操作',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          
                          _buildTextField('SN 号码', _snController, 'SN123456'),
                          const SizedBox(height: 16),
                          
                          // 操作选择
                          DropdownButtonFormField<String>(
                            value: _selectedAction,
                            decoration: const InputDecoration(
                              labelText: '操作类型',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'start', child: Text('开始 (Start)')),
                              DropdownMenuItem(value: 'complete', child: Text('完成-良品 (Complete)')),
                              DropdownMenuItem(value: 'nccomplete', child: Text('完成-不良品 (NC Complete)')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedAction = value!;
                              });
                            },
                          ),
                          
                          // 不良品参数（仅在选择 nccomplete 时显示）
                          if (_selectedAction == 'nccomplete') ...[
                            const SizedBox(height: 16),
                            const Text(
                              '不良品参数',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            _buildTextField('不良代码', _ncCodeController, 'NC001'),
                            const SizedBox(height: 12),
                            _buildTextField('不良描述', _ncContextController, '测试不良'),
                            const SizedBox(height: 12),
                            _buildTextField('失败项目', _failItemController, '测试项'),
                            const SizedBox(height: 12),
                            _buildTextField('失败值', _failValueController, '失败值'),
                          ],
                          
                          const SizedBox(height: 24),
                          
                          // 操作按钮
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _testConnection,
                                  icon: const Icon(Icons.wifi_tethering),
                                  label: const Text('测试连接'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _executeMesAction,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.send),
                                  label: Text(_isLoading ? '执行中...' : '执行操作'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 24),
                  
                  // 右侧：日志
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '操作日志',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _clearLogs,
                              icon: const Icon(Icons.clear_all, size: 16),
                              label: const Text('清空'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: ListView.builder(
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                final log = _logs[index];
                                Color textColor = Colors.white70;
                                
                                if (log.contains('✅')) {
                                  textColor = Colors.green;
                                } else if (log.contains('❌')) {
                                  textColor = Colors.red;
                                } else if (log.contains('⚠️')) {
                                  textColor = Colors.orange;
                                } else if (log.contains('🔧') || log.contains('📤')) {
                                  textColor = Colors.blue;
                                }
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    log,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: textColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
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
  
  Widget _buildTextField(String label, TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
