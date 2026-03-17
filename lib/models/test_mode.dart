/// Test mode enumeration
/// 测试模式枚举
enum TestMode {
  /// Single board testing (via serial port)
  /// 单板产测（通过串口）
  singleBoard,
  
  /// Pre-ultrasound complete device testing (via SPP Bluetooth)
  /// 超声前整机产测（通过SPP蓝牙）
  preUltrasoundComplete,
  
  /// Transition complete device testing (via SPP Bluetooth)
  /// 过渡整机产测（通过SPP蓝牙）
  transitionComplete,
  
  /// Formal complete device testing (via SPP Bluetooth)
  /// 正式整机产测（通过SPP蓝牙）
  formalComplete,
}

/// Extension methods for TestMode
extension TestModeExtension on TestMode {
  /// Get display name in Chinese
  String get displayName {
    switch (this) {
      case TestMode.singleBoard:
        return '单板产测';
      case TestMode.preUltrasoundComplete:
        return '超声前整机产测';
      case TestMode.transitionComplete:
        return '过渡整机产测';
      case TestMode.formalComplete:
        return '正式整机产测';
    }
  }
  
  /// Get description
  String get description {
    switch (this) {
      case TestMode.singleBoard:
        return '通过串口连接进行单板测试';
      case TestMode.preUltrasoundComplete:
        return '超声前整机产测（通过SPP蓝牙）';
      case TestMode.transitionComplete:
        return '过渡整机产测（通过SPP蓝牙）';
      case TestMode.formalComplete:
        return '正式整机产测（通过SPP蓝牙）';
    }
  }
  
  /// Get icon name
  String get iconName {
    switch (this) {
      case TestMode.singleBoard:
        return 'developer_board';
      case TestMode.preUltrasoundComplete:
        return 'devices_other';
      case TestMode.transitionComplete:
        return 'sync_alt';
      case TestMode.formalComplete:
        return 'verified';
    }
  }
  
  /// Check if uses serial port
  bool get usesSerialPort {
    return this == TestMode.singleBoard;
  }
  
  /// Check if uses SPP Bluetooth
  bool get usesSppBluetooth {
    return this == TestMode.preUltrasoundComplete ||
           this == TestMode.transitionComplete ||
           this == TestMode.formalComplete;
  }
  
  /// Check if is complete device mode
  bool get isCompleteDeviceMode {
    return usesSppBluetooth;
  }
}
