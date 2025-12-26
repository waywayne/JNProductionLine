import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';

/// GPIB检测弹窗
class GpibDetectionDialog extends StatefulWidget {
  const GpibDetectionDialog({super.key});

  @override
  State<GpibDetectionDialog> createState() => _GpibDetectionDialogState();
}

class _GpibDetectionDialogState extends State<GpibDetectionDialog> {
  final TextEditingController _addressController = TextEditingController(
    text: 'GPIB0::5::INSTR',
  );
  bool _isConnecting = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TestState>();

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
            // 标题栏
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.settings_input_component,
                    color: Colors.purple.shade600,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'GPIB 设备检测',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (state.isGpibReady)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'GPIB Ready',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isConnecting
                      ? null
                      : () {
                          state.closeGpibDialog();
                        },
                  icon: const Icon(Icons.close),
                  tooltip: '关闭',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 说明信息
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.purple.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'GPIB 自动检测流程',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '系统将自动完成以下步骤：',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.purple.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildInfoItem('1. 检查 Python 环境'),
                  _buildInfoItem('2. 自动安装 PyVISA 依赖'),
                  _buildInfoItem('3. 连接 GPIB 设备'),
                  _buildInfoItem('4. 初始化参数 (5V, 1A)'),
                  _buildInfoItem('5. 漏电流测试'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // GPIB地址输入
            const Text(
              'GPIB 设备地址',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              enabled: !_isConnecting && !state.isGpibReady,
              decoration: InputDecoration(
                hintText: '例如: GPIB0::5::INSTR',
                prefixIcon: Icon(
                  Icons.cable,
                  color: state.isGpibReady ? Colors.green : null,
                ),
                suffixIcon: state.isGpibReady
                    ? Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: state.isGpibReady
                    ? Colors.green.shade50
                    : Colors.grey.shade50,
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

            // 参数配置显示
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
                  Row(
                    children: [
                      Icon(
                        Icons.settings,
                        size: 18,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '初始化参数',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildParameterItem('电压', '5.0 V'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildParameterItem('电流限制', '1.0 A'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 底部按钮
            Row(
              children: [
                if (state.isGpibReady) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isConnecting
                          ? null
                          : () async {
                              setState(() {
                                _isConnecting = true;
                              });
                              await state.disconnectGpib();
                              setState(() {
                                _isConnecting = false;
                              });
                            },
                      icon: const Icon(Icons.power_off),
                      label: const Text('断开连接'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        state.closeGpibDialog();
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('完成'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isConnecting
                          ? null
                          : () {
                              state.closeGpibDialog();
                            },
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isConnecting ? null : _startDetection,
                      icon: _isConnecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(_isConnecting ? '检测中...' : '开始检测'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
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
            color: Colors.purple.shade600,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.purple.shade600,
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

  Future<void> _startDetection() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入GPIB设备地址'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    final state = context.read<TestState>();
    final success = await state.detectAndConnectGpib(address);

    if (mounted) {
      setState(() {
        _isConnecting = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ GPIB Ready - 设备已就绪！'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ GPIB检测失败，请查看日志'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
