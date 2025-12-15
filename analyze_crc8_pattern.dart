import 'dart:typed_data';

void main() {
  print('分析示例中的 CRC8 计算规律');
  print('=' * 80);
  
  // 两个示例
  final examples = [
    {
      'name': 'Exit Sleep Mode',
      'hex': 'D0D2C5C200250003040000B2232305001DF70400000009000000FFFFFFFFFFFFFFFF0040409F686B40',
    },
    {
      'name': 'Reboot',
      'hex': 'D0D2C5C2001E0003040000A72323060044F20000000002004800200440408E9ECB57',
    },
  ];
  
  for (var example in examples) {
    final name = example['name'] as String;
    final hex = example['hex'] as String;
    final data = _hexToBytes(hex);
    
    print('\n$name:');
    print('-' * 80);
    
    // 提取 header 数据
    final version = data[4];
    final length = ByteData.view(data.buffer).getUint16(5, Endian.little);
    final type = data[7];
    final fc = data[8];
    final seq = ByteData.view(data.buffer).getUint16(9, Endian.little);
    final crc8 = data[11];
    
    print('Header 字段:');
    print('  Version: 0x${version.toRadixString(16).padLeft(2, '0').toUpperCase()} ($version)');
    print('  Length: 0x${length.toRadixString(16).padLeft(4, '0').toUpperCase()} ($length)');
    print('  Type: 0x${type.toRadixString(16).padLeft(2, '0').toUpperCase()} ($type)');
    print('  FC: 0x${fc.toRadixString(16).padLeft(2, '0').toUpperCase()} ($fc)');
    print('  Seq: 0x${seq.toRadixString(16).padLeft(4, '0').toUpperCase()} ($seq)');
    print('  CRC8: 0x${crc8.toRadixString(16).padLeft(2, '0').toUpperCase()} ($crc8)');
    
    // Header 原始字节
    final headerBytes = data.sublist(4, 11);
    print('\nHeader 原始字节 (7 bytes): ${_formatHex(headerBytes)}');
    
    // 尝试各种简单运算
    print('\n尝试简单运算:');
    
    // 1. 简单求和
    int sum = 0;
    for (var b in headerBytes) {
      sum += b;
    }
    print('  求和: ${sum} (0x${sum.toRadixString(16).padLeft(2, '0').toUpperCase()})');
    print('  求和 & 0xFF: ${sum & 0xFF} (0x${(sum & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase()}) ${(sum & 0xFF) == crc8 ? "✓" : "✗"}');
    print('  求和取反 & 0xFF: ${(~sum) & 0xFF} (0x${((~sum) & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase()}) ${((~sum) & 0xFF) == crc8 ? "✓" : "✗"}');
    print('  求和补码 & 0xFF: ${(0x100 - (sum & 0xFF)) & 0xFF} (0x${((0x100 - (sum & 0xFF)) & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase()}) ${((0x100 - (sum & 0xFF)) & 0xFF) == crc8 ? "✓" : "✗"}');
    
    // 2. 异或
    int xor = 0;
    for (var b in headerBytes) {
      xor ^= b;
    }
    print('  异或: ${xor} (0x${xor.toRadixString(16).padLeft(2, '0').toUpperCase()}) ${xor == crc8 ? "✓" : "✗"}');
    print('  异或取反: ${(~xor) & 0xFF} (0x${((~xor) & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase()}) ${((~xor) & 0xFF) == crc8 ? "✓" : "✗"}');
    
    // 3. 尝试不同的 CRC8 多项式
    print('\n尝试不同的 CRC8 多项式:');
    final polys = [0x07, 0x09, 0x1D, 0x31, 0x39, 0x9B, 0xA6, 0xD5, 0xEA];
    
    for (var poly in polys) {
      for (var init in [0x00, 0xFF]) {
        for (var xorOut in [0x00, 0xFF]) {
          final result = _calculateCRC8(headerBytes.toList(), poly, init, xorOut);
          if (result == crc8) {
            print('  ✓ FOUND: poly=0x${poly.toRadixString(16).padLeft(2, '0').toUpperCase()}, init=0x${init.toRadixString(16).padLeft(2, '0').toUpperCase()}, xorOut=0x${xorOut.toRadixString(16).padLeft(2, '0').toUpperCase()} => 0x${result.toRadixString(16).padLeft(2, '0').toUpperCase()}');
          }
        }
      }
    }
    
    // 4. 尝试查找表方法
    print('\n尝试反向查找规律:');
    
    // 计算每个字节对 CRC8 的贡献
    print('  逐字节分析:');
    for (int i = 0; i < headerBytes.length; i++) {
      print('    Byte $i: 0x${headerBytes[i].toRadixString(16).padLeft(2, '0').toUpperCase()} (${headerBytes[i]})');
    }
  }
  
  // 对比两个示例，寻找规律
  print('\n\n对比两个示例:');
  print('=' * 80);
  
  final data1 = _hexToBytes(examples[0]['hex'] as String);
  final data2 = _hexToBytes(examples[1]['hex'] as String);
  
  final header1 = data1.sublist(4, 11);
  final header2 = data2.sublist(4, 11);
  final crc1 = data1[11];
  final crc2 = data2[11];
  
  print('示例 1: ${_formatHex(header1)} => CRC8: 0x${crc1.toRadixString(16).padLeft(2, '0').toUpperCase()} ($crc1)');
  print('示例 2: ${_formatHex(header2)} => CRC8: 0x${crc2.toRadixString(16).padLeft(2, '0').toUpperCase()} ($crc2)');
  
  print('\n字节差异:');
  for (int i = 0; i < 7; i++) {
    if (header1[i] != header2[i]) {
      print('  位置 $i: 0x${header1[i].toRadixString(16).padLeft(2, '0').toUpperCase()} vs 0x${header2[i].toRadixString(16).padLeft(2, '0').toUpperCase()}');
    }
  }
  
  print('\nCRC8 差异: 0x${crc1.toRadixString(16).padLeft(2, '0').toUpperCase()} vs 0x${crc2.toRadixString(16).padLeft(2, '0').toUpperCase()} (差值: ${(crc1 - crc2).abs()})');
}

int _calculateCRC8(List<int> data, int poly, int init, int xorOut) {
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
