/// Touch测试步骤状态枚举
enum TouchStepStatus {
  waiting,    // 等待开始
  testing,    // 正在测试
  userAction, // 等待用户操作
  success,    // 成功
  failed,     // 失败
  timeout,    // 超时
  skipped,    // 跳过
}

/// Touch测试步骤类
class TouchTestStep {
  final int touchId;        // Touch ID (0x00=左, 0x01=右)
  final int actionId;       // 动作ID
  final String name;        // 步骤名称
  final String description; // 步骤描述
  final String userPrompt;  // 用户提示信息
  final TouchStepStatus status;
  final String? errorMessage;
  final int? cdcValue;      // CDC值
  final int currentRetry;
  final int maxRetries;
  final bool isSkipped;     // 是否跳过
  final int? cdcDiff;       // CDC差值

  const TouchTestStep({
    required this.touchId,
    required this.actionId,
    required this.name,
    required this.description,
    required this.userPrompt,
    this.status = TouchStepStatus.waiting,
    this.errorMessage,
    this.cdcValue,
    this.currentRetry = 0,
    this.maxRetries = 10,
    this.isSkipped = false,
    this.cdcDiff,
  });

  TouchTestStep copyWith({
    int? touchId,
    int? actionId,
    String? name,
    String? description,
    String? userPrompt,
    TouchStepStatus? status,
    String? errorMessage,
    int? cdcValue,
    int? currentRetry,
    int? maxRetries,
    bool? isSkipped,
    int? cdcDiff,
  }) {
    return TouchTestStep(
      touchId: touchId ?? this.touchId,
      actionId: actionId ?? this.actionId,
      name: name ?? this.name,
      description: description ?? this.description,
      userPrompt: userPrompt ?? this.userPrompt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      cdcValue: cdcValue ?? this.cdcValue,
      currentRetry: currentRetry ?? this.currentRetry,
      maxRetries: maxRetries ?? this.maxRetries,
      isSkipped: isSkipped ?? this.isSkipped,
      cdcDiff: cdcDiff ?? this.cdcDiff,
    );
  }
}

/// Touch测试配置
class TouchTestConfig {
  // Touch ID
  static const int touchLeft = 0x00;   // 左Touch
  static const int touchRight = 0x01;  // 右Touch
  
  // CDC阈值配置
  static const int cdcThreshold = 500; // CDC差值阈值

  // 左Touch动作ID (ActionID)
  static const int leftActionUntouched = 0x00;  // 未触摸
  static const int leftActionSingleTap = 0x01;  // 单击
  static const int leftActionDoubleTap = 0x02;  // 双击
  static const int leftActionLongPress = 0x03;  // 长按
  static const int leftActionWearDetect = 0x04; // 佩戴检测

  // 右Touch区域ID (AreaID)
  static const int rightAreaUntouched = 0x00;  // 未触摸
  static const int rightAreaTK1 = 0x01;        // TK1
  static const int rightAreaTK2 = 0x02;        // TK2
  static const int rightAreaTK3 = 0x03;        // TK3

  /// 获取左Touch动作名称
  static String getLeftActionName(int actionId) {
    switch (actionId) {
      case leftActionUntouched:
        return '未触摸';
      case leftActionSingleTap:
        return '单击';
      case leftActionDoubleTap:
        return '双击';
      case leftActionLongPress:
        return '长按';
      case leftActionWearDetect:
        return '佩戴检测';
      default:
        return '未知动作';
    }
  }

  /// 获取右Touch区域名称
  static String getRightAreaName(int areaId) {
    switch (areaId) {
      case rightAreaUntouched:
        return '未触摸';
      case rightAreaTK1:
        return 'TK1';
      case rightAreaTK2:
        return 'TK2';
      case rightAreaTK3:
        return 'TK3';
      default:
        return '未知区域';
    }
  }

  /// 获取左Touch用户提示
  static String getLeftActionPrompt(int actionId) {
    switch (actionId) {
      case leftActionUntouched:
        return '请不要触摸左侧Touch区域';
      case leftActionSingleTap:
        return '请单击左侧Touch区域';
      case leftActionDoubleTap:
        return '请快速双击左侧Touch区域';
      case leftActionLongPress:
        return '请长按左侧Touch区域（保持3秒）';
      case leftActionWearDetect:
        return '请将设备佩戴到耳朵上进行佩戴检测';
      default:
        return '请按照指示操作左侧Touch区域';
    }
  }

  /// 获取右Touch用户提示
  static String getRightAreaPrompt(int areaId) {
    switch (areaId) {
      case rightAreaUntouched:
        return '请不要触摸右侧Touch区域';
      case rightAreaTK1:
        return '请触摸右侧TK1区域';
      case rightAreaTK2:
        return '请触摸右侧TK2区域';
      case rightAreaTK3:
        return '请触摸右侧TK3区域';
      default:
        return '请按照指示操作右侧Touch区域';
    }
  }
}
