import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../models/test_mode.dart';

/// Test mode selector widget
/// 测试模式选择器组件
class TestModeSelector extends StatelessWidget {
  const TestModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TestState>(
      builder: (context, state, _) {
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
                Icons.settings_input_component,
                color: Colors.blue[700],
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '测试模式:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModeCard(
                  context,
                  state,
                  TestMode.singleBoard,
                  Icons.developer_board,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeCard(
                  context,
                  state,
                  TestMode.completeDevice,
                  Icons.devices,
                  Colors.green,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeCard(
    BuildContext context,
    TestState state,
    TestMode mode,
    IconData icon,
    Color color,
  ) {
    final isSelected = state.testMode == mode;
    final isDisabled = state.isConnected;

    return InkWell(
      onTap: isDisabled
          ? null
          : () async {
              await state.switchTestMode(mode);
            },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.15)
              : Colors.grey.withOpacity(0.05),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isDisabled
                  ? Colors.grey
                  : (isSelected ? color : Colors.grey[600]),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                mode.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isDisabled
                      ? Colors.grey
                      : (isSelected ? color : Colors.grey[700]),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
