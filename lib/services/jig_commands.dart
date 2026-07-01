/// 治具串口指令常量
/// 通信格式: N81, 115200 baud
/// 发送: <COMMAND>\r\n
/// 成功: <COMMAND>_OK\r\n
/// 失败: XXX_ERROR\r\n 或 CMD_ERROR\r\n
class JigCommands {
  JigCommands._();

  /// 治具打开（测试结束或异常时释放设备）
  static const String open = 'OPEN';

  /// 治具关闭（MES 开始后夹紧设备）
  static const String close = 'CLOSE';

  /// 光源通道1 开（亮环境）
  static const String lightSourceCh1On = 'LIGHT_SOURCE_CH1_ON';

  /// 光源通道1 关（暗环境）
  static const String lightSourceCh1Off = 'LIGHT_SOURCE_CH1_OFF';

  /// 仅分辨率图卡下降
  static const String onlyResolutionCardDown = 'ONLY_RESOLUTION_CARD_DOWN';

  /// 仅色卡下降
  static const String onlyColorCardDown = 'ONLY_COLOR_CARD_DOWN';

  /// 治具上电（测试开始前）
  static const String powerIn = 'POWER_IN';

  /// 治具断电（开箱释放设备后）
  static const String powerOut = 'POWER_OUT';
}
