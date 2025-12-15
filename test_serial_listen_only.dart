import 'dart:typed_data';
import 'package:libserialport/libserialport.dart';

/// 纯监听模式测试 - 不发送任何数据，只接收
void main() async {
  final portName = '/dev/cu.usbserial-3120';
  
  print('串口监听测试 (只接收，不发送)');
  print('=' * 80);
  print('端口: $portName');
  print('波特率: 115200');
  print('按 Ctrl+C 停止\n');
  
  // 检查端口是否可用
  final availablePorts = SerialPort.availablePorts;
  print('可用串口: ${availablePorts.join(", ")}\n');
  
  if (!availablePorts.contains(portName)) {
    print('错误: 串口 $portName 不可用');
    print('请检查:');
    print('  1. 设备是否已连接');
    print('  2. 是否有其他程序（如 WindTerm）正在使用该串口');
    return;
  }
  
  // 打开串口
  final port = SerialPort(portName);
  
  print('正在打开串口...');
  if (!port.openReadWrite()) {
    print('错误: 无法打开串口');
    print('可能原因:');
    print('  1. 串口被其他程序占用（如 WindTerm）');
    print('  2. 权限不足，尝试: sudo chmod 666 $portName');
    return;
  }
  print('✓ 串口打开成功\n');
  
  // 配置串口
  final config = SerialPortConfig();
  config.baudRate = 115200;
  config.bits = 8;
  config.stopBits = 1;
  config.parity = SerialPortParity.none;
  port.config = config;
  
  print('✓ 串口配置完成');
  print('开始监听数据...\n');
  print('-' * 80);
  
  // 开始读取数据
  final reader = SerialPortReader(port);
  var packetCount = 0;
  var totalBytes = 0;
  var gtpPacketCount = 0;
  
  try {
    await for (final data in reader.stream) {
      packetCount++;
      totalBytes += data.length;
      
      final receivedData = Uint8List.fromList(data);
      
      // 格式化输出
      print('\n[$packetCount] 接收 ${data.length} bytes:');
      print(_formatHex(receivedData));
      
      // 检查是否是 GTP 数据包
      if (receivedData.length >= 4 && 
          receivedData[0] == 0xD0 && 
          receivedData[1] == 0xD2 && 
          receivedData[2] == 0xC5 && 
          receivedData[3] == 0xC2) {
        gtpPacketCount++;
        print('>>> 检测到 GTP 数据包! <<<');
        
        if (receivedData.length >= 12) {
          final version = receivedData[4];
          final length = (receivedData[6] << 8) | receivedData[5]; // Little endian
          final type = receivedData[7];
          final fc = receivedData[8];
          
          print('    Preamble: D0 D2 C5 C2');
          print('    Version: 0x${version.toRadixString(16).padLeft(2, '0').toUpperCase()}');
          print('    Length: $length');
          print('    Type: 0x${type.toRadixString(16).padLeft(2, '0').toUpperCase()}');
          print('    FC: 0x${fc.toRadixString(16).padLeft(2, '0').toUpperCase()}');
        }
      }
      
      print('-' * 80);
    }
  } catch (e) {
    print('\n错误: $e');
  } finally {
    port.close();
    print('\n\n总结:');
    print('  接收数据包: $packetCount');
    print('  总字节数: $totalBytes');
    print('  GTP 数据包: $gtpPacketCount');
  }
}

String _formatHex(Uint8List data) {
  final buffer = StringBuffer();
  for (int i = 0; i < data.length; i += 16) {
    buffer.write('  ${i.toString().padLeft(4, '0')}: ');
    
    // Hex part
    for (int j = 0; j < 16; j++) {
      if (i + j < data.length) {
        buffer.write(data[i + j].toRadixString(16).padLeft(2, '0').toUpperCase());
        buffer.write(' ');
      } else {
        buffer.write('   ');
      }
    }
    
    buffer.writeln();
  }
  return buffer.toString();
}
