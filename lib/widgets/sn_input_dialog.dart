import 'package:flutter/material.dart';
import '../services/product_sn_api.dart';

/// 输入模式枚举
enum InputMode {
  sn,           // SN 码模式（通过 API 查询蓝牙地址）
  bluetooth,    // 蓝牙 MAC 地址模式（直接输入）
}

/// SN号/蓝牙地址输入对话框
/// 支持两种输入模式：
/// 1. SN 码模式：输入 SN 码，通过 API 查询蓝牙地址
/// 2. 蓝牙 MAC 地址模式：直接输入蓝牙 MAC 地址
class SNInputDialog extends StatefulWidget {
  const SNInputDialog({super.key});

  @override
  State<SNInputDialog> createState() => _SNInputDialogState();
}

class _SNInputDialogState extends State<SNInputDialog> {
  final TextEditingController _snController = TextEditingController();
  final TextEditingController _bluetoothController = TextEditingController();
  InputMode _inputMode = InputMode.sn;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _snController.dispose();
    _bluetoothController.dispose();
    super.dispose();
  }

  /// 验证蓝牙 MAC 地址格式
  bool _isValidBluetoothAddress(String address) {
    // 支持格式: AA:BB:CC:DD:EE:FF 或 AA-BB-CC-DD-EE-FF
    final regex = RegExp(
      r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$',
      caseSensitive: false,
    );
    return regex.hasMatch(address);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.bluetooth, size: 28, color: Colors.blue[700]),
                ),
                const SizedBox(width: 16),
                const Text(
                  '蓝牙连接设置',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // 输入模式选择
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModeButton(
                      mode: InputMode.sn,
                      icon: Icons.qr_code_scanner,
                      label: 'SN 码查询',
                      isSelected: _inputMode == InputMode.sn,
                    ),
                  ),
                  Expanded(
                    child: _buildModeButton(
                      mode: InputMode.bluetooth,
                      icon: Icons.bluetooth,
                      label: '蓝牙 MAC 地址',
                      isSelected: _inputMode == InputMode.bluetooth,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // 输入框区域
            if (_inputMode == InputMode.sn) ...[
              // SN 输入框
              TextField(
                controller: _snController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'SN 码',
                  hintText: '请输入设备 SN 码',
                  prefixIcon: const Icon(Icons.tag),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: _errorMessage,
                  helperText: '输入 SN 码后将自动查询蓝牙地址',
                ),
                onSubmitted: (_) => _handleConfirm(),
              ),
            ] else ...[
              // 蓝牙 MAC 地址输入框
              TextField(
                controller: _bluetoothController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '蓝牙 MAC 地址',
                  hintText: '例如: AA:BB:CC:DD:EE:FF',
                  prefixIcon: const Icon(Icons.bluetooth),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: _errorMessage,
                  helperText: '直接输入蓝牙 MAC 地址进行连接',
                ),
                onSubmitted: (_) => _handleConfirm(),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // 按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _inputMode == InputMode.sn ? '查询并连接' : '连接',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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

  Widget _buildModeButton({
    required InputMode mode,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : () {
        setState(() {
          _inputMode = mode;
          _errorMessage = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleConfirm() async {
    if (_inputMode == InputMode.sn) {
      await _handleSNInput();
    } else {
      await _handleBluetoothInput();
    }
  }

  /// 处理 SN 码输入
  Future<void> _handleSNInput() async {
    final sn = _snController.text.trim();
    
    print('🔍 用户输入SN: $sn');
    
    if (sn.isEmpty) {
      setState(() {
        _errorMessage = '请输入 SN 码';
      });
      return;
    }
    
    // 开始加载
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      print('🚀 开始调用API获取产品信息...');
      
      // 调用API获取产品信息
      final productInfo = await ProductSNApi.getProductSNInfo(sn);
      
      if (productInfo == null) {
        print('❌ API返回null');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'API返回数据为空';
          });
        }
        return;
      }
      
      print('✅ 成功获取产品信息: ${productInfo.snCode}');
      print('   蓝牙地址: ${productInfo.bluetoothAddress}');
      
      // 返回产品信息
      if (mounted) {
        Navigator.of(context).pop(productInfo);
      }
    } catch (e) {
      print('❌ 获取产品信息失败: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '获取产品信息失败: ${e.toString()}';
        });
      }
    }
  }

  /// 处理蓝牙 MAC 地址输入
  Future<void> _handleBluetoothInput() async {
    final bluetoothAddress = _bluetoothController.text.trim();
    
    print('🔍 用户输入蓝牙地址: $bluetoothAddress');
    
    if (bluetoothAddress.isEmpty) {
      setState(() {
        _errorMessage = '请输入蓝牙 MAC 地址';
      });
      return;
    }
    
    // 验证蓝牙地址格式
    if (!_isValidBluetoothAddress(bluetoothAddress)) {
      setState(() {
        _errorMessage = '蓝牙地址格式不正确，请使用 AA:BB:CC:DD:EE:FF 格式';
      });
      return;
    }
    
    // 格式化地址（统一为大写，冒号分隔）
    final formattedAddress = bluetoothAddress.toUpperCase().replaceAll('-', ':');
    
    print('✅ 蓝牙地址格式验证通过: $formattedAddress');
    
    // 创建一个简单的 ProductSNInfo 对象，只包含蓝牙地址
    final productInfo = ProductSNInfo(
      snCode: '手动输入',
      bluetoothAddress: formattedAddress,
      macAddress: '',
    );
    
    if (mounted) {
      Navigator.of(context).pop(productInfo);
    }
  }
}
