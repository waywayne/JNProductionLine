import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../services/product_sn_api.dart';
import 'sn_input_dialog.dart';
import 'bluetooth_test_options_dialog.dart';

/// 手动蓝牙测试对话框
class ManualBluetoothTestDialog extends StatefulWidget {
  const ManualBluetoothTestDialog({super.key});

  @override
  State<ManualBluetoothTestDialog> createState() => _ManualBluetoothTestDialogState();
}

class _ManualBluetoothTestDialogState extends State<ManualBluetoothTestDialog> {
  String _status = '请选择输入方式';
  bool _isConnecting = false;
  bool _isConnected = false;
  ProductSNInfo? _productInfo;
  BluetoothTestMethod _selectedMethod = BluetoothTestMethod.rfcommBind; // 默认使用方案3
  
  // MAC 地址直接输入
  final TextEditingController _macController = TextEditingController();
  bool _isManualInput = false; // 是否手动输入 MAC 地址

  @override
  void dispose() {
    _macController.dispose();
    super.dispose();
  }

  bool _isValidBluetoothAddress(String address) {
    final regex = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');
    return regex.hasMatch(address);
  }

  Future<void> _showSNInput() async {
    final productInfo = await showDialog<ProductSNInfo>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SNInputDialog(),
    );

    if (productInfo == null) {
      if (mounted) {
        setState(() {
          _status = '❌ 未获取到设备信息';
        });
      }
      return;
    }

    setState(() {
      _productInfo = productInfo;
      _isManualInput = false;
      _status = '✅ 已获取设备信息\nSN: ${productInfo.snCode}\n蓝牙地址: ${productInfo.bluetoothAddress}';
    });
  }
  
  void _useManualMacInput() {
    final address = _macController.text.trim();
    
    if (address.isEmpty) {
      setState(() {
        _status = '❌ 请输入蓝牙 MAC 地址';
      });
      return;
    }
    
    if (!_isValidBluetoothAddress(address)) {
      setState(() {
        _status = '❌ MAC 地址格式不正确\n正确格式: 48:08:EB:60:00:60';
      });
      return;
    }
    
    final formattedAddress = address.toUpperCase().replaceAll('-', ':');
    
    setState(() {
      _productInfo = ProductSNInfo(
        snCode: '手动输入',
        bluetoothAddress: formattedAddress,
        macAddress: '',
      );
      _isManualInput = true;
      _status = '✅ 已设置蓝牙地址\n蓝牙地址: $formattedAddress';
    });
  }

  Future<void> _connectBluetooth() async {
    if (_productInfo == null) return;

    final bluetoothAddress = _productInfo!.bluetoothAddress;
    if (bluetoothAddress == null || bluetoothAddress.isEmpty) {
      setState(() {
        _status = '❌ 设备信息中无蓝牙地址';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _status = '⏳ 正在连接蓝牙...\n地址: $bluetoothAddress\n方案: ${_getMethodName(_selectedMethod)}';
    });

    final state = context.read<TestState>();
    
    // 根据选择的方案使用不同的连接方式
    bool connected = false;
    switch (_selectedMethod) {
      case BluetoothTestMethod.autoScan:
        connected = await state.testBluetoothMethod1AutoScan(
          deviceAddress: bluetoothAddress,
          channel: 5,
          uuid: '7033',
        );
        break;
      case BluetoothTestMethod.directConnect:
        connected = await state.testBluetoothMethod2DirectConnect(
          deviceAddress: bluetoothAddress,
          channel: 5,
          uuid: '7033',
        );
        break;
      case BluetoothTestMethod.rfcommBind:
        connected = await state.testBluetoothMethod3RfcommBind(
          deviceAddress: bluetoothAddress,
          channel: 5,
          uuid: '7033',
        );
        break;
      case BluetoothTestMethod.rfcommSocket:
        connected = await state.testBluetoothMethod4RfcommSocket(
          deviceAddress: bluetoothAddress,
          channel: 5,
          uuid: '7033',
        );
        break;
      case BluetoothTestMethod.serial:
        connected = await state.testBluetoothMethod5Serial(
          deviceAddress: bluetoothAddress,
          channel: 5,
          uuid: '7033',
        );
        break;
      case BluetoothTestMethod.commandLine:
        connected = await state.testBluetoothMethod6CommandLine(
          deviceAddress: bluetoothAddress,
          channel: 5,
          uuid: '7033',
        );
        break;
    }

    if (mounted) {
      setState(() {
        _isConnecting = false;
        _isConnected = connected;
        if (connected) {
          _status = '✅ 蓝牙连接成功！\n\n设备信息：\nSN: ${_productInfo!.snCode}\n蓝牙地址: $bluetoothAddress\n连接方案: ${_getMethodName(_selectedMethod)}\n\n连接已保持，可以关闭此窗口进行手动测试。';
        } else {
          _status = '❌ 蓝牙连接失败\n\n请检查：\n1. 设备是否开机\n2. 蓝牙地址是否正确\n3. 设备是否已配对\n4. 尝试其他连接方案';
        }
      });
    }
  }
  
  String _getMethodName(BluetoothTestMethod method) {
    switch (method) {
      case BluetoothTestMethod.autoScan:
        return '方案1: 扫描配对';
      case BluetoothTestMethod.directConnect:
        return '方案2: 直接连接';
      case BluetoothTestMethod.rfcommBind:
        return '方案3: RFCOMM Bind';
      case BluetoothTestMethod.rfcommSocket:
        return '方案4: RFCOMM Socket';
      case BluetoothTestMethod.serial:
        return '方案5: 串口设备';
      case BluetoothTestMethod.commandLine:
        return '方案6: 命令行工具';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
            color: _isConnected ? Colors.green : Colors.blue,
          ),
          const SizedBox(width: 12),
          const Text('蓝牙测试'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // MAC 地址输入区域（未连接且无设备信息时显示）
            if (_productInfo == null && !_isConnecting && !_isConnected) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bluetooth, color: Colors.orange[700], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '直接输入蓝牙 MAC 地址',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _macController,
                      decoration: InputDecoration(
                        hintText: '例如: 48:08:EB:60:00:60',
                        prefixIcon: const Icon(Icons.bluetooth, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _useManualMacInput,
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('确认地址'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showSNInput,
                            icon: const Icon(Icons.qr_code, size: 16),
                            label: const Text('SN码查询'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_isConnecting)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在连接蓝牙，请稍候...'),
                  ],
                ),
              )
            else if (_productInfo != null || _status.contains('❌'))
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isConnected ? Colors.green[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isConnected ? Colors.green : Colors.grey,
                    width: 1,
                  ),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    fontSize: 14,
                    color: _isConnected ? Colors.green[900] : Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),
            // 方案选择下拉框
            if (_productInfo != null && !_isConnecting && !_isConnected) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.settings, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '连接方案',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<BluetoothTestMethod>(
                      value: _selectedMethod,
                      isDense: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: BluetoothTestMethod.autoScan,
                          child: Text('方案1: 扫描配对', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: BluetoothTestMethod.directConnect,
                          child: Text('方案2: 直接连接', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: BluetoothTestMethod.rfcommBind,
                          child: Text('方案3: RFCOMM Bind ⭐', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: BluetoothTestMethod.rfcommSocket,
                          child: Text('方案4: RFCOMM Socket', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: BluetoothTestMethod.serial,
                          child: Text('方案5: 串口设备', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: BluetoothTestMethod.commandLine,
                          child: Text('方案6: 命令行工具', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedMethod = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
            if (_productInfo != null && !_isConnecting) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                '设备详细信息',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('SN码', _productInfo!.snCode),
              _buildInfoRow('蓝牙地址', _productInfo!.bluetoothAddress),
              _buildInfoRow('MAC地址', _productInfo!.macAddress),
              if (_productInfo!.hardwareVersion != null)
                _buildInfoRow('硬件版本', _productInfo!.hardwareVersion!),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isConnecting && !_isConnected && _productInfo != null)
          ElevatedButton(
            onPressed: _connectBluetooth,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('开始连接'),
          ),
        if (!_isConnecting && !_isConnected && _productInfo != null)
          TextButton(
            onPressed: () {
              setState(() {
                _productInfo = null;
                _status = '请选择输入方式';
                _macController.clear();
              });
            },
            child: const Text('重新输入'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_isConnected),
          child: Text(_isConnected ? '关闭' : '取消'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
