import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';
import '../models/log_state.dart';
import '../services/linux_bluetooth_spp_service.dart';
import '../services/gtp_protocol.dart';

/// SPP 调试页面
/// 用于收发 SPP 指令，支持 SN 或 MAC 地址连接
class SppDebugScreen extends StatefulWidget {
  const SppDebugScreen({super.key});

  @override
  State<SppDebugScreen> createState() => _SppDebugScreenState();
}

class _SppDebugScreenState extends State<SppDebugScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _payloadController = TextEditingController();
  final TextEditingController _moduleIdController = TextEditingController(text: '0006');
  final TextEditingController _messageIdController = TextEditingController(text: 'FF01');
  final ScrollController _scrollController = ScrollController();
  
  bool _isConnecting = false;
  bool _isSending = false;
  bool _showRawData = true;  // 是否显示原始数据
  bool _autoScroll = true;   // 自动滚动
  final List<_SppMessage> _messages = [];
  
  // GTP 缓冲区（用于分片数据组装）
  final List<int> _gtpBuffer = [];
  int _fragmentCount = 0;
  
  // 数据流订阅
  StreamSubscription<Uint8List>? _dataSubscription;
  
  @override
  void initState() {
    super.initState();
    // 延迟订阅数据流，确保 context 可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeToDataStream();
    });
  }
  
  @override
  void dispose() {
    _dataSubscription?.cancel();
    _addressController.dispose();
    _payloadController.dispose();
    _moduleIdController.dispose();
    _messageIdController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  /// 订阅数据流，实时显示接收到的原始数据
  void _subscribeToDataStream() {
    final state = Provider.of<TestState>(context, listen: false);
    final sppService = state.linuxBluetoothSppService;
    
    _dataSubscription?.cancel();
    _dataSubscription = sppService.dataStream.listen((data) {
      if (!_showRawData) return;
      
      _fragmentCount++;
      final hexStr = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      
      // 添加到缓冲区
      _gtpBuffer.addAll(data);
      
      // 显示分片数据
      _addMessage(_SppMessage(
        type: _MessageType.info,
        content: '🔵 分片 #$_fragmentCount [${data.length}字节]: $hexStr',
        timestamp: DateTime.now(),
      ));
      
      // 尝试解析缓冲区中的 GTP 数据包
      _tryParseGtpBuffer();
    });
  }
  
  /// 尝试解析缓冲区中的 GTP 数据包
  void _tryParseGtpBuffer() {
    if (_gtpBuffer.length < 4) return;
    
    // 查找 GTP 前导码 (D0 D2 C5 C2)
    int preambleIndex = -1;
    for (int i = 0; i <= _gtpBuffer.length - 4; i++) {
      if (_gtpBuffer[i] == 0xD0 && _gtpBuffer[i + 1] == 0xD2 &&
          _gtpBuffer[i + 2] == 0xC5 && _gtpBuffer[i + 3] == 0xC2) {
        preambleIndex = i;
        break;
      }
    }
    
    if (preambleIndex == -1) {
      // 没有找到前导码，检查缓冲区是否过大
      if (_gtpBuffer.length > 500) {
        _addMessage(_SppMessage(
          type: _MessageType.error,
          content: '⚠️ 缓冲区过大 (${_gtpBuffer.length}字节) 且未找到 GTP 前导码，清空缓冲区',
        ));
        _gtpBuffer.clear();
        _fragmentCount = 0;
      }
      return;
    }
    
    // 跳过前导码之前的数据
    if (preambleIndex > 0) {
      _gtpBuffer.removeRange(0, preambleIndex);
    }
    
    // 检查是否有足够的数据读取 Length 字段
    if (_gtpBuffer.length < 7) return;
    
    // 读取 Length 字段 (offset 5-6, little endian)
    final gtpLength = _gtpBuffer[5] | (_gtpBuffer[6] << 8);
    final totalLength = 4 + gtpLength;
    
    _addMessage(_SppMessage(
      type: _MessageType.info,
      content: '📊 GTP Length: $gtpLength, 需要: $totalLength, 当前: ${_gtpBuffer.length}',
    ));
    
    if (_gtpBuffer.length < totalLength) {
      // 数据不完整，等待更多数据
      return;
    }
    
    // 提取完整的 GTP 数据包
    final gtpPacket = Uint8List.fromList(_gtpBuffer.sublist(0, totalLength));
    _gtpBuffer.removeRange(0, totalLength);
    
    // 显示完整的 GTP 数据包
    final gtpHex = gtpPacket.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    _addMessage(_SppMessage(
      type: _MessageType.receive,
      content: '📦 完整 GTP [${gtpPacket.length}字节]: $gtpHex',
      timestamp: DateTime.now(),
      rawBytes: gtpPacket,
    ));
    
    // 解析 GTP 数据包
    _parseAndDisplayGtp(gtpPacket);
    
    // 重置分片计数
    _fragmentCount = 0;
    
    // 如果缓冲区还有数据，继续解析
    if (_gtpBuffer.isNotEmpty) {
      _tryParseGtpBuffer();
    }
  }
  
  /// 解析并显示 GTP 数据包详情
  void _parseAndDisplayGtp(Uint8List packet) {
    if (packet.length < 12) return;
    
    // 解析 GTP 头部
    final version = packet[4];
    final length = packet[5] | (packet[6] << 8);
    final type = packet[7];
    final fc = packet[8];
    final seq = packet[9] | (packet[10] << 8);
    final crc8 = packet[11];
    
    _addMessage(_SppMessage(
      type: _MessageType.info,
      content: '   GTP头: Version=0x${version.toRadixString(16).padLeft(2, '0').toUpperCase()}, '
               'Length=$length, Type=0x${type.toRadixString(16).padLeft(2, '0').toUpperCase()}, '
               'FC=0x${fc.toRadixString(16).padLeft(2, '0').toUpperCase()}, Seq=$seq, '
               'CRC8=0x${crc8.toRadixString(16).padLeft(2, '0').toUpperCase()}',
    ));
    
    // 尝试解析 CLI 消息
    final parsedGTP = GTPProtocol.parseGTPResponse(packet, skipCrcVerify: true);
    if (parsedGTP != null && !parsedGTP.containsKey('error')) {
      if (parsedGTP.containsKey('moduleId')) {
        _addMessage(_SppMessage(
          type: _MessageType.info,
          content: '   CLI: ModuleID=0x${(parsedGTP['moduleId'] as int).toRadixString(16).padLeft(4, '0').toUpperCase()}, '
                   'MessageID=0x${(parsedGTP['messageId'] as int).toRadixString(16).padLeft(4, '0').toUpperCase()}, '
                   'Result=${parsedGTP['result']}, SN=${parsedGTP['sn']}',
        ));
      }
      
      if (parsedGTP.containsKey('payload')) {
        final payload = parsedGTP['payload'] as Uint8List;
        if (payload.isNotEmpty) {
          final payloadHex = payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
          _addMessage(_SppMessage(
            type: _MessageType.success,
            content: '   Payload [${payload.length}字节]: $payloadHex',
          ));
        }
      }
    }
  }
  
  /// 清空 GTP 缓冲区
  void _clearGtpBuffer() {
    _gtpBuffer.clear();
    _fragmentCount = 0;
    _addMessage(_SppMessage(
      type: _MessageType.info,
      content: '🗑️ GTP 缓冲区已清空',
    ));
  }

  /// 解析 HEX 字符串为字节数组
  Uint8List? _parseHexString(String hexString) {
    try {
      String cleaned = hexString.replaceAll(RegExp(r'[\s,\-:]'), '').toUpperCase();
      if (cleaned.isEmpty) return null;
      if (cleaned.length % 2 != 0) {
        cleaned = '0$cleaned';
      }
      List<int> bytes = [];
      for (int i = 0; i < cleaned.length; i += 2) {
        String byteStr = cleaned.substring(i, i + 2);
        int byte = int.parse(byteStr, radix: 16);
        bytes.add(byte);
      }
      return Uint8List.fromList(bytes);
    } catch (e) {
      return null;
    }
  }

  /// 解析 ID 字符串（支持 0x 前缀和纯数字）
  int? _parseIdString(String idString) {
    try {
      String cleaned = idString.trim();
      if (cleaned.isEmpty) return null;
      if (cleaned.startsWith('0x') || cleaned.startsWith('0X')) {
        return int.parse(cleaned.substring(2), radix: 16);
      }
      if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(cleaned)) {
        return int.parse(cleaned, radix: 16);
      }
      return int.parse(cleaned);
    } catch (e) {
      return null;
    }
  }

  /// 连接蓝牙设备
  Future<void> _connect() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      _showError('请输入 SN 或蓝牙 MAC 地址');
      return;
    }

    setState(() => _isConnecting = true);
    
    try {
      final state = Provider.of<TestState>(context, listen: false);
      final logState = Provider.of<LogState>(context, listen: false);
      
      // 判断是 SN 还是 MAC 地址
      String macAddress = address;
      if (!_isMacAddress(address)) {
        // 如果不是 MAC 地址，尝试从 SN 转换
        macAddress = _snToMacAddress(address);
        _addMessage(_SppMessage(
          type: _MessageType.info,
          content: '从 SN "$address" 转换为 MAC: $macAddress',
        ));
      }
      
      // 断开现有连接
      if (state.isLinuxBluetoothConnected) {
        await state.disconnectLinuxBluetooth();
        _addMessage(_SppMessage(
          type: _MessageType.info,
          content: '已断开现有连接',
        ));
      }
      
      // 连接设备
      _addMessage(_SppMessage(
        type: _MessageType.info,
        content: '正在连接 $macAddress ...',
      ));
      
      final success = await state.connectLinuxBluetoothDevice(
        deviceAddress: macAddress,
        channel: 5,
        uuid: '00001101-0000-1000-8000-00805F9B34FB',
      );
      
      if (success) {
        _addMessage(_SppMessage(
          type: _MessageType.success,
          content: '✅ 连接成功: $macAddress',
        ));
      } else {
        _addMessage(_SppMessage(
          type: _MessageType.error,
          content: '❌ 连接失败: $macAddress',
        ));
      }
    } catch (e) {
      _addMessage(_SppMessage(
        type: _MessageType.error,
        content: '❌ 连接异常: $e',
      ));
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  /// 断开连接
  Future<void> _disconnect() async {
    try {
      final state = Provider.of<TestState>(context, listen: false);
      await state.disconnectLinuxBluetooth();
      _addMessage(_SppMessage(
        type: _MessageType.info,
        content: '已断开连接',
      ));
    } catch (e) {
      _addMessage(_SppMessage(
        type: _MessageType.error,
        content: '❌ 断开连接失败: $e',
      ));
    }
  }

  /// 发送命令
  Future<void> _sendCommand() async {
    final payloadHex = _payloadController.text.trim();
    if (payloadHex.isEmpty) {
      _showError('请输入 Payload (HEX)');
      return;
    }

    final payload = _parseHexString(payloadHex);
    if (payload == null) {
      _showError('无效的 HEX 格式');
      return;
    }

    final state = Provider.of<TestState>(context, listen: false);
    if (!state.isLinuxBluetoothConnected) {
      _showError('请先连接蓝牙设备');
      return;
    }

    final moduleId = _parseIdString(_moduleIdController.text) ?? 0x0006;
    final messageId = _parseIdString(_messageIdController.text) ?? 0xFF01;

    setState(() => _isSending = true);

    try {
      // 显示发送的 Payload
      final payloadDisplay = payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      _addMessage(_SppMessage(
        type: _MessageType.send,
        content: '📤 发送 Payload [${ payload.length}]: $payloadDisplay',
        timestamp: DateTime.now(),
      ));

      // 发送命令
      final response = await state.sendCommandViaLinuxBluetooth(
        payload,
        moduleId: moduleId,
        messageId: messageId,
        timeout: const Duration(seconds: 5),
      );

      if (response == null) {
        _addMessage(_SppMessage(
          type: _MessageType.error,
          content: '❌ 响应为空（超时）',
        ));
      } else if (response.containsKey('error')) {
        _addMessage(_SppMessage(
          type: _MessageType.error,
          content: '❌ 错误: ${response['error']}',
        ));
      } else {
        // 显示完整原始字节
        if (response.containsKey('rawBytes')) {
          final rawBytes = response['rawBytes'] as Uint8List;
          final rawHex = rawBytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
          _addMessage(_SppMessage(
            type: _MessageType.receive,
            content: '📥 原始字节 [${rawBytes.length}]: $rawHex',
            timestamp: DateTime.now(),
            rawBytes: rawBytes,
          ));
        }
        
        // 显示解析后的 Payload
        if (response.containsKey('payload')) {
          final respPayload = response['payload'] as Uint8List;
          final respPayloadHex = respPayload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
          _addMessage(_SppMessage(
            type: _MessageType.info,
            content: '   Payload [${respPayload.length}]: $respPayloadHex',
          ));
        }
        
        // 显示其他信息
        if (response.containsKey('moduleId')) {
          _addMessage(_SppMessage(
            type: _MessageType.info,
            content: '   Module ID: 0x${(response['moduleId'] as int).toRadixString(16).toUpperCase().padLeft(4, '0')}',
          ));
        }
        if (response.containsKey('messageId')) {
          _addMessage(_SppMessage(
            type: _MessageType.info,
            content: '   Message ID: 0x${(response['messageId'] as int).toRadixString(16).toUpperCase().padLeft(4, '0')}',
          ));
        }
        if (response.containsKey('result')) {
          _addMessage(_SppMessage(
            type: _MessageType.info,
            content: '   Result: ${response['result']}',
          ));
        }
      }
    } catch (e) {
      _addMessage(_SppMessage(
        type: _MessageType.error,
        content: '❌ 发送异常: $e',
      ));
    } finally {
      setState(() => _isSending = false);
    }
  }

  /// 判断是否为 MAC 地址格式
  bool _isMacAddress(String input) {
    // 支持 XX:XX:XX:XX:XX:XX 或 XX-XX-XX-XX-XX-XX 格式
    final macRegex = RegExp(r'^([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}$');
    return macRegex.hasMatch(input);
  }

  /// 从 SN 转换为 MAC 地址（简单规则：取后12位作为MAC）
  String _snToMacAddress(String sn) {
    // 假设 SN 格式中包含 MAC 信息，这里使用简单规则
    // 实际项目中可能需要查询数据库或使用其他转换规则
    String cleaned = sn.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (cleaned.length >= 12) {
      cleaned = cleaned.substring(cleaned.length - 12);
    } else {
      cleaned = cleaned.padLeft(12, '0');
    }
    // 格式化为 XX:XX:XX:XX:XX:XX
    List<String> parts = [];
    for (int i = 0; i < 12; i += 2) {
      parts.add(cleaned.substring(i, i + 2).toUpperCase());
    }
    return parts.join(':');
  }

  void _addMessage(_SppMessage message) {
    setState(() {
      _messages.add(message);
      // 限制消息数量，避免内存溢出
      if (_messages.length > 1000) {
        _messages.removeRange(0, 100);
      }
    });
    // 自动滚动到底部
    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _clearMessages() {
    setState(() {
      _messages.clear();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SPP 调试'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // 数据解析模式选择
          Consumer<TestState>(
            builder: (context, state, child) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<DataParseMode>(
                    value: state.linuxBluetoothParseMode,
                    dropdownColor: Colors.teal[700],
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: DataParseMode.values.map((mode) {
                      return DropdownMenuItem(
                        value: mode,
                        child: Text(mode.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        state.setLinuxBluetoothParseMode(value);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 连接区域
          _buildConnectionSection(),
          const Divider(height: 1),
          // 消息列表
          Expanded(child: _buildMessageList()),
          const Divider(height: 1),
          // 发送区域
          _buildSendSection(),
        ],
      ),
    );
  }

  Widget _buildConnectionSection() {
    return Consumer<TestState>(
      builder: (context, state, child) {
        final isConnected = state.isLinuxBluetoothConnected;
        
        return Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey[100],
          child: Row(
            children: [
              // 连接状态指示
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isConnected ? '已连接' : '未连接',
                style: TextStyle(
                  color: isConnected ? Colors.green[700] : Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              // 地址输入
              Expanded(
                child: TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    hintText: '输入 SN 或蓝牙 MAC 地址 (如: AA:BB:CC:DD:EE:FF)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  enabled: !_isConnecting,
                ),
              ),
              const SizedBox(width: 8),
              // 连接/断开按钮
              if (isConnected)
                ElevatedButton.icon(
                  onPressed: _isConnecting ? null : _disconnect,
                  icon: const Icon(Icons.link_off, size: 18),
                  label: const Text('断开'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _isConnecting ? null : _connect,
                  icon: _isConnecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.link, size: 18),
                  label: Text(_isConnecting ? '连接中...' : '连接'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageList() {
    return Container(
      color: Colors.grey[900],
      child: Column(
        children: [
          // 工具栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.grey[800],
            child: Row(
              children: [
                Text(
                  '消息记录 (${_messages.length})',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 16),
                // 缓冲区状态
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _gtpBuffer.isNotEmpty ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '缓冲区: ${_gtpBuffer.length}字节',
                    style: TextStyle(
                      color: _gtpBuffer.isNotEmpty ? Colors.orange[300] : Colors.green[300],
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 分片计数
                if (_fragmentCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '分片: $_fragmentCount',
                      style: TextStyle(color: Colors.blue[300], fontSize: 11),
                    ),
                  ),
                const Spacer(),
                // 显示原始数据开关
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('原始数据', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    Switch(
                      value: _showRawData,
                      onChanged: (value) => setState(() => _showRawData = value),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                // 清空缓冲区按钮
                IconButton(
                  icon: Icon(Icons.memory, color: _gtpBuffer.isNotEmpty ? Colors.orange[300] : Colors.white38, size: 18),
                  onPressed: _gtpBuffer.isNotEmpty ? _clearGtpBuffer : null,
                  tooltip: '清空缓冲区',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                // 清空消息按钮
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 20),
                  onPressed: _clearMessages,
                  tooltip: '清空消息',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          // 消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageItem(msg);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(_SppMessage msg) {
    Color textColor;
    IconData? icon;
    
    switch (msg.type) {
      case _MessageType.send:
        textColor = Colors.cyan;
        icon = Icons.arrow_upward;
        break;
      case _MessageType.receive:
        textColor = Colors.lightGreen;
        icon = Icons.arrow_downward;
        break;
      case _MessageType.error:
        textColor = Colors.red[300]!;
        icon = Icons.error_outline;
        break;
      case _MessageType.success:
        textColor = Colors.green[300]!;
        icon = Icons.check_circle_outline;
        break;
      case _MessageType.info:
        textColor = Colors.white70;
        icon = null;
        break;
    }

    return InkWell(
      onTap: msg.rawBytes != null ? () {
        final hex = msg.rawBytes!.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
        _copyToClipboard(hex);
      } : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.timestamp != null)
              Text(
                '${msg.timestamp!.hour.toString().padLeft(2, '0')}:${msg.timestamp!.minute.toString().padLeft(2, '0')}:${msg.timestamp!.second.toString().padLeft(2, '0')} ',
                style: TextStyle(color: Colors.grey[600], fontSize: 11, fontFamily: 'monospace'),
              ),
            if (icon != null) ...[
              Icon(icon, color: textColor, size: 14),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: SelectableText(
                msg.content,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            if (msg.rawBytes != null)
              IconButton(
                icon: Icon(Icons.copy, color: Colors.grey[600], size: 14),
                onPressed: () {
                  final hex = msg.rawBytes!.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
                  _copyToClipboard(hex);
                },
                tooltip: '复制 HEX',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendSection() {
    return Consumer<TestState>(
      builder: (context, state, child) {
        final isConnected = state.isLinuxBluetoothConnected;
        
        return Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey[100],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Module ID 和 Message ID
              Row(
                children: [
                  const Text('Module ID:', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _moduleIdController,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text('Message ID:', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _messageIdController,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '提示: 输入 Payload HEX，自动拼接 GTP 协议发送',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Payload 输入和发送按钮
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _payloadController,
                      decoration: InputDecoration(
                        hintText: 'Payload HEX (如: 00 01 02 03)',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      enabled: isConnected && !_isSending,
                      onSubmitted: (_) => _sendCommand(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: (isConnected && !_isSending) ? _sendCommand : null,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: Text(_isSending ? '发送中...' : '发送'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _MessageType {
  send,
  receive,
  error,
  success,
  info,
}

class _SppMessage {
  final _MessageType type;
  final String content;
  final DateTime? timestamp;
  final Uint8List? rawBytes;

  _SppMessage({
    required this.type,
    required this.content,
    this.timestamp,
    this.rawBytes,
  });
}
