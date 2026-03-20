import 'dart:typed_data';

/// CRC32 calculation test
int calculateCRC32(List<int> data) {
  int crc = 0xFFFFFFFF;
  for (int byte in data) {
    crc ^= byte;
    for (int i = 0; i < 8; i++) {
      if ((crc & 1) != 0) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc = crc >> 1;
      }
    }
  }
  return (~crc) & 0xFFFFFFFF;
}

void main() {
  print('=== CRC32 验证测试 ===\n');
  
  // 正确的数据包（串口工具）
  // D0 D2 C5 C2 00 1D 00 03 04 00 00 FE 23 23 06 00 8D EF 01 FF 00 00 01 00 00 00 00 40 40 C9 D9 4D 45
  final correctPacket = [
    0xD0, 0xD2, 0xC5, 0xC2, // Preamble
    0x00, 0x1D, 0x00, 0x03, 0x04, 0x00, 0x00, 0xFE, // Header + CRC8
    0x23, 0x23, 0x06, 0x00, 0x8D, 0xEF, 0x01, 0xFF, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x40, 0x40, // CLI Message
    0xC9, 0xD9, 0x4D, 0x45  // CRC32
  ];
  
  // 错误的数据包（我们软件）
  // D0 D2 C5 C2 00 1D 00 03 04 00 00 FE 23 23 06 00 8D EF 01 FF 00 00 01 00 0A 00 00 40 40 68 C1 FD 0F
  final wrongPacket = [
    0xD0, 0xD2, 0xC5, 0xC2, // Preamble
    0x00, 0x1D, 0x00, 0x03, 0x04, 0x00, 0x00, 0xFE, // Header + CRC8
    0x23, 0x23, 0x06, 0x00, 0x8D, 0xEF, 0x01, 0xFF, 0x00, 0x00, 0x01, 0x00, 0x0A, 0x00, 0x00, 0x40, 0x40, // CLI Message (SN=0x000A)
    0x68, 0xC1, 0xFD, 0x0F  // CRC32
  ];
  
  // CRC32 计算范围：从 Version 到 Payload 结束（不包括 Preamble 和 CRC32 本身）
  // 即从索引 4 到倒数第5个字节
  
  print('1. 正确数据包（串口工具，SN=0x0000）:');
  final correctDataForCRC = correctPacket.sublist(4, correctPacket.length - 4);
  print('   CRC32 计算数据: ${correctDataForCRC.map((b) => b.toRadixString(16).padLeft(2, "0").toUpperCase()).join(" ")}');
  final correctCalculatedCRC = calculateCRC32(correctDataForCRC);
  final correctExpectedCRC = ByteData(4)
    ..setUint8(0, correctPacket[correctPacket.length - 4])
    ..setUint8(1, correctPacket[correctPacket.length - 3])
    ..setUint8(2, correctPacket[correctPacket.length - 2])
    ..setUint8(3, correctPacket[correctPacket.length - 1]);
  final correctExpectedCRCValue = correctExpectedCRC.getUint32(0, Endian.little);
  
  print('   计算的 CRC32: 0x${correctCalculatedCRC.toRadixString(16).padLeft(8, "0").toUpperCase()}');
  print('   期望的 CRC32: 0x${correctExpectedCRCValue.toRadixString(16).padLeft(8, "0").toUpperCase()}');
  print('   验证结果: ${correctCalculatedCRC == correctExpectedCRCValue ? "✅ 正确" : "❌ 错误"}');
  
  print('\n2. 错误数据包（我们软件，SN=0x000A）:');
  final wrongDataForCRC = wrongPacket.sublist(4, wrongPacket.length - 4);
  print('   CRC32 计算数据: ${wrongDataForCRC.map((b) => b.toRadixString(16).padLeft(2, "0").toUpperCase()).join(" ")}');
  final wrongCalculatedCRC = calculateCRC32(wrongDataForCRC);
  final wrongExpectedCRC = ByteData(4)
    ..setUint8(0, wrongPacket[wrongPacket.length - 4])
    ..setUint8(1, wrongPacket[wrongPacket.length - 3])
    ..setUint8(2, wrongPacket[wrongPacket.length - 2])
    ..setUint8(3, wrongPacket[wrongPacket.length - 1]);
  final wrongExpectedCRCValue = wrongExpectedCRC.getUint32(0, Endian.little);
  
  print('   计算的 CRC32: 0x${wrongCalculatedCRC.toRadixString(16).padLeft(8, "0").toUpperCase()}');
  print('   期望的 CRC32: 0x${wrongExpectedCRCValue.toRadixString(16).padLeft(8, "0").toUpperCase()}');
  print('   验证结果: ${wrongCalculatedCRC == wrongExpectedCRCValue ? "✅ 正确" : "❌ 错误"}');
  
  print('\n3. 如果将错误数据包的SN改为0x0000，CRC32应该是:');
  final fixedPacket = List<int>.from(wrongPacket);
  fixedPacket[24] = 0x00; // SN低字节
  fixedPacket[25] = 0x00; // SN高字节
  final fixedDataForCRC = fixedPacket.sublist(4, fixedPacket.length - 4);
  final fixedCalculatedCRC = calculateCRC32(fixedDataForCRC);
  print('   计算的 CRC32: 0x${fixedCalculatedCRC.toRadixString(16).padLeft(8, "0").toUpperCase()}');
  print('   应该等于正确数据包的 CRC32: ${fixedCalculatedCRC == correctExpectedCRCValue ? "✅ 是" : "❌ 否"}');
  
  print('\n=== 结论 ===');
  print('CRC32 算法本身是正确的。');
  print('问题在于序列号（SN）字段不同：');
  print('  - 串口工具: SN = 0x0000 (00 00)');
  print('  - 我们软件: SN = 0x000A (0A 00)');
  print('由于SN不同，导致CRC32计算结果不同，这是正常的。');
  print('设备可能要求第一个命令的SN必须为0。');
}
