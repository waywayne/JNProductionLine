import 'package:flutter/material.dart';
import '../screens/gpib_test_screen.dart';

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
            title: 'Edit',
            onPressed: () {},
          ),
          _MenuButton(
            title: 'Log',
            onPressed: () {},
          ),
          _MenuButton(
            title: 'GPIB Test',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GpibTestScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  final String title;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.title,
    required this.onPressed,
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
          child: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
