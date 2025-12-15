import 'dart:typed_data';
import 'lib/services/gtp_protocol.dart';

void main() {
  print('测试 CRC 计算');
  print('=' * 60);
  
  // 测试 CRC8
  print('\n1. 测试 CRC8:');
  final headerData = Uint8List.fromList([0x00, 0x25, 0x00, 0x03, 0x04, 0x00, 0x00]);
  final crc8 = GTPProtocol.calculateCRC8(headerData);
  print('   输入: ${_formatHex(headerData)}');
  print('   计算结果: 0x${crc8.toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('   示例结果: 0xB2');
  print('   匹配: ${crc8 == 0xB2 ? "✓" : "✗"}');
  
  // 测试 CRC16 (payload CRC32 的高 16bit)
  print('\n2. 测试 CRC16 (Payload CRC32 高 16bit):');
  final payloadData = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00]);
  final crc16 = GTPProtocol.calculateCRC16(payloadData);
  print('   输入: ${_formatHex(payloadData)}');
  print('   计算结果: 0x${crc16.toRadixString(16).padLeft(4, '0').toUpperCase()}');
  print('   示例结果: 0xF71D (小端序: 1D F7)');
  print('   匹配: ${crc16 == 0xF71D ? "✓" : "✗"}');
  
  // 测试完整的 CRC32
  print('\n3. 测试 Payload CRC32:');
  final crc32 = GTPProtocol.calculateCRC32(payloadData.toList());
  print('   输入: ${_formatHex(payloadData)}');
  print('   计算结果: 0x${crc32.toRadixString(16).padLeft(8, '0').toUpperCase()}');
  print('   高 16bit: 0x${(crc32 >> 16).toRadixString(16).padLeft(4, '0').toUpperCase()}');
  
  // 测试 GTP CRC32
  print('\n4. 测试 GTP CRC32:');
  // 从 Version 到 Tail 的所有数据
  final gtpData = Uint8List.fromList([
    0x00, 0x25, 0x00, 0x03, 0x04, 0x00, 0x00, // Header
    0xB2, // CRC8
    0x23, 0x23, 0x05, 0x00, 0x1D, 0xF7, 0x04, 0x00, 0x00, 0x00, 0x09, 0x00, 0x00, 0x00, // CLI Header
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, // Payload
    0x40, 0x40, // Tail
  ]);
  final gtpCrc32 = GTPProtocol.calculateCRC32(gtpData.toList());
  print('   输入长度: ${gtpData.length} bytes');
  print('   计算结果: 0x${gtpCrc32.toRadixString(16).padLeft(8, '0').toUpperCase()}');
  print('   示例结果: 0x406B689F (小端序: 9F 68 6B 40)');
  print('   匹配: ${gtpCrc32 == 0x406B689F ? "✓" : "✗"}');
}

String _formatHex(Uint8List data) {
  return data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
}
