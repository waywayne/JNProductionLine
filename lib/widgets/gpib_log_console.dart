import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/log_state.dart';

/// GPIB 专用日志控制台
class GpibLogConsole extends StatefulWidget {
  const GpibLogConsole({super.key});

  @override
  State<GpibLogConsole> createState() => _GpibLogConsoleState();
}

class _GpibLogConsoleState extends State<GpibLogConsole> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.success:
        return Colors.green;
    }
  }

  IconData _getLogIcon(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Icons.bug_report;
      case LogLevel.info:
        return Icons.info_outline;
      case LogLevel.warning:
        return Icons.warning_amber;
      case LogLevel.error:
        return Icons.error_outline;
      case LogLevel.success:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LogState>(
      builder: (context, logState, child) {
        // 获取 GPIB 类型的日志
        final gpibLogs = logState.getLogsByType(LogType.gpib);
        
        // 自动滚动到底部
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.blue.shade200),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.cable, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'GPIB 测试日志',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${gpibLogs.length} 条',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 自动滚动开关
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_downward,
                        size: 16,
                        color: _autoScroll ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Switch(
                        value: _autoScroll,
                        onChanged: (value) {
                          setState(() {
                            _autoScroll = value;
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // 清空日志按钮
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '清空日志',
                    onPressed: () {
                      logState.clearLogs();
                    },
                  ),
                ],
              ),
            ),
            
            // 日志内容
            Expanded(
              child: Container(
                color: Colors.grey.shade50,
                child: gpibLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cable,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无 GPIB 日志',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '连接 GPIB 设备后，日志将显示在这里',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: gpibLogs.length,
                        itemBuilder: (context, index) {
                          final log = gpibLogs[index];
                          final color = _getLogColor(log.level);
                          final icon = _getLogIcon(log.level);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                left: BorderSide(
                                  color: color,
                                  width: 3,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  icon,
                                  size: 16,
                                  color: color,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        log.message,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontFamily: 'monospace',
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${log.timestamp.hour.toString().padLeft(2, '0')}:'
                                        '${log.timestamp.minute.toString().padLeft(2, '0')}:'
                                        '${log.timestamp.second.toString().padLeft(2, '0')}.'
                                        '${log.timestamp.millisecond.toString().padLeft(3, '0')}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
