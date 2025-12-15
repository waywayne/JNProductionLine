import 'dart:typed_data';

/// GTP (General Transport Protocol) implementation
/// Based on the protocol specification from the provided documentation
class GTPProtocol {
  // GTP Constants
  static const int preamble = 0xC2C5D2D0; // 固定前导码 0xC2C5D2D0
  static const int version = 0x00; // 版本号 0x00
  static const int typeCliCommand = 0x03; // Type: CLI命令
  
  /// Calculate CRC8 for GTP header (Version, Length, Type, FC, Seq)
  /// Algorithm: CRC-8/MAXIM
  /// Poly: 0x31, Init: 0xFF, XorOut: 0xFF, RefIn: true, RefOut: true
  static int calculateCRC8(List<int> data) {
    int crc = 0xFF; // Init value
    
    for (int byte in data) {
      // Reflect input byte
      int reflectedByte = _reflect8(byte);
      crc ^= reflectedByte;
      
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x80) != 0) {
          crc = (crc << 1) ^ 0x31; // Poly
        } else {
          crc = crc << 1;
        }
      }
    }
    
    crc = crc & 0xFF;
    
    // Reflect output
    crc = _reflect8(crc);
    
    // XorOut
    return (crc ^ 0xFF) & 0xFF;
  }
  
  /// Reflect 8 bits
  static int _reflect8(int value) {
    int result = 0;
    for (int i = 0; i < 8; i++) {
      if ((value & (1 << i)) != 0) {
        result |= 1 << (7 - i);
      }
    }
    return result;
  }
  
  /// Calculate CRC16 for CLI payload (CRC32 的低 16bit)
  static int calculateCRC16(List<int> data) {
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
    // Return low 16 bits (not high 16 bits!)
    return (~crc) & 0xFFFF;
  }
  
  /// Calculate CRC32 checksum
  static int calculateCRC32(List<int> data) {
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
  
  /// Build GTP packet
  /// Returns the complete GTP packet as bytes
  static Uint8List buildGTPPacket(Uint8List cliPayload, {int? moduleId, int? messageId, int? sequenceNumber}) {
    // Build CLI message first
    Uint8List cliMessage = buildCLIMessage(cliPayload, moduleId: moduleId, messageId: messageId, sequenceNumber: sequenceNumber);
    
    // Calculate total length
    // Preamble(4) + Header(Version(1) + Length(2) + Type(1) + FC(1) + Seq(2)) + CRC8(1) + Payload + CRC32(4)
    int headerLength = 1 + 2 + 1 + 1 + 2; // Version + Length + Type + FC + Seq = 7 bytes
    int totalLength = 4 + headerLength + 1 + cliMessage.length + 4;
    
    ByteData buffer = ByteData(totalLength);
    int offset = 0;
    
    // 1. Preamble (4 bytes) - 0xC2C5D2D0
    buffer.setUint32(offset, preamble, Endian.little);
    offset += 4;
    
    // 2. Version (1 byte)
    buffer.setUint8(offset, version);
    int headerStart = offset;
    offset += 1;
    
    // 3. Length (2 bytes) - 从 Version 到 CRC32 之前的所有字节（包含 Length 字段本身）
    // Length = Version(1) + Length(2) + Type(1) + FC(1) + Seq(2) + CRC8(1) + Payload + CRC32(4)
    // 即 headerLength + 1 + cliMessage.length + 4
    int lengthField = headerLength + 1 + cliMessage.length + 4;
    buffer.setUint16(offset, lengthField, Endian.little);
    offset += 2;
    
    // 4. Type (1 byte)
    buffer.setUint8(offset, typeCliCommand);
    offset += 1;
    
    // 5. FC (1 byte) - 0x04
    buffer.setUint8(offset, 0x04);
    offset += 1;
    
    // 6. Seq (2 bytes) - Sequence number 0x0000
    buffer.setUint16(offset, 0x0000, Endian.little);
    offset += 2;
    
    // 7. CRC8 - Calculate from header (Version, Length, Type, FC, Seq)
    List<int> headerData = buffer.buffer.asUint8List(headerStart, headerLength);
    int crc8 = calculateCRC8(headerData);
    buffer.setUint8(offset, crc8);
    offset += 1;
    
    // 8. Payload (CLI Message)
    for (int i = 0; i < cliMessage.length; i++) {
      buffer.setUint8(offset + i, cliMessage[i]);
    }
    offset += cliMessage.length;
    
    // 9. CRC32 (4 bytes) - Calculate from header(Version,Length,Type,FC,Seq), CRC8, Payload
    List<int> dataForCRC = buffer.buffer.asUint8List(headerStart, offset - headerStart);
    int crc32 = calculateCRC32(dataForCRC);
    buffer.setUint32(offset, crc32, Endian.little);
    
    return buffer.buffer.asUint8List();
  }
  
  /// Build CLI message
  /// Module ID: 模块ID, Message ID: 消息ID
  static Uint8List buildCLIMessage(Uint8List payload, {int? moduleId, int? messageId, int? sequenceNumber}) {
    // CLI structure: Start(2) + Module ID(2) + CRC(2) + Message ID(2) + Flags(1) + Result(1) + Length(2) + SN(2) + Payload + Tail(2)
    int cliLength = 2 + 2 + 2 + 2 + 1 + 1 + 2 + 2 + payload.length + 2;
    ByteData buffer = ByteData(cliLength);
    int offset = 0;
    
    // 1. Start (2 bytes) - 固定起始 0x2323
    buffer.setUint16(offset, 0x2323, Endian.little);
    offset += 2;
    
    // 2. Module ID (2 bytes) - 模块ID
    buffer.setUint16(offset, moduleId ?? 0x0000, Endian.little);
    offset += 2;
    
    // 3. CRC (2 bytes) - placeholder, will calculate later (计算 payload 部分 CRC32 取高16bit)
    int crcOffset = offset;
    buffer.setUint16(offset, 0x0000, Endian.little);
    offset += 2;
    
    // 4. Message ID (2 bytes) - 消息ID, Little Endian
    buffer.setUint16(offset, messageId ?? 0x0000, Endian.little);
    offset += 2;
    
    // 5. ACK(1bit) + Type(3bit) + Reversed(4bit) - Combined into 1 byte
    // ACK: bit 7 (0=command, 1=response)
    // Type: bits 4-6 (0 CMD 1RES2IND)
    // Reversed: bits 0-3 (reserved)
    buffer.setUint8(offset, 0x00);
    offset += 1;
    
    // 7. Result (1 byte) - 用于上行时返回结果或状态
    buffer.setUint8(offset, 0x00);
    offset += 1;
    
    // 8. Length (2 bytes) - 消息 payload 的长度, Little Endian
    buffer.setUint16(offset, payload.length, Endian.little);
    offset += 2;
    
    // 9. SN (2 bytes) - 消息序号，每发一条消息序号+1
    buffer.setUint16(offset, sequenceNumber ?? 0x0000, Endian.little);
    offset += 2;
    
    // 10. Payload (消息参数)
    int payloadStart = offset;
    for (int i = 0; i < payload.length; i++) {
      buffer.setUint8(offset + i, payload[i]);
    }
    offset += payload.length;
    
    // 11. Tail (2 bytes) - 固定结束 0x4040 (little endian)
    buffer.setUint16(offset, 0x4040, Endian.little);
    offset += 2;
    
    // Calculate CRC16 for payload part (取高16bit)
    List<int> payloadForCRC = buffer.buffer.asUint8List(payloadStart, payload.length);
    int crc16 = calculateCRC16(payloadForCRC);
    buffer.setUint16(crcOffset, crc16, Endian.little);
    
    return buffer.buffer.asUint8List();
  }
  
  /// Parse GTP response
  static Map<String, dynamic>? parseGTPResponse(Uint8List data) {
    if (data.length < 16) return null;
    
    ByteData buffer = ByteData.sublistView(data);
    
    // Check preamble
    int receivedPreamble = buffer.getUint32(0, Endian.big);
    if (receivedPreamble != preamble) return null;
    
    int offset = 4;
    int version = buffer.getUint8(offset);
    offset += 1;
    
    int length = buffer.getUint16(offset, Endian.little);
    offset += 2;
    
    int type = buffer.getUint8(offset);
    offset += 1;
    
    int fc = buffer.getUint8(offset);
    offset += 1;
    
    // Seq (3 bytes)
    offset += 3;
    
    // Payload
    int payloadLength = length - 8; // Subtract Version(1) + Length(2) + Type(1) + FC(1) + Seq(3)
    if (data.length < offset + payloadLength + 4) return null;
    
    Uint8List payload = data.sublist(offset, offset + payloadLength);
    offset += payloadLength;
    
    // CRC32
    int receivedCRC32 = buffer.getUint32(offset, Endian.little);
    
    // Verify CRC32
    List<int> dataForCRC = data.sublist(4, offset);
    int calculatedCRC32 = calculateCRC32(dataForCRC);
    
    if (receivedCRC32 != calculatedCRC32) {
      return {'error': 'CRC32 mismatch'};
    }
    
    // Parse CLI response if type is CLI
    if (type == typeCliCommand) {
      return parseCLIResponse(payload);
    }
    
    return {
      'version': version,
      'type': type,
      'fc': fc,
      'payload': payload,
    };
  }
  
  /// Parse CLI response
  static Map<String, dynamic>? parseCLIResponse(Uint8List data) {
    if (data.length < 15) return null;
    
    ByteData buffer = ByteData.sublistView(data);
    int offset = 0;
    
    // Start
    int start = buffer.getUint8(offset);
    if (start != 0x23) return null;
    offset += 1;
    
    // Module ID (3 bytes)
    int moduleId = (buffer.getUint8(offset) << 16) | 
                   (buffer.getUint8(offset + 1) << 8) | 
                   buffer.getUint8(offset + 2);
    offset += 3;
    
    // CRC
    int crc = buffer.getUint8(offset);
    offset += 1;
    
    // Message ID (2 bytes)
    int messageId = buffer.getUint16(offset, Endian.little);
    offset += 2;
    
    // ACK
    int ack = buffer.getUint8(offset);
    offset += 1;
    
    // Msg Level
    int msgLevel = buffer.getUint8(offset);
    offset += 1;
    
    // High Freq
    int highFreq = buffer.getUint8(offset);
    offset += 1;
    
    // Result
    int result = buffer.getUint8(offset);
    offset += 1;
    
    // Length
    int length = buffer.getUint16(offset, Endian.little);
    offset += 2;
    
    // SN
    int sn = buffer.getUint8(offset);
    offset += 1;
    
    // Payload
    Uint8List payload = data.sublist(offset, offset + length);
    
    return {
      'moduleId': moduleId,
      'messageId': messageId,
      'ack': ack,
      'result': result,
      'length': length,
      'sn': sn,
      'payload': payload,
    };
  }
}
