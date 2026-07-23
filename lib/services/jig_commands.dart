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

  /// 光源通道2 开
  static const String lightSourceCh2On = 'LIGHT_SOURCE_CH2_ON';

  /// 仅分辨率图卡下降
  static const String onlyResolutionCardDown = 'ONLY_RESOLUTION_CARD_DOWN';

  /// 仅色卡下降
  static const String onlyColorCardDown = 'ONLY_COLOR_CARD_DOWN';

  /// 仅棋盘格卡下降
  static const String onlyCheckerCardDown = 'ONLY_CHECKER_CARD_DOWN';

  /// 仅灰卡下降
  static const String onlyGrayCardDown = 'ONLY_GRAY_CARD_DOWN';

  /// 电机复位
  static const String motorReset = 'MOTOR_RESET';

  /// 夹爪夹紧（测试开始前）
  static const String clawClamp = 'CLAW_CLAMP';

  /// 治具上电（测试开始前）
  static const String powerIn = 'POWER_IN';

  /// 治具断电（开箱释放设备后）
  static const String powerOut = 'POWER_OUT';

  /// Touch 按压指令，如 PRESS_TK1_100G
  /// tkIndex: 1=右TK1, 2=右TK2, 3=右TK3, 4=左Touch, 5=佩戴检测
  static String pressTk(int tkIndex, int grams) => 'PRESS_TK${tkIndex}_${grams}G';
}
