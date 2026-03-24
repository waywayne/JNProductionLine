import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../services/product_sn_api.dart';
import 'sn_input_dialog.dart';

/// 手动蓝牙测试对话框
class ManualBluetoothTestDialog extends StatefulWidget {
  const ManualBluetoothTestDialog({super.key});

  @override
  State<ManualBluetoothTestDialog> createState() => _ManualBluetoothTestDialogState();
}

class _ManualBluetoothTestDialogState extends State<ManualBluetoothTestDialog> {
  String _status = '等待输入SN码...';
  bool _isConnecting = false;
  bool _isConnected = false;
  ProductSNInfo? _productInfo;

  @override
  void initState() {
    super.initState();
    // 自动弹出SN输入对话框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSNInput();
    });
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
      _status = '✅ 已获取设备信息\nSN: ${productInfo.snCode}\n蓝牙地址: ${productInfo.bluetoothAddress}';
    });

    // 自动开始连接
    await _connectBluetooth();
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
      _status = '⏳ 正在连接蓝牙...\n地址: $bluetoothAddress';
    });

    final state = context.read<TestState>();
    final connected = await state.testLinuxBluetooth(
      deviceAddress: bluetoothAddress,
      uuid: '7033',
    );

    if (mounted) {
      setState(() {
        _isConnecting = false;
        _isConnected = connected;
        if (connected) {
          _status = '✅ 蓝牙连接成功！\n\n设备信息：\nSN: ${_productInfo!.snCode}\n蓝牙地址: $bluetoothAddress\n\n连接已保持，可以关闭此窗口进行手动测试。';
        } else {
          _status = '❌ 蓝牙连接失败\n\n请检查：\n1. 设备是否开机\n2. 蓝牙地址是否正确\n3. 设备是否已配对';
        }
      });
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
            else
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
          TextButton(
            onPressed: _connectBluetooth,
            child: const Text('重试连接'),
          ),
        if (!_isConnecting && !_isConnected)
          TextButton(
            onPressed: _showSNInput,
            child: const Text('重新输入SN'),
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
