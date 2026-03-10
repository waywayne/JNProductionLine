import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../config/sn_mac_config.dart';

/// SN 码管理服务
/// 负责 SN 码生成、分配、记录和查询
class SNManagerService {
  // 单例模式
  static final SNManagerService _instance = SNManagerService._internal();
  factory SNManagerService() => _instance;
  SNManagerService._internal();

  // 数据文件路径
  String? _dataFilePath;
  
  // SN 记录数据
  final Map<String, SNRecord> _snRecords = {};
  
  // MAC 地址范围
  static const String wifiMacStart = '48:08:EB:50:00:50';
  static const String wifiMacEnd = '48:08:EB:5F:FF:FF';
  static const String btMacStart = '48:08:EB:60:00:50';
  static const String btMacEnd = '48:08:EB:6F:FF:FF';
  
  // 当前分配的 MAC 地址索引 (从 0x50 = 80 开始)
  int _currentWifiMacIndex = 0x50;
  int _currentBtMacIndex = 0x50;

  /// 初始化服务
  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    _dataFilePath = '${directory.path}/sn_records.json';
    await _loadRecords();
  }

  /// 加载已有记录
  Future<void> _loadRecords() async {
    if (_dataFilePath == null) return;
    
    final file = File(_dataFilePath!);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        
        _snRecords.clear();
        data.forEach((key, value) {
          _snRecords[key] = SNRecord.fromJson(value as Map<String, dynamic>);
        });
        
        // 更新 MAC 地址索引
        _updateMacIndexes();
        
        print('✅ 加载 SN 记录: ${_snRecords.length} 条');
      } catch (e) {
        print('❌ 加载 SN 记录失败: $e');
      }
    }
  }

  /// 更新 MAC 地址索引（找到最大的已分配索引）
  void _updateMacIndexes() {
    int maxWifiIndex = 0x50 - 1; // 初始值为起始索引 - 1
    int maxBtIndex = 0x50 - 1;
    
    for (final record in _snRecords.values) {
      if (record.wifiMac != null) {
        final index = _macToIndex(record.wifiMac!, isWifi: true);
        if (index > maxWifiIndex) maxWifiIndex = index;
      }
      if (record.btMac != null) {
        final index = _macToIndex(record.btMac!, isWifi: false);
        if (index > maxBtIndex) maxBtIndex = index;
      }
    }
    
    // 下一个可用索引 = 最大索引 + 1，但不能小于起始索引 0x50
    _currentWifiMacIndex = maxWifiIndex + 1;
    _currentBtMacIndex = maxBtIndex + 1;
  }

  /// 保存记录到文件
  Future<void> _saveRecords() async {
    if (_dataFilePath == null) return;
    
    try {
      final file = File(_dataFilePath!);
      final data = <String, dynamic>{};
      
      _snRecords.forEach((key, value) {
        data[key] = value.toJson();
      });
      
      await file.writeAsString(jsonEncode(data));
      print('✅ 保存 SN 记录: ${_snRecords.length} 条');
    } catch (e) {
      print('❌ 保存 SN 记录失败: $e');
    }
  }

  /// 添加新的 SN 记录
  Future<void> addRecord({
    required String sn,
    String? wifiMac,
    String? btMac,
    String? hardwareVersion,
  }) async {
    final now = DateTime.now();
    final record = SNRecord(
      sn: sn,
      wifiMac: wifiMac,
      btMac: btMac,
      hardwareVersion: hardwareVersion ?? 'V1.0',
      createdAt: now,
      updatedAt: now,
    );
    
    _snRecords[sn] = record;
    
    // 更新 MAC 地址索引
    _updateMacIndexes();
    
    // 保存到文件
    await _saveRecords();
  }

  /// 清空所有 SN 记录
  /// 
  /// 删除所有记录并重置 MAC 地址索引到初始值
  /// 返回删除的记录数量
  Future<int> clearAllRecords() async {
    final count = _snRecords.length;
    
    // 清空内存中的记录
    _snRecords.clear();
    
    // 重置 MAC 地址索引到初始值
    _currentWifiMacIndex = 0;
    _currentBtMacIndex = 0;
    
    // 保存到文件（空记录）
    await _saveRecords();
    
    print('✅ 已清空所有 SN 记录，共删除 $count 条');
    print('   WiFi MAC 索引已重置为: 0 (48:08:EB:50:00:50)');
    print('   蓝牙 MAC 索引已重置为: 0 (48:08:EB:60:00:50)');
    
    return count;
  }

  /// 生成 SN 码
  /// 
  /// [productLine] 产品线代码，如 '637' (Kanaan-K2)
  /// [factory] 工厂代码，如 '1' (比亚迪)
  /// [productionLine] 产线代码，如 '1'
  /// [sequenceNumber] 流水号，5位数字
  String generateSN({
    required String productLine,
    required String factory,
    required String productionLine,
    required int sequenceNumber,
  }) {
    // 生产日期 YMMDD
    final now = DateTime.now();
    final year = now.year % 10; // 取年份最后一位
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final date = '$year$month$day';
    
    // 流水号 5 位
    final sequence = sequenceNumber.toString().padLeft(5, '0');
    
    // 基础 SN（不含校验码）
    final baseSN = '$productLine$factory$date$productionLine$sequence';
    
    // 计算校验码（Base36，4位）
    final checksum = _calculateChecksum(baseSN);
    
    // 完整 SN
    return '$baseSN$checksum';
  }

  /// 计算校验码（Base36，4位）
  String _calculateChecksum(String baseSN) {
    // 简单的校验算法：对所有字符的 ASCII 值求和，然后转 Base36
    int sum = 0;
    for (int i = 0; i < baseSN.length; i++) {
      sum += baseSN.codeUnitAt(i);
    }
    
    // 转 Base36（0-9, A-Z），取模确保不超过4位
    return _toBase36(sum % (36 * 36 * 36 * 36), 4);
  }
  
  /// 将数字转换为Base36字符串
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

  /// 验证 SN 码格式
  bool validateSN(String sn) {
    // SN 格式: PPP-F-YMMDD-L-BBBBB-SSSS
    // 实际存储: PPPFYMMDDLBBBBBSSSS (19位)
    if (sn.length != 19) return false;
    
    // 提取基础 SN 和校验码
    final baseSN = sn.substring(0, 15);
    final checksum = sn.substring(15);
    
    // 验证校验码
    final calculatedChecksum = _calculateChecksum(baseSN);
    return checksum == calculatedChecksum;
  }

  /// 格式化 SN 码显示（添加分隔符）
  String formatSN(String sn) {
    if (sn.length != 19) return sn;
    
    // PPP-F-YMMDD-L-BBBBB-SSSS
    return '${sn.substring(0, 3)}-${sn.substring(3, 4)}-${sn.substring(4, 9)}-${sn.substring(9, 10)}-${sn.substring(10, 15)}-${sn.substring(15)}';
  }

  /// 分配新的 WiFi MAC 地址
  String allocateWifiMac() {
    final mac = _indexToMac(_currentWifiMacIndex, isWifi: true);
    _currentWifiMacIndex++;
    return mac;
  }

  /// 分配新的蓝牙 MAC 地址
  String allocateBtMac() {
    final mac = _indexToMac(_currentBtMacIndex, isWifi: false);
    _currentBtMacIndex++;
    return mac;
  }

  /// 索引转 MAC 地址
  /// 
  /// WiFi MAC 范围: 48:08:EB:50:00:50 ~ 48:08:EB:5F:FF:FF
  /// 蓝牙 MAC 范围: 48:08:EB:60:00:50 ~ 48:08:EB:6F:FF:FF
  String _indexToMac(int index, {required bool isWifi}) {
    // 起始地址的后3字节: 0x500050 (WiFi) 或 0x600050 (蓝牙)
    final baseValue = isWifi ? 0x500050 : 0x600050;
    final macValue = baseValue + index;
    
    // 分解为3个字节
    final byte4 = (macValue >> 16) & 0xFF;  // 第4字节 (0x50-0x5F 或 0x60-0x6F)
    final byte5 = (macValue >> 8) & 0xFF;   // 第5字节 (0x00-0xFF)
    final byte6 = macValue & 0xFF;          // 第6字节 (0x00-0xFF)
    
    return '48:08:EB:${byte4.toRadixString(16).padLeft(2, '0').toUpperCase()}:${byte5.toRadixString(16).padLeft(2, '0').toUpperCase()}:${byte6.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  /// MAC 地址转索引
  int _macToIndex(String mac, {required bool isWifi}) {
    // 移除分隔符
    final macClean = mac.replaceAll(':', '').replaceAll('-', '');
    
    // 提取后 6 位（3 字节）
    final lastBytes = macClean.substring(6);
    final macValue = int.parse(lastBytes, radix: 16);
    
    // 起始地址的后3字节: 0x500050 (WiFi) 或 0x600050 (蓝牙)
    final baseValue = isWifi ? 0x500050 : 0x600050;
    return macValue - baseValue;
  }

  /// 查询 SN 记录
  SNRecord? querySN(String sn) {
    return _snRecords[sn];
  }

  /// 创建新记录
  Future<SNRecord> createRecord({
    required String sn,
    required String hardwareVersion,
    String? wifiMac,
    String? btMac,
  }) async {
    final record = SNRecord(
      sn: sn,
      hardwareVersion: hardwareVersion,
      wifiMac: wifiMac ?? allocateWifiMac(),
      btMac: btMac ?? allocateBtMac(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _snRecords[sn] = record;
    await _saveRecords();
    
    return record;
  }

  /// 更新记录
  Future<void> updateRecord(String sn, {
    String? hardwareVersion,
    String? wifiMac,
    String? btMac,
  }) async {
    final record = _snRecords[sn];
    if (record == null) return;
    
    final updatedRecord = SNRecord(
      sn: sn,
      hardwareVersion: hardwareVersion ?? record.hardwareVersion,
      wifiMac: wifiMac ?? record.wifiMac,
      btMac: btMac ?? record.btMac,
      createdAt: record.createdAt,
      updatedAt: DateTime.now(),
    );
    
    _snRecords[sn] = updatedRecord;
    await _saveRecords();
  }

  /// 获取下一个流水号
  int getNextSequenceNumber({
    required String productLine,
    required String factory,
    required String productionLine,
  }) {
    // 查找今天的最大流水号
    final today = DateFormat('yMMdd').format(DateTime.now());
    final year = today.substring(2, 3); // 年份最后一位
    final monthDay = today.substring(3); // MMDD
    
    int maxSequence = 0;
    
    for (final sn in _snRecords.keys) {
      // 检查是否匹配产品线、工厂、日期、产线
      if (sn.startsWith(productLine) &&
          sn.substring(3, 4) == factory &&
          sn.substring(4, 9) == '$year$monthDay' &&
          sn.substring(9, 10) == productionLine) {
        // 提取流水号
        final sequence = int.tryParse(sn.substring(10, 15)) ?? 0;
        if (sequence > maxSequence) {
          maxSequence = sequence;
        }
      }
    }
    
    return maxSequence + 1;
  }

  /// 获取所有记录
  List<SNRecord> getAllRecords() {
    return _snRecords.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 导出记录为 CSV
  Future<String> exportToCSV() async {
    final buffer = StringBuffer();
    buffer.writeln('SN,硬件版本,WiFi MAC,蓝牙 MAC,创建时间,更新时间');
    
    for (final record in getAllRecords()) {
      buffer.writeln('${record.sn},${record.hardwareVersion},${record.wifiMac},${record.btMac},${record.createdAt},${record.updatedAt}');
    }
    
    return buffer.toString();
  }

  /// 检查WiFi MAC地址是否已存在于数据库中
  bool isWifiMacExists(String macAddress) {
    for (final record in _snRecords.values) {
      if (record.wifiMac != null && record.wifiMac == macAddress) {
        return true;
      }
    }
    return false;
  }

  /// 检查蓝牙MAC地址是否已存在于数据库中
  bool isBluetoothMacExists(String macAddress) {
    for (final record in _snRecords.values) {
      if (record.btMac != null && record.btMac == macAddress) {
        return true;
      }
    }
    return false;
  }

  /// 获取统计信息
  /// 从 SNMacConfig 获取真实的 MAC 地址计数器和下一个 MAC 地址
  /// 下一个 MAC 地址会检查数据库去重，确保返回真正可用的地址
  Map<String, dynamic> getStatistics() {
    final config = SNMacConfig.getCurrentConfig();
    int wifiMacCounter = config['wifiMacCounter'] as int? ?? 0;
    int btMacCounter = config['bluetoothMacCounter'] as int? ?? 0;
    
    // 计算下一个可用的 WiFi MAC 地址（检查数据库去重）
    String nextWifiMac;
    int wifiAttempts = 0;
    const maxAttempts = 1000;
    
    do {
      if (wifiAttempts >= maxAttempts) {
        nextWifiMac = '无可用地址';
        break;
      }
      
      final nextWifiMacValue = SNMacConfig.wifiMacBaseValue + wifiMacCounter;
      final wifiByte4 = (nextWifiMacValue >> 16) & 0xFF;
      final wifiByte5 = (nextWifiMacValue >> 8) & 0xFF;
      final wifiByte6 = nextWifiMacValue & 0xFF;
      nextWifiMac = '${SNMacConfig.wifiMacPrefix}:${wifiByte4.toRadixString(16).toUpperCase().padLeft(2, '0')}:${wifiByte5.toRadixString(16).toUpperCase().padLeft(2, '0')}:${wifiByte6.toRadixString(16).toUpperCase().padLeft(2, '0')}';
      
      // 检查是否已存在于数据库中
      if (isWifiMacExists(nextWifiMac)) {
        wifiMacCounter++;
        wifiAttempts++;
        continue;
      }
      
      break;
    } while (true);
    
    // 计算下一个可用的蓝牙 MAC 地址（检查数据库去重）
    String nextBtMac;
    int btAttempts = 0;
    
    do {
      if (btAttempts >= maxAttempts) {
        nextBtMac = '无可用地址';
        break;
      }
      
      final nextBtMacValue = SNMacConfig.bluetoothMacBaseValue + btMacCounter;
      final btByte4 = (nextBtMacValue >> 16) & 0xFF;
      final btByte5 = (nextBtMacValue >> 8) & 0xFF;
      final btByte6 = nextBtMacValue & 0xFF;
      nextBtMac = '${SNMacConfig.bluetoothMacPrefix}:${btByte4.toRadixString(16).toUpperCase().padLeft(2, '0')}:${btByte5.toRadixString(16).toUpperCase().padLeft(2, '0')}:${btByte6.toRadixString(16).toUpperCase().padLeft(2, '0')}';
      
      // 检查是否已存在于数据库中
      if (isBluetoothMacExists(nextBtMac)) {
        btMacCounter++;
        btAttempts++;
        continue;
      }
      
      break;
    } while (true);
    
    return {
      'total_records': _snRecords.length,  // 直接从数据库读取总记录数
      'current_wifi_mac_index': wifiMacCounter,
      'current_bt_mac_index': btMacCounter,
      'next_wifi_mac': nextWifiMac,  // 已去重的下一个可用WiFi MAC
      'next_bt_mac': nextBtMac,      // 已去重的下一个可用蓝牙MAC
    };
  }
}

/// SN 记录数据模型
class SNRecord {
  final String sn;
  final String hardwareVersion;
  final String? wifiMac;
  final String? btMac;
  final DateTime createdAt;
  final DateTime updatedAt;

  SNRecord({
    required this.sn,
    required this.hardwareVersion,
    this.wifiMac,
    this.btMac,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'sn': sn,
      'hardware_version': hardwareVersion,
      'wifi_mac': wifiMac,
      'bt_mac': btMac,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SNRecord.fromJson(Map<String, dynamic> json) {
    return SNRecord(
      sn: json['sn'] as String,
      hardwareVersion: json['hardware_version'] as String,
      wifiMac: json['wifi_mac'] as String?,
      btMac: json['bt_mac'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  String toString() {
    return 'SNRecord(sn: $sn, hw: $hardwareVersion, wifi: $wifiMac, bt: $btMac)';
  }
}

/// 产品线定义
class ProductLine {
  static const String kanaan_k2 = '637'; // Kanaan-K2 AI拍摄眼镜
  static const String tongxing = '638';  // 瞳行 AI 拍摄眼镜
  
  static String getName(String code) {
    switch (code) {
      case kanaan_k2:
        return 'Kanaan-K2 AI拍摄眼镜';
      case tongxing:
        return '瞳行 AI 拍摄眼镜';
      default:
        return '未知产品';
    }
  }
}

/// 工厂定义
class Factory {
  static const String byd = '1'; // 比亚迪
  static const String factory_b = '2'; // 工厂 B
  
  static String getName(String code) {
    switch (code) {
      case byd:
        return '比亚迪';
      case factory_b:
        return '工厂 B';
      default:
        return '未知工厂';
    }
  }
}
