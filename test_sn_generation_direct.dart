String _calculateChecksum(String baseSN) {
  // 简单的校验算法：对所有字符的 ASCII 值求和，然后转 Base36
  int sum = 0;
  for (int i = 0; i < baseSN.length; i++) {
    sum += baseSN.codeUnitAt(i) * (i + 1); // 加权求和
  }
  
  // 转 Base36（0-9, A-Z）
  final checksum = sum.toRadixString(36).toUpperCase();
  
  print('  Sum: $sum');
  print('  Base36: $checksum');
  print('  Length: ${checksum.length}');
  
  // 补齐到 4 位
  final result = checksum.padLeft(4, '0').substring(checksum.length > 4 ? checksum.length - 4 : 0);
  print('  After padLeft(4, "0"): ${checksum.padLeft(4, '0')}');
  print('  Substring start: ${checksum.length > 4 ? checksum.length - 4 : 0}');
  print('  Final: $result');
  
  return result;
}

void main() {
  print('测试基础 SN: 637160307100001');
  final checksum1 = _calculateChecksum('637160307100001');
  print('结果: $checksum1\n');
  
  print('测试基础 SN: 637160307100003');
  final checksum2 = _calculateChecksum('637160307100003');
  print('结果: $checksum2');
}
