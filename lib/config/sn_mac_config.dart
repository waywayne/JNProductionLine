import 'dart:io';
import 'dart:convert';
import 'dart:math';

/// SN码和MAC地址统一分配管理器
class SNMacConfig {
  // 产品线代码
  static const Map<String, String> productLines = {
    '637': 'AI拍摄眼镜',
    '638': 'AI音频眼镜',
  };
  
  // 工厂代码
  static const Map<String, String> factories = {
    '1': '工厂A',
    '2': '工厂B',
  };
  
  // WiFi MAC地址范围: 48-08-EB-50-00-00 到 48-08-EB-5F-FF-FF
  static const String wifiMacPrefix = '48:08:EB:5';
  static const int wifiMacRangeStart = 0x0; // 50-00-00
  static const int wifiMacRangeEnd = 0xFFFFF; // 5F-FF-FF
  
  // 蓝牙MAC地址范围: 48-08-EB-60-00-00 到 48-08-EB-6F-FF-FF  
  static const String bluetoothMacPrefix = '48:08:EB:6';
  static const int bluetoothMacRangeStart = 0x0; // 60-00-00
  static const int bluetoothMacRangeEnd = 0xFFFFF; // 6F-FF-FF
  
  // Base36字符集
  static const String base36Chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  
  // 配置文件路径
  static const String configFilePath = 'sn_mac_allocation.json';
  
  // 当前配置
  static Map<String, dynamic> _currentConfig = {
    'productLine': '637',
    'factory': '1',
    'productionLine': '1',
    'serialCounter': 1,
    'wifiMacCounter': 0,
    'bluetoothMacCounter': 0,
    'allocatedSNs': <String>[],
    'allocatedWifiMacs': <String>[],
    'allocatedBluetoothMacs': <String>[],
  };
  
  /// 初始化配置，从文件加载或创建默认配置
  static Future<void> initialize() async {
    try {
      final file = File(configFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        _currentConfig = json.decode(content);
      } else {
        await _saveConfig();
      }
    } catch (e) {
      print('初始化SN/MAC配置失败: $e');
      // 使用默认配置
    }
  }
  
  /// 保存配置到文件
  static Future<void> _saveConfig() async {
    try {
      final file = File(configFilePath);
      await file.writeAsString(json.encode(_currentConfig));
    } catch (e) {
      print('保存SN/MAC配置失败: $e');
    }
  }
  
  /// 生成生产日期字符串 (YMMDD格式)
  static String _generateProductionDate() {
    final now = DateTime.now();
    final year = (now.year % 10).toString(); // 年份最后一位
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }
  
  /// 将数字转换为Base36字符串
  static String _toBase36(int number, int length) {
    if (number == 0) return '0' * length;
    
    String result = '';
    while (number > 0) {
      result = base36Chars[number % 36] + result;
      number ~/= 36;
    }
    
    return result.padLeft(length, '0');
  }
  
  /// 计算校验码 (4位Base36)
  static String _calculateChecksum(String snWithoutChecksum) {
    int sum = 0;
    for (int i = 0; i < snWithoutChecksum.length; i++) {
      sum += snWithoutChecksum.codeUnitAt(i);
    }
    return _toBase36(sum % (36 * 36 * 36 * 36), 4);
  }
  
  /// 生成新的SN码
  static Future<String> generateSN() async {
    final productLine = _currentConfig['productLine'] as String;
    final factory = _currentConfig['factory'] as String;
    final productionDate = _generateProductionDate();
    final line = _currentConfig['productionLine'].toString();
    final counter = _currentConfig['serialCounter'] as int;
    
    // 生成流水号 (5位Base36)
    final serialNumber = _toBase36(counter, 5);
    
    // 生成不含校验码的SN
    final snWithoutChecksum = '$productLine$factory$productionDate$line$serialNumber';
    
    // 计算校验码
    final checksum = _calculateChecksum(snWithoutChecksum);
    
    // 完整SN码
    final fullSN = '$snWithoutChecksum$checksum';
    
    // 更新计数器并保存
    _currentConfig['serialCounter'] = counter + 1;
    final allocatedSNs = _currentConfig['allocatedSNs'] as List<dynamic>;
    allocatedSNs.add(fullSN);
    await _saveConfig();
    
    return fullSN;
  }
  
  /// 生成WiFi MAC地址
  static Future<String> generateWifiMac() async {
    final counter = _currentConfig['wifiMacCounter'] as int;
    
    if (counter > wifiMacRangeEnd) {
      throw Exception('WiFi MAC地址已用完');
    }
    
    // 计算MAC地址的后3字节
    final macSuffix = counter;
    final byte1 = (macSuffix >> 16) & 0xFF;
    final byte2 = (macSuffix >> 8) & 0xFF;
    final byte3 = macSuffix & 0xFF;
    
    // 生成完整MAC地址
    final macAddress = '$wifiMacPrefix${byte1.toRadixString(16).toUpperCase().padLeft(1, '0')}:${byte2.toRadixString(16).toUpperCase().padLeft(2, '0')}:${byte3.toRadixString(16).toUpperCase().padLeft(2, '0')}';
    
    // 更新计数器并保存
    _currentConfig['wifiMacCounter'] = counter + 1;
    final allocatedWifiMacs = _currentConfig['allocatedWifiMacs'] as List<dynamic>;
    allocatedWifiMacs.add(macAddress);
    await _saveConfig();
    
    return macAddress;
  }
  
  /// 生成蓝牙MAC地址
  static Future<String> generateBluetoothMac() async {
    final counter = _currentConfig['bluetoothMacCounter'] as int;
    
    if (counter > bluetoothMacRangeEnd) {
      throw Exception('蓝牙MAC地址已用完');
    }
    
    // 计算MAC地址的后3字节
    final macSuffix = counter;
    final byte1 = (macSuffix >> 16) & 0xFF;
    final byte2 = (macSuffix >> 8) & 0xFF;
    final byte3 = macSuffix & 0xFF;
    
    // 生成完整MAC地址
    final macAddress = '$bluetoothMacPrefix${byte1.toRadixString(16).toUpperCase().padLeft(1, '0')}:${byte2.toRadixString(16).toUpperCase().padLeft(2, '0')}:${byte3.toRadixString(16).toUpperCase().padLeft(2, '0')}';
    
    // 更新计数器并保存
    _currentConfig['bluetoothMacCounter'] = counter + 1;
    final allocatedBluetoothMacs = _currentConfig['allocatedBluetoothMacs'] as List<dynamic>;
    allocatedBluetoothMacs.add(macAddress);
    await _saveConfig();
    
    return macAddress;
  }
  
  /// 生成完整的设备标识信息
  static Future<Map<String, String>> generateDeviceIdentity() async {
    final sn = await generateSN();
    final wifiMac = await generateWifiMac();
    final bluetoothMac = await generateBluetoothMac();
    
    return {
      'sn': sn,
      'wifiMac': wifiMac,
      'bluetoothMac': bluetoothMac,
      'productLine': productLines[_currentConfig['productLine']] ?? 'Unknown',
      'factory': factories[_currentConfig['factory']] ?? 'Unknown',
      'productionDate': _generateProductionDate(),
    };
  }
  
  /// 设置产品线
  static Future<void> setProductLine(String productLine) async {
    if (productLines.containsKey(productLine)) {
      _currentConfig['productLine'] = productLine;
      await _saveConfig();
    }
  }
  
  /// 设置工厂
  static Future<void> setFactory(String factory) async {
    if (factories.containsKey(factory)) {
      _currentConfig['factory'] = factory;
      await _saveConfig();
    }
  }
  
  /// 设置产线
  static Future<void> setProductionLine(int line) async {
    if (line >= 1 && line <= 9) {
      _currentConfig['productionLine'] = line;
      await _saveConfig();
    }
  }
  
  /// 获取当前配置信息
  static Map<String, dynamic> getCurrentConfig() {
    return Map<String, dynamic>.from(_currentConfig);
  }
  
  /// 获取统计信息
  static Map<String, dynamic> getStatistics() {
    return {
      'totalSNsGenerated': (_currentConfig['allocatedSNs'] as List).length,
      'totalWifiMacsGenerated': (_currentConfig['allocatedWifiMacs'] as List).length,
      'totalBluetoothMacsGenerated': (_currentConfig['allocatedBluetoothMacs'] as List).length,
      'currentSerialCounter': _currentConfig['serialCounter'],
      'wifiMacRemaining': wifiMacRangeEnd - (_currentConfig['wifiMacCounter'] as int) + 1,
      'bluetoothMacRemaining': bluetoothMacRangeEnd - (_currentConfig['bluetoothMacCounter'] as int) + 1,
    };
  }
  
  /// 验证SN码格式
  static bool validateSN(String sn) {
    if (sn.length != 19) return false;
    
    // 提取各部分
    final productLine = sn.substring(0, 3);
    final factory = sn.substring(3, 4);
    final productionDate = sn.substring(4, 9);
    final line = sn.substring(9, 10);
    final serialNumber = sn.substring(10, 15);
    final checksum = sn.substring(15, 19);
    
    // 验证产品线和工厂
    if (!productLines.containsKey(productLine)) return false;
    if (!factories.containsKey(factory)) return false;
    
    // 验证校验码
    final snWithoutChecksum = sn.substring(0, 15);
    final calculatedChecksum = _calculateChecksum(snWithoutChecksum);
    
    return checksum == calculatedChecksum;
  }
  
  /// 解析SN码信息
  static Map<String, String>? parseSN(String sn) {
    if (!validateSN(sn)) return null;
    
    final productLine = sn.substring(0, 3);
    final factory = sn.substring(3, 4);
    final productionDate = sn.substring(4, 9);
    final line = sn.substring(9, 10);
    final serialNumber = sn.substring(10, 15);
    final checksum = sn.substring(15, 19);
    
    return {
      'sn': sn,
      'productLine': productLine,
      'productLineName': productLines[productLine] ?? 'Unknown',
      'factory': factory,
      'factoryName': factories[factory] ?? 'Unknown',
      'productionDate': productionDate,
      'line': line,
      'serialNumber': serialNumber,
      'checksum': checksum,
    };
  }
}
