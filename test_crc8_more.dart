import 'dart:typed_data';

void main() {
  final data = Uint8List.fromList([0x00, 0x25, 0x00, 0x03, 0x04, 0x00, 0x00]);
  final expected = 0xB2;
  
  print('测试更多 CRC8 多项式');
  print('输入: ${data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}');
  print('期望: 0x${expected.toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('=' * 60);
  
  // Common CRC8 polynomials
  final polys = [
    0x07, 0x09, 0x1D, 0x31, 0x39, 0x9B, 0xA6, 0xD5, 0xEA
  ];
  
  for (var poly in polys) {
    for (var init in [0x00, 0xFF]) {
      for (var xorOut in [0x00, 0xFF]) {
        final crc = calculateCRC8(data, poly, init, xorOut);
        if (crc == expected) {
          print('✓ FOUND: poly=0x${poly.toRadixString(16).padLeft(2, '0').toUpperCase()}, init=0x${init.toRadixString(16).padLeft(2, '0').toUpperCase()}, xorOut=0x${xorOut.toRadixString(16).padLeft(2, '0').toUpperCase()} => 0x${crc.toRadixString(16).padLeft(2, '0').toUpperCase()}');
        }
      }
    }
  }
  
  // 尝试简单的校验和变体
  print('\n尝试校验和变体:');
  
  // 累加和取反
  int sum = 0;
  for (var b in data) {
    sum = (sum + b) & 0xFF;
  }
  int notSum = (~sum) & 0xFF;
  print('累加和取反: 0x${notSum.toRadixString(16).padLeft(2, '0').toUpperCase()} ${notSum == expected ? "✓" : "✗"}');
  
  // 累加和的补码
  int complement = (0x100 - sum) & 0xFF;
  print('累加和补码: 0x${complement.toRadixString(16).padLeft(2, '0').toUpperCase()} ${complement == expected ? "✓" : "✗"}');
  
  // 异或后取反
  int xor = 0;
  for (var b in data) {
    xor ^= b;
  }
  int notXor = (~xor) & 0xFF;
  print('异或后取反: 0x${notXor.toRadixString(16).padLeft(2, '0').toUpperCase()} ${notXor == expected ? "✓" : "✗"}');
}

int calculateCRC8(Uint8List data, int poly, int init, int xorOut) {
  int crc = init;
  
  for (int byte in data) {
    crc ^= byte;
    for (int i = 0; i < 8; i++) {
      if ((crc & 0x80) != 0) {
        crc = (crc << 1) ^ poly;
      } else {
        crc = crc << 1;
      }
    }
  }
  
  return (crc ^ xorOut) & 0xFF;
}
