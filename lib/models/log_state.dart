import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
  success,
}

enum LogType {
  all,        // 所有日志
  device,     // 设备日志 (Type 0x02)
  debug,      // 调试信息 (Type 0x03)
  gpib,       // GPIB 测试日志
}

class LogEntry {
  final String message;
  final LogLevel level;
  final DateTime timestamp;
  final LogType type;

  LogEntry({
    required this.message,
    required this.level,
    DateTime? timestamp,
    this.type = LogType.all,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedMessage {
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${(timestamp.millisecond ~/ 10).toString().padLeft(2, '0')}';
    final levelStr = level.name.toUpperCase().padRight(7);
    return '[$time] [$levelStr] $message';
  }
}

class LogState extends ChangeNotifier {
  final List<LogEntry> _logs = [];
  static const int maxLogs = 1000; // 最多保留1000条日志
  bool _showRawHex = false; // 是否显示原始 hex 数据

  List<LogEntry> get logs => _logs;
  bool get showRawHex => _showRawHex;
  
  void setShowRawHex(bool value) {
    _showRawHex = value;
    notifyListeners();
  }
  
  // 根据类型过滤日志
  List<LogEntry> getLogsByType(LogType type) {
    if (type == LogType.all) {
      return _logs;
    }
    return _logs.where((log) => log.type == type).toList();
  }

  void addLog(String message, {LogLevel level = LogLevel.info, LogType type = LogType.all}) {
    final entry = LogEntry(message: message, level: level, type: type);
    _logs.add(entry);
    
    // 限制日志数量
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }
    
    // 同时输出到控制台
    debugPrint(entry.formattedMessage);
    
    notifyListeners();
  }

  void debug(String message, {LogType type = LogType.all}) => addLog(message, level: LogLevel.debug, type: type);
  void info(String message, {LogType type = LogType.all}) => addLog(message, level: LogLevel.info, type: type);
  void warning(String message, {LogType type = LogType.all}) => addLog(message, level: LogLevel.warning, type: type);
  void error(String message, {LogType type = LogType.all}) => addLog(message, level: LogLevel.error, type: type);
  void success(String message, {LogType type = LogType.all}) => addLog(message, level: LogLevel.success, type: type);

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }
}
