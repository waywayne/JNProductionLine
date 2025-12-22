/// WiFi测试配置类
/// 包含WiFi测试相关的配置参数
class WiFiConfig {
  /// 默认SSID（可以从配置文件读取）
  static String defaultSSID = '';
  
  /// 默认密码（可以从配置文件读取）
  static String defaultPassword = '';
  
  /// WiFi测试选项常量
  static const int optStartTest = 0x00;      // 开始测试
  static const int optConnectAP = 0x01;      // 连接固定热点
  static const int optTestRSSI = 0x02;       // 测试RSSI
  static const int optGetMAC = 0x03;         // 获取MAC地址
  static const int optBurnMAC = 0x04;        // 烧录MAC地址
  static const int optEndTest = 0xFF;        // 结束WiFi测试
  
  /// MAC地址长度（包含\0）
  static const int macAddressLength = 18;
  
  /// 获取选项名称
  static String getOptionName(int opt) {
    switch (opt) {
      case optStartTest:
        return '开始测试';
      case optConnectAP:
        return '连接热点';
      case optTestRSSI:
        return '测试RSSI';
      case optGetMAC:
        return '获取MAC地址';
      case optBurnMAC:
        return '烧录MAC地址';
      case optEndTest:
        return '结束测试';
      default:
        return 'UNKNOWN';
    }
  }
  
  /// 将字符串转换为以\0结尾的字节数组
  static List<int> stringToBytes(String str) {
    // 使用List.from创建可变列表，因为codeUnits返回不可变列表
    List<int> bytes = List<int>.from(str.codeUnits);
    bytes.add(0); // 添加\0结尾
    return bytes;
  }
  
  /// 将以\0结尾的字节数组转换为字符串
  static String bytesToString(List<int> bytes) {
    // 找到\0的位置
    int nullIndex = bytes.indexOf(0);
    if (nullIndex >= 0) {
      bytes = bytes.sublist(0, nullIndex);
    }
    return String.fromCharCodes(bytes);
  }
}
