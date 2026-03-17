import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import 'rf_image_workstation.dart';

/// 整机产测主界面 - 支持三个工位
class ProductionTestSection extends StatefulWidget {
  const ProductionTestSection({super.key});

  @override
  State<ProductionTestSection> createState() => _ProductionTestSectionState();
}

class _ProductionTestSectionState extends State<ProductionTestSection> {
  String? _selectedWorkstation;

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, state, _) {
        if (!state.isConnected) {
          return _buildNotConnectedView();
        }

        // 如果未选择工位，显示工位选择界面
        if (_selectedWorkstation == null) {
          return _buildWorkstationSelector();
        }

        // 显示选中的工位测试界面
        return _buildWorkstationContent();
      },
    );
  }

  Widget _buildNotConnectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cable, size: 64, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            '请先连接串口设备',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '连接设备后即可开始整机产测',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkstationSelector() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[50]!, Colors.white],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.precision_manufacturing, size: 32, color: Colors.blue[700]),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '整机产测',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '请选择测试工位',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // 工位选择卡片
            Expanded(
              child: Row(
                children: [
                  // 工位1: 射频图像测试
                  Expanded(
                    child: _buildWorkstationCard(
                      title: '射频图像测试',
                      subtitle: '工位 1',
                      icon: Icons.wifi,
                      color: Colors.blue,
                      tests: [
                        '物奇/SIGM/WIFI上电',
                        '蓝牙连接测试',
                        'WIFI连接测试',
                        '光敏传感器测试',
                        'IMU传感器测试',
                      ],
                      onTap: () {
                        setState(() {
                          _selectedWorkstation = 'rf_image';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // 工位2: 整机音频测试 (待实现)
                  Expanded(
                    child: _buildWorkstationCard(
                      title: '整机音频测试',
                      subtitle: '工位 2',
                      icon: Icons.volume_up,
                      color: Colors.orange,
                      tests: [
                        'MIC测试',
                        'SPK测试',
                        '音频回路测试',
                      ],
                      enabled: false,
                      onTap: () {
                        // TODO: 实现音频测试工位
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // 工位3: 电源外设测试 (待实现)
                  Expanded(
                    child: _buildWorkstationCard(
                      title: '电源外设测试',
                      subtitle: '工位 3',
                      icon: Icons.power,
                      color: Colors.green,
                      tests: [
                        '电源测试',
                        'LED测试',
                        'Touch测试',
                        'RTC测试',
                      ],
                      enabled: false,
                      onTap: () {
                        // TODO: 实现电源外设测试工位
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkstationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<String> tests,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Card(
      elevation: enabled ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: enabled ? color.withOpacity(0.3) : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图标和标题
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: enabled ? color.withOpacity(0.1) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 40,
                      color: enabled ? color : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: enabled ? color : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: enabled ? Colors.black87 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // 测试项列表
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '测试项目',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: enabled ? Colors.grey[700] : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: tests.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: enabled ? color : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    tests[index],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: enabled ? Colors.grey[700] : Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 底部按钮
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: enabled ? onTap : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: enabled ? color : Colors.grey[300],
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        enabled ? '开始测试' : '即将开放',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (enabled) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkstationContent() {
    return Column(
      children: [
        // 顶部导航栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // 返回按钮
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedWorkstation = null;
                  });
                },
                tooltip: '返回工位选择',
              ),
              const SizedBox(width: 8),
              
              // 当前工位标题
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      _getWorkstationIcon(),
                      color: _getWorkstationColor(),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getWorkstationTitle(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getWorkstationSubtitle(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // 工位内容
        Expanded(
          child: _getWorkstationWidget(),
        ),
      ],
    );
  }

  IconData _getWorkstationIcon() {
    switch (_selectedWorkstation) {
      case 'rf_image':
        return Icons.wifi;
      case 'audio':
        return Icons.volume_up;
      case 'power_peripheral':
        return Icons.power;
      default:
        return Icons.help;
    }
  }

  Color _getWorkstationColor() {
    switch (_selectedWorkstation) {
      case 'rf_image':
        return Colors.blue;
      case 'audio':
        return Colors.orange;
      case 'power_peripheral':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getWorkstationTitle() {
    switch (_selectedWorkstation) {
      case 'rf_image':
        return '射频图像测试';
      case 'audio':
        return '整机音频测试';
      case 'power_peripheral':
        return '电源外设测试';
      default:
        return '未知工位';
    }
  }

  String _getWorkstationSubtitle() {
    switch (_selectedWorkstation) {
      case 'rf_image':
        return '工位 1';
      case 'audio':
        return '工位 2';
      case 'power_peripheral':
        return '工位 3';
      default:
        return '';
    }
  }

  Widget _getWorkstationWidget() {
    switch (_selectedWorkstation) {
      case 'rf_image':
        return const RFImageWorkstation();
      case 'audio':
        // TODO: 实现音频测试工位
        return const Center(child: Text('音频测试工位 - 待实现'));
      case 'power_peripheral':
        // TODO: 实现电源外设测试工位
        return const Center(child: Text('电源外设测试工位 - 待实现'));
      default:
        return const Center(child: Text('未知工位'));
    }
  }
}
