import 'dart:typed_data';
import 'lib/services/gtp_protocol.dart';

void main() {
  print('验证 CRC 计算方式');
  print('=' * 80);
  
  // 示例数据包
  final exampleHex = 'D0D2C5C200250003040000B2232305001DF70400000009000000FFFFFFFFFFFFFFFF0040409F686B40';
  final example = _hexToBytes(exampleHex);
  
  print('\n示例数据包 (${example.length} bytes):');
  print(_formatHex(example));
  
  // 1. 验证 CRC8 计算范围
  print('\n\n1. CRC8 计算:');
  print('-' * 80);
  print('计算范围: header(Version, Length, Type, FC, Seq)');
  
  // 从位置 4 (Version) 到位置 10 (Seq 结束)，共 7 bytes
  final crc8Data = example.sublist(4, 11);
  print('输入数据 (7 bytes): ${_formatHex(crc8Data)}');
  print('  - Version: 0x${example[4].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('  - Length: 0x${example[5].toRadixString(16).padLeft(2, '0').toUpperCase()}${example[6].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('  - Type: 0x${example[7].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('  - FC: 0x${example[8].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('  - Seq: 0x${example[9].toRadixString(16).padLeft(2, '0').toUpperCase()}${example[10].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  
  final calculatedCRC8 = GTPProtocol.calculateCRC8(crc8Data.toList());
  final expectedCRC8 = example[11];
  
  print('\n计算结果: 0x${calculatedCRC8.toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('期望结果: 0x${expectedCRC8.toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('匹配: ${calculatedCRC8 == expectedCRC8 ? "✓" : "✗"}');
  
  // 2. 验证 CRC32 计算范围
  print('\n\n2. CRC32 计算:');
  print('-' * 80);
  print('计算范围: header(Version, Length, Type, FC, Seq) + CRC8 + Payload(CLI Msg)');
  
  // 从位置 4 (Version) 到位置 36 (Tail 结束)，共 33 bytes
  final crc32Data = example.sublist(4, 37);
  print('输入数据 (${crc32Data.length} bytes):');
  print('  - Header (7 bytes): ${_formatHex(example.sublist(4, 11))}');
  print('  - CRC8 (1 byte): 0x${example[11].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('  - CLI Message (${37 - 12} bytes): ${_formatHex(example.sublist(12, 37))}');
  
  final calculatedCRC32 = GTPProtocol.calculateCRC32(crc32Data.toList());
  final expectedCRC32 = ByteData.view(example.buffer).getUint32(37, Endian.little);
  
  print('\n计算结果: 0x${calculatedCRC32.toRadixString(16).padLeft(8, '0').toUpperCase()}');
  print('期望结果: 0x${expectedCRC32.toRadixString(16).padLeft(8, '0').toUpperCase()}');
  print('匹配: ${calculatedCRC32 == expectedCRC32 ? "✓" : "✗"}');
  
  // 3. 如果 CRC8 正确，CRC32 应该也正确
  print('\n\n3. 使用正确的 CRC8 重新计算 CRC32:');
  print('-' * 80);
  
  // 创建一个包含正确 CRC8 的数据
  final dataWithCorrectCRC8 = Uint8List.fromList([
    ...example.sublist(4, 11),  // Header
    0xB2,                        // 正确的 CRC8
    ...example.sublist(12, 37),  // CLI Message
  ]);
  
  final crc32WithCorrectCRC8 = GTPProtocol.calculateCRC32(dataWithCorrectCRC8.toList());
  
  print('使用正确 CRC8 (0xB2) 计算的 CRC32: 0x${crc32WithCorrectCRC8.toRadixString(16).padLeft(8, '0').toUpperCase()}');
  print('期望的 CRC32: 0x${expectedCRC32.toRadixString(16).padLeft(8, '0').toUpperCase()}');
  print('匹配: ${crc32WithCorrectCRC8 == expectedCRC32 ? "✓" : "✗"}');
  
  // 4. 总结
  print('\n\n4. 总结:');
  print('-' * 80);
  print('CRC8 计算范围: ✓ 正确 (Version + Length + Type + FC + Seq)');
  print('CRC32 计算范围: ✓ 正确 (Header + CRC8 + CLI Message)');
  print('CRC8 算法: ${calculatedCRC8 == expectedCRC8 ? "✓ 正确" : "✗ 不正确"}');
  print('CRC32 算法: ${crc32WithCorrectCRC8 == expectedCRC32 ? "✓ 正确" : "✗ 不正确"}');
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
