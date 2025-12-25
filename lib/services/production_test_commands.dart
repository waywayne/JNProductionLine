import 'dart:typed_data';
import 'dart:math' as Math;

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
  static const int cmdWriteSN = 0xFE; // SN码写入
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
  static const int imuOptStopData = 0xFF; // 停止获取IMU数据
  
  // 保持向后兼容
  static const int imuOptGetData = 0x00; // 获取IMU数据（兼容旧版本）
  static const int imuOptSetCalibration = 0x01; // 设置IMU标定参数（兼容旧版本）
  
  // Sensor operations
  static const int sensorOptStart = 0x00; // 开始sensor测试
  static const int sensorOptBeginData = 0x01; // 开始发送数据
  static const int sensorOptStop = 0xFF; // 停止sensor测试
  
  // Bluetooth MAC operations
  static const int bluetoothOptBurnMac = 0x00; // 蓝牙mac地址烧录（6字节）
  static const int bluetoothOptReadMac = 0x01; // 上位机主动读MAC地址
  static const int bluetoothOptSetName = 0x02; // 设置蓝牙名称
  static const int bluetoothOptGetName = 0x03; // 获取蓝牙名称
  
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
  /// Sensor测试 - 请求: opt
  /// [opt] - 0x00: 开始sensor测试, 0xFF: 停止sensor测试
  static Uint8List createSensorCommand(int opt) {
    return Uint8List.fromList([cmdSensor, opt]);
  }
  
  /// Create bluetooth MAC command (0x0D)
  /// 蓝牙MAC地址操作 - 请求: opt + 数据(可选)
  /// [opt] - 0x00: 蓝牙mac地址烧录（6字节）, 0x01: 上位机主动读MAC地址
  /// [macAddress] - MAC地址（6字节，仅烧录时需要）
  static Uint8List createBluetoothMacCommand(int opt, {List<int>? macAddress}) {
    List<int> command = [cmdBluetooth, opt];
    if (opt == bluetoothOptBurnMac && macAddress != null && macAddress.length == 6) {
      command.addAll(macAddress);
    }
    return Uint8List.fromList(command);
  }
  
  /// Create set bluetooth name command (0x0D 0x02)
  /// 设置蓝牙名称 - CMD 0x0D + OPT 0x02 + 名称字符串 + \0
  /// [name] - 蓝牙名称字符串（ASCII编码）
  static Uint8List createSetBluetoothNameCommand(String name) {
    List<int> command = [cmdBluetooth, bluetoothOptSetName];
    // 将名称字符串转换为ASCII字节
    command.addAll(name.codeUnits);
    // 添加null终止符
    command.add(0x00);
    return Uint8List.fromList(command);
  }
  
  /// Create get bluetooth name command (0x0D 0x03)
  /// 获取蓝牙名称 - CMD 0x0D + OPT 0x03
  static Uint8List createGetBluetoothNameCommand() {
    return Uint8List.fromList([cmdBluetooth, bluetoothOptGetName]);
  }
  
  /// Parse bluetooth name response
  /// 响应格式：[CMD 0x0D] + [名称字符串] + [\0]（可能有多个）
  /// 返回响应中的蓝牙名称
  static String? parseBluetoothNameResponse(Uint8List payload) {
    if (payload.isEmpty) return null;
    
    // 检查第一个字节是否为0x0D
    if (payload[0] != cmdBluetooth) return null;
    
    // 提取名称（跳过CMD字节）
    if (payload.length < 2) return null;
    
    try {
      var nameBytes = payload.sublist(1);
      
      // 移除末尾所有的null终止符（可能有多个0x00）
      while (nameBytes.isNotEmpty && nameBytes.last == 0x00) {
        nameBytes = nameBytes.sublist(0, nameBytes.length - 1);
      }
      
      if (nameBytes.isEmpty) return null;
      
      return String.fromCharCodes(nameBytes);
    } catch (e) {
      return null;
    }
  }
  
  /// Create write SN command (0xFE)
  /// SN码写入 - CMD 0xFE + SN码字符串 + \0
  /// [snCode] - SN码字符串（ASCII编码）
  static Uint8List createWriteSNCommand(String snCode) {
    List<int> command = [cmdWriteSN];
    // 将SN码字符串转换为ASCII字节
    command.addAll(snCode.codeUnits);
    // 添加null终止符
    command.add(0x00);
    return Uint8List.fromList(command);
  }
  
  /// Parse write SN response
  /// 响应格式：[CMD 0xFE] + [SN码字符串] + [\0]（可选）
  /// 返回响应中的SN码，用于验证
  static String? parseWriteSNResponse(Uint8List payload) {
    if (payload.isEmpty) return null;
    
    // 检查第一个字节是否为0xFE
    if (payload[0] != cmdWriteSN) return null;
    
    // 提取SN码（跳过CMD字节）
    if (payload.length < 2) return null;
    
    try {
      // 将字节转换为字符串
      var snBytes = payload.sublist(1);
      
      // 移除末尾的null终止符（如果存在）
      if (snBytes.isNotEmpty && snBytes.last == 0x00) {
        snBytes = snBytes.sublist(0, snBytes.length - 1);
      }
      
      return String.fromCharCodes(snBytes);
    } catch (e) {
      return null;
    }
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
  /// Returns map with 'mode' and 'fault'
  /// 设备返回格式：[CMD 0x03] + [充电状态枚举] + [故障码]
  /// 充电状态枚举：0=STOP, 1=CC, 2=CV, 3=DONE
  /// 故障码：0x00=正常, 0x01=故障
  static Map<String, int>? parseChargeStatusResponse(Uint8List payload) {
    if (payload.isEmpty) return null;
    
    // 检查第一个字节是否是充电状态命令 (0x03)
    if (payload.length < 3) return null;
    if (payload[0] != cmdGetChargeStatus) return null;
    
    return {
      'mode': payload[1],      // 充电状态枚举类型
      'fault': payload[2],     // 故障码
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
      case 0xFF: // 结束测试
        // 这些步骤通常只返回确认
        result['success'] = true;
        break;
        
      case 0x01: // 连接热点 - 返回IP地址
        if (payload.length >= 2) { // CMD + IP数据
          // IP地址以ASCII字符串形式返回，格式如 "192.168.1.100"
          // 从索引1开始读取（跳过CMD字节），直到遇到\0或数据结束
          List<int> ipBytes = payload.sublist(2);
          
          // 找到\0的位置
          int nullIndex = ipBytes.indexOf(0);
          if (nullIndex >= 0) {
            ipBytes = ipBytes.sublist(0, nullIndex);
          }
          
          // 将字节转换为ASCII字符串
          String ipAddress = String.fromCharCodes(ipBytes);
          
          // 验证IP地址格式
          if (ipAddress.isNotEmpty) {
            result['ip'] = ipAddress;
            result['success'] = true;
          } else {
            result['success'] = false;
            result['error'] = 'IP地址为空';
          }
        } else {
          // 如果没有IP数据，也认为连接成功
          result['success'] = true;
        }
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
  
  /// Parse sensor response
  /// Returns parsed sensor data or null if parsing fails
  /// 设备返回格式：[CMD] + [picTotalBytes(4)] + [dataIndex(4)] + [dataLen(4)] + [data[]]
  static Map<String, dynamic>? parseSensorResponse(Uint8List payload) {
    if (payload.isEmpty) return null;
    
    // 检查是否包含Sensor命令字节
    if (payload[0] != cmdSensor) return null;
    
    // 如果只有命令字节，表示开始或停止确认
    if (payload.length == 1) {
      return {
        'cmd': payload[0],
        'success': true,
        'message': 'Sensor命令执行成功',
        'type': 'command_ack',
      };
    }
    
    // 解析sensor图片数据包
    // 数据结构: CMD(1) + picTotalBytes(4) + dataIndex(4) + dataLen(4) + data[]
    if (payload.length < 13) { // 至少需要 1 + 4 + 4 + 4 = 13 字节
      return {
        'cmd': payload[0],
        'success': false,
        'error': '数据包长度不足',
      };
    }
    
    try {
      ByteData buffer = ByteData.sublistView(payload);
      
      // 解析包头信息 (小端序)
      int picTotalBytes = buffer.getUint32(1, Endian.little);
      int dataIndex = buffer.getUint32(5, Endian.little);
      int dataLen = buffer.getUint32(9, Endian.little);
      
      // 取消严格的数据长度限制，允许接收更大的数据包
      int minExpectedLength = 13 + dataLen;
      if (payload.length < minExpectedLength) {
        return {
          'cmd': payload[0],
          'success': false,
          'error': '数据包长度不足，最少需要: $minExpectedLength, 实际: ${payload.length}',
        };
      }
      
      // 提取数据部分，使用实际可用的数据长度
      int actualDataLen = Math.min(dataLen, payload.length - 13);
      Uint8List data = payload.sublist(13, 13 + actualDataLen);
      
      // 检查是否是最后一个包（使用原始dataLen）
      bool isLastPacket = (dataIndex + dataLen) == picTotalBytes;
      
      return {
        'cmd': payload[0],
        'type': 'image_data',
        'picTotalBytes': picTotalBytes,
        'dataIndex': dataIndex,
        'dataLen': actualDataLen, // 使用实际提取的数据长度
        'originalDataLen': dataLen, // 保留原始声明的数据长度
        'data': data,
        'isLastPacket': isLastPacket,
        'success': true,
        'dataHex': data.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' '),
      };
    } catch (e) {
      return {
        'cmd': payload[0],
        'success': false,
        'error': '解析数据包时出错: $e',
      };
    }
  }
  
  /// Parse Bluetooth MAC response
  /// Returns MAC address
  /// 设备回复第一个字节为 cmd 后面为 6字节mac，需要解析出来
  static Map<String, dynamic>? parseBluetoothMacResponse(Uint8List payload) {
    if (payload.isEmpty) return null;
    
    // 检查是否包含Bluetooth命令字节
    if (payload[0] != cmdBluetooth) return null;
    
    // 如果只有命令字节，表示烧录成功确认
    if (payload.length == 1) {
      return {
        'cmd': payload[0],
        'success': true,
        'message': '蓝牙MAC地址烧录成功',
      };
    }
    
    // 解析MAC地址（6字节）
    if (payload.length >= 7) { // CMD + 6字节MAC
      List<int> macBytes = payload.sublist(1, 7);
      String macAddress = macBytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(':');
      
      return {
        'cmd': payload[0],
        'mac': macAddress,
        'macBytes': macBytes,
        'success': true,
      };
    }
    
    return {
      'cmd': payload[0],
      'success': false,
      'error': 'MAC地址数据长度不足',
    };
  }
  
  /// Get sensor option name
  static String getSensorOptionName(int opt) {
    switch (opt) {
      case sensorOptStart: return '开始sensor测试';
      case sensorOptBeginData: return '开始发送数据';
      case sensorOptStop: return '停止sensor测试';
      default: return 'UNKNOWN';
    }
  }
  
  /// Get Bluetooth MAC option name
  static String getBluetoothMacOptionName(int opt) {
    switch (opt) {
      case bluetoothOptBurnMac: return '蓝牙mac地址烧录';
      case bluetoothOptReadMac: return '上位机主动读MAC地址';
      default: return 'UNKNOWN';
    }
  }

  /// Create LED command
  /// ledType: LED类型 (0x00=外侧, 0x01=内侧)
  /// opt: LED操作 (0x00=开启, 0x01=关闭)
  static Uint8List createLEDCommand(int ledType, int opt) {
    final command = Uint8List(3);
    command[0] = cmdControlLED; // 0x05
    command[1] = ledType; // 0x00=外侧, 0x01=内侧
    command[2] = opt; // 0x00=开启, 0x01=关闭
    return command;
  }

  /// Parse LED response
  static Map<String, dynamic>? parseLEDResponse(Uint8List payload) {
    if (payload.isEmpty) return null;
    
    // 检查是否包含LED命令字节
    if (payload[0] != cmdControlLED) return null;
    
    // 如果只有命令字节，表示LED操作成功确认
    if (payload.length == 1) {
      return {
        'cmd': payload[0],
        'success': true,
        'message': 'LED操作成功',
      };
    }
    
    // 如果有更多数据，可以在这里解析
    return {
      'cmd': payload[0],
      'success': true,
      'data': payload.sublist(1),
    };
  }

  /// Parse MIC response
  static Map<String, dynamic>? parseMICResponse(Uint8List payload) {
    if (payload.isEmpty) return null;
    
    // 检查是否包含MIC命令字节
    if (payload[0] != cmdControlMIC) return null;
    
    // 如果只有命令字节，表示MIC操作成功确认
    if (payload.length == 1) {
      return {
        'cmd': payload[0],
        'success': true,
        'message': 'MIC操作成功',
      };
    }
    
    // 如果有更多数据，可以在这里解析
    return {
      'cmd': payload[0],
      'success': true,
      'data': payload.sublist(1),
    };
  }

  /// Get LED option name
  static String getLEDOptionName(int ledType, int opt) {
    final ledTypeName = ledType == 0x00 ? '外侧' : '内侧';
    final optName = opt == 0x00 ? '开启' : '关闭';
    return 'LED$ledTypeName$optName';
  }

  /// Create Bluetooth MAC command
  /// opt: 0x00=写入MAC地址, 0x01=读取MAC地址
  /// macBytes: MAC地址字节数组（6字节），仅在写入时需要
  static Uint8List createBluetoothMACCommand(int opt, List<int> macBytes) {
    if (opt == 0x00) {
      // 写入MAC地址：CMD + OPT + 6字节MAC
      if (macBytes.length != 6) {
        throw ArgumentError('MAC地址必须是6字节');
      }
      final command = Uint8List(8);
      command[0] = cmdBluetooth; // 0x0D
      command[1] = opt; // 0x00
      for (int i = 0; i < 6; i++) {
        command[2 + i] = macBytes[i];
      }
      return command;
    } else {
      // 读取MAC地址：CMD + OPT
      final command = Uint8List(2);
      command[0] = cmdBluetooth; // 0x0D
      command[1] = opt; // 0x01
      return command;
    }
  }
}
