import 'dart:convert';
import 'package:http/http.dart' as http;

/// SN码API服务
/// 从服务端获取SN码和MAC地址
class SNApiService {
  static const String baseUrl = 'http://api.jiananai.com/api/v1/product-sn';
  static const String fetchSnEndpoint = '/fetch-sn';
  static const String updateSnStatusEndpoint = '/update-sn-status';
  
  // Token和User-Agent（可以根据需要配置）
  static const String token = '7f0052b35618d1533f1e235b7d1f5928'; // TODO: 配置实际的Token
  static const String userAgent = 'com.jnai.glasses/3.0.0(android;12;xiaomimi10@release)';
  
  /// 从服务端获取SN码
  /// 
  /// [productLine] 产品线代码，如 "637"
  /// [factoryCode] 工厂代码，如 "1"
  /// [lineCode] 产线代码，如 "1"
  /// [hardwareVersion] 硬件版本号，如 "1.0.0"
  /// [existingSn] 可选的现有SN码，如果设备已有SN则传入
  /// 
  /// 返回包含 sn_code, bluetooth_address, mac_address 的Map
  /// 如果请求失败，返回null
  static Future<Map<String, String>?> fetchSN({
    required String productLine,
    required String factoryCode,
    required String lineCode,
    required String hardwareVersion,
    String? existingSn,
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
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📡 请求SN码API');
      print('   URL: $url');
      print('   产品线: $productLine');
      print('   工厂: $factoryCode');
      print('   产线: $lineCode');
      print('   硬件版本: $hardwareVersion');
      if (existingSn != null && existingSn.isNotEmpty) {
        print('   现有SN: $existingSn');
      }
      print('   请求体: ${json.encode(body)}');
      
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
          print('❌ API请求超时（10秒）');
          throw Exception('请求超时');
        },
      );
      
      print('   状态码: ${response.statusCode}');
      print('   响应体: ${response.body}');
      
      if (response.statusCode != 200) {
        print('❌ API请求失败: HTTP ${response.statusCode}');
        print('   完整响应: ${response.body}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return null;
      }
      
      // 解析响应
      final responseData = json.decode(response.body);
      
      // 检查错误码
      final errorCode = responseData['error_code'];
      if (errorCode != 0) {
        final msg = responseData['msg'] ?? '未知错误';
        print('❌ API返回错误: $msg (错误码: $errorCode)');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return null;
      }
      
      // 提取数据
      final data = responseData['data'];
      if (data == null) {
        print('❌ API响应中没有data字段');
        print('   完整响应: ${response.body}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return null;
      }
      
      final snCode = data['sn_code'] as String?;
      final bluetoothAddress = data['bluetooth_address'] as String?;
      final macAddress = data['mac_address'] as String?;
      
      if (snCode == null || bluetoothAddress == null || macAddress == null) {
        print('❌ API响应数据不完整');
        print('   sn_code: $snCode');
        print('   bluetooth_address: $bluetoothAddress');
        print('   mac_address: $macAddress');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return null;
      }
      
      print('✅ 成功获取SN码');
      print('   SN: $snCode');
      print('   蓝牙MAC: $bluetoothAddress');
      print('   WiFi MAC: $macAddress');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // 返回格式化的数据
      return {
        'sn': snCode,
        'bluetoothMac': _formatMacAddress(bluetoothAddress),
        'wifiMac': _formatMacAddress(macAddress),
      };
    } catch (e, stackTrace) {
      print('❌ 请求SN码API异常: $e');
      print('   异常类型: ${e.runtimeType}');
      print('   堆栈跟踪: $stackTrace');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return null;
    }
  }
  
  /// 更新SN状态
  /// 
  /// [sn] SN码
  /// [status] 状态码，产测通过为 4
  /// 
  /// 返回是否更新成功
  static Future<bool> updateSNStatus({
    required String sn,
    required int status,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$updateSnStatusEndpoint');
      
      // 构建请求体
      final body = {
        'sn': sn,
        'status': status,
      };
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📡 更新SN状态API');
      print('   URL: $url');
      print('   SN: $sn');
      print('   状态: $status');
      
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
          throw Exception('请求超时');
        },
      );
      
      print('   状态码: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('❌ API请求失败: HTTP ${response.statusCode}');
        print('   响应: ${response.body}');
        return false;
      }
      
      // 解析响应
      final responseData = json.decode(response.body);
      print('   响应: ${response.body}');
      
      // 检查错误码
      final errorCode = responseData['error_code'];
      if (errorCode != 0) {
        final msg = responseData['msg'] ?? '未知错误';
        print('❌ API返回错误: $msg (错误码: $errorCode)');
        return false;
      }
      
      print('✅ SN状态更新成功');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      return true;
    } catch (e) {
      print('❌ 更新SN状态API异常: $e');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return false;
    }
  }
  
  /// 格式化MAC地址
  /// 将 "48-08-EB-60-00-02" 格式转换为 "48:08:EB:60:00:02"
  static String _formatMacAddress(String mac) {
    return mac.replaceAll('-', ':').toUpperCase();
  }
}
