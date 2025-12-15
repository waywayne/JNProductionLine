import 'dart:typed_data';
import 'lib/services/gtp_protocol.dart';
import 'lib/services/production_test_commands.dart';

void main() {
  print('测试退出休眠命令协议');
  print('=' * 60);
  
  // 创建退出休眠命令 payload
  final exitSleepPayload = ProductionTestCommands.createExitSleepModeCommand();
  
  print('\n1. Payload (${exitSleepPayload.length} bytes):');
  print('   ${_formatHex(exitSleepPayload)}');
  
  // 构建完整的 GTP 数据包
  final gtpPacket = GTPProtocol.buildGTPPacket(
    exitSleepPayload,
    moduleId: ProductionTestCommands.exitSleepModuleId,
    messageId: ProductionTestCommands.exitSleepMessageId,
  );
  
  print('\n2. 完整 GTP 数据包 (${gtpPacket.length} bytes):');
  print('   ${_formatHex(gtpPacket)}');
  
  print('\n3. 示例数据包 (42 bytes):');
  print('   D0D2C5C200250003040000B2232305001DF70400000009000000FFFFFFFFFFFFFFFF0040409F686B40');
  
  print('\n4. 对比分析:');
  final example = _hexStringToBytes('D0D2C5C200250003040000B2232305001DF70400000009000000FFFFFFFFFFFFFFFF0040409F686B40');
  
  print('   位置  我们的    示例    说明');
  print('   ' + '-' * 50);
  
  for (int i = 0; i < gtpPacket.length && i < example.length; i++) {
    final match = gtpPacket[i] == example[i] ? '✓' : '✗';
    final desc = _getFieldDescription(i);
    print('   ${i.toString().padLeft(4)}  ${gtpPacket[i].toRadixString(16).padLeft(2, '0').toUpperCase()}        ${example[i].toRadixString(16).padLeft(2, '0').toUpperCase()}      $match $desc');
  }
  
  print('\n5. 详细解析:');
  _parsePacket(gtpPacket, '我们的数据包');
  print('');
  _parsePacket(example, '示例数据包');
}

String _formatHex(Uint8List data) {
  final hex = data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join('');
  return hex;
}

Uint8List _hexStringToBytes(String hex) {
  final bytes = <int>[];
  for (int i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}

String _getFieldDescription(int offset) {
  if (offset < 4) return 'Preamble';
  if (offset == 4) return 'Version';
  if (offset >= 5 && offset < 7) return 'Length';
  if (offset == 7) return 'Type';
  if (offset == 8) return 'FC';
  if (offset >= 9 && offset < 11) return 'Seq';
  if (offset == 11) return 'CRC8';
  if (offset >= 12 && offset < 14) return 'CLI Start';
  if (offset >= 14 && offset < 16) return 'Module ID';
  if (offset >= 16 && offset < 18) return 'CRC16';
  if (offset >= 18 && offset < 20) return 'Message ID';
  if (offset == 20) return 'Flags';
  if (offset == 21) return 'Result';
  if (offset >= 22 && offset < 24) return 'Payload Length';
  if (offset >= 24 && offset < 26) return 'SN';
  if (offset >= 26 && offset < 35) return 'Payload';
  if (offset == 35) return 'Padding';
  if (offset >= 36 && offset < 38) return 'Tail';
  if (offset >= 38) return 'CRC32';
  return '';
}

void _parsePacket(Uint8List data, String label) {
  print('$label:');
  
  if (data.length < 12) {
    print('  数据包太短');
    return;
  }
  
  final buffer = ByteData.view(data.buffer);
  
  // GTP Header
  print('  GTP Header:');
  print('    Preamble: ${_formatHex(data.sublist(0, 4))}');
  print('    Version: ${data[4]}');
  print('    Length: ${buffer.getUint16(5, Endian.little)}');
  print('    Type: 0x${data[7].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('    FC: 0x${data[8].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('    Seq: ${buffer.getUint16(9, Endian.little)}');
  print('    CRC8: 0x${data[11].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  
  if (data.length < 26) return;
  
  // CLI Message
  print('  CLI Message:');
  print('    Start: ${_formatHex(data.sublist(12, 14))}');
  print('    Module ID: ${buffer.getUint16(14, Endian.little)} (0x${buffer.getUint16(14, Endian.little).toRadixString(16).padLeft(4, '0').toUpperCase()})');
  print('    CRC16: 0x${buffer.getUint16(16, Endian.little).toRadixString(16).padLeft(4, '0').toUpperCase()}');
  print('    Message ID: ${buffer.getUint16(18, Endian.little)} (0x${buffer.getUint16(18, Endian.little).toRadixString(16).padLeft(4, '0').toUpperCase()})');
  print('    Flags: 0x${data[20].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('    Result: 0x${data[21].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('    Payload Length: ${buffer.getUint16(22, Endian.little)}');
  print('    SN: ${buffer.getUint16(24, Endian.little)}');
  
  if (data.length >= 35) {
    print('    Payload: ${_formatHex(data.sublist(26, 35))}');
  }
  
  if (data.length >= 36) {
    print('    Padding: 0x${data[35].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  }
  
  if (data.length >= 38) {
    print('    Tail: ${_formatHex(data.sublist(36, 38))}');
  }
  
  if (data.length >= 42) {
    print('  GTP Trailer:');
    print('    CRC32: 0x${buffer.getUint32(38, Endian.little).toRadixString(16).padLeft(8, '0').toUpperCase()}');
  }
}
