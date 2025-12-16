import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../models/test_state.dart';
import '../models/log_state.dart';

/// Widget for manually inputting and sending GTP hex commands
class ManualGtpCommandWidget extends StatefulWidget {
  const ManualGtpCommandWidget({super.key});

  @override
  State<ManualGtpCommandWidget> createState() => _ManualGtpCommandWidgetState();
}

class _ManualGtpCommandWidgetState extends State<ManualGtpCommandWidget> {
  final TextEditingController _hexController = TextEditingController();
  final TextEditingController _moduleIdController = TextEditingController(text: '0x0006');
  final TextEditingController _messageIdController = TextEditingController(text: '0xFF01');
  bool _isExpanded = false;
  
  // 默认的 Module ID 和 Message ID
  static const int defaultModuleId = 0x0006;  // 6
  static const int defaultMessageId = 0xFF01; // 65281

  @override
  void dispose() {
    _hexController.dispose();
    _moduleIdController.dispose();
    _messageIdController.dispose();
    super.dispose();
  }

  /// Parse hex or decimal string to int
  int? _parseIdString(String idString) {
    try {
      String cleaned = idString.trim();
      if (cleaned.isEmpty) return null;
      
      // 支持 0x 前缀的十六进制
      if (cleaned.toLowerCase().startsWith('0x')) {
        return int.parse(cleaned.substring(2), radix: 16);
      }
      
      // 尝试解析为十进制
      return int.parse(cleaned);
    } catch (e) {
      return null;
    }
  }

  /// Parse hex string to Uint8List
  Uint8List? _parseHexString(String hexString) {
    try {
      // Remove spaces, commas, and 0x prefixes
      String cleaned = hexString
          .replaceAll(RegExp(r'[\s,]'), '')
          .replaceAll('0x', '')
          .replaceAll('0X', '');
      
      if (cleaned.isEmpty) return null;
      if (cleaned.length % 2 != 0) {
        // Pad with leading zero if odd length
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

  void _sendCommand() {
    final hexString = _hexController.text.trim();
    if (hexString.isEmpty) {
      context.read<LogState>().error('请输入 Hex 指令', type: LogType.debug);
      return;
    }

    final payload = _parseHexString(hexString);
    if (payload == null) {
      context.read<LogState>().error('无效的 Hex 格式', type: LogType.debug);
      return;
    }

    // Parse Module ID and Message ID
    final moduleId = _parseIdString(_moduleIdController.text) ?? defaultModuleId;
    final messageId = _parseIdString(_messageIdController.text) ?? defaultMessageId;

    // Send command with user-specified module ID and message ID
    final hexDisplay = payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    context.read<TestState>().runManualTest(
      '手动 GTP 指令',
      payload,
      moduleId: moduleId,
      messageId: messageId,
    );
    
    context.read<LogState>().info('发送手动指令 (Module: 0x${moduleId.toRadixString(16).padLeft(4, "0").toUpperCase()} ($moduleId), Message: 0x${messageId.toRadixString(16).padLeft(4, "0").toUpperCase()} ($messageId)): $hexDisplay', type: LogType.debug);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
        color: Colors.grey[50],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '手动 GTP 指令',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          // Content
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Module ID and Message ID input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _moduleIdController,
                          decoration: const InputDecoration(
                            labelText: 'Module ID',
                            labelStyle: TextStyle(fontSize: 10),
                            hintText: '0x0006 或 6',
                            hintStyle: TextStyle(fontSize: 9),
                            contentPadding: EdgeInsets.all(8),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 10, fontFamily: 'Courier'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _messageIdController,
                          decoration: const InputDecoration(
                            labelText: 'Message ID',
                            labelStyle: TextStyle(fontSize: 10),
                            hintText: '0xFF01 或 65281',
                            hintStyle: TextStyle(fontSize: 9),
                            contentPadding: EdgeInsets.all(8),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 10, fontFamily: 'Courier'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Hex input
                  TextField(
                    controller: _hexController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Hex 指令 (Payload)',
                      labelStyle: TextStyle(fontSize: 10),
                      hintText: '例: 00 或 01 02 03 或 0x01 0x02',
                      hintStyle: TextStyle(fontSize: 9),
                      contentPadding: EdgeInsets.all(8),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 10, fontFamily: 'Courier'),
                  ),
                  const SizedBox(height: 8),
                  // Send button
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: ElevatedButton(
                      onPressed: _sendCommand,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        '发送指令',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Help text
                  Text(
                    '提示: 输入 Payload 的 Hex 数据和对应的 Module ID、Message ID，将自动封装为 GTP 协议包发送。ID 支持十六进制(0x前缀)或十进制格式。',
                    style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
