import 'package:flutter/material.dart';
import '../screens/gpib_test_screen.dart';
import '../screens/production_config_screen.dart';
import '../screens/native_spp_debug_screen.dart';
import 'byd_mes_test_dialog.dart';
import 'ota_upgrade_widget.dart';
import 'wifi_range_test_widget.dart';
import 'image_algorithm_test_widget.dart';

class MenuBarWidget extends StatelessWidget {
  const MenuBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(
          bottom: BorderSide(color: Colors.grey[400]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          _MenuButton(
            title: 'GPIB Test',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GpibTestScreen()),
              );
            },
          ),
          _MenuButton(
            title: '通用配置',
            icon: Icons.settings,
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProductionConfigScreen()),
              );
              // 如果配置已更新，可以在这里刷新相关状态
              if (result == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('配置已更新，新的测试将使用新配置'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          _MenuButton(
            title: 'BYD MES 测试',
            icon: Icons.cloud_sync,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const BydMesTestDialog(),
              );
            },
          ),
          _MenuButton(
            title: 'SPP 通讯',
            icon: Icons.bluetooth,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NativeSppDebugScreen()),
              );
            },
          ),
          _MenuButton(
            title: '产测OTA',
            icon: Icons.system_update,
            onPressed: () {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Dialog(
                  child: Container(
                    width: 900,
                    height: 700,
                    padding: const EdgeInsets.all(16),
                    child: const OTAUpgradeWidget(),
                  ),
                ),
              );
            },
          ),
          _MenuButton(
            title: 'WiFi拉距',
            icon: Icons.wifi,
            onPressed: () {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Dialog(
                  child: Container(
                    width: 900,
                    height: 700,
                    padding: const EdgeInsets.all(16),
                    child: const WiFiRangeTestWidget(),
                  ),
                ),
              );
            },
          ),
          _MenuButton(
            title: '图像算法',
            icon: Icons.image,
            onPressed: () {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Dialog(
                  child: Container(
                    width: 900,
                    height: 700,
                    padding: const EdgeInsets.all(16),
                    child: const ImageAlgorithmTestWidget(),
                  ),
                ),
              );
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  final String title;
  final VoidCallback onPressed;
  final IconData? icon;

  const _MenuButton({
    required this.title,
    required this.onPressed,
    this.icon,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _isHovered ? Colors.grey[300] : Colors.transparent,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: Colors.black87),
                const SizedBox(width: 6),
              ],
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
