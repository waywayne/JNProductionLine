import 'package:flutter/material.dart';
import '../models/automation_test_config.dart';

/// 跳过设置面板组件
class SkipSettingsPanel extends StatefulWidget {
  const SkipSettingsPanel({super.key});

  @override
  State<SkipSettingsPanel> createState() => _SkipSettingsPanelState();
}

class _SkipSettingsPanelState extends State<SkipSettingsPanel> {
  bool _showSettings = false;  // 默认折叠

  bool _hasSkipEnabled() {
    return AutomationTestConfig.skipGpibTests ||
        AutomationTestConfig.skipGpibReadyCheck ||
        AutomationTestConfig.skipLeakageCurrentTest ||
        AutomationTestConfig.skipWorkingCurrentTest ||
        AutomationTestConfig.skipPowerOnTest ||
        AutomationTestConfig.skipBydMes;
  }

  @override
  Widget build(BuildContext context) {
    final hasSkipEnabled = _hasSkipEnabled();

    return Container(
      decoration: BoxDecoration(
        color: hasSkipEnabled ? Colors.orange.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasSkipEnabled ? Colors.orange.shade300 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 标题栏
          InkWell(
            onTap: () {
              setState(() {
                _showSettings = !_showSettings;
              });
            },
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    color: hasSkipEnabled ? Colors.orange.shade700 : Colors.grey.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '测试跳过选项',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: hasSkipEnabled ? Colors.orange.shade700 : Colors.grey.shade700,
                    ),
                  ),
                  if (hasSkipEnabled) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '已启用',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    _showSettings ? Icons.expand_less : Icons.expand_more,
                    color: hasSkipEnabled ? Colors.orange.shade700 : Colors.grey.shade600,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          
          // 设置内容
          if (_showSettings) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // 快捷操作按钮
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              AutomationTestConfig.skipGpibTests = true;
                              AutomationTestConfig.skipGpibReadyCheck = true;
                              AutomationTestConfig.skipLeakageCurrentTest = true;
                              AutomationTestConfig.skipWorkingCurrentTest = true;
                              AutomationTestConfig.skipPowerOnTest = true;
                              AutomationTestConfig.skipBydMes = true;
                            });
                          },
                          icon: const Icon(Icons.check_box, size: 18),
                          label: const Text('全部跳过'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade700,
                            side: BorderSide(color: Colors.orange.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              AutomationTestConfig.skipGpibTests = false;
                              AutomationTestConfig.skipGpibReadyCheck = false;
                              AutomationTestConfig.skipLeakageCurrentTest = false;
                              AutomationTestConfig.skipPowerOnTest = false;
                              AutomationTestConfig.skipWorkingCurrentTest = false;
                              AutomationTestConfig.skipBydMes = false;
                            });
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('全部重置'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 跳过选项开关
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildSkipSwitch(
                        label: '跳过GPIB检测',
                        value: AutomationTestConfig.skipGpibTests,
                        icon: Icons.cable,
                        onChanged: (value) {
                          setState(() {
                            AutomationTestConfig.skipGpibTests = value;
                          });
                        },
                      ),
                      _buildSkipSwitch(
                        label: '跳过GPIB未就绪',
                        value: AutomationTestConfig.skipGpibReadyCheck,
                        icon: Icons.link_off,
                        onChanged: (value) {
                          setState(() {
                            AutomationTestConfig.skipGpibReadyCheck = value;
                          });
                        },
                      ),
                      _buildSkipSwitch(
                        label: '跳过漏电流测试',
                        value: AutomationTestConfig.skipLeakageCurrentTest,
                        icon: Icons.electrical_services,
                        onChanged: (value) {
                          setState(() {
                            AutomationTestConfig.skipLeakageCurrentTest = value;
                          });
                        },
                      ),
                      _buildSkipSwitch(
                        label: '跳过工作功耗',
                        value: AutomationTestConfig.skipWorkingCurrentTest,
                        icon: Icons.power,
                        onChanged: (value) {
                          setState(() {
                            AutomationTestConfig.skipWorkingCurrentTest = value;
                          });
                        },
                      ),
                      _buildSkipSwitch(
                        label: '跳过上电测试',
                        value: AutomationTestConfig.skipPowerOnTest,
                        icon: Icons.power_settings_new,
                        onChanged: (value) {
                          setState(() {
                            AutomationTestConfig.skipPowerOnTest = value;
                          });
                        },
                      ),
                      _buildSkipSwitch(
                        label: '跳过BYD MES',
                        value: AutomationTestConfig.skipBydMes,
                        icon: Icons.cloud_off,
                        onChanged: (value) {
                          setState(() {
                            AutomationTestConfig.skipBydMes = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 构建单个跳过开关
  Widget _buildSkipSwitch({
    required String label,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value ? Colors.orange.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? Colors.orange.shade400 : Colors.grey.shade300,
            width: value ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: value ? Colors.orange.shade700 : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                color: value ? Colors.orange.shade700 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 8),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.orange.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
