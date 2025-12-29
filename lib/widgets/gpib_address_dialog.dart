import 'package:flutter/material.dart';
import '../models/automation_test_config.dart';

class GpibAddressDialog extends StatefulWidget {
  final String? initialAddress;
  
  const GpibAddressDialog({
    super.key,
    this.initialAddress,
  });
  
  @override
  State<GpibAddressDialog> createState() => _GpibAddressDialogState();
}

class _GpibAddressDialogState extends State<GpibAddressDialog> {
  late TextEditingController _addressController;
  bool _isConnecting = false;
  bool _skipGpibTests = false;
  bool _skipGpibReadyCheck = false;
  bool _skipLeakageCurrentTest = false;
  bool _skipPowerOnTest = false;
  bool _skipWorkingCurrentTest = false;
  
  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(
      text: widget.initialAddress ?? 'GPIB0::5::INSTR',
    );
    // 初始化当前设置
    _skipGpibTests = AutomationTestConfig.skipGpibTests;
    _skipGpibReadyCheck = AutomationTestConfig.skipGpibReadyCheck;
    _skipLeakageCurrentTest = AutomationTestConfig.skipLeakageCurrentTest;
    _skipPowerOnTest = AutomationTestConfig.skipPowerOnTest;
    _skipWorkingCurrentTest = AutomationTestConfig.skipWorkingCurrentTest;
  }
  
  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(
                  Icons.settings_input_component,
                  color: Colors.blue.shade600,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  '程控电源配置',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _isConnecting ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: '关闭',
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // 说明文字
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '自动化测试配置',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请输入GPIB设备地址以开始自动化测试。系统将自动：',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildInfoItem('检查Python环境和依赖'),
                  _buildInfoItem('连接GPIB设备'),
                  _buildInfoItem('初始化电源参数 (5V, 1A限制)'),
                  _buildInfoItem('配置采样参数 (20次采样, 10Hz)'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // GPIB地址输入
            const Text(
              'GPIB设备地址',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              enabled: !_isConnecting,
              decoration: InputDecoration(
                hintText: '例如: GPIB0::5::INSTR',
                prefixIcon: const Icon(Icons.cable),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '常用格式: GPIB0::[地址]::INSTR (地址通常为1-30)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            
            // 电源参数显示
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '电源参数配置',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildParameterItem('电压', '5.0V'),
                      const SizedBox(width: 24),
                      _buildParameterItem('电流限制', '1.0A'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildParameterItem('采样次数', '20次'),
                      const SizedBox(width: 24),
                      _buildParameterItem('采样率', '10Hz'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // 跳过选项开关
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.skip_next,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '测试跳过选项（调试模式）',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('跳过GPIB相关测试'),
                    subtitle: const Text('跳过GPIB连接和电源初始化'),
                    value: _skipGpibTests,
                    onChanged: (value) {
                      setState(() {
                        _skipGpibTests = value ?? false;
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('跳过GPIB设备未就绪检查'),
                    subtitle: const Text('允许在GPIB未连接时开始测试'),
                    value: _skipGpibReadyCheck,
                    onChanged: (value) {
                      setState(() {
                        _skipGpibReadyCheck = value ?? false;
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('跳过漏电流测试'),
                    subtitle: const Text('跳过设备漏电流测试'),
                    value: _skipLeakageCurrentTest,
                    onChanged: (value) {
                      setState(() {
                        _skipLeakageCurrentTest = value ?? false;
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('跳过工作电流测试'),
                    subtitle: const Text('跳过设备工作电流测试'),
                    value: _skipWorkingCurrentTest,
                    onChanged: (value) {
                      setState(() {
                        _skipWorkingCurrentTest = value ?? false;
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('跳过上电测试'),
                    subtitle: const Text('跳过设备上电测试'),
                    value: _skipPowerOnTest,
                    onChanged: (value) {
                      setState(() {
                        _skipPowerOnTest = value ?? false;
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // 底部按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isConnecting ? null : () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnecting ? null : _startAutomationTest,
                    child: _isConnecting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('连接中...'),
                            ],
                          )
                        : const Text('开始测试'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 2),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 14,
            color: Colors.blue.shade600,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade600,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildParameterItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
  
  void _startAutomationTest() async {
    final address = _addressController.text.trim();
    if (address.isEmpty && !_skipGpibTests && !_skipGpibReadyCheck) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入GPIB设备地址或选择跳过GPIB测试/就绪检查'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isConnecting = true;
    });
    
    // 保存跳过选项设置
    AutomationTestConfig.skipGpibTests = _skipGpibTests;
    AutomationTestConfig.skipGpibReadyCheck = _skipGpibReadyCheck;
    AutomationTestConfig.skipLeakageCurrentTest = _skipLeakageCurrentTest;
    AutomationTestConfig.skipPowerOnTest = _skipPowerOnTest;
    AutomationTestConfig.skipWorkingCurrentTest = _skipWorkingCurrentTest;
    
    // 模拟连接过程
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      Navigator.of(context).pop(address);
    }
  }
}
