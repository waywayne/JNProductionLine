import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../models/log_state.dart';
import '../config/wifi_config.dart';
import '../services/production_test_commands.dart';
import '../services/product_sn_api.dart';
import 'sn_input_dialog.dart';

/// Wi-Fi 拉距测试 Widget
class WiFiRangeTestWidget extends StatefulWidget {
  const WiFiRangeTestWidget({super.key});

  @override
  State<WiFiRangeTestWidget> createState() => _WiFiRangeTestWidgetState();
}

class _WiFiRangeTestWidgetState extends State<WiFiRangeTestWidget> {
  bool _isTesting = false;
  String? _deviceIP;
  int _testRound = 0;
  String _statusMessage = '';
  String _iperfResult1 = '';
  String _iperfResult2 = '';
  bool _round1Done = false;
  bool _round2Done = false;
  bool _waitingForReposition = false;

  /// 确保设备已连接（串口优先，否则SN扫码→蓝牙连接）
  Future<bool> _ensureConnection(TestState state) async {
    if (state.serialService.isConnected || state.isLinuxBluetoothConnected) {
      return true;
    }

    if (!mounted) return false;
    final productInfo = await showDialog<ProductSNInfo>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SNInputDialog(),
    );

    if (productInfo == null) {
      _setStatus('❌ 未获取到设备信息');
      return false;
    }

    final bluetoothAddress = productInfo.bluetoothAddress;
    if (bluetoothAddress.isEmpty) {
      _setStatus('❌ 设备蓝牙地址为空');
      return false;
    }

    _setStatus('🔵 正在连接蓝牙 $bluetoothAddress ...');
    final connected = await state.testLinuxBluetooth(deviceAddress: bluetoothAddress);
    if (!connected) {
      _setStatus('❌ 蓝牙连接失败');
      return false;
    }
    _setStatus('✅ 蓝牙连接成功');
    return true;
  }

  /// 发送WiFi拉距命令(0x06)并获取设备IP
  Future<String?> _sendWifiRangeCommand(TestState state, LogState logState) async {
    final ssid = WiFiConfig.defaultSSID;
    final password = WiFiConfig.defaultPassword;

    if (ssid.isEmpty) {
      logState.error('❌ WiFi SSID未配置，请在通用配置中设置');
      _setStatus('❌ WiFi SSID未配置');
      return null;
    }

    final connectionType = state.serialService.isConnected ? '串口' : 'Linux 蓝牙 SPP';
    logState.info('📶 发送WiFi拉距命令(0x06)');
    logState.info('   通信方式: $connectionType');
    logState.info('   SSID: $ssid');

    final ssidBytes = ssid.codeUnits + [0x00];
    final pwdBytes = password.codeUnits + [0x00];
    final wifiPayload = [...ssidBytes, ...pwdBytes];
    final wifiCommand = ProductionTestCommands.createControlWifiCommand(0x06, data: wifiPayload);

    for (int retry = 0; retry < 3; retry++) {
      if (retry > 0) {
        logState.info('   重试 ($retry/3)...');
        await Future.delayed(const Duration(seconds: 2));
      }

      try {
        // 串口优先，否则使用蓝牙SPP
        Map<String, dynamic>? response;
        if (state.serialService.isConnected) {
          response = await state.serialService.sendCommandAndWaitResponse(
            wifiCommand,
            timeout: const Duration(seconds: 15),
            moduleId: ProductionTestCommands.moduleId,
            messageId: ProductionTestCommands.messageId,
          );
        } else {
          response = await state.sendCommandViaLinuxBluetooth(
            wifiCommand,
            timeout: const Duration(seconds: 15),
            moduleId: ProductionTestCommands.moduleId,
            messageId: ProductionTestCommands.messageId,
          );
        }

        if (response != null && !response.containsKey('error')) {
          if (response.containsKey('payload') && response['payload'] != null) {
            final responsePayload = response['payload'] as Uint8List;
            final wifiResult = ProductionTestCommands.parseWifiResponse(responsePayload, 0x06);

            if (wifiResult != null && wifiResult['success'] == true && wifiResult.containsKey('ip')) {
              final ip = wifiResult['ip'] as String;
              logState.success('✅ 获取到设备IP: $ip');
              return ip;
            }
          }
        }
      } catch (e) {
        logState.warning('⚠️ WiFi命令异常: $e');
      }
    }

    logState.error('❌ WiFi拉距命令失败，未获取到设备IP');
    return null;
  }

  /// 执行iperf3测试
  Future<String> _runIperf(String deviceIP, LogState logState) async {
    final cmd = 'iperf3';
    final args = ['-c', deviceIP, '-p', '5001', '-t', '3', '-i', '1', '--json'];
    logState.info('🚀 执行: $cmd ${args.join(' ')}');

    try {
      final result = await Process.run(cmd, args, stdoutEncoding: utf8, stderrEncoding: utf8);

      if (result.exitCode == 0) {
        final jsonStr = result.stdout as String;
        // 尝试解析JSON提取关键信息
        try {
          final data = json.decode(jsonStr) as Map<String, dynamic>;
          final end = data['end'] as Map<String, dynamic>?;
          if (end != null) {
            final sumSent = end['sum_sent'] as Map<String, dynamic>?;
            final sumReceived = end['sum_received'] as Map<String, dynamic>?;
            final sb = StringBuffer();
            sb.writeln('═══════════════════════════════');
            if (sumSent != null) {
              final bps = (sumSent['bits_per_second'] as num?) ?? 0;
              final mbps = (bps / 1000000).toStringAsFixed(2);
              sb.writeln('📤 发送: $mbps Mbps');
            }
            if (sumReceived != null) {
              final bps = (sumReceived['bits_per_second'] as num?) ?? 0;
              final mbps = (bps / 1000000).toStringAsFixed(2);
              sb.writeln('📥 接收: $mbps Mbps');
            }
            sb.writeln('═══════════════════════════════');
            final summary = sb.toString();
            logState.success(summary);
            return summary;
          }
        } catch (_) {
          // JSON解析失败，返回原始输出
        }
        logState.info(jsonStr.length > 500 ? '${jsonStr.substring(0, 500)}...' : jsonStr);
        return jsonStr;
      } else {
        final err = '退出码: ${result.exitCode}\n${result.stderr}';
        logState.error('❌ iperf3 失败: $err');
        return '❌ iperf3 失败:\n$err';
      }
    } catch (e) {
      final err = '执行iperf3异常: $e\n请确认已安装 iperf3';
      logState.error('❌ $err');
      return '❌ $err';
    }
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _statusMessage = msg);
  }

  /// 开始第一轮测试
  Future<void> _startTest() async {
    final state = context.read<TestState>();
    final logState = context.read<LogState>();

    setState(() {
      _isTesting = true;
      _testRound = 1;
      _iperfResult1 = '';
      _iperfResult2 = '';
      _round1Done = false;
      _round2Done = false;
      _waitingForReposition = false;
      _deviceIP = null;
    });

    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('📡 Wi-Fi 拉距测试开始');
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // 1. 确保连接
    _setStatus('🔗 检查设备连接...');
    final connected = await _ensureConnection(state);
    if (!connected) {
      setState(() => _isTesting = false);
      return;
    }

    // 2. 发送WiFi拉距命令获取IP
    _setStatus('📶 发送WiFi拉距命令，等待设备IP...');
    final ip = await _sendWifiRangeCommand(state, logState);
    if (ip == null) {
      _setStatus('❌ 未获取到设备IP，测试终止');
      setState(() => _isTesting = false);
      return;
    }
    _deviceIP = ip;

    // 3. 执行第一轮iperf
    _setStatus('🚀 第一轮测试: iperf3 → $ip ...');
    logState.info('📡 第一轮拉距测试');
    final result1 = await _runIperf(ip, logState);

    setState(() {
      _iperfResult1 = result1;
      _round1Done = true;
      _waitingForReposition = true;
      _statusMessage = '✅ 第一轮测试完成，请重新放置设备后点击「再次测试」';
    });
  }

  /// 第二轮测试（重新放置设备后）
  Future<void> _startRound2() async {
    if (_deviceIP == null) return;
    final logState = context.read<LogState>();

    setState(() {
      _waitingForReposition = false;
      _testRound = 2;
    });

    _setStatus('🚀 第二轮测试: iperf3 → $_deviceIP ...');
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('📡 第二轮拉距测试（设备已重新放置）');

    final result2 = await _runIperf(_deviceIP!, logState);

    setState(() {
      _iperfResult2 = result2;
      _round2Done = true;
      _isTesting = false;
      _statusMessage = '✅ 两轮测试均已完成';
    });

    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    logState.info('🏁 Wi-Fi 拉距测试结束');
    logState.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  /// 重置测试
  void _reset() {
    setState(() {
      _isTesting = false;
      _deviceIP = null;
      _testRound = 0;
      _statusMessage = '';
      _iperfResult1 = '';
      _iperfResult2 = '';
      _round1Done = false;
      _round2Done = false;
      _waitingForReposition = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[50]!, Colors.white],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题栏
            _buildHeader(),
            const SizedBox(height: 16),
            // 操作按钮
            _buildActionButtons(),
            const SizedBox(height: 12),
            // 状态
            if (_statusMessage.isNotEmpty) _buildStatusBar(),
            const SizedBox(height: 12),
            // 结果区域
            Expanded(child: _buildResultArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal[600]!, Colors.teal[400]!],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_tethering, color: Colors.white, size: 24),
          const SizedBox(width: 10),
          const Text(
            'Wi-Fi 拉距测试',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Spacer(),
          if (_deviceIP != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'IP: $_deviceIP',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // 开始测试
        ElevatedButton.icon(
          onPressed: (_isTesting && !_waitingForReposition) ? null : (_waitingForReposition ? null : _startTest),
          icon: const Icon(Icons.play_arrow),
          label: const Text('开始测试'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        const SizedBox(width: 12),
        // 再次测试
        ElevatedButton.icon(
          onPressed: _waitingForReposition ? _startRound2 : null,
          icon: const Icon(Icons.replay),
          label: const Text('再次测试'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        const SizedBox(width: 12),
        // 重置
        OutlinedButton.icon(
          onPressed: _isTesting ? null : _reset,
          icon: const Icon(Icons.refresh),
          label: const Text('重置'),
        ),
      ],
    );
  }

  Widget _buildStatusBar() {
    Color bgColor = Colors.blue[50]!;
    Color textColor = Colors.blue[800]!;
    IconData icon = Icons.info_outline;

    if (_statusMessage.contains('❌')) {
      bgColor = Colors.red[50]!;
      textColor = Colors.red[800]!;
      icon = Icons.error_outline;
    } else if (_statusMessage.contains('✅')) {
      bgColor = Colors.green[50]!;
      textColor = Colors.green[800]!;
      icon = Icons.check_circle_outline;
    } else if (_statusMessage.contains('🚀') || _statusMessage.contains('📶')) {
      bgColor = Colors.orange[50]!;
      textColor = Colors.orange[800]!;
      icon = Icons.hourglass_top;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_statusMessage, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
          ),
          if (_isTesting && !_waitingForReposition)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }

  Widget _buildResultArea() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 测试说明
          if (_testRound == 0 && !_round1Done)
            _buildInstructions(),

          // 第一轮结果
          if (_round1Done)
            _buildResultCard('第一轮测试结果', _iperfResult1, 1),

          // 重新放置提示
          if (_waitingForReposition)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, color: Colors.amber[800], size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '请重新放置设备',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber[900]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '将设备移至新位置后，点击上方「再次测试」按钮进行第二轮测试',
                            style: TextStyle(color: Colors.amber[800]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 第二轮结果
          if (_round2Done)
            _buildResultCard('第二轮测试结果', _iperfResult2, 2),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.teal[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.teal[700], size: 24),
              const SizedBox(width: 10),
              Text('测试说明', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal[800])),
            ],
          ),
          const SizedBox(height: 12),
          _buildStep('1', '发送WiFi拉距命令(0x06)，设备启动iperf服务'),
          _buildStep('2', '上位机使用iperf3连接设备进行第一轮带宽测试'),
          _buildStep('3', '提示重新放置设备到新位置'),
          _buildStep('4', '再次执行iperf3进行第二轮测试'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi, color: Colors.grey[600], size: 18),
                const SizedBox(width: 8),
                Text(
                  'SSID: ${WiFiConfig.defaultSSID.isEmpty ? "未配置" : WiFiConfig.defaultSSID}',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.teal[600],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildResultCard(String title, String result, int round) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: round == 1 ? Colors.blue[50] : Colors.green[50],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(
                children: [
                  Icon(
                    round == 1 ? Icons.looks_one : Icons.looks_two,
                    color: round == 1 ? Colors.blue[700] : Colors.green[700],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: round == 1 ? Colors.blue[800] : Colors.green[800],
                    ),
                  ),
                ],
              ),
            ),
            // 内容
            Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                result.isEmpty ? '等待测试...' : result,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
