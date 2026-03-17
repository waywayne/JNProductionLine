import 'package:flutter/material.dart';
import '../services/product_sn_api.dart';

/// SN号输入对话框
class SNInputDialog extends StatefulWidget {
  const SNInputDialog({super.key});

  @override
  State<SNInputDialog> createState() => _SNInputDialogState();
}

class _SNInputDialogState extends State<SNInputDialog> {
  final TextEditingController _snController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _snController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
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
                  child: Icon(Icons.qr_code_scanner, size: 28, color: Colors.blue[700]),
                ),
                const SizedBox(width: 16),
                const Text(
                  '输入设备SN号',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // SN输入框
            TextField(
              controller: _snController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'SN号',
                hintText: '请输入设备SN号',
                prefixIcon: const Icon(Icons.tag),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: _errorMessage,
              ),
              onSubmitted: (_) => _handleConfirm(),
            ),
            
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
                      : const Text(
                          '确定',
                          style: TextStyle(
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

  Future<void> _handleConfirm() async {
    final sn = _snController.text.trim();
    
    print('🔍 用户输入SN: $sn');
    
    if (sn.isEmpty) {
      setState(() {
        _errorMessage = '请输入SN号';
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
}
