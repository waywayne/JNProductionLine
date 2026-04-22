/// Test mode enumeration
/// 测试模式枚举
enum TestMode {
  /// Single board testing (via serial port)
  /// 单板产测（通过串口）
  singleBoard,
  
  /// Complete device testing (via SPP Bluetooth)
  /// 整机产测（通过SPP蓝牙）
  completeDevice,
}

/// Extension methods for TestMode
extension TestModeExtension on TestMode {
  /// Get display name in Chinese
  String get displayName {
    switch (this) {
      case TestMode.singleBoard:
        return '单板产测';
      case TestMode.completeDevice:
        return '整机产测';
    }
  }
  
  /// Get description
  String get description {
    switch (this) {
      case TestMode.singleBoard:
        return '通过串口连接进行单板测试';
      case TestMode.completeDevice:
        return '整机产测（通过SPP蓝牙）';
    }
  }
  
  /// Get icon name
  String get iconName {
    switch (this) {
      case TestMode.singleBoard:
        return 'developer_board';
      case TestMode.completeDevice:
        return 'devices_other';
    }
  }
  
  /// Check if uses serial port
  bool get usesSerialPort {
    return this == TestMode.singleBoard;
  }
  
  /// Check if uses SPP Bluetooth
  bool get usesSppBluetooth {
    return this == TestMode.completeDevice;
  }
  
  /// Check if is complete device mode
  bool get isCompleteDeviceMode {
    return usesSppBluetooth;
  }

  /// Get workstation count for this mode
  int get workstationCount {
    switch (this) {
      case TestMode.singleBoard:
        return 0;
      case TestMode.completeDevice:
        return 6; // 6 workstations for complete device testing
    }
  }
}
