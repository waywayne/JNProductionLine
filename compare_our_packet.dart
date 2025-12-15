import 'dart:typed_data';
import 'lib/services/gtp_protocol.dart';
import 'lib/services/production_test_commands.dart';

void main() {
  print('对比我们的数据包与示例');
  print('=' * 80);
  
  // 生成我们的数据包
  final exitSleepPayload = ProductionTestCommands.createExitSleepModeCommand();
  final ourPacket = GTPProtocol.buildGTPPacket(
    exitSleepPayload,
    moduleId: ProductionTestCommands.exitSleepModuleId,
    messageId: ProductionTestCommands.exitSleepMessageId,
  );
  
  // 示例数据包
  final exampleHex = 'D0D2C5C200250003040000B2232305001DF70400000009000000FFFFFFFFFFFFFFFF0040409F686B40';
  final examplePacket = _hexToBytes(exampleHex);
  
  print('\n我们的数据包 (${ourPacket.length} bytes):');
  print(_formatHex(ourPacket));
  
  print('\n示例数据包 (${examplePacket.length} bytes):');
  print(_formatHex(examplePacket));
  
  print('\n\n逐字节对比:');
  print('位置  我们的  示例  字段说明                状态');
  print('-' * 80);
  
  final fields = [
    [0, 4, 'Preamble'],
    [4, 1, 'Version'],
    [5, 2, 'Length'],
    [7, 1, 'Type'],
    [8, 1, 'FC'],
    [9, 2, 'Seq'],
    [11, 1, 'CRC8'],
    [12, 2, 'CLI Start'],
    [14, 2, 'CLI Module ID'],
    [16, 2, 'CLI CRC'],
    [18, 2, 'CLI Message ID'],
    [20, 1, 'CLI 字段9 (ACK/Type/Reversed)'],
    [21, 1, 'CLI Result'],
    [22, 2, 'CLI Payload Length'],
    [24, 2, 'CLI SN'],
    [26, 9, 'CLI Payload'],
    [35, 2, 'CLI Tail'],
    [37, 4, 'GTP CRC32'],
  ];
  
  for (var field in fields) {
    final start = field[0] as int;
    final len = field[1] as int;
    final name = field[2] as String;
    final end = start + len;
    
    if (start >= ourPacket.length || start >= examplePacket.length) break;
    
    final ourValue = ourPacket.sublist(start, end.clamp(0, ourPacket.length));
    final exampleValue = examplePacket.sublist(start, end.clamp(0, examplePacket.length));
    
    final ourHex = _formatHex(ourValue);
    final exampleHex = _formatHex(exampleValue);
    final match = ourHex == exampleHex;
    
    print('${start.toString().padLeft(4)}  ${ourHex.padRight(20)}  ${exampleHex.padRight(20)}  ${name.padRight(30)}  ${match ? "✓" : "✗"}');
    
    // 详细分析不匹配的字段
    if (!match && len == 1) {
      print('      我们: 0x${ourValue[0].toRadixString(16).padLeft(2, '0').toUpperCase()} = ${ourValue[0].toRadixString(2).padLeft(8, '0')}b');
      print('      示例: 0x${exampleValue[0].toRadixString(16).padLeft(2, '0').toUpperCase()} = ${exampleValue[0].toRadixString(2).padLeft(8, '0')}b');
    }
  }
  
  print('\n\n关键发现:');
  print('-' * 80);
  
  // 检查 Tail 字段
  print('\n1. CLI Tail 字段:');
  final ourTail = ourPacket.sublist(35, 37);
  final exampleTail = examplePacket.sublist(35, 37);
  print('   我们的: ${_formatHex(ourTail)}');
  print('   示例:   ${_formatHex(exampleTail)}');
  
  if (ourTail[0] == 0x40 && ourTail[1] == 0x40) {
    print('   ✓ Tail 值正确 (40 40)');
  } else {
    print('   ✗ Tail 值不正确');
  }
  
  // 检查字段 9
  print('\n2. CLI 字段9 (ACK/Type/Reversed):');
  final ourField9 = ourPacket[20];
  final exampleField9 = examplePacket[20];
  print('   我们的: 0x${ourField9.toRadixString(16).padLeft(2, '0').toUpperCase()} = ${ourField9.toRadixString(2).padLeft(8, '0')}b');
  print('   示例:   0x${exampleField9.toRadixString(16).padLeft(2, '0').toUpperCase()} = ${exampleField9.toRadixString(2).padLeft(8, '0')}b');
  
  if (ourField9 == exampleField9) {
    print('   ✓ 字段9 正确');
  } else {
    print('   ✗ 字段9 不正确');
  }
}

String _formatHex(Uint8List data) {
  return data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
}

Uint8List _hexToBytes(String hex) {
  final bytes = <int>[];
  for (int i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}
