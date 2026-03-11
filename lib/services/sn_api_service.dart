import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/log_state.dart';

/// SN码API服务
class SNApiService {
  static const String baseUrl = 'http://test.jiananai.com/api/v1/product-sn';
  static const String fetchSnEndpoint = '/fetch-sn';
  static const String updateSnStatusEndpoint = '/update-sn-status';
  
  // Token和User-Agent（可以根据需要配置）
  static const String token = '7f0052b35618d1533f1e235b7d1f5928'; // TODO: 配置实际的Token
  static const String userAgent = 'com.jnai.glasses/3.0.0(android;12;xiaomimi10@release)';
  
  /// 从服务端获取SN码
  /// 
  /// [productLine] 产品线，如 "637"
  /// [factoryCode] 工厂代码，如 "1"
  /// [lineCode] 产线代码，如 "1"
  /// [hardwareVersion] 硬件版本号，如 "1.0.0"
  /// [existingSn] 可选的现有SN码，如果设备已有SN则传入
  /// [logState] 日志状态对象，用于记录日志
  /// 
  /// 返回包含 sn_code, bluetooth_address, mac_address 的Map
  /// 如果请求失败，返回null
  static Future<Map<String, String>?> fetchSN({
    required String productLine,
    required String factoryCode,
    required String lineCode,
    required String hardwareVersion,
    String? existingSn,
    LogState? logState,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$fetchSnEndpoint');
      
      // 构建请求体
      final body = {
        'product_line': productLine,
        'factory_code': factoryCode,
        'line_code': lineCode,
        'hardware_version': hardwareVersion,
        'sn': existingSn ?? '',
      };
      
      logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      logState?.info('📡 请求SN码API', type: LogType.debug);
      logState?.info('   URL: $url', type: LogType.debug);
      logState?.info('   产品线: $productLine', type: LogType.debug);
      logState?.info('   工厂: $factoryCode', type: LogType.debug);
      logState?.info('   产线: $lineCode', type: LogType.debug);
      logState?.info('   硬件版本: $hardwareVersion', type: LogType.debug);
      if (existingSn != null && existingSn.isNotEmpty) {
        logState?.info('   现有SN: $existingSn', type: LogType.debug);
      }
      logState?.info('   请求体: ${json.encode(body)}', type: LogType.debug);
      
      // 发送POST请求
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Token': token,
          'User-Agent': userAgent,
        },
        body: json.encode(body),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          logState?.error('❌ API请求超时（10秒）', type: LogType.debug);
          throw Exception('请求超时');
        },
      );
      
      logState?.info('   状态码: ${response.statusCode}', type: LogType.debug);
      logState?.info('   响应体: ${response.body}', type: LogType.debug);
      
      if (response.statusCode != 200) {
        logState?.error('❌ API请求失败: HTTP ${response.statusCode}', type: LogType.debug);
        logState?.error('   完整响应: ${response.body}', type: LogType.debug);
        logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        return null;
      }
      
      // 解析响应
      final responseData = json.decode(response.body);
      
      // 检查错误码
      final errorCode = responseData['error_code'];
      if (errorCode != 0) {
        final msg = responseData['msg'] ?? '未知错误';
        logState?.error('❌ API返回错误: $msg (错误码: $errorCode)', type: LogType.debug);
        logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        return null;
      }
      
      // 提取数据
      final data = responseData['data'];
      if (data == null) {
        logState?.error('❌ API响应中没有data字段', type: LogType.debug);
        logState?.error('   完整响应: ${response.body}', type: LogType.debug);
        logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        return null;
      }
      
      final snCode = data['sn_code'] as String?;
      final bluetoothAddress = data['bluetooth_address'] as String?;
      final macAddress = data['mac_address'] as String?;
      
      if (snCode == null || bluetoothAddress == null || macAddress == null) {
        logState?.error('❌ API响应数据不完整', type: LogType.debug);
        logState?.error('   sn_code: $snCode', type: LogType.debug);
        logState?.error('   bluetooth_address: $bluetoothAddress', type: LogType.debug);
        logState?.error('   mac_address: $macAddress', type: LogType.debug);
        logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        return null;
      }
      
      logState?.success('✅ 成功获取SN码', type: LogType.debug);
      logState?.info('   SN: $snCode', type: LogType.debug);
      logState?.info('   蓝牙MAC: $bluetoothAddress', type: LogType.debug);
      logState?.info('   WiFi MAC: $macAddress', type: LogType.debug);
      logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      
      // 返回格式化的数据
      return {
        'sn': snCode,
        'bluetoothMac': _formatMacAddress(bluetoothAddress),
        'wifiMac': _formatMacAddress(macAddress),
      };
    } catch (e, stackTrace) {
      logState?.error('❌ 请求SN码API异常: $e', type: LogType.debug);
      logState?.error('   异常类型: ${e.runtimeType}', type: LogType.debug);
      logState?.error('   堆栈跟踪: $stackTrace', type: LogType.debug);
      logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      return null;
    }
  }
  
  /// 更新SN状态
  /// 
  /// [sn] SN码
  /// [status] 状态码，产测通过为 4
  /// [logState] 日志状态对象，用于记录日志
  /// 
  /// 返回是否更新成功
  static Future<bool> updateSNStatus({
    required String sn,
    required int status,
    LogState? logState,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$updateSnStatusEndpoint');
      
      // 构建请求体
      final body = {
        'sn': sn,
        'status': status,
      };
      
      logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      logState?.info('📡 更新SN状态API', type: LogType.debug);
      logState?.info('   URL: $url', type: LogType.debug);
      logState?.info('   SN: $sn', type: LogType.debug);
      logState?.info('   状态: $status', type: LogType.debug);
      
      // 发送POST请求
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Token': token,
          'User-Agent': userAgent,
        },
        body: json.encode(body),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          logState?.error('❌ API请求超时（10秒）', type: LogType.debug);
          throw Exception('请求超时');
        },
      );
      
      logState?.info('   状态码: ${response.statusCode}', type: LogType.debug);
      logState?.info('   响应体: ${response.body}', type: LogType.debug);
      
      if (response.statusCode != 200) {
        logState?.error('❌ API请求失败: HTTP ${response.statusCode}', type: LogType.debug);
        logState?.error('   完整响应: ${response.body}', type: LogType.debug);
        logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        return false;
      }
      
      // 解析响应
      final responseData = json.decode(response.body);
      
      // 检查错误码
      final errorCode = responseData['error_code'];
      if (errorCode != 0) {
        final msg = responseData['msg'] ?? '未知错误';
        logState?.error('❌ API返回错误: $msg (错误码: $errorCode)', type: LogType.debug);
        logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
        return false;
      }
      
      logState?.success('✅ SN状态更新成功', type: LogType.debug);
      logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      
      return true;
    } catch (e, stackTrace) {
      logState?.error('❌ 更新SN状态API异常: $e', type: LogType.debug);
      logState?.error('   异常类型: ${e.runtimeType}', type: LogType.debug);
      logState?.error('   堆栈跟踪: $stackTrace', type: LogType.debug);
      logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.debug);
      return false;
    }
  }
  
  /// 格式化MAC地址
  /// 将 "48-08-EB-60-00-02" 格式转换为 "48:08:EB:60:00:02"
  static String _formatMacAddress(String mac) {
    return mac.replaceAll('-', ':').toUpperCase();
  }
}
