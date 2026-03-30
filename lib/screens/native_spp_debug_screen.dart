import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/native_rfcomm_service.dart';
import '../services/gtp_protocol.dart';

/// 纯 Dart 实现的 SPP 调试页面
/// 不依赖 Python 脚本，直接读写 /dev/rfcomm0 设备文件
/// 类似第三方 SPP 调试工具的实现方式
class NativeSppDebugScreen extends StatefulWidget {
  const NativeSppDebugScreen({super.key});

  @override
  State<NativeSppDebugScreen> createState() => _NativeSppDebugScreenState();
}

class _NativeSppDebugScreenState extends State<NativeSppDebugScreen> {
  final NativeRfcommService _rfcommService = NativeRfcommService();
  
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _channelController = TextEditingController(text: '1');
  final TextEditingController _payloadController = TextEditingController();
  final TextEditingController _moduleIdController = TextEditingController(text: '0006');
  final TextEditingController _messageIdController = TextEditingController(text: 'FF01');
  final ScrollController _scrollController = ScrollController();
  
  bool _isConnecting = false;
  bool _isSending = false;
  bool _showRawData = true;
  bool _autoScroll = true;
  final List<_LogMessage> _messages = [];
  
  StreamSubscription<Uint8List>? _dataSubscription;
  StreamSubscription<String>? _logSubscription;
  
  @override
  void initState() {
    super.initState();
    _subscribeToStreams();
  }
  
  @override
  void dispose() {
    _dataSubscription?.cancel();
    _logSubscription?.cancel();
    _rfcommService.dispose();
    _addressController.dispose();
    _channelController.dispose();
    _payloadController.dispose();
    _moduleIdController.dispose();
    _messageIdController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _subscribeToStreams() {
    // 订阅数据流
    _dataSubscription = _rfcommService.dataStream.listen((data) {
      if (!_showRawData) return;
      
      final hexStr = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
      _addMessage(_LogMessage(
        type: _MessageType.data,
        content: '🔵 数据 [${data.length}字节]: $hexStr',
        timestamp: DateTime.now(),
        rawBytes: data,
      ));
    });
    
    // 订阅日志流
    _logSubscription = _rfcommService.logStream.listen((log) {
      _MessageType type = _MessageType.info;
      if (log.contains('❌')) {
        type = _MessageType.error;
      } else if (log.contains('✅')) {
        type = _MessageType.success;
      } else if (log.contains('📤')) {
        type = _MessageType.send;
      } else if (log.contains('📥') || log.contains('📦')) {
        type = _MessageType.receive;
      }
      
      _addMessage(_LogMessage(
        type: type,
        content: log,
        timestamp: DateTime.now(),
      ));
    });
  }
  
  void _addMessage(_LogMessage message) {
    setState(() {
      _messages.add(message);
      if (_messages.length > 1000) {
        _messages.removeRange(0, 100);
      }
    });
    
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

  /// 解析 ID 字符串
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
  
  /// 判断是否为 MAC 地址格式
  bool _isMacAddress(String input) {
    final macRegex = RegExp(r'^([0-9A-Fa-f]{2}[:\-]){5}[0-9A-Fa-f]{2}$');
    return macRegex.hasMatch(input);
  }

  /// 从 SN 转换为 MAC 地址
  String _snToMacAddress(String sn) {
    String cleaned = sn.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (cleaned.length >= 12) {
      cleaned = cleaned.substring(cleaned.length - 12);
    } else {
      cleaned = cleaned.padLeft(12, '0');
    }
    List<String> parts = [];
    for (int i = 0; i < 12; i += 2) {
      parts.add(cleaned.substring(i, i + 2).toUpperCase());
    }
    return parts.join(':');
  }
  
  /// 连接设备
  Future<void> _connect() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      _showError('请输入 SN 或蓝牙 MAC 地址');
      return;
    }
    
    final channel = int.tryParse(_channelController.text.trim()) ?? 1;
    
    setState(() => _isConnecting = true);
    
    try {
      String macAddress = address;
      if (!_isMacAddress(address)) {
        macAddress = _snToMacAddress(address);
        _addMessage(_LogMessage(
          type: _MessageType.info,
          content: '从 SN "$address" 转换为 MAC: $macAddress',
        ));
      }
      
      final success = await _rfcommService.connect(macAddress, channel: channel);
      
      if (!success) {
        _showError('连接失败');
      }
    } catch (e) {
      _showError('连接异常: $e');
    } finally {
      setState(() => _isConnecting = false);
    }
  }
  
  /// 断开连接
  Future<void> _disconnect() async {
    await _rfcommService.disconnect();
    setState(() {});
  }
  
  /// 发送原始 HEX 数据
  Future<void> _sendRawHex() async {
    final hexStr = _payloadController.text.trim();
    if (hexStr.isEmpty) {
      _showError('请输入 HEX 数据');
      return;
    }
    
    final data = _parseHexString(hexStr);
    if (data == null) {
      _showError('无效的 HEX 格式');
      return;
    }
    
    setState(() => _isSending = true);
    
    try {
      await _rfcommService.sendRawData(data);
    } catch (e) {
      _showError('发送异常: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }
  
  /// 发送 GTP 命令
  Future<void> _sendGtpCommand() async {
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
    
    final moduleId = _parseIdString(_moduleIdController.text) ?? 0x0006;
    final messageId = _parseIdString(_messageIdController.text) ?? 0xFF01;
    
    setState(() => _isSending = true);
    
    try {
      final response = await _rfcommService.sendCommandAndWaitResponse(
        payload,
        moduleId: moduleId,
        messageId: messageId,
        timeout: const Duration(seconds: 5),
      );
      
      if (response == null) {
        _addMessage(_LogMessage(
          type: _MessageType.error,
          content: '❌ 响应为空',
        ));
      } else if (response.containsKey('error')) {
        _addMessage(_LogMessage(
          type: _MessageType.error,
          content: '❌ 错误: ${response['error']}',
        ));
      } else {
        // 显示响应详情
        if (response.containsKey('rawBytes')) {
          final rawBytes = response['rawBytes'] as Uint8List;
          final rawHex = rawBytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
          _addMessage(_LogMessage(
            type: _MessageType.success,
            content: '✅ 响应 [${rawBytes.length}字节]: $rawHex',
            rawBytes: rawBytes,
          ));
        }
      }
    } catch (e) {
      _showError('发送异常: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SPP 调试 (纯 Dart)'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // 统计信息
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_downward, size: 14, color: Colors.green[300]),
                Text(' ${_rfcommService.totalBytesReceived}B ',
                    style: const TextStyle(fontSize: 11)),
                Icon(Icons.arrow_upward, size: 14, color: Colors.cyan[300]),
                Text(' ${_rfcommService.totalBytesSent}B',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _rfcommService.resetStats();
              setState(() {});
            },
            tooltip: '重置统计',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildConnectionSection(),
          const Divider(height: 1),
          Expanded(child: _buildMessageList()),
          const Divider(height: 1),
          _buildSendSection(),
        ],
      ),
    );
  }
  
  Widget _buildConnectionSection() {
    final isConnected = _rfcommService.isConnected;
    
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Column(
        children: [
          Row(
            children: [
              // 连接状态
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
              if (isConnected) ...[
                const SizedBox(width: 8),
                Text(
                  '${_rfcommService.currentDeviceAddress} (CH${_rfcommService.currentChannel})',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
              const Spacer(),
              // 模式标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.code, size: 14, color: Colors.deepPurple),
                    SizedBox(width: 4),
                    Text('纯 Dart 模式', style: TextStyle(fontSize: 11, color: Colors.deepPurple)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // MAC 地址输入
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    hintText: 'SN 或 MAC 地址 (如: AA:BB:CC:DD:EE:FF)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  enabled: !_isConnecting && !isConnected,
                ),
              ),
              const SizedBox(width: 8),
              // Channel 输入
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _channelController,
                  decoration: InputDecoration(
                    labelText: 'Channel',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  keyboardType: TextInputType.number,
                  enabled: !_isConnecting && !isConnected,
                ),
              ),
              const SizedBox(width: 8),
              // 连接/断开按钮
              if (isConnected)
                ElevatedButton.icon(
                  onPressed: _disconnect,
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
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ],
      ),
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
                  '日志 (${_messages.length})',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 16),
                // 缓冲区状态
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _rfcommService.bufferSize > 0
                        ? Colors.orange.withOpacity(0.3)
                        : Colors.green.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '缓冲区: ${_rfcommService.bufferSize}B',
                    style: TextStyle(
                      color: _rfcommService.bufferSize > 0
                          ? Colors.orange[300]
                          : Colors.green[300],
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 分片计数
                if (_rfcommService.fragmentCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '分片: ${_rfcommService.fragmentCount}',
                      style: TextStyle(color: Colors.blue[300], fontSize: 11),
                    ),
                  ),
                const SizedBox(width: 8),
                // 数据包计数
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'GTP: ${_rfcommService.packetCount}',
                    style: TextStyle(color: Colors.purple[300], fontSize: 11),
                  ),
                ),
                const Spacer(),
                // 显示原始数据开关
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('原始数据', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    Switch(
                      value: _showRawData,
                      onChanged: (value) => setState(() => _showRawData = value),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                // 清空缓冲区
                IconButton(
                  icon: Icon(
                    Icons.memory,
                    color: _rfcommService.bufferSize > 0 ? Colors.orange[300] : Colors.white38,
                    size: 18,
                  ),
                  onPressed: _rfcommService.bufferSize > 0
                      ? () {
                          _rfcommService.clearBuffer();
                          setState(() {});
                        }
                      : null,
                  tooltip: '清空缓冲区',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                // 清空日志
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 20),
                  onPressed: _clearMessages,
                  tooltip: '清空日志',
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
  
  Widget _buildMessageItem(_LogMessage msg) {
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
      case _MessageType.data:
        textColor = Colors.blue[300]!;
        icon = Icons.data_array;
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
      onTap: msg.rawBytes != null
          ? () {
              final hex = msg.rawBytes!
                  .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
                  .join(' ');
              _copyToClipboard(hex);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.timestamp != null)
              Text(
                '${msg.timestamp!.hour.toString().padLeft(2, '0')}:'
                '${msg.timestamp!.minute.toString().padLeft(2, '0')}:'
                '${msg.timestamp!.second.toString().padLeft(2, '0')} ',
                style: TextStyle(color: Colors.grey[600], fontSize: 10, fontFamily: 'monospace'),
              ),
            if (icon != null) ...[
              Icon(icon, color: textColor, size: 12),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: SelectableText(
                msg.content,
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            if (msg.rawBytes != null)
              IconButton(
                icon: Icon(Icons.copy, color: Colors.grey[600], size: 12),
                onPressed: () {
                  final hex = msg.rawBytes!
                      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
                      .join(' ');
                  _copyToClipboard(hex);
                },
                tooltip: '复制 HEX',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSendSection() {
    final isConnected = _rfcommService.isConnected;
    
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
                '直接读写 /dev/rfcomm0，不依赖 Python',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
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
                    hintText: 'HEX 数据 (如: 00 01 02 03)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  enabled: isConnected && !_isSending,
                ),
              ),
              const SizedBox(width: 8),
              // 发送原始 HEX
              ElevatedButton(
                onPressed: (isConnected && !_isSending) ? _sendRawHex : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('发送 RAW'),
              ),
              const SizedBox(width: 8),
              // 发送 GTP 命令
              ElevatedButton.icon(
                onPressed: (isConnected && !_isSending) ? _sendGtpCommand : null,
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
                label: Text(_isSending ? '发送中...' : '发送 GTP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _MessageType {
  send,
  receive,
  data,
  error,
  success,
  info,
}

class _LogMessage {
  final _MessageType type;
  final String content;
  final DateTime? timestamp;
  final Uint8List? rawBytes;

  _LogMessage({
    required this.type,
    required this.content,
    this.timestamp,
    this.rawBytes,
  });
}
