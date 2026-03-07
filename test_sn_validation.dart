void testSN(String sn) {
  
  print('SN 码: $sn');
  print('长度: ${sn.length}');
  
  // 提取基础 SN 和校验码
  final baseSN = sn.substring(0, 15);
  final checksum = sn.substring(15);
  
  print('基础 SN: $baseSN');
  print('校验码: $checksum');
  
  // 计算校验码
  int sum = 0;
  for (int i = 0; i < baseSN.length; i++) {
    final charCode = baseSN.codeUnitAt(i);
    final weighted = charCode * (i + 1);
    sum += weighted;
    print('字符[$i]: ${baseSN[i]} (ASCII: $charCode) × ${i + 1} = $weighted, 累计: $sum');
  }
  
  // 转 Base36
  final calculatedChecksum = sum.toRadixString(36).toUpperCase();
  print('\n总和: $sum');
  print('Base36: $calculatedChecksum');
  
  // 补齐到 4 位
  final finalChecksum = calculatedChecksum.padLeft(4, '0').substring(
    calculatedChecksum.length > 4 ? calculatedChecksum.length - 4 : 0
  );
  
  print('最终校验码: $finalChecksum');
  print('读取的校验码: $checksum');
  print('校验结果: ${finalChecksum == checksum ? "✅ 通过" : "❌ 失败"}');
  
  // 分析 SN 结构
  print('\n=== SN 结构分析 ===');
  print('产品线: ${sn.substring(0, 3)}');
  print('工厂: ${sn.substring(3, 4)}');
  print('日期: ${sn.substring(4, 9)}');
  print('产线: ${sn.substring(9, 10)}');
  print('流水号: ${sn.substring(10, 15)}');
  print('校验码: ${sn.substring(15)}');
}

void main() {
  print('========================================');
  print('测试 1: 读取到的 SN 码');
  print('========================================');
  testSN('63716030710000100KZ');
  
  print('\n========================================');
  print('测试 2: 新生成的 SN 码');
  print('========================================');
  testSN('63716030710000300L1');
}
