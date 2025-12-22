import 'lib/config/sn_mac_config.dart';

void main() async {
  print('=== SN码和MAC地址生成测试 ===\n');
  
  // 初始化配置
  await SNMacConfig.initialize();
  
  // 设置配置
  await SNMacConfig.setProductLine('637'); // AI拍摄眼镜
  await SNMacConfig.setFactory('1'); // 代工厂A
  await SNMacConfig.setProductionLine(1); // 产线1
  
  print('当前配置:');
  final config = SNMacConfig.getCurrentConfig();
  print('产品线: ${config['productLine']} (${SNMacConfig.productLines[config['productLine']]})');
  print('工厂: ${config['factory']} (${SNMacConfig.factories[config['factory']]})');
  print('产线: ${config['productionLine']}');
  print('当前流水号: ${config['serialCounter']}');
  print('');
  
  // 生成5个设备标识
  print('生成设备标识信息:');
  print('格式: PPP-F-YMMDD-L-BBBBB-SSSS');
  print('');
  
  for (int i = 1; i <= 5; i++) {
    print('=== 设备 #$i ===');
    final deviceInfo = await SNMacConfig.generateDeviceIdentity();
    
    print('SN码: ${deviceInfo['sn']}');
    print('WiFi MAC: ${deviceInfo['wifiMac']}');
    print('蓝牙 MAC: ${deviceInfo['bluetoothMac']}');
    print('产品线: ${deviceInfo['productLine']}');
    print('工厂: ${deviceInfo['factory']}');
    print('生产日期: ${deviceInfo['productionDate']}');
    
    // 验证SN码
    final isValid = SNMacConfig.validateSN(deviceInfo['sn']!);
    print('SN码验证: ${isValid ? '✅ 有效' : '❌ 无效'}');
    
    if (isValid) {
      final parsedSN = SNMacConfig.parseSN(deviceInfo['sn']!);
      if (parsedSN != null) {
        print('SN码解析:');
        print('  产品线: ${parsedSN['productLine']} (${parsedSN['productLineName']})');
        print('  工厂: ${parsedSN['factory']} (${parsedSN['factoryName']})');
        print('  生产日期: ${parsedSN['productionDate']}');
        print('  产线: ${parsedSN['line']}');
        print('  流水号: ${parsedSN['serialNumber']}');
        print('  校验码: ${parsedSN['checksum']}');
      }
    }
    print('');
  }
  
  // 显示统计信息
  print('=== 统计信息 ===');
  final stats = SNMacConfig.getStatistics();
  print('已生成SN码数量: ${stats['totalSNsGenerated']}');
  print('已生成WiFi MAC数量: ${stats['totalWifiMacsGenerated']}');
  print('已生成蓝牙MAC数量: ${stats['totalBluetoothMacsGenerated']}');
  print('当前流水号: ${stats['currentSerialCounter']}');
  print('WiFi MAC剩余: ${stats['wifiMacRemaining']}');
  print('蓝牙MAC剩余: ${stats['bluetoothMacRemaining']}');
  
  print('\n=== 测试完成 ===');
}
