import 'package:flutter/material.dart';
import '../services/product_sn_api.dart';

/// 蓝牙连接测试方案枚举
enum BluetoothTestMethod {
  autoScan,       // 方案1: 自动扫描配对连接
  directConnect,  // 方案2: 直接连接（已配对设备）
  rfcommBind,     // 方案3: RFCOMM Bind 模式
  rfcommSocket,   // 方案4: RFCOMM Socket 模式
}

/// 蓝牙测试方案结果
class BluetoothTestOptions {
  final ProductSNInfo productInfo;
  final BluetoothTestMethod method;
  final int channel;
  final String uuid;
  
  BluetoothTestOptions({
    required this.productInfo,
    required this.method,
    this.channel = 5,
    this.uuid = '7033',
  });
}

/// 输入模式枚举
enum InputMode {
  sn,           // SN 码模式（通过 API 查询蓝牙地址）
  bluetooth,    // 蓝牙 MAC 地址模式（直接输入）
}

/// 蓝牙连接测试方案选择对话框
/// 支持多种连接方式测试
class BluetoothTestOptionsDialog extends StatefulWidget {
  const BluetoothTestOptionsDialog({super.key});

  @override
  State<BluetoothTestOptionsDialog> createState() => _BluetoothTestOptionsDialogState();
}

class _BluetoothTestOptionsDialogState extends State<BluetoothTestOptionsDialog> {
  final TextEditingController _snController = TextEditingController();
  final TextEditingController _bluetoothController = TextEditingController();
  final TextEditingController _channelController = TextEditingController(text: '5');
  final TextEditingController _uuidController = TextEditingController(text: '7033');
  
  InputMode _inputMode = InputMode.bluetooth;
  BluetoothTestMethod _selectedMethod = BluetoothTestMethod.autoScan;
  bool _isLoading = false;
  String? _errorMessage;
  ProductSNInfo? _productInfo;

  @override
  void dispose() {
    _snController.dispose();
    _bluetoothController.dispose();
    _channelController.dispose();
    _uuidController.dispose();
    super.dispose();
  }

  /// 验证蓝牙 MAC 地址格式
  bool _isValidBluetoothAddress(String address) {
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
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
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
                    child: Icon(Icons.bluetooth_searching, size: 28, color: Colors.blue[700]),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '蓝牙连接测试',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '选择不同方案测试蓝牙连接',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // 输入模式选择
              _buildSectionTitle('步骤 1: 输入设备信息'),
              const SizedBox(height: 8),
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
                        mode: InputMode.bluetooth,
                        icon: Icons.bluetooth,
                        label: '蓝牙 MAC 地址',
                        isSelected: _inputMode == InputMode.bluetooth,
                      ),
                    ),
                    Expanded(
                      child: _buildModeButton(
                        mode: InputMode.sn,
                        icon: Icons.qr_code_scanner,
                        label: 'SN 码查询',
                        isSelected: _inputMode == InputMode.sn,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // 输入框
              if (_inputMode == InputMode.sn)
                TextField(
                  controller: _snController,
                  decoration: InputDecoration(
                    labelText: 'SN 码',
                    hintText: '请输入设备 SN 码',
                    prefixIcon: const Icon(Icons.tag),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorText: _errorMessage,
                  ),
                )
              else
                TextField(
                  controller: _bluetoothController,
                  decoration: InputDecoration(
                    labelText: '蓝牙 MAC 地址',
                    hintText: '例如: 48:08:EB:60:00:60',
                    prefixIcon: const Icon(Icons.bluetooth),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorText: _errorMessage,
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // 连接参数
              _buildSectionTitle('步骤 2: 连接参数'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _channelController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'RFCOMM Channel',
                        hintText: '默认: 5',
                        prefixIcon: const Icon(Icons.settings_input_component),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _uuidController,
                      decoration: InputDecoration(
                        labelText: 'UUID',
                        hintText: '默认: 7033',
                        prefixIcon: const Icon(Icons.fingerprint),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // 测试方案选择
              _buildSectionTitle('步骤 3: 选择连接方案'),
              const SizedBox(height: 8),
              _buildMethodCard(
                method: BluetoothTestMethod.autoScan,
                title: '方案 1: 自动扫描配对连接',
                description: '先扫描发现设备 → 配对 → 信任 → RFCOMM Socket 连接',
                icon: Icons.search,
                color: Colors.blue,
              ),
              const SizedBox(height: 8),
              _buildMethodCard(
                method: BluetoothTestMethod.directConnect,
                title: '方案 2: 直接连接（已配对）',
                description: '跳过扫描，直接使用已配对设备进行 RFCOMM Socket 连接',
                icon: Icons.link,
                color: Colors.green,
              ),
              const SizedBox(height: 8),
              _buildMethodCard(
                method: BluetoothTestMethod.rfcommBind,
                title: '方案 3: RFCOMM Bind 模式',
                description: '使用 rfcomm bind 命令绑定设备到 /dev/rfcommX',
                icon: Icons.cable,
                color: Colors.orange,
              ),
              const SizedBox(height: 8),
              _buildMethodCard(
                method: BluetoothTestMethod.rfcommSocket,
                title: '方案 4: RFCOMM Socket 模式',
                description: '使用 Python bluetooth socket 直接连接',
                icon: Icons.code,
                color: Colors.purple,
              ),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
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
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleConfirm,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(_isLoading ? '处理中...' : '开始测试'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.grey[700],
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

  Widget _buildMethodCard({
    required BluetoothTestMethod method,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedMethod == method;
    
    return GestureDetector(
      onTap: _isLoading ? null : () {
        setState(() {
          _selectedMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.2) : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? color : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _handleConfirm() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 获取蓝牙地址
      String? bluetoothAddress;
      
      if (_inputMode == InputMode.sn) {
        final sn = _snController.text.trim();
        if (sn.isEmpty) {
          setState(() {
            _errorMessage = '请输入 SN 码';
            _isLoading = false;
          });
          return;
        }
        
        // 通过 API 查询
        final productInfo = await ProductSNApi.getProductSNInfo(sn);
        if (productInfo == null || productInfo.bluetoothAddress.isEmpty) {
          setState(() {
            _errorMessage = '未找到 SN 对应的蓝牙地址';
            _isLoading = false;
          });
          return;
        }
        
        _productInfo = productInfo;
        bluetoothAddress = productInfo.bluetoothAddress;
      } else {
        bluetoothAddress = _bluetoothController.text.trim();
        if (bluetoothAddress.isEmpty) {
          setState(() {
            _errorMessage = '请输入蓝牙 MAC 地址';
            _isLoading = false;
          });
          return;
        }
        
        if (!_isValidBluetoothAddress(bluetoothAddress)) {
          setState(() {
            _errorMessage = '蓝牙地址格式不正确';
            _isLoading = false;
          });
          return;
        }
        
        // 格式化地址
        bluetoothAddress = bluetoothAddress.toUpperCase().replaceAll('-', ':');
        
        _productInfo = ProductSNInfo(
          snCode: '手动输入',
          bluetoothAddress: bluetoothAddress,
          macAddress: '',
        );
      }
      
      // 获取连接参数
      final channel = int.tryParse(_channelController.text.trim()) ?? 5;
      final uuid = _uuidController.text.trim().isEmpty ? '7033' : _uuidController.text.trim();
      
      // 返回结果
      final result = BluetoothTestOptions(
        productInfo: _productInfo!,
        method: _selectedMethod,
        channel: channel,
        uuid: uuid,
      );
      
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '处理失败: $e';
        _isLoading = false;
      });
    }
  }
}
