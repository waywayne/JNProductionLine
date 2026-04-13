import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/production_config.dart';

/// BYD MES 系统服务
/// 用于与 BYD MES 系统进行通讯（纯 Dart HTTP 实现，无需 Python 脚本）
class BydMesService {
  // MES 配置 - 从 ProductionConfig 读取
  final ProductionConfig _config = ProductionConfig();
  
  // 日志回调
  Function(String)? _onLog;
  
  // HTTP 请求头
  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36',
    'Cookie': 'cookiesession1=426EF394ULRHIHCOMFONBBXJAGLM1F47;',
  };
  
  // 最大重试次数
  static const int _maxRetries = 3;
  
  // 请求超时时间
  static const Duration _timeout = Duration(seconds: 5);
  
  // 获取配置中的 MES IP
  String get mesIp => _config.bydMesIp;
  
  // 获取配置中的 Client ID
  String get clientId => _config.bydMesClientId;
  
  // 获取当前工站（从配置读取）
  String get station => _config.bydMesStation;
  
  BydMesService({
    Function(String)? onLog,
  }) {
    _onLog = onLog;
  }
  
  /// 更新工站配置（现在通过 ProductionConfig 配置）
  Future<void> updateStation(String station) async {
    await _config.setBydMesStation(station);
    _log('🔧 MES 工站已更新: $station');
  }
  
  /// 打印当前配置
  void printConfig() {
    _log('🔧 MES 配置:');
    _log('   MES IP: $mesIp');
    _log('   Client ID: $clientId');
    _log('   工站: ${_config.bydMesStation}');
  }
  
  /// 日志输出
  void _log(String message) {
    debugPrint('[BYD MES] $message');
    _onLog?.call(message);
  }
  
  /// 执行 HTTP GET 请求（带重试）
  Future<Map<String, dynamic>?> _httpGet(String url) async {
    int retryCount = 0;
    
    while (retryCount < _maxRetries) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: _headers,
        ).timeout(_timeout);
        
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data;
      } on TimeoutException {
        retryCount++;
        _log('   ⚠️ 请求超时，重试 $retryCount/$_maxRetries...');
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        retryCount++;
        _log('   ⚠️ 请求错误: $e，重试 $retryCount/$_maxRetries...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    
    return null;
  }
  
  /// 获取 SFC 信息
  Future<Map<String, dynamic>?> _getSfcInfo(String sn) async {
    final url = 'http://$mesIp/Service.action?method=GetSfcInfo&param='
        '{"LOGIN_ID":"-1","CLIENT_ID":"$clientId","SFC":"$sn"}';
    
    _log('   获取 SFC 信息: $sn');
    _log('   URL: $url');
    
    final data = await _httpGet(url);
    if (data == null) {
      _log('   ❌ 获取 SFC 信息失败，已重试 $_maxRetries 次');
      return null;
    }
    
    _log('   响应: ${json.encode(data)}');
    
    if (data['RESULT'] == 'FAIL') {
      _log('   ❌ SFC $sn 不存在');
      return null;
    }
    
    final sfcData = data['SFC'] as Map<String, dynamic>?;
    if (sfcData != null) {
      _log('   ✅ SFC 信息获取成功');
      _log('      型号: ${sfcData['PROJECT'] ?? 'N/A'}');
      _log('      产线: ${sfcData['LINE'] ?? 'N/A'}');
      _log('      工单: ${sfcData['SHOPORDER'] ?? 'N/A'}');
      _log('      排程ID: ${sfcData['SCHEDULING_ID'] ?? 'N/A'}');
    }
    
    return sfcData;
  }
  
  /// MES 开始
  Future<Map<String, dynamic>> start(String sn) async {
    _log('🚀 MES 开始: $sn');
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('📤 执行 MES 操作: START');
    _log('   SN: $sn');
    _log('   工站: $station');
    _log('   MES IP: $mesIp');
    
    try {
      // 1. 获取 SFC 信息
      final sfcData = await _getSfcInfo(sn);
      if (sfcData == null) {
        _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return {'success': false, 'error': '获取 SFC 信息失败'};
      }
      
      // 2. 调用 Start
      final line = sfcData['LINE'] ?? '';
      final shoporder = sfcData['SHOPORDER'] ?? '';
      final schedulingId = sfcData['SCHEDULING_ID'] ?? '';
      
      final url = 'http://$mesIp/Service.action?method=Start&param='
          '{"LOGIN_ID":"-1","CLIENT_ID":"$clientId","SFC":"$sn",'
          '"STATION_NAME":"$station","LINE":"$line","SHOPORDER":"$shoporder",'
          '"SCHEDULING_ID":"$schedulingId","WORK_STATION":"$station"}';
      
      _log('   开始测试: $sn @ $station');
      _log('   URL: $url');
      
      final data = await _httpGet(url);
      if (data == null) {
        _log('   ❌ Start 请求失败');
        _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return {'success': false, 'error': 'Start 请求失败'};
      }
      
      _log('   响应: ${json.encode(data)}');
      
      if (data['RESULT'] == 'PASS') {
        _log('   ✅ $sn START PASS');
        _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return {'success': true, 'sfcData': sfcData};
      } else {
        _log('   ❌ $sn START FAIL');
        _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return {'success': false, 'error': 'MES Start 返回 FAIL: ${json.encode(data)}'};
      }
    } catch (e) {
      _log('   ❌ 开始测试异常: $e');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// MES 完成（良品）
  Future<Map<String, dynamic>> complete(String sn, {String testTime = '0'}) async {
    _log('✅ MES 完成（良品）: $sn');
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('📤 执行 MES 操作: COMPLETE');
    _log('   SN: $sn');
    _log('   工站: $station');
    
    try {
      // 1. 获取 SFC 信息
      final sfcData = await _getSfcInfo(sn);
      if (sfcData == null) {
        _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return {'success': false, 'error': '获取 SFC 信息失败'};
      }
      
      // 2. 调用 Complete
      final line = sfcData['LINE'] ?? '';
      final shoporder = sfcData['SHOPORDER'] ?? '';
      final schedulingId = sfcData['SCHEDULING_ID'] ?? '';
      
      final url = 'http://$mesIp/Service.action?method=Complete&param='
          '{"LOGIN_ID":"-1","CLIENT_ID":"$clientId","SFC":"$sn",'
          '"STATION_NAME":"$station","LINE":"$line","SHOPORDER":"$shoporder",'
          '"SCHEDULING_ID":"$schedulingId","TEST_TIME":"$testTime",'
          '"WORK_STATION":"$station"}';
      
      _log('   完成测试（良品）: $sn @ $station');
      _log('   URL: $url');
      
      final data = await _httpGet(url);
      if (data == null) {
        _log('   ❌ Complete 请求失败');
        _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return {'success': false, 'error': 'Complete 请求失败'};
      }
      
      _log('   响应: ${json.encode(data)}');
      
      if (data['RESULT'] == 'PASS') {
        _log('   ✅ $sn COMPLETE PASS');
        _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return {'success': true};
      } else {
        _log('   ❌ $sn COMPLETE FAIL');
        _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return {'success': false, 'error': 'MES Complete 返回 FAIL: ${json.encode(data)}'};
      }
    } catch (e) {
      _log('   ❌ 完成测试异常: $e');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// MES 完成（不良品）
  Future<Map<String, dynamic>> ncComplete(
    String sn, {
    required String ncCode,
    required String ncContext,
    required String failItem,
    required String failValue,
    String testTime = '0',
  }) async {
    _log('❌ MES 完成（不良品）: $sn');
    _log('   不良代码: $ncCode');
    _log('   不良描述: $ncContext');
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('📤 执行 MES 操作: NC_COMPLETE');
    _log('   SN: $sn');
    _log('   工站: $station');
    
    try {
      // 1. 获取 SFC 信息
      final sfcData = await _getSfcInfo(sn);
      if (sfcData == null) {
        _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return {'success': false, 'error': '获取 SFC 信息失败'};
      }
      
      // 2. 调用 NcComplete
      final schedulingId = sfcData['SCHEDULING_ID'] ?? '';
      
      final url = 'http://$mesIp/Service.action?method=NcComplete&param='
          '{"LOGIN_ID":"-1","CLIENT_ID":"$clientId","SFC":"$sn",'
          '"STATION_NAME":"$station","SCHEDULING_ID":"$schedulingId",'
          '"TEST_TIME":"$testTime","NC_CODE":"$ncCode","NC_CONTEXT":"$ncContext",'
          '"NC_TYPE":"$station","FAIL_ITEM":"$failItem","FAIL_VALUE":"$failValue",'
          '"WORK_STATION":"$station"}';
      
      _log('   完成测试（不良品）: $sn @ $station');
      _log('   URL: $url');
      
      final data = await _httpGet(url);
      if (data == null) {
        _log('   ❌ NcComplete 请求失败');
        _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return {'success': false, 'error': 'NcComplete 请求失败'};
      }
      
      _log('   响应: ${json.encode(data)}');
      
      if (data['RESULT'] == 'PASS') {
        _log('   ✅ $sn NC_COMPLETE PASS');
        _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return {'success': true};
      } else {
        _log('   ❌ $sn NC_COMPLETE FAIL');
        _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return {'success': false, 'error': 'MES NcComplete 返回 FAIL: ${json.encode(data)}'};
      }
    } catch (e) {
      _log('   ❌ 不良品完成异常: $e');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// 测试 MES 连接
  Future<Map<String, dynamic>> testConnection(String testSn) async {
    _log('🧪 测试 MES 连接');
    _log('   测试 SN: $testSn');
    
    try {
      final result = await start(testSn);
      return result;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
