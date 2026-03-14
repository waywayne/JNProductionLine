import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';

/// Linux 蓝牙设备扫描和连接弹窗
/// 支持扫描附近蓝牙设备、选择设备、输入服务 UUID 并建立 SPP 连接
class LinuxBluetoothScanDialog extends StatefulWidget {
  const LinuxBluetoothScanDialog({super.key});

  @override
  State<LinuxBluetoothScanDialog> createState() => _LinuxBluetoothScanDialogState();
}

class _LinuxBluetoothScanDialogState extends State<LinuxBluetoothScanDialog> {
  bool _isScanning = false;
  bool _isConnecting = false;
  List<Map<String, String>> _devices = [];
  Map<String, String>? _selectedDevice;
  final TextEditingController _uuidController = TextEditingController(
    text: '00001101-0000-1000-8000-00805F9B34FB', // SPP 默认 UUID
  );
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 自动开始扫描
    _startScan();
  }

  @override
  void dispose() {
    _uuidController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _devices = [];
      _selectedDevice = null;
    });

    try {
      final state = Provider.of<TestState>(context, listen: false);
      final devices = await state.scanLinuxBluetoothDevices();
      
      setState(() {
        _devices = devices;
        _isScanning = false;
        if (devices.isEmpty) {
          _errorMessage = '未找到蓝牙设备，请确保设备已开启蓝牙';
        }
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _errorMessage = '扫描失败: $e';
      });
    }
  }

  Future<void> _connectToDevice() async {
    if (_selectedDevice == null) {
      setState(() {
        _errorMessage = '请先选择一个设备';
      });
      return;
    }

    final uuid = _uuidController.text.trim();
    if (uuid.isEmpty) {
      setState(() {
        _errorMessage = '请输入服务 UUID';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final state = Provider.of<TestState>(context, listen: false);
      final success = await state.connectLinuxBluetoothDevice(
        deviceAddress: _selectedDevice!['address']!,
        deviceName: _selectedDevice!['name']!,
        uuid: uuid,
      );

      if (success && mounted) {
        // 连接成功，关闭弹窗
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 已连接到 ${_selectedDevice!['name']}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _isConnecting = false;
          _errorMessage = '连接失败，请检查设备是否可用';
        });
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _errorMessage = '连接异常: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      elevation: 8,
      title: Row(
        children: [
          Icon(
            Icons.bluetooth_searching,
            color: Colors.teal[600],
            size: 28,
          ),
          const SizedBox(width: 8),
          Text(
            'Linux 蓝牙设备扫描',
            style: TextStyle(
              color: Colors.teal[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 扫描状态和刷新按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isScanning ? '正在扫描...' : '发现 ${_devices.length} 个设备',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isScanning || _isConnecting ? null : _startScan,
                  icon: Icon(_isScanning ? Icons.hourglass_empty : Icons.refresh, size: 18),
                  label: const Text('重新扫描'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[400],
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 设备列表
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isScanning
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal[600]!),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '正在扫描蓝牙设备...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : _devices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.bluetooth_disabled,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '未找到蓝牙设备',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '请确保设备已开启蓝牙',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _devices.length,
                            itemBuilder: (context, index) {
                              final device = _devices[index];
                              final isSelected = _selectedDevice == device;
                              
                              return ListTile(
                                selected: isSelected,
                                selectedTileColor: Colors.teal[50],
                                leading: Icon(
                                  Icons.bluetooth,
                                  color: isSelected ? Colors.teal[600] : Colors.grey[600],
                                  size: 28,
                                ),
                                title: Text(
                                  device['name'] ?? '未知设备',
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.teal[800] : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  device['address'] ?? '',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: Colors.teal[600],
                                      )
                                    : null,
                                onTap: _isConnecting
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedDevice = device;
                                          _errorMessage = null;
                                        });
                                      },
                              );
                            },
                          ),
              ),
            ),
            const SizedBox(height: 16),

            // UUID 输入
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '服务 UUID',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _uuidController,
                  enabled: !_isConnecting,
                  decoration: InputDecoration(
                    hintText: '00001101-0000-1000-8000-00805F9B34FB',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: _isConnecting ? null : () => _uuidController.clear(),
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '默认为 SPP 标准 UUID (00001101-0000-1000-8000-00805F9B34FB)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),

            // 错误信息
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
                    Icon(
                      Icons.error_outline,
                      color: Colors.red[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // 取消按钮
        TextButton(
          onPressed: _isConnecting ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        const SizedBox(width: 8),
        // 连接按钮
        ElevatedButton.icon(
          onPressed: _isConnecting || _selectedDevice == null ? null : _connectToDevice,
          icon: _isConnecting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.link, size: 18),
          label: Text(_isConnecting ? '连接中...' : '连接设备'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal[600],
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[300],
            disabledForegroundColor: Colors.grey[500],
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
}
