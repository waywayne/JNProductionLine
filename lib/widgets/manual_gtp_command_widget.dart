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
  bool _isExpanded = false;
  
  // 固定的 Module ID 和 Message ID
  static const int moduleId = 0x0006;  // 6
  static const int messageId = 0xFF01; // 65281

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
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

    // Send command with fixed module ID and message ID
    final hexDisplay = payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
    context.read<TestState>().runManualTest(
      '手动 GTP 指令',
      payload,
      moduleId: moduleId,
      messageId: messageId,
    );
    
    context.read<LogState>().info('发送手动指令 (Module: 0x${moduleId.toRadixString(16).padLeft(4, "0").toUpperCase()}, Message: 0x${messageId.toRadixString(16).padLeft(4, "0").toUpperCase()}): $hexDisplay', type: LogType.debug);
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
                  // Fixed Module ID and Message ID display
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text(
                          'Module ID: 0x${moduleId.toRadixString(16).padLeft(4, "0").toUpperCase()} ($moduleId)  |  Message ID: 0x${messageId.toRadixString(16).padLeft(4, "0").toUpperCase()} ($messageId)',
                          style: const TextStyle(fontSize: 9, color: Colors.blue),
                        ),
                      ],
                    ),
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
                    '提示: 输入 Payload 的 Hex 数据，将使用固定的 Module ID 和 Message ID 自动封装为 GTP 协议包发送',
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
