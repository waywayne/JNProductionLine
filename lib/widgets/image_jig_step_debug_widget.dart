import 'package:flutter/material.dart';
import '../config/production_config.dart';
import '../services/jig_commands.dart';
import '../services/jig_serial_service.dart';

/// 图像治具单步调试组件
/// 支持工位4治具所有串口指令的独立测试
class ImageJigStepDebugWidget extends StatefulWidget {
  const ImageJigStepDebugWidget({super.key});

  @override
  State<ImageJigStepDebugWidget> createState() => _ImageJigStepDebugWidgetState();
}

class _JigCommandDef {
  final String command;
  final String label;
  final String description;
  final Duration timeout;

  const _JigCommandDef({
    required this.command,
    required this.label,
    required this.description,
    this.timeout = const Duration(seconds: 10),
  });
}

/// 与 PreUltrasoundAutoTest._runJigStep4 调用的指令一致
const _jigCommands = [
  _JigCommandDef(
    command: JigCommands.powerIn,
    label: '治具上电',
    description: '测试开始前上电（POWER_IN）',
  ),
  _JigCommandDef(
    command: JigCommands.close,
    label: '治具关闭',
    description: 'MES 开始后夹紧设备（CLOSE）',
  ),
  _JigCommandDef(
    command: JigCommands.lightSourceCh1On,
    label: '光源通道1开',
    description: '亮环境光敏测试前开启光源',
  ),
  _JigCommandDef(
    command: JigCommands.lightSourceCh1Off,
    label: '光源通道1关',
    description: '暗环境光敏测试前关闭光源',
  ),
  _JigCommandDef(
    command: JigCommands.onlyResolutionCardDown,
    label: '分辨率图卡下降',
    description: 'ISO12233 MTF 测试前下降图卡',
    timeout: Duration(seconds: 30),
  ),
  _JigCommandDef(
    command: JigCommands.onlyColorCardDown,
    label: '色卡下降',
    description: '24 色色卡测试前下降色卡',
    timeout: Duration(seconds: 30),
  ),
  _JigCommandDef(
    command: JigCommands.open,
    label: '治具打开',
    description: '测试结束或异常时释放设备（OPEN）',
  ),
  _JigCommandDef(
    command: JigCommands.powerOut,
    label: '治具断电',
    description: '开箱释放设备后断电（POWER_OUT）',
  ),
];

class _LogEntry {
  final DateTime time;
  final String message;
  final bool isSuccess;
  final bool isError;

  _LogEntry({
    required this.time,
    required this.message,
    this.isSuccess = false,
    this.isError = false,
  });
}

class _ImageJigStepDebugWidgetState extends State<ImageJigStepDebugWidget> {
  final JigSerialService _jigService = JigSerialService();
  final ProductionConfig _config = ProductionConfig();
  final List<_LogEntry> _logs = [];
  final ScrollController _logScrollController = ScrollController();

  List<String> _availablePorts = [];
  String? _selectedPort;
  bool _isConnecting = false;
  bool _isSending = false;
  String? _lastCommand;
  bool? _lastSuccess;

  @override
  void initState() {
    super.initState();
    _initPort();
  }

  Future<void> _initPort() async {
    await _config.init();
    _refreshPorts(preferConfigPort: true);
  }

  void _refreshPorts({bool preferConfigPort = false}) {
    final ports = JigSerialService.getAvailablePorts();
    String? selected = _selectedPort;
    if (preferConfigPort) {
      final configPort = _config.jigSerialPort.trim();
      if (configPort.isNotEmpty && ports.contains(configPort)) {
        selected = configPort;
      }
    }
    if (selected == null || !ports.contains(selected)) {
      selected = ports.isNotEmpty ? ports.first : null;
    }
    setState(() {
      _availablePorts = ports;
      _selectedPort = selected;
    });
  }

  void _addLog(String message, {bool isSuccess = false, bool isError = false}) {
    setState(() {
      _logs.insert(
        0,
        _LogEntry(
          time: DateTime.now(),
          message: message,
          isSuccess: isSuccess,
          isError: isError,
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  Future<void> _connect() async {
    final port = _selectedPort?.trim();
    if (port == null || port.isEmpty) {
      _addLog('请先选择治具串口', isError: true);
      return;
    }

    setState(() => _isConnecting = true);
    _addLog('正在连接治具串口: $port');

    final ok = await _jigService.connect(port);
    setState(() => _isConnecting = false);

    if (ok) {
      _addLog('治具串口连接成功 ($port, 115200 N81)', isSuccess: true);
    } else {
      _addLog('治具串口连接失败: $port', isError: true);
    }
  }

  Future<void> _disconnect() async {
    await _jigService.disconnect();
    _addLog('治具串口已断开');
    setState(() {});
  }

  Future<void> _sendCommand(_JigCommandDef def) async {
    if (!_jigService.isConnected) {
      _addLog('治具串口未连接，请先连接', isError: true);
      return;
    }
    if (_isSending) {
      _addLog('上一条指令仍在执行，请稍候', isError: true);
      return;
    }

    setState(() {
      _isSending = true;
      _lastCommand = def.command;
      _lastSuccess = null;
    });

    _addLog('发送指令: ${def.label} (${def.command})，超时 ${def.timeout.inSeconds}s');

    final ok = await _jigService.sendCommand(def.command, timeout: def.timeout);

    setState(() {
      _isSending = false;
      _lastSuccess = ok;
    });

    if (ok) {
      _addLog('指令成功: ${def.label} → ${def.command}_OK', isSuccess: true);
    } else {
      _addLog('指令失败: ${def.label} (${def.command})', isError: true);
    }
  }

  @override
  void dispose() {
    _jigService.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configPort = _config.jigSerialPort.trim();
    final isConnected = _jigService.isConnected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildConnectionPanel(configPort, isConnected),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: _buildCommandPanel(isConnected)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _buildLogPanel()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionPanel(String configPort, bool isConnected) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isConnected ? Icons.link : Icons.link_off,
                size: 18,
                color: isConnected ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                isConnected ? '已连接: ${_jigService.portName}' : '未连接',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isConnected ? Colors.green.shade700 : Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              if (configPort.isNotEmpty)
                Text(
                  '配置串口: $configPort',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('串口:', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _availablePorts.contains(_selectedPort) ? _selectedPort : null,
                      hint: Text(
                        _availablePorts.isEmpty ? '无可用串口' : '选择串口',
                        style: const TextStyle(fontSize: 13),
                      ),
                      items: _availablePorts
                          .map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: isConnected || _isConnecting
                          ? null
                          : (value) => setState(() => _selectedPort = value),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: '刷新串口列表',
                onPressed: isConnected || _isConnecting ? null : () => _refreshPorts(),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isConnecting || _isSending
                    ? null
                    : (isConnected ? _disconnect : _connect),
                icon: _isConnecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(isConnected ? Icons.power_off : Icons.power, size: 18),
                label: Text(_isConnecting ? '连接中...' : (isConnected ? '断开' : '连接')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? Colors.red.shade600 : Colors.orange.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommandPanel(bool isConnected) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.build_circle_outlined, size: 18, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text(
                '治具指令单步测试',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              if (_isSending) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 6),
                Text('执行中: $_lastCommand', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '通信格式: N81, 115200 baud · 发送 <COMMAND>\\r\\n · 成功 <COMMAND>_OK',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _jigCommands.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final def = _jigCommands[index];
                final isLast = _lastCommand == def.command && _lastSuccess != null;
                return _buildCommandTile(def, isConnected, isLast);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandTile(_JigCommandDef def, bool isConnected, bool isLast) {
    Color? borderColor;
    Color? bgColor;
    if (isLast) {
      if (_lastSuccess == true) {
        borderColor = Colors.green.shade300;
        bgColor = Colors.green.shade50;
      } else {
        borderColor = Colors.red.shade300;
        bgColor = Colors.red.shade50;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor ?? Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  def.command,
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.blue.shade700),
                ),
                const SizedBox(height: 2),
                Text(def.description, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                if (def.timeout.inSeconds > 10)
                  Text(
                    '超时: ${def.timeout.inSeconds}s',
                    style: TextStyle(fontSize: 10, color: Colors.orange.shade700),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: !isConnected || _isSending ? null : () => _sendCommand(def),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('执行'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              const Text(
                '执行日志',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton(
                onPressed: _logs.isEmpty ? null : () => setState(() => _logs.clear()),
                child: const Text('清空', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      '连接治具串口后，点击指令「执行」进行单步测试',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    controller: _logScrollController,
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final entry = _logs[index];
                      Color color = Colors.white70;
                      if (entry.isSuccess) color = Colors.greenAccent;
                      if (entry.isError) color = Colors.redAccent;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '[${_formatTime(entry.time)}] ${entry.message}',
                          style: TextStyle(color: color, fontSize: 11, fontFamily: 'monospace'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
