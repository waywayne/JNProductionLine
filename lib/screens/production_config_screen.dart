import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/production_config.dart';

/// 产测通用配置页面
class ProductionConfigScreen extends StatefulWidget {
  const ProductionConfigScreen({super.key});

  @override
  State<ProductionConfigScreen> createState() => _ProductionConfigScreenState();
}

class _ProductionConfigScreenState extends State<ProductionConfigScreen> {
  final _config = ProductionConfig();
  final _formKey = GlobalKey<FormState>();

  // 控制器
  late TextEditingController _hardwareVersionController;
  late TextEditingController _leakageCurrentController;
  late TextEditingController _wuqiPowerController;
  late TextEditingController _ispWorkingPowerController;
  late TextEditingController _fullPowerController;
  late TextEditingController _ispSleepPowerController;
  late TextEditingController _minVoltageController;
  late TextEditingController _minBatteryController;
  late TextEditingController _maxBatteryController;
  late TextEditingController _touchThresholdController;
  late TextEditingController _emmcMinCapacityController;
  late TextEditingController _gpibAddressController;
  late TextEditingController _wifiSsidController;
  late TextEditingController _wifiPasswordController;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _hardwareVersionController = TextEditingController(text: _config.hardwareVersion);
    _leakageCurrentController = TextEditingController(text: _config.leakageCurrentUa.toString());
    _wuqiPowerController = TextEditingController(text: _config.wuqiPowerThresholdMa.toString());
    _ispWorkingPowerController = TextEditingController(text: _config.ispWorkingPowerThresholdMa.toString());
    _fullPowerController = TextEditingController(text: _config.fullPowerThresholdMa.toString());
    _ispSleepPowerController = TextEditingController(text: _config.ispSleepPowerThresholdMa.toString());
    _minVoltageController = TextEditingController(text: _config.minVoltageV.toString());
    _minBatteryController = TextEditingController(text: _config.minBatteryPercent.toString());
    _maxBatteryController = TextEditingController(text: _config.maxBatteryPercent.toString());
    _touchThresholdController = TextEditingController(text: _config.touchThreshold.toString());
    _emmcMinCapacityController = TextEditingController(text: _config.emmcMinCapacityGb.toString());
    _gpibAddressController = TextEditingController(text: _config.gpibAddress);
    _wifiSsidController = TextEditingController(text: _config.wifiSsid);
    _wifiPasswordController = TextEditingController(text: _config.wifiPassword);
  }

  @override
  void dispose() {
    _hardwareVersionController.dispose();
    _leakageCurrentController.dispose();
    _wuqiPowerController.dispose();
    _ispWorkingPowerController.dispose();
    _fullPowerController.dispose();
    _ispSleepPowerController.dispose();
    _minVoltageController.dispose();
    _minBatteryController.dispose();
    _maxBatteryController.dispose();
    _touchThresholdController.dispose();
    _emmcMinCapacityController.dispose();
    _gpibAddressController.dispose();
    _wifiSsidController.dispose();
    _wifiPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    if (_formKey.currentState!.validate()) {
      await _config.setHardwareVersion(_hardwareVersionController.text);
      await _config.setLeakageCurrentUa(double.parse(_leakageCurrentController.text));
      await _config.setWuqiPowerThresholdMa(double.parse(_wuqiPowerController.text));
      await _config.setIspWorkingPowerThresholdMa(double.parse(_ispWorkingPowerController.text));
      await _config.setFullPowerThresholdMa(double.parse(_fullPowerController.text));
      await _config.setIspSleepPowerThresholdMa(double.parse(_ispSleepPowerController.text));
      await _config.setMinVoltageV(double.parse(_minVoltageController.text));
      await _config.setMinBatteryPercent(int.parse(_minBatteryController.text));
      await _config.setMaxBatteryPercent(int.parse(_maxBatteryController.text));
      await _config.setTouchThreshold(int.parse(_touchThresholdController.text));
      await _config.setEmmcMinCapacityGb(double.parse(_emmcMinCapacityController.text));
      await _config.setGpibAddress(_gpibAddressController.text);
      await _config.setWifiSsid(_wifiSsidController.text);
      await _config.setWifiPassword(_wifiPasswordController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('配置已保存'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true); // 返回true表示配置已更新
      }
    }
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认重置'),
        content: const Text('确定要将所有配置重置为默认值吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _config.resetToDefaults();
      setState(() {
        _initControllers();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已重置为默认值'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('产测通用配置'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: '重置为默认值',
            onPressed: _resetToDefaults,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存配置',
            onPressed: _saveConfig,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 硬件版本号
            _buildSectionTitle('0. 硬件信息'),
            _buildTextField(
              controller: _hardwareVersionController,
              label: '硬件版本号',
              hint: '例如: 1.0.0',
              icon: Icons.info_outline,
            ),
            const SizedBox(height: 24),

            // 电流相关配置
            _buildSectionTitle('1. 电流阈值配置'),
            _buildTextField(
              controller: _leakageCurrentController,
              label: '程控电流值（漏电流）',
              hint: '默认 500',
              suffix: 'μA',
              icon: Icons.electric_bolt,
              inputType: TextInputType.number,
              validator: _validatePositiveNumber,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _wuqiPowerController,
              label: '只开启物奇的程控电流值',
              hint: '≤ 15',
              suffix: 'mA',
              icon: Icons.power,
              inputType: TextInputType.number,
              validator: _validatePositiveNumber,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _ispWorkingPowerController,
              label: '开启物奇和ISP程控电流值',
              hint: '≤ 100',
              suffix: 'mA',
              icon: Icons.power,
              inputType: TextInputType.number,
              validator: _validatePositiveNumber,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _fullPowerController,
              label: '开启物奇、ISP和WIFI的程控电流值',
              hint: '≤ 400',
              suffix: 'mA',
              icon: Icons.power,
              inputType: TextInputType.number,
              validator: _validatePositiveNumber,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _ispSleepPowerController,
              label: '开启物奇、ISP休眠状态的程控电流值',
              hint: '≤ 30',
              suffix: 'mA',
              icon: Icons.power,
              inputType: TextInputType.number,
              validator: _validatePositiveNumber,
            ),
            const SizedBox(height: 24),

            // 电压和电量配置
            _buildSectionTitle('2. 电压和电量配置'),
            _buildTextField(
              controller: _minVoltageController,
              label: '获取硬件检测电池电压值',
              hint: '> 2.5',
              suffix: 'V',
              icon: Icons.battery_charging_full,
              inputType: TextInputType.number,
              validator: _validatePositiveNumber,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _minBatteryController,
                    label: '电量最小值',
                    hint: '0',
                    suffix: '%',
                    icon: Icons.battery_0_bar,
                    inputType: TextInputType.number,
                    validator: (value) => _validateRange(value, 0, 100),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _maxBatteryController,
                    label: '电量最大值',
                    hint: '100',
                    suffix: '%',
                    icon: Icons.battery_full,
                    inputType: TextInputType.number,
                    validator: (value) => _validateRange(value, 0, 100),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Touch配置
            _buildSectionTitle('3. Touch测试配置'),
            _buildTextField(
              controller: _touchThresholdController,
              label: 'Touch阈值变化量',
              hint: '> 500',
              suffix: '',
              icon: Icons.touch_app,
              inputType: TextInputType.number,
              validator: _validatePositiveNumber,
              helperText: '手按TK1/TK2/TK3时，阈值变化量需超过此值',
            ),
            const SizedBox(height: 24),

            // EMMC配置
            _buildSectionTitle('4. EMMC容量配置'),
            _buildTextField(
              controller: _emmcMinCapacityController,
              label: 'EMMC最小容量',
              hint: '≥ 1',
              suffix: 'GB',
              icon: Icons.storage,
              inputType: TextInputType.number,
              validator: _validatePositiveNumber,
              helperText: '设备返回的容量字节数将与此值比对',
            ),
            const SizedBox(height: 24),

            // GPIB配置
            _buildSectionTitle('5. GPIB设备配置'),
            _buildTextField(
              controller: _gpibAddressController,
              label: 'GPIB设备地址',
              hint: 'GPIB0::5::INSTR',
              suffix: '',
              icon: Icons.settings_input_component,
              inputType: TextInputType.text,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入GPIB地址';
                }
                return null;
              },
              helperText: '程控电源的GPIB地址，用于电流测试',
            ),
            const SizedBox(height: 24),

            // WiFi配置
            _buildSectionTitle('6. WiFi测试配置'),
            _buildTextField(
              controller: _wifiSsidController,
              label: 'WiFi SSID',
              hint: '输入测试用的WiFi名称',
              suffix: '',
              icon: Icons.wifi,
              inputType: TextInputType.text,
              helperText: 'WiFi控制测试中连接固定热点使用的SSID',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _wifiPasswordController,
              label: 'WiFi 密码',
              hint: '输入WiFi密码',
              suffix: '',
              icon: Icons.lock,
              inputType: TextInputType.text,
              helperText: 'WiFi控制测试中连接固定热点使用的密码',
              obscureText: true,
            ),
            const SizedBox(height: 32),

            // 保存按钮
            ElevatedButton.icon(
              onPressed: _saveConfig,
              icon: const Icon(Icons.save),
              label: const Text('保存配置'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? suffix,
    IconData? icon,
    TextInputType? inputType,
    String? Function(String?)? validator,
    String? helperText,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        prefixIcon: icon != null ? Icon(icon, color: Colors.blue[700]) : null,
        helperText: helperText,
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
        ),
      ),
      keyboardType: inputType,
      inputFormatters: inputType == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : null,
      validator: validator,
    );
  }

  String? _validatePositiveNumber(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入数值';
    }
    final number = double.tryParse(value);
    if (number == null || number < 0) {
      return '请输入有效的正数';
    }
    return null;
  }

  String? _validateRange(String? value, int min, int max) {
    if (value == null || value.isEmpty) {
      return '请输入数值';
    }
    final number = int.tryParse(value);
    if (number == null || number < min || number > max) {
      return '请输入$min~$max之间的整数';
    }
    return null;
  }
}
