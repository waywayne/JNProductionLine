import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/log_state.dart';
import 'manual_gtp_command_widget.dart';

/// Log console section widget
class LogConsoleSection extends StatefulWidget {
  const LogConsoleSection({super.key});

  @override
  State<LogConsoleSection> createState() => _LogConsoleSectionState();
}

class _LogConsoleSectionState extends State<LogConsoleSection> {
  final ScrollController _deviceLogScrollController = ScrollController();
  final ScrollController _debugLogScrollController = ScrollController();
  final TextEditingController _deviceFilterController = TextEditingController();
  final TextEditingController _debugFilterController = TextEditingController();
  bool _deviceLogAutoScroll = true;
  bool _debugLogAutoScroll = true;
  String _deviceFilterPattern = '';
  String _debugFilterPattern = '';
  
  @override
  void initState() {
    super.initState();
    _deviceFilterController.addListener(() {
      setState(() {
        _deviceFilterPattern = _deviceFilterController.text;
      });
    });
    _debugFilterController.addListener(() {
      setState(() {
        _debugFilterPattern = _debugFilterController.text;
      });
    });
  }

  @override
  void dispose() {
    _deviceLogScrollController.dispose();
    _debugLogScrollController.dispose();
    _deviceFilterController.dispose();
    _debugFilterController.dispose();
    super.dispose();
  }

  void _scrollToBottom(ScrollController controller, bool autoScroll) {
    if (autoScroll && controller.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.hasClients) {
          controller.animateTo(
            controller.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with controls
        Row(
          children: [
            // Raw Hex checkbox
            Consumer<LogState>(
              builder: (context, logState, _) => Row(
                children: [
                  Checkbox(
                    value: logState.showRawHex,
                    onChanged: (value) => logState.setShowRawHex(value ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const Text(
                    '显示原始Hex',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Export button
            SizedBox(
              height: 28,
              child: ElevatedButton(
                onPressed: _exportLogs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[400],
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Export',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Copy button
            SizedBox(
              height: 28,
              child: ElevatedButton(
                onPressed: () {
                  _copyLogsToClipboard(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[400],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Copy',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Clear button
            SizedBox(
              height: 28,
              child: ElevatedButton(
                onPressed: () {
                  context.read<LogState>().clearLogs();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[400],
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Clear',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Manual GTP command input
        const ManualGtpCommandWidget(),
        const SizedBox(height: 8),
        // Split view for logs
        Expanded(
          child: Row(
            children: [
              // Left: 设备日志 (Type 0x02)
              Expanded(
                child: _buildLogView(
                  '设备日志',
                  LogType.device,
                  _deviceLogScrollController,
                  _deviceFilterController,
                  _deviceFilterPattern,
                  _deviceLogAutoScroll,
                  (value) => setState(() => _deviceLogAutoScroll = value),
                ),
              ),
              const SizedBox(width: 8),
              // Right: 调试信息 (Type 0x03)
              Expanded(
                child: _buildLogView(
                  '调试信息',
                  LogType.debug,
                  _debugLogScrollController,
                  _debugFilterController,
                  _debugFilterPattern,
                  _debugLogAutoScroll,
                  (value) => setState(() => _debugLogAutoScroll = value),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogView(
    String title,
    LogType logType,
    ScrollController scrollController,
    TextEditingController filterController,
    String filterPattern,
    bool autoScroll,
    ValueChanged<bool> onAutoScrollChanged,
  ) {
    return Column(
      children: [
        // Title and controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Checkbox(
                    value: autoScroll,
                    onChanged: (value) => onAutoScrollChanged(value ?? true),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const Text(
                    '自动滚动',
                    style: TextStyle(fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Filter input
              TextField(
                controller: filterController,
                decoration: InputDecoration(
                  hintText: '过滤 (支持正则表达式)',
                  hintStyle: const TextStyle(fontSize: 10),
                  prefixIcon: const Icon(Icons.filter_alt, size: 16),
                  suffixIcon: filterController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => filterController.clear(),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        // Log display
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: Consumer<LogState>(
              builder: (context, logState, _) {
                var filteredLogs = logState.getLogsByType(logType);
                
                // Apply regex filter
                if (filterPattern.isNotEmpty) {
                  try {
                    final regex = RegExp(filterPattern, caseSensitive: false);
                    filteredLogs = filteredLogs.where((log) => regex.hasMatch(log.formattedMessage)).toList();
                  } catch (e) {
                    // Invalid regex, show all logs
                  }
                }
                
                // Auto-scroll when new logs arrive
                _scrollToBottom(scrollController, autoScroll);

                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = filteredLogs[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: SelectableText(
                        log.formattedMessage,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Courier',
                          color: _getLogColor(log.level),
                          height: 1.3,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportLogs() async {
    try {
      final logState = context.read<LogState>();
      
      // 导出所有日志
      final logs = logState.logs;
      
      if (logs.isEmpty) {
        _showMessage('没有日志可导出');
        return;
      }
      
      // 选择保存路径
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final defaultName = 'logs_all_$timestamp.txt';
      
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出日志',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: ['txt', 'log'],
      );
      
      if (result == null) {
        return; // 用户取消
      }
      
      // 生成日志内容
      final buffer = StringBuffer();
      buffer.writeln('========================================');
      buffer.writeln('JN Production Line - Log Export');
      buffer.writeln('Export Time: ${DateTime.now()}');
      buffer.writeln('Total Logs: ${logs.length}');
      buffer.writeln('========================================');
      buffer.writeln();
      
      for (final log in logs) {
        buffer.writeln(log.formattedMessage);
      }
      
      // 写入文件
      final file = File(result);
      await file.writeAsString(buffer.toString());
      
      _showMessage('日志已导出到: $result');
    } catch (e) {
      _showMessage('导出失败: $e');
    }
  }
  
  Future<void> _copyLogsToClipboard(BuildContext context) async {
    try {
      final logState = context.read<LogState>();
      
      // 获取所有日志
      final logs = logState.logs;
      
      if (logs.isEmpty) {
        _showMessage('没有日志可复制');
        return;
      }
      
      // 生成日志内容
      final buffer = StringBuffer();
      buffer.writeln('========================================');
      buffer.writeln('JN Production Line - Log Copy');
      buffer.writeln('Copy Time: ${DateTime.now()}');
      buffer.writeln('Total Logs: ${logs.length}');
      buffer.writeln('========================================');
      buffer.writeln();
      
      for (final log in logs) {
        buffer.writeln(log.formattedMessage);
      }
      
      // 复制到剪贴板
      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      
      _showMessage('已复制 ${logs.length} 条日志到剪贴板');
    } catch (e) {
      _showMessage('复制失败: $e');
    }
  }
  
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return Colors.red[300]!;
      case LogLevel.warning:
        return Colors.orange[300]!;
      case LogLevel.info:
        return Colors.blue[300]!;
      case LogLevel.success:
        return Colors.green[300]!;
      case LogLevel.debug:
        return Colors.grey[400]!;
      default:
        return Colors.white;
    }
  }
}
