import 'package:flutter/material.dart';
import '../screens/gpib_test_screen.dart';
import '../screens/production_config_screen.dart';
import '../screens/sn_records_screen.dart';
import 'sn_mac_config_section.dart';

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
            title: 'SN/MAC配置',
            onPressed: () {
              _showSNMacConfigDialog(context);
            },
          ),
          _MenuButton(
            title: 'SN记录管理',
            icon: Icons.storage,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SNRecordsScreen()),
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
          const Spacer(),
        ],
      ),
    );
  }

  static void _showSNMacConfigDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 800,
          height: 600,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SN码和MAC地址配置',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const Expanded(
                child: SNMacConfigSection(),
              ),
            ],
          ),
        ),
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
