import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../config/sn_mac_config.dart';

class SNMacConfigSection extends StatefulWidget {
  const SNMacConfigSection({Key? key}) : super(key: key);

  @override
  State<SNMacConfigSection> createState() => _SNMacConfigSectionState();
}

class _SNMacConfigSectionState extends State<SNMacConfigSection> {
  String _selectedProductLine = '637';
  String _selectedFactory = '1';
  int _selectedProductionLine = 1;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    final config = SNMacConfig.getCurrentConfig();
    setState(() {
      _selectedProductLine = config['productLine'] ?? '637';
      _selectedFactory = config['factory'] ?? '1';
      // 确保productionLine是int类型
      final productionLine = config['productionLine'];
      _selectedProductionLine = productionLine is int ? productionLine : int.tryParse(productionLine.toString()) ?? 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, state, child) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SN码和MAC地址配置',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // 配置选项
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('产品线:', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        DropdownButton<String>(
                          value: _selectedProductLine,
                          isExpanded: true,
                          items: SNMacConfig.productLines.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text('${entry.key} - ${entry.value}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedProductLine = value;
                              });
                              state.setProductLine(value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('工厂:', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        DropdownButton<String>(
                          value: _selectedFactory,
                          isExpanded: true,
                          items: SNMacConfig.factories.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text('${entry.key} - ${entry.value}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedFactory = value;
                              });
                              state.setFactory(value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('产线:', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        DropdownButton<int>(
                          value: _selectedProductionLine,
                          isExpanded: true,
                          items: List.generate(9, (index) => index + 1).map((line) {
                            return DropdownMenuItem<int>(
                              value: line,
                              child: Text('产线 $line'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedProductionLine = value;
                              });
                              state.setProductionLine(value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // 操作按钮
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => state.generateDeviceIdentity(),
                    icon: const Icon(Icons.add),
                    label: const Text('生成设备标识'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showStatistics(context, state),
                    icon: const Icon(Icons.analytics),
                    label: const Text('查看统计'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => state.initializeSNMacConfig(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新加载配置'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // 当前设备信息显示
              if (state.currentDeviceIdentity != null) ...[
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  '当前设备标识信息:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDeviceInfoCard(state.currentDeviceIdentity!),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeviceInfoCard(Map<String, String> deviceInfo) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('SN码', deviceInfo['sn']!, Icons.qr_code),
          const SizedBox(height: 8),
          _buildInfoRow('WiFi MAC', deviceInfo['wifiMac']!, Icons.wifi),
          const SizedBox(height: 8),
          _buildInfoRow('蓝牙 MAC', deviceInfo['bluetoothMac']!, Icons.bluetooth),
          const SizedBox(height: 8),
          _buildInfoRow('产品线', deviceInfo['productLine']!, Icons.category),
          const SizedBox(height: 8),
          _buildInfoRow('工厂', deviceInfo['factory']!, Icons.factory),
          const SizedBox(height: 8),
          _buildInfoRow('生产日期', deviceInfo['productionDate']!, Icons.calendar_today),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }

  void _showStatistics(BuildContext context, TestState state) {
    final stats = state.getSNMacStatistics();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SN/MAC统计信息'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow('已生成SN码数量', '${stats['totalSNsGenerated']}'),
              _buildStatRow('已生成WiFi MAC数量', '${stats['totalWifiMacsGenerated']}'),
              _buildStatRow('已生成蓝牙MAC数量', '${stats['totalBluetoothMacsGenerated']}'),
              _buildStatRow('当前流水号', '${stats['currentSerialCounter']}'),
              _buildStatRow('WiFi MAC剩余', '${stats['wifiMacRemaining']}'),
              _buildStatRow('蓝牙MAC剩余', '${stats['bluetoothMacRemaining']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
