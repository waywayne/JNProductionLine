void main() {
  // 测试当前的错误逻辑
  final checksum = '4KW'; // Base36 结果
  
  print('原始校验码: $checksum');
  print('长度: ${checksum.length}');
  
  // 错误的逻辑
  final wrong = checksum.padLeft(4, '0').substring(checksum.length > 4 ? checksum.length - 4 : 0);
  print('错误逻辑结果: $wrong');
  
  // 正确的逻辑
  final correct = checksum.length > 4 
      ? checksum.substring(checksum.length - 4) 
      : checksum.padLeft(4, '0');
  print('正确逻辑结果: $correct');
  
  print('\n--- 测试长度 > 4 的情况 ---');
  final longChecksum = '12345';
  print('原始: $longChecksum');
  print('错误逻辑: ${longChecksum.padLeft(4, '0').substring(longChecksum.length > 4 ? longChecksum.length - 4 : 0)}');
  print('正确逻辑: ${longChecksum.length > 4 ? longChecksum.substring(longChecksum.length - 4) : longChecksum.padLeft(4, '0')}');
}
