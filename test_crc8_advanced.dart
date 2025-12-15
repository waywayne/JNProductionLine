import 'dart:typed_data';

void main() {
  print('高级 CRC8 算法测试');
  print('=' * 80);
  
  // 两个示例
  final examples = [
    {'data': [0x00, 0x25, 0x00, 0x03, 0x04, 0x00, 0x00], 'expected': 0xB2, 'name': 'Exit Sleep'},
    {'data': [0x00, 0x1E, 0x00, 0x03, 0x04, 0x00, 0x00], 'expected': 0xA7, 'name': 'Reboot'},
  ];
  
  // 测试所有可能的多项式
  final polys = [
    0x07, 0x09, 0x1D, 0x31, 0x39, 0x9B, 0xA6, 0xD5, 0xEA,
    0x8C, 0x97, 0x2F, 0x1D, 0xA7, 0xB8, 0xC6, 0xD8, 0xE5,
  ];
  
  print('\n测试所有组合 (poly × init × xorOut × refIn × refOut):');
  print('-' * 80);
  
  var found = false;
  
  for (var poly in polys) {
    for (var init in [0x00, 0xFF, 0x55, 0xAA]) {
      for (var xorOut in [0x00, 0xFF, 0x55, 0xAA]) {
        for (var refIn in [false, true]) {
          for (var refOut in [false, true]) {
            // 测试两个示例
            var match = true;
            for (var example in examples) {
              final data = example['data'] as List<int>;
              final expected = example['expected'] as int;
              final result = _calculateCRC8(data, poly, init, xorOut, refIn, refOut);
              
              if (result != expected) {
                match = false;
                break;
              }
            }
            
            if (match) {
              found = true;
              print('✓ FOUND!');
              print('  Poly: 0x${poly.toRadixString(16).padLeft(2, '0').toUpperCase()}');
              print('  Init: 0x${init.toRadixString(16).padLeft(2, '0').toUpperCase()}');
              print('  XorOut: 0x${xorOut.toRadixString(16).padLeft(2, '0').toUpperCase()}');
              print('  RefIn: $refIn');
              print('  RefOut: $refOut');
              
              // 验证两个示例
              print('\n  验证:');
              for (var example in examples) {
                final data = example['data'] as List<int>;
                final expected = example['expected'] as int;
                final name = example['name'] as String;
                final result = _calculateCRC8(data, poly, init, xorOut, refIn, refOut);
                print('    $name: 0x${result.toRadixString(16).padLeft(2, '0').toUpperCase()} (期望: 0x${expected.toRadixString(16).padLeft(2, '0').toUpperCase()}) ${result == expected ? "✓" : "✗"}');
              }
              print('');
            }
          }
        }
      }
    }
  }
  
  if (!found) {
    print('未找到匹配的 CRC8 算法');
    
    // 尝试查找表方法
    print('\n\n尝试查找表方法:');
    print('-' * 80);
    
    // 如果是查找表，我们需要更多示例来推导
    print('需要更多示例数据包来推导查找表');
  }
}

int _calculateCRC8(List<int> data, int poly, int init, int xorOut, bool refIn, bool refOut) {
  int crc = init;
  
  for (int byte in data) {
    int b = refIn ? _reflect8(byte) : byte;
    crc ^= b;
    
    for (int i = 0; i < 8; i++) {
      if ((crc & 0x80) != 0) {
        crc = (crc << 1) ^ poly;
      } else {
        crc = crc << 1;
      }
    }
  }
  
  crc = crc & 0xFF;
  
  if (refOut) {
    crc = _reflect8(crc);
  }
  
  return (crc ^ xorOut) & 0xFF;
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
