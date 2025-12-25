import 'package:flutter/material.dart';

/// 测试报告项
class TestReportItem {
  final String testName;
  final String testType;
  final TestReportStatus status;
  final String? errorMessage;
  final DateTime startTime;
  final DateTime? endTime;
  final Map<String, dynamic>? testData;
  
  TestReportItem({
    required this.testName,
    required this.testType,
    required this.status,
    this.errorMessage,
    required this.startTime,
    this.endTime,
    this.testData,
  });
  
  Duration? get duration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return null;
  }
  
  String get statusText {
    switch (status) {
      case TestReportStatus.pass:
        return '通过';
      case TestReportStatus.fail:
        return '失败';
      case TestReportStatus.skip:
        return '跳过';
      case TestReportStatus.running:
        return '进行中';
      case TestReportStatus.waiting:
        return '等待中';
    }
  }
  
  Color get statusColor {
    switch (status) {
      case TestReportStatus.pass:
        return Colors.green;
      case TestReportStatus.fail:
        return Colors.red;
      case TestReportStatus.skip:
        return Colors.grey;
      case TestReportStatus.running:
        return Colors.blue;
      case TestReportStatus.waiting:
        return Colors.orange;
    }
  }
  
  IconData get statusIcon {
    switch (status) {
      case TestReportStatus.pass:
        return Icons.check_circle;
      case TestReportStatus.fail:
        return Icons.error;
      case TestReportStatus.skip:
        return Icons.remove_circle;
      case TestReportStatus.running:
        return Icons.sync;
      case TestReportStatus.waiting:
        return Icons.hourglass_empty;
    }
  }
  
  TestReportItem copyWith({
    String? testName,
    String? testType,
    TestReportStatus? status,
    String? errorMessage,
    DateTime? startTime,
    DateTime? endTime,
    Map<String, dynamic>? testData,
  }) {
    return TestReportItem(
      testName: testName ?? this.testName,
      testType: testType ?? this.testType,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      testData: testData ?? this.testData,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'testName': testName,
      'testType': testType,
      'status': status.toString(),
      'errorMessage': errorMessage,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': duration?.inMilliseconds,
      'testData': testData,
    };
  }
}

/// 测试报告状态
enum TestReportStatus {
  waiting,
  running,
  pass,
  fail,
  skip,
}

/// 完整测试报告
class TestReport {
  final String deviceSN;
  final String? deviceMAC;
  final DateTime startTime;
  final DateTime? endTime;
  final List<TestReportItem> items;
  final String? notes;
  
  TestReport({
    required this.deviceSN,
    this.deviceMAC,
    required this.startTime,
    this.endTime,
    required this.items,
    this.notes,
  });
  
  Duration? get totalDuration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    return null;
  }
  
  int get totalTests => items.length;
  
  int get passedTests => items.where((item) => item.status == TestReportStatus.pass).length;
  
  int get failedTests => items.where((item) => item.status == TestReportStatus.fail).length;
  
  int get skippedTests => items.where((item) => item.status == TestReportStatus.skip).length;
  
  double get passRate {
    if (totalTests == 0) return 0.0;
    return (passedTests / totalTests) * 100;
  }
  
  bool get allTestsPassed => failedTests == 0 && totalTests > 0;
  
  String get summaryText {
    return '总计: $totalTests | 通过: $passedTests | 失败: $failedTests | 跳过: $skippedTests | 通过率: ${passRate.toStringAsFixed(1)}%';
  }
  
  Map<String, dynamic> toJson() {
    return {
      'deviceSN': deviceSN,
      'deviceMAC': deviceMAC,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'totalDuration': totalDuration?.inMilliseconds,
      'totalTests': totalTests,
      'passedTests': passedTests,
      'failedTests': failedTests,
      'skippedTests': skippedTests,
      'passRate': passRate,
      'allTestsPassed': allTestsPassed,
      'items': items.map((item) => item.toJson()).toList(),
      'notes': notes,
    };
  }
  
  String toFormattedString() {
    final buffer = StringBuffer();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('           测试报告');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('设备SN: $deviceSN');
    if (deviceMAC != null) {
      buffer.writeln('设备MAC: $deviceMAC');
    }
    buffer.writeln('开始时间: ${_formatDateTime(startTime)}');
    if (endTime != null) {
      buffer.writeln('结束时间: ${_formatDateTime(endTime!)}');
      buffer.writeln('总耗时: ${_formatDuration(totalDuration!)}');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln(summaryText);
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('测试详情:');
    buffer.writeln('');
    
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      buffer.writeln('${i + 1}. ${item.testName} (${item.testType})');
      buffer.writeln('   状态: ${item.statusText}');
      if (item.duration != null) {
        buffer.writeln('   耗时: ${_formatDuration(item.duration!)}');
      }
      if (item.errorMessage != null) {
        buffer.writeln('   错误: ${item.errorMessage}');
      }
      buffer.writeln('');
    }
    
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    if (notes != null) {
      buffer.writeln('备注: $notes');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
    
    return buffer.toString();
  }
  
  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final milliseconds = duration.inMilliseconds % 1000;
    
    if (minutes > 0) {
      return '${minutes}分${seconds}秒';
    } else if (seconds > 0) {
      return '${seconds}.${(milliseconds / 100).floor()}秒';
    } else {
      return '${milliseconds}毫秒';
    }
  }
}
