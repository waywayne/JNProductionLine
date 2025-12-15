import 'dart:typed_data';

void main() {
  print('分析示例数据包');
  print('=' * 80);
  
  // 示例 1: Exit Sleep Mode
  print('\n1. Exit Sleep Mode (Module ID: 5, Message ID: 4)');
  print('-' * 80);
  final exitSleepReq = 'D0D2C5C200250003040000B2232305001DF70400000009000000FFFFFFFFFFFFFFFF0040409F686B40';
  final exitSleepRsp = 'D0D2C5C2002000030400005923230500442104000200040012000000000040401786143E';
  
  print('请求:');
  analyzePacket(_hexToBytes(exitSleepReq), 'Exit Sleep Req');
  
  print('\n响应:');
  analyzePacket(_hexToBytes(exitSleepRsp), 'Exit Sleep Rsp');
  
  // 示例 2: Reboot
  print('\n\n2. Reboot (Module ID: 6, Message ID: 0)');
  print('-' * 80);
  final rebootReq = 'D0D2C5C2001E0003040000A72323060044F20000000002004800200440408E9ECB57';
  final rebootRsp = 'D0D2C5C2001C0003040000C923230600000000000200000048004040464474D4';
  
  print('请求:');
  analyzePacket(_hexToBytes(rebootReq), 'Reboot Req');
  
  print('\n响应:');
  analyzePacket(_hexToBytes(rebootRsp), 'Reboot Rsp');
  
  // 分析 CLI 字段 9
  print('\n\n3. CLI 字段 9 分析');
  print('-' * 80);
  analyzeField9(exitSleepReq, 'Exit Sleep Req');
  analyzeField9(rebootReq, 'Reboot Req');
}

void analyzePacket(Uint8List data, String label) {
  print('$label (${data.length} bytes):');
  
  if (data.length < 12) {
    print('  数据包太短');
    return;
  }
  
  final buffer = ByteData.view(data.buffer);
  
  // GTP Header
  print('  GTP Header:');
  print('    Preamble: ${_hex(data.sublist(0, 4))}');
  print('    Version: 0x${data[4].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('    Length: ${buffer.getUint16(5, Endian.little)} (0x${buffer.getUint16(5, Endian.little).toRadixString(16).padLeft(4, '0').toUpperCase()})');
  print('    Type: 0x${data[7].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('    FC: 0x${data[8].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('    Seq: ${buffer.getUint16(9, Endian.little)} (0x${buffer.getUint16(9, Endian.little).toRadixString(16).padLeft(4, '0').toUpperCase()})');
  print('    CRC8: 0x${data[11].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  
  if (data.length < 26) return;
  
  // CLI Message
  print('  CLI Message:');
  print('    Start: ${_hex(data.sublist(12, 14))}');
  print('    Module ID: ${buffer.getUint16(14, Endian.little)} (0x${buffer.getUint16(14, Endian.little).toRadixString(16).padLeft(4, '0').toUpperCase()})');
  print('    CRC: 0x${buffer.getUint16(16, Endian.little).toRadixString(16).padLeft(4, '0').toUpperCase()}');
  print('    Message ID: ${buffer.getUint16(18, Endian.little)} (0x${buffer.getUint16(18, Endian.little).toRadixString(16).padLeft(4, '0').toUpperCase()})');
  
  // 字段 9 (Add(1bit) + Type(3bit) + Reversed(4bit))
  final field9 = data[20];
  final ack = (field9 >> 7) & 0x01;
  final type = (field9 >> 4) & 0x07;
  final reversed = field9 & 0x0F;
  print('    字段9 (Add/Type/Reversed): 0x${field9.toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('      - ACK (bit 7): $ack');
  print('      - Type (bits 4-6): $type');
  print('      - Reversed (bits 0-3): $reversed');
  
  print('    Result: 0x${data[21].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('    Payload Length: ${buffer.getUint16(22, Endian.little)} (0x${buffer.getUint16(22, Endian.little).toRadixString(16).padLeft(4, '0').toUpperCase()})');
  print('    SN: ${buffer.getUint16(24, Endian.little)} (0x${buffer.getUint16(24, Endian.little).toRadixString(16).padLeft(4, '0').toUpperCase()})');
  
  final payloadLen = buffer.getUint16(22, Endian.little);
  if (data.length >= 26 + payloadLen) {
    print('    Payload: ${_hex(data.sublist(26, 26 + payloadLen))}');
    
    if (data.length >= 26 + payloadLen + 2) {
      print('    Tail: ${_hex(data.sublist(26 + payloadLen, 26 + payloadLen + 2))}');
    }
    
    if (data.length >= 26 + payloadLen + 2 + 4) {
      print('  GTP Trailer:');
      final crc32Offset = 26 + payloadLen + 2;
      print('    CRC32: 0x${buffer.getUint32(crc32Offset, Endian.little).toRadixString(16).padLeft(8, '0').toUpperCase()}');
    }
  }
}

void analyzeField9(String hexStr, String label) {
  final data = _hexToBytes(hexStr);
  if (data.length < 21) return;
  
  final field9 = data[20];
  final ack = (field9 >> 7) & 0x01;
  final type = (field9 >> 4) & 0x07;
  final reversed = field9 & 0x0F;
  
  print('$label:');
  print('  字段9: 0x${field9.toRadixString(16).padLeft(2, '0').toUpperCase()} = ${field9.toRadixString(2).padLeft(8, '0')}b');
  print('  ACK (bit 7): $ack ${ack == 0 ? "(请求)" : "(响应)"}');
  print('  Type (bits 4-6): $type ${_getTypeName(type)}');
  print('  Reversed (bits 0-3): $reversed');
}

String _getTypeName(int type) {
  switch (type) {
    case 0: return '(CMD)';
    case 1: return '(RES)';
    case 2: return '(IND)';
    default: return '(未知)';
  }
}

String _hex(Uint8List data) {
  return data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
}

Uint8List _hexToBytes(String hex) {
  final bytes = <int>[];
  for (int i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}
