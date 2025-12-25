/// 自动化测试配置
class AutomationTestConfig {
  // GPIB配置
  static String gpibAddress = '';
  
  // 测试跳过开关
  static bool skipGpibTests = false;             // 跳过GPIB相关测试
  static bool skipLeakageCurrentTest = false;    // 跳过漏电流测试
  static bool skipPowerOnTest = false;           // 跳过上电测试
  static bool skipWorkingCurrentTest = false;    // 跳过工作电流测试
  
  // 电源参数配置
  static const double defaultVoltage = 5.0;      // 默认电压 5V
  static const double currentLimit = 1.0;        // 电流限制 1A
  static const double currentRange = 1.0;        // 电流范围 1A
  
  // 采样配置
  static const int sampleCount = 20;             // 采样次数 20次
  static const double sampleRate = 10.0;        // 采样率 10Hz
  
  // 测试阈值
  static const double leakageCurrentThreshold = 500e-6;  // 漏电流阈值 < 500uA
  static const double workingCurrentThreshold = 380e-3;  // 工作电流阈值 < 380mA
  static const double batteryVoltageThreshold = 2.5;     // 电池电压阈值 > 2.5V
  static const double batteryCapacityMin = 0.0;          // 电量范围 0-100%
  static const double batteryCapacityMax = 100.0;
}

/// 自动化测试步骤状态
enum AutoTestStepStatus {
  waiting,     // 等待执行
  running,     // 正在执行
  success,     // 执行成功
  failed,      // 执行失败
  skipped,     // 跳过
}

/// 自动化测试步骤类型
enum AutoTestStepType {
  automatic,    // 自动测试
  semiAuto,     // 半自动测试
}

/// 自动化测试步骤
class AutoTestStep {
  final String id;
  final String name;
  final String description;
  final String expectedResult;
  final AutoTestStepType type;
  final AutoTestStepStatus status;
  final String? errorMessage;
  final Map<String, dynamic>? testData;
  final DateTime? startTime;
  final DateTime? endTime;
  
  const AutoTestStep({
    required this.id,
    required this.name,
    required this.description,
    required this.expectedResult,
    required this.type,
    this.status = AutoTestStepStatus.waiting,
    this.errorMessage,
    this.testData,
    this.startTime,
    this.endTime,
  });
  
  AutoTestStep copyWith({
    String? id,
    String? name,
    String? description,
    String? expectedResult,
    AutoTestStepType? type,
    AutoTestStepStatus? status,
    String? errorMessage,
    Map<String, dynamic>? testData,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return AutoTestStep(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      expectedResult: expectedResult ?? this.expectedResult,
      type: type ?? this.type,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      testData: testData ?? this.testData,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
  
  Duration? get duration {
    if (startTime != null && endTime != null) {
      return endTime!.difference(startTime!);
    }
    return null;
  }
}

/// 自动化测试步骤定义
class AutoTestSteps {
  static List<AutoTestStep> getTestSteps() {
    return [
      // 自动测试项
      const AutoTestStep(
        id: 'leakage_current',
        name: '漏电流测试',
        description: '测试设备漏电流',
        expectedResult: '静态电流值 < 500uA',
        type: AutoTestStepType.automatic,
      ),
      const AutoTestStep(
        id: 'power_on',
        name: '上电测试',
        description: '设备上电测试',
        expectedResult: '物音/SIGM/WIFI正常工作状态',
        type: AutoTestStepType.automatic,
      ),
      const AutoTestStep(
        id: 'working_current',
        name: '工作功耗测试',
        description: '测试设备工作电流',
        expectedResult: '静态电流值 < 380mA',
        type: AutoTestStepType.automatic,
      ),
      const AutoTestStep(
        id: 'battery_voltage',
        name: '设备电压测试',
        description: '测试设备电池电压',
        expectedResult: '获取硬件检测电池电压值 > 2.5V',
        type: AutoTestStepType.automatic,
      ),
      const AutoTestStep(
        id: 'battery_capacity',
        name: '电量检测测试',
        description: '测试电池电量',
        expectedResult: '电量值在0~100范围内',
        type: AutoTestStepType.automatic,
      ),
      const AutoTestStep(
        id: 'charging_status',
        name: '充电状态测试',
        description: '测试充电状态',
        expectedResult: '获取充电状态为充电',
        type: AutoTestStepType.automatic,
      ),
      const AutoTestStep(
        id: 'wifi_test',
        name: 'WIFI测试',
        description: 'WIFI连接测试',
        expectedResult: 'WIFI连接、MAC地址确认',
        type: AutoTestStepType.automatic,
      ),
      const AutoTestStep(
        id: 'rtc_set',
        name: 'RTC设置时间测试',
        description: 'RTC时间设置测试',
        expectedResult: '设置RTC成功',
        type: AutoTestStepType.automatic,
      ),
      const AutoTestStep(
        id: 'rtc_get',
        name: 'RTC获取时间测试',
        description: 'RTC时间获取测试',
        expectedResult: 'RTC获取时间成功',
        type: AutoTestStepType.automatic,
      ),
      const AutoTestStep(
        id: 'light_sensor',
        name: '光敏传感器测试',
        description: '光敏传感器测试',
        expectedResult: '获取到光敏值测试OK',
        type: AutoTestStepType.automatic,
      ),
      const AutoTestStep(
        id: 'imu_sensor',
        name: 'IMU传感器测试',
        description: 'IMU传感器测试',
        expectedResult: '获取到IMU值测试OK',
        type: AutoTestStepType.automatic,
      ),
      
      // 半自动测试项
      const AutoTestStep(
        id: 'right_touch_tk1',
        name: '右触控-TK1测试',
        description: '右触控TK1区域测试',
        expectedResult: '手按TK1，阈值变化量超过500，测试OK',
        type: AutoTestStepType.semiAuto,
      ),
      const AutoTestStep(
        id: 'right_touch_tk2',
        name: '右触控-TK2测试',
        description: '右触控TK2区域测试',
        expectedResult: '手按TK2，阈值变化量超过500，测试OK',
        type: AutoTestStepType.semiAuto,
      ),
      const AutoTestStep(
        id: 'right_touch_tk3',
        name: '右触控-TK3测试',
        description: '右触控TK3区域测试',
        expectedResult: '手按TK3，阈值变化量超过500，测试OK',
        type: AutoTestStepType.semiAuto,
      ),
      const AutoTestStep(
        id: 'left_touch_single',
        name: '左触控-单击测试',
        description: '左触控单击功能测试',
        expectedResult: '靠近佩戴区域，返回佩戴检测值，测试OK',
        type: AutoTestStepType.semiAuto,
      ),
      const AutoTestStep(
        id: 'left_touch_double',
        name: '左触控-双击测试',
        description: '左触控双击功能测试',
        expectedResult: '点击左侧触控，返回点击检测值，测试OK',
        type: AutoTestStepType.semiAuto,
      ),
      // const AutoTestStep(
      //   id: 'left_touch_long',
      //   name: '左触控-长按测试',
      //   description: '左触控长按功能测试',
      //   expectedResult: '双击左侧触控，返回双击检测值，测试OK',
      //   type: AutoTestStepType.semiAuto,
      // ),
      const AutoTestStep(
        id: 'left_touch_wear',
        name: '左触控-佩戴测试',
        description: '左触控佩戴检测测试',
        expectedResult: '长按左侧触控，返回长按检测值，测试OK',
        type: AutoTestStepType.semiAuto,
      ),
    ];
  }
}
