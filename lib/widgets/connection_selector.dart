import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../models/test_mode.dart';

/// Connection selector widget that adapts based on test mode
/// 根据测试模式自适应的连接选择器组件
class ConnectionSelector extends StatefulWidget {
  const ConnectionSelector({super.key});

  @override
  State<ConnectionSelector> createState() => _ConnectionSelectorState();
}

class _ConnectionSelectorState extends State<ConnectionSelector> {
  String? _selectedSerialPort;
  dynamic _selectedSppDevice;
  List<dynamic> _sppDevices = [];
  bool _isScanning = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, state, _) {
        if (state.testMode.usesSerialPort) {
          return _buildSerialPortSelector(state);
        } else if (state.testMode == TestMode.completeDevice) {
          // 整机产测不显示SPP连接UI，在自动测试中处理
          return const SizedBox.shrink();
        } else {
          return _buildSppDeviceSelector(state);
        }
      },
    );
  }

  Widget _buildSerialPortSelector(TestState state) {
    final ports = state.availablePorts;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(
            Icons.usb,
            color: Colors.blue[700],
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: _selectedSerialPort,
              decoration: const InputDecoration(
                labelText: '选择串口',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              dropdownColor: Colors.white,
              items: ports.map((port) {
                return DropdownMenuItem(
                  value: port,
                  child: Text(
                    port, 
                    style: const TextStyle(
                      fontSize: 13, 
                      color: Colors.black87,
                    ),
                  ),
                );
              }).toList(),
              onChanged: state.isConnected
                  ? null
                  : (value) {
                      setState(() {
                        _selectedSerialPort = value;
                      });
                    },
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: state.isConnected
                ? () => state.disconnect()
                : (_selectedSerialPort == null
                    ? null
                    : () => state.connectToPort(_selectedSerialPort!)),
            icon: Icon(state.isConnected ? Icons.link_off : Icons.link, size: 16),
            label: Text(state.isConnected ? '断开' : '连接', style: const TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: state.isConnected ? Colors.red : Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: const Size(80, 36),
            ),
          ),
          if (state.isConnected) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, color: Colors.green, size: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildSppDeviceSelector(TestState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bluetooth,
                color: Colors.green[700],
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'SPP蓝牙连接',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<dynamic>(
                  value: _selectedSppDevice,
                  decoration: const InputDecoration(
                    labelText: '选择蓝牙设备',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _sppDevices.map((device) {
                    return DropdownMenuItem(
                      value: device,
                      child: Text('${device.name ?? "未知设备"} (${device.address})'),
                    );
                  }).toList(),
                  onChanged: state.isConnected
                      ? null
                      : (value) {
                          setState(() {
                            _selectedSppDevice = value;
                          });
                        },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isScanning || state.isConnected
                    ? null
                    : () async {
                        setState(() {
                          _isScanning = true;
                        });
                        final devices = await state.getAvailableSppDevices();
                        setState(() {
                          _sppDevices = devices;
                          _isScanning = false;
                        });
                      },
                icon: _isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(_isScanning ? '扫描中...' : '扫描'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: state.isConnected
                ? () => state.disconnect()
                : (_selectedSppDevice == null
                    ? null
                    : () => state.connectToSppDevice(_selectedSppDevice)),
            icon: Icon(state.isConnected ? Icons.link_off : Icons.link),
            label: Text(state.isConnected ? '断开连接' : '连接设备'),
            style: ElevatedButton.styleFrom(
              backgroundColor: state.isConnected ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          if (state.isConnected) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '已连接: ${_selectedSppDevice?.name ?? state.selectedPort}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
