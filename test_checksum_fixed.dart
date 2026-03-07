String _toBase36(int number, int length) {
  const base36Chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  
  if (number == 0) return '0' * length;
  
  String result = '';
  while (number > 0) {
    result = base36Chars[number % 36] + result;
    number ~/= 36;
  }
  
  return result.padLeft(length, '0');
}

String _calculateChecksum(String baseSN) {
  int sum = 0;
  for (int i = 0; i < baseSN.length; i++) {
    sum += baseSN.codeUnitAt(i);
  }
  
  return _toBase36(sum % (36 * 36 * 36 * 36), 4);
}

void main() {
  print('测试 1: 637160307100001');
  final baseSN1 = '637160307100001';
  int sum1 = 0;
  for (int i = 0; i < baseSN1.length; i++) {
    sum1 += baseSN1.codeUnitAt(i);
  }
  print('  Sum: $sum1');
  print('  Sum % (36^4): ${sum1 % (36 * 36 * 36 * 36)}');
  final checksum1 = _calculateChecksum(baseSN1);
  print('  Checksum: $checksum1');
  print('  Full SN: $baseSN1$checksum1');
  print('  Expected: 63716030710000100KZ');
  print('  Match: ${baseSN1 + checksum1 == '63716030710000100KZ' ? "✅" : "❌"}');
  
  print('\n测试 2: 637160307100003');
  final baseSN2 = '637160307100003';
  int sum2 = 0;
  for (int i = 0; i < baseSN2.length; i++) {
    sum2 += baseSN2.codeUnitAt(i);
  }
  print('  Sum: $sum2');
  print('  Sum % (36^4): ${sum2 % (36 * 36 * 36 * 36)}');
  final checksum2 = _calculateChecksum(baseSN2);
  print('  Checksum: $checksum2');
  print('  Full SN: $baseSN2$checksum2');
  print('  Expected: 63716030710000300L1');
  print('  Match: ${baseSN2 + checksum2 == '63716030710000300L1' ? "✅" : "❌"}');
}
