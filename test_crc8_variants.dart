import 'dart:typed_data';

void main() {
  final data = Uint8List.fromList([0x00, 0x25, 0x00, 0x03, 0x04, 0x00, 0x00]);
  final expected = 0xB2;
  
  print('测试不同的 CRC8 算法');
  print('输入: ${data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}');
  print('期望: 0x${expected.toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('=' * 60);
  
  // Test different CRC8 variants
  testCRC8('CRC8 (poly=0x07, init=0x00)', data, 0x07, 0x00, false, expected);
  testCRC8('CRC8 (poly=0x07, init=0xFF)', data, 0x07, 0xFF, false, expected);
  testCRC8('CRC8-CCITT (poly=0x07, init=0x00)', data, 0x07, 0x00, true, expected);
  testCRC8('CRC8-CCITT (poly=0x07, init=0xFF)', data, 0x07, 0xFF, true, expected);
  testCRC8('CRC8-MAXIM (poly=0x31, init=0x00)', data, 0x31, 0x00, false, expected);
  testCRC8('CRC8-MAXIM (poly=0x31, init=0xFF)', data, 0x31, 0xFF, false, expected);
  testCRC8('CRC8-ROHC (poly=0x07, init=0xFF, xorout=0xFF)', data, 0x07, 0xFF, false, expected, xorOut: 0xFF);
  testCRC8('CRC8-ITU (poly=0x07, init=0x00, xorout=0x55)', data, 0x07, 0x00, false, expected, xorOut: 0x55);
  testCRC8('CRC8-ITU (poly=0x07, init=0x55, xorout=0x55)', data, 0x07, 0x55, false, expected, xorOut: 0x55);
  
  // Try summing bytes
  print('\n简单求和:');
  int sum = 0;
  for (var b in data) {
    sum = (sum + b) & 0xFF;
  }
  print('  结果: 0x${sum.toRadixString(16).padLeft(2, '0').toUpperCase()} ${sum == expected ? "✓" : "✗"}');
  
  // Try XOR
  print('\n简单异或:');
  int xor = 0;
  for (var b in data) {
    xor ^= b;
  }
  print('  结果: 0x${xor.toRadixString(16).padLeft(2, '0').toUpperCase()} ${xor == expected ? "✓" : "✗"}');
}

void testCRC8(String name, Uint8List data, int poly, int init, bool refIn, int expected, {int xorOut = 0}) {
  int crc = init;
  
  for (int byte in data) {
    if (refIn) {
      byte = _reflect8(byte);
    }
    crc ^= byte;
    for (int i = 0; i < 8; i++) {
      if ((crc & 0x80) != 0) {
        crc = (crc << 1) ^ poly;
      } else {
        crc = crc << 1;
      }
    }
  }
  
  crc = (crc ^ xorOut) & 0xFF;
  
  print('$name: 0x${crc.toRadixString(16).padLeft(2, '0').toUpperCase()} ${crc == expected ? "✓" : "✗"}');
}

int _reflect8(int value) {
  int result = 0;
  for (int i = 0; i < 8; i++) {
    if ((value & (1 << i)) != 0) {
      result |= 1 << (7 - i);
    }
  }
  return result;
}
