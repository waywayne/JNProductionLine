import 'dart:typed_data';

/// Production test commands based on the specification
/// 产测业务指令集
class ProductionTestCommands {
  // Module ID and Message ID for exit sleep mode
  static const int exitSleepModuleId = 0x0005; // 退出休眠模块ID: 5
  static const int exitSleepMessageId = 0x0004; // 退出休眠消息ID: 4
  
  // Module ID and Message ID for production test
  static const int moduleId = 0x0006; // 模块ID: 6
  static const int messageId = 0xFF01; // 消息ID: 0xFF01
  
  // Command codes
  static const int cmdStartTest = 0x00; // 产测开始
  static const int cmdGetVoltage = 0x01; // 获取设备电压
  static const int cmdGetCurrent = 0x02; // 获取设备电量
  static const int cmdGetChargeStatus = 0x03; // 获取设备充电状态
  static const int cmdControlWifi = 0x04; // 控制设备连接wifi
  static const int cmdControlLED = 0x05; // 控制设备LED灯
  static const int cmdControlSPK = 0x06; // 控制设备SPK放音
  static const int cmdTouch = 0x07; // Touch测试
  static const int cmdControlMIC = 0x08; // 控制MIC录音
  static const int cmdRTC = 0x09; // RTC测试
  static const int cmdLightSensor = 0x0A; // 光敏传感器
  static const int cmdIMU = 0x0B; // IMU测试
  static const int cmdSensor = 0x0C; // Sensor测试
  static const int cmdBluetooth = 0x0D; // 蓝牙测试
  static const int cmdEndTest = 0xFF; // 产测结束
  
  // LED control values
  static const int ledOuter = 0x00; // LED0(外侧)
  static const int ledInner = 0x01; // LED1(内侧)
  
  // LED state values
  static const int ledOn = 0x00; // LED开启
  static const int ledOff = 0x01; // LED关闭
  
  // SPK control values
  static const int spk0 = 0x00; // SPK0
  static const int spk1 = 0x01; // SPK1
  
  // Touch control values
  static const int touchLeft = 0x00; // 左touch
  static const int touchRight = 0x01; // 右touch
  
  // Touch operations
  static const int touchOptGetCDC = 0x00; // 获取CDC值
  static const int touchOptSetThreshold = 0x01; // 设置阈值
  
  // MIC control values
  static const int mic0 = 0x00; // MIC0
  static const int mic1 = 0x01; // MIC1
  static const int mic2 = 0x02; // MIC2
  
  // RTC operations
  static const int rtcOptSetTime = 0x00; // 设置时间
  static const int rtcOptGetTime = 0x01; // 获取时间
  
  // IMU operations
  static const int imuOptStartData = 0x00; // 开始获取IMU数据
  static const int imuOptStopData = 0x01; // 停止获取IMU数据
  
  // 保持向后兼容
  static const int imuOptGetData = 0x00; // 获取IMU数据（兼容旧版本）
  static const int imuOptSetCalibration = 0x01; // 设置IMU标定参数（兼容旧版本）
  
  /// Create exit sleep mode command
  /// 退出休眠模式 - module id:5, message id:4
  static Uint8List createExitSleepModeCommand({
    int deep = 0xFFFFFFFF,   // 默认 0xFFFFFFFF
    int light = 0xFFFFFFFF,  // 默认 0xFFFFFFFF
    int core = 0,            // 默认 0 (0:DTOP 1:BT)
  }) {
    final buffer = ByteData(9);
    int offset = 0;
    
    // deep (4 bytes, little endian)
    buffer.setUint32(offset, deep, Endian.little);
    offset += 4;
    
    // light (4 bytes, little endian)
    buffer.setUint32(offset, light, Endian.little);
    offset += 4;
    
    // core (1 byte)
    buffer.setUint8(offset, core);
    
    return buffer.buffer.asUint8List();
  }
  
  /// Create start test command (0x00)
  /// 产测开始 - 无参数
  static Uint8List createStartTestCommand() {
    return Uint8List.fromList([cmdStartTest]);
  }
  
  /// Create get voltage command (0x01)
  /// 获取设备电压 - 返回 uint16_t 类型的电压
  static Uint8List createGetVoltageCommand() {
    return Uint8List.fromList([cmdGetVoltage]);
  }
  
  /// Create get current command (0x02)
  /// 获取设备电量 - 返回 uint8_t 类型的电量
  static Uint8List createGetCurrentCommand() {
    return Uint8List.fromList([cmdGetCurrent]);
  }
  
  /// Create get charge status command (0x03)
  /// 获取设备充电状态 - 返回 uint8 + uint8 (充电状态枚举类型 + 故障码)
  /// 0. CHARGER_MODE_STOP
  /// 1. CHARGER_MODE_CC
  /// 2. CHARGER_MODE_CV
  /// 3. CHARGER_MODE_DONE
  static Uint8List createGetChargeStatusCommand() {
    return Uint8List.fromList([cmdGetChargeStatus]);
  }
  
  /// Create control WiFi command (0x04)
  /// 控制设备连接wifi - 多步骤测试流程
  /// [opt] - 测试选项：0x00开始测试, 0x01连接热点, 0x02测试RSSI, 0x03获取MAC, 0x04烧录MAC, 0xFF结束测试
  /// [data] - 可选数据（连接热点时需要SSID+PWD，烧录MAC时需要MAC地址）
  static Uint8List createControlWifiCommand(int opt, {List<int>? data}) {
    List<int> command = [cmdControlWifi, opt];
    if (data != null) {
      command.addAll(data);
    }
    return Uint8List.fromList(command);
  }
  
  /// Create control LED command (0x05)
  /// 控制设备LED灯 - 请求: LED号 + 状态
  /// [ledNumber] - 0x00: LED0(外侧), 0x01: LED1(内侧)
  /// [state] - 0x00: 开启, 0x01: 关闭
  static Uint8List createControlLEDCommand(int ledNumber, int state) {
    return Uint8List.fromList([cmdControlLED, ledNumber, state]);
  }
  
  /// Create control SPK command (0x06)
  /// 控制设备SPK放音 - 请求: SPK号
  /// [spkNumber] - 0x00: SPK0, 0x01: SPK1
  static Uint8List createControlSPKCommand(int spkNumber) {
    return Uint8List.fromList([cmdControlSPK, spkNumber]);
  }
  
  /// Create touch command (0x07)
  /// 左Touch请求: CMD + TouchID + ActionID
  /// 右Touch请求: CMD + TouchID + AreaID
  /// [touchId] - 0x00: 左Touch, 0x01: 右Touch
  /// [actionOrAreaId] - 左Touch为ActionID，右Touch为AreaID
  static Uint8List createTouchCommand(int touchId, int actionOrAreaId) {
    return Uint8List.fromList([cmdTouch, touchId, actionOrAreaId]);
  }
  
  /// Create legacy touch command (保持向后兼容)
  /// [touchSide] - 0x00: 左touch, 0x01: 右touch
  /// [touchId] - touch ID
  /// [opt] - 0x00: 获取CDC值, 0x01: 设置阈值
  /// [data] - 可选数据
  static Uint8List createLegacyTouchCommand(int touchSide, {int touchId = 0, int opt = touchOptGetCDC, List<int>? data}) {
    List<int> command = [cmdTouch, touchSide, touchId, opt];
    if (data != null) {
      command.addAll(data);
    }
    return Uint8List.fromList(command);
  }
  
  // MIC control operations
  static const int micControlOpen = 0x00; // 打开MIC
  static const int micControlClose = 0x01; // 关闭MIC
  
  /// Create control MIC command (0x08)
  /// 控制MIC录音 - 请求: MIC号 + 控制
  /// [micNumber] - 0x00: MIC0, 0x01: MIC1, 0x02: MIC2
  /// [control] - 0x00: 打开, 0x01: 关闭
  static Uint8List createControlMICCommand(int micNumber, int control) {
    return Uint8List.fromList([cmdControlMIC, micNumber, control]);
  }
  
  /// Create RTC command (0x09)
  /// RTC测试 - 请求: opt + 时间戳(可选)
  /// [opt] - 0x00: 设置时间, 0x01: 获取时间
  /// [timestamp] - 毫秒级时间戳(毫秒位0，精确到秒)
  static Uint8List createRTCCommand(int opt, {int? timestamp}) {
    List<int> command = [cmdRTC, opt];
    if (opt == rtcOptSetTime && timestamp != null) {
      // Convert timestamp to 8 bytes (uint64_t, little endian)
      ByteData buffer = ByteData(8);
      buffer.setUint64(0, timestamp, Endian.little);
      
      command.addAll(buffer.buffer.asUint8List());
    }
    return Uint8List.fromList(command);
  }
  
  /// Create light sensor command (0x0A)
  /// 光敏传感器 - 回复: double
  static Uint8List createLightSensorCommand() {
    return Uint8List.fromList([cmdLightSensor]);
  }
  
  /// Create IMU command (0x0B)
  /// IMU测试 - 请求: opt + 数据(可选)
  /// [opt] - 0x00: 获取IMU数据, 0x01: 设置IMU标定参数
  /// [calibrationData] - 标定参数数据
  static Uint8List createIMUCommand(int opt, {List<int>? calibrationData}) {
    List<int> command = [cmdIMU, opt];
    if (opt == imuOptSetCalibration && calibrationData != null) {
      command.addAll(calibrationData);
    }
    return Uint8List.fromList(command);
  }
  
  /// Create sensor command (0x0C)
  /// Sensor测试 - 待定
  static Uint8List createSensorCommand() {
    return Uint8List.fromList([cmdSensor]);
  }
  
  /// Create bluetooth command (0x0D)
  /// 蓝牙测试 - 待定
  static Uint8List createBluetoothCommand() {
    return Uint8List.fromList([cmdBluetooth]);
  }
  
  /// Create end test command (0xFF)
  /// 产测结束 - 结束产测状态
  static Uint8List createEndTestCommand() {
    return Uint8List.fromList([cmdEndTest]);
  }
  
  /// Parse voltage response
  /// Returns voltage in mV (uint16_t)
  /// 设备返回格式：[CMD] + [2字节电压值]
  static int? parseVoltageResponse(Uint8List payload) {
    if (payload.isEmpty) return null;
    
    // 跳过第一个命令字节，读取2字节电压值
    int offset = payload[0] == cmdGetVoltage ? 1 : 0;
    if (payload.length < offset + 2) return null;
    
    ByteData buffer = ByteData.sublistView(payload);
    return buffer.getUint16(offset, Endian.little);
  }
  
  /// Parse current response
  /// Returns current in % (uint8_t)
  /// 设备返回格式：[CMD] + [1字节电量百分比]
  static int? parseCurrentResponse(Uint8List payload) {
    if (payload.isEmpty) return null;
    
    // 跳过第一个命令字节
    int offset = payload[0] == cmdGetCurrent ? 1 : 0;
    if (payload.length < offset + 1) return null;
    
    return payload[offset];
  }
  
  /// Parse charge status response
  /// Returns map with 'mode' and 'errorCode'
  /// 设备返回格式：[CMD] + [2字节：模式+错误码]
  static Map<String, int>? parseChargeStatusResponse(Uint8List payload) {
    if (payload.isEmpty) return null;
    
    // 跳过第一个命令字节
    int offset = payload[0] == cmdGetChargeStatus ? 1 : 0;
    if (payload.length < offset + 2) return null;
    
    return {
      'mode': payload[offset],
      'errorCode': payload[offset + 1],
    };
  }
  
  /// Get charge mode name
  static String getChargeModeName(int mode) {
    switch (mode) {
      case 0:
        return 'CHARGER_MODE_STOP';
      case 1:
        return 'CHARGER_MODE_CC';
      case 2:
        return 'CHARGER_MODE_CV';
      case 3:
        return 'CHARGER_MODE_DONE';
      default:
        return 'UNKNOWN';
    }
  }
  
  /// Get LED name
  static String getLEDName(int ledNumber) {
    switch (ledNumber) {
      case ledOuter:
        return 'LED0(外侧)';
      case ledInner:
        return 'LED1(内侧)';
      default:
        return 'UNKNOWN';
    }
  }
  
  /// Get LED state name
  static String getLEDStateName(int state) {
    switch (state) {
      case ledOn:
        return '开启';
      case ledOff:
        return '关闭';
      default:
        return 'UNKNOWN';
    }
  }
  
  /// Parse WiFi response
  /// Returns response data based on the WiFi test step
  /// 设备返回格式：[CMD] + [数据] (不包含OPT)
  /// @param payload 设备返回的数据
  /// @param opt 当前执行的WiFi操作码
  static Map<String, dynamic>? parseWifiResponse(Uint8List payload, int opt) {
    if (payload.isEmpty) return null;
    
    // 检查是否包含WiFi命令字节
    if (payload[0] != cmdControlWifi) return null;
    
    Map<String, dynamic> result = {
      'opt': opt,
      'optName': _getWifiOptionName(opt),
    };
    
    // 根据不同的选项解析数据
    switch (opt) {
      case 0x00: // 开始测试
      case 0x01: // 连接热点
      case 0xFF: // 结束测试
        // 这些步骤通常只返回确认
        result['success'] = true;
        break;
        
      case 0x02: // 测试RSSI
        if (payload.length >= 2) { // CMD + RSSI值
          // RSSI值通常是有符号整数
          int rssi = payload[1];
          if (rssi > 127) rssi = rssi - 256; // 转换为有符号数
          result['rssi'] = rssi;
          result['success'] = true;
        }
        break;
        
      case 0x03: // 获取MAC地址
      case 0x04: // 烧录MAC地址
        if (payload.length >= 2) { // 至少需要 CMD + 数据
          // MAC地址以ASCII字符串形式返回，格式如 "00:90:4c:2e:e3:16"
          // 从索引1开始读取（跳过CMD字节），直到遇到\0或数据结束
          List<int> macBytes = payload.sublist(1);
          
          // 找到\0的位置
          int nullIndex = macBytes.indexOf(0);
          if (nullIndex >= 0) {
            macBytes = macBytes.sublist(0, nullIndex);
          }
          
          // 将字节转换为ASCII字符串
          String macAddress = String.fromCharCodes(macBytes);
          
          // 验证MAC地址格式（应该是 XX:XX:XX:XX:XX:XX 格式）
          if (macAddress.isNotEmpty) {
            result['mac'] = macAddress;
            result['success'] = true;
          } else {
            result['success'] = false;
            result['error'] = 'MAC地址为空';
          }
        } else {
          result['success'] = false;
          result['error'] = '响应数据长度不足';
        }
        break;
        
      default:
        result['success'] = false;
        result['error'] = 'Unknown WiFi option: 0x${opt.toRadixString(16)}';
    }
    
    return result;
  }
  
  /// Get WiFi option name
  static String _getWifiOptionName(int opt) {
    switch (opt) {
      case 0x00: return '开始测试';
      case 0x01: return '连接热点';
      case 0x02: return '测试RSSI';
      case 0x03: return '获取MAC地址';
      case 0x04: return '烧录MAC地址';
      case 0xFF: return '结束测试';
      default: return 'UNKNOWN';
    }
  }
  
  /// Parse touch response
  /// 新协议格式：CMD + TouchID + AreaID/ActionID + Data(2字节CDC)
  /// 返回值：Map包含touchId, areaOrActionId, cdcValue
  static Map<String, dynamic>? parseTouchResponse(Uint8List payload) {
    if (payload.isEmpty) return null;
    
    // 检查是否包含Touch命令字节
    if (payload[0] != cmdTouch) return null;
    
    // 新协议格式：CMD + TouchID + AreaID/ActionID + Data(2字节CDC)
    if (payload.length >= 5) {
      int touchId = payload[1];
      int areaOrActionId = payload[2];
      // CDC值为2字节小端序
      int cdcValue = payload[3] | (payload[4] << 8);
      
      return {
        'touchId': touchId,
        'areaOrActionId': areaOrActionId,
        'cdcValue': cdcValue,
        'success': true,
      };
    }
    
    // 兼容旧格式
    return _parseLegacyTouchResponse(payload);
  }
  
  /// Parse legacy touch response (兼容旧协议)
  /// Returns CDC value or success status
  /// 设备返回格式：[CMD] 或 [CMD] + [CDC数据]
  /// 返回值：CDC数值（包括0）表示成功，null表示解析失败
  static Map<String, dynamic>? _parseLegacyTouchResponse(Uint8List payload) {
    if (payload.isEmpty) return null;
    
    // 检查是否包含Touch命令字节
    if (payload[0] != cmdTouch) return null;
    
    // 如果只有命令字节，表示命令成功执行，返回0作为CDC值
    if (payload.length == 1) {
      return {
        'cdcValue': 0,
        'success': true,
      };
    }
    
    // 如果有额外数据，解析CDC值
    int offset = 1;
    
    // 尝试读取4字节CDC值
    if (payload.length >= offset + 4) {
      ByteData buffer = ByteData.sublistView(payload);
      int cdcValue = buffer.getUint32(offset, Endian.little);
      return {
        'cdcValue': cdcValue,
        'success': true,
      };
    }
    
    // 兼容模式：读取1字节CDC值
    if (payload.length >= offset + 1) {
      return {
        'cdcValue': payload[offset],
        'success': true,
      };
    }
    
    return null;
  }
  
  /// Parse legacy touch response and return CDC value (for backward compatibility)
  static int? parseLegacyTouchResponseValue(Uint8List payload) {
    final result = _parseLegacyTouchResponse(payload);
    return result?['cdcValue'];
  }
  
  /// Parse RTC response
  /// Returns timestamp in milliseconds
  /// 设备返回格式：[CMD] + [8字节毫秒级时间戳]
  static int? parseRTCResponse(Uint8List payload) {
    if (payload.isEmpty) return null;
    
    // 跳过第一个命令字节
    int offset = payload[0] == cmdRTC ? 1 : 0;
    if (payload.length < offset + 8) return null;
    
    ByteData buffer = ByteData.sublistView(payload);
    return buffer.getUint64(offset, Endian.little);
  }
  
  /// Parse light sensor response
  /// Returns light value as double
  /// 设备返回格式：[CMD] + [1字节数值]
  static double? parseLightSensorResponse(Uint8List payload) {
    if (payload.isEmpty) return null;
    
    // 跳过第一个命令字节
    int offset = payload[0] == cmdLightSensor ? 1 : 0;
    if (payload.length < offset + 1) return null;
    
    // 读取1字节数值并转换为double
    int lightValue = payload[offset];
    return lightValue.toDouble();
  }
  
  /// Parse IMU response
  /// Returns map with accelerometer, gyroscope, and timestamp data
  /// 设备返回格式：[CMD] + [40字节IMU数据]
  static Map<String, dynamic>? parseIMUResponse(Uint8List payload) {
    if (payload.isEmpty) return null;
    
    // 跳过第一个命令字节
    int offset = payload[0] == cmdIMU ? 1 : 0;
    
    // IMU data: accel_xyz(3*float) + gyro_xyz(3*float) + timestamp1 + timestamp2
    // Assuming 4 bytes per float, 8 bytes for timestamps
    if (payload.length < offset + 40) return null;
    
    ByteData buffer = ByteData.sublistView(payload);
    
    return {
      'accel_x': buffer.getFloat32(offset, Endian.little),
      'accel_y': buffer.getFloat32(offset + 4, Endian.little),
      'accel_z': buffer.getFloat32(offset + 8, Endian.little),
      'gyro_x': buffer.getFloat32(offset + 12, Endian.little),
      'gyro_y': buffer.getFloat32(offset + 16, Endian.little),
      'gyro_z': buffer.getFloat32(offset + 20, Endian.little),
      'timestamp1': buffer.getUint64(offset + 24, Endian.little),
      'timestamp2': buffer.getUint64(offset + 32, Endian.little),
    };
  }
  
  /// Get SPK name
  static String getSPKName(int spkNumber) {
    switch (spkNumber) {
      case spk0:
        return 'SPK0';
      case spk1:
        return 'SPK1';
      default:
        return 'UNKNOWN';
    }
  }
  
  /// Get MIC name
  static String getMICName(int micNumber) {
    switch (micNumber) {
      case mic0:
        return 'MIC0';
      case mic1:
        return 'MIC1';
      case mic2:
        return 'MIC2';
      default:
        return 'UNKNOWN';
    }
  }
  
  /// Get touch side name
  static String getTouchSideName(int touchSide) {
    switch (touchSide) {
      case touchLeft:
        return '左Touch';
      case touchRight:
        return '右Touch';
      default:
        return 'UNKNOWN';
    }
  }
}
