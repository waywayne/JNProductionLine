import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/test_config.dart';

/// 产品SN API响应数据模型
class ProductSNInfo {
  final int id;
  final String snCode;
  final String productLine;
  final String factoryCode;
  final String productionDate;
  final String lineCode;
  final String orderCode;
  final String checkCode;
  final String bluetoothAddress;
  final String macAddress;
  final String hardwareVersion;
  final int activated;
  final int status;
  final int createTime;
  final int updateTime;

  ProductSNInfo({
    required this.id,
    required this.snCode,
    required this.productLine,
    required this.factoryCode,
    required this.productionDate,
    required this.lineCode,
    required this.orderCode,
    required this.checkCode,
    required this.bluetoothAddress,
    required this.macAddress,
    required this.hardwareVersion,
    required this.activated,
    required this.status,
    required this.createTime,
    required this.updateTime,
  });

  factory ProductSNInfo.fromJson(Map<String, dynamic> json) {
    return ProductSNInfo(
      id: json['id'] as int,
      snCode: json['sn_code'] as String,
      productLine: json['product_line'] as String,
      factoryCode: json['factory_code'] as String,
      productionDate: json['production_date'] as String,
      lineCode: json['line_code'] as String,
      orderCode: json['order_code'] as String,
      checkCode: json['check_code'] as String,
      bluetoothAddress: json['bluetooth_address'] as String,
      macAddress: json['mac_address'] as String,
      hardwareVersion: json['hardware_version'] as String,
      activated: json['activated'] as int,
      status: json['status'] as int,
      createTime: json['create_time'] as int,
      updateTime: json['update_time'] as int,
    );
  }
}

/// 产品SN API服务
class ProductSNApi {
  static const String baseUrl = 'http://test.jiananai.com/api/v1/product-sn';
  
  // API认证信息（与单板产测保持一致）
  static const String token = '7f0052b35618d1533f1e235b7d1f5928';
  static const String userAgent = 'com.jnai.glasses/3.0.0(android;12;xiaomimi10@release)';

  /// 获取产品SN信息
  static Future<ProductSNInfo?> getProductSNInfo(String snCode) async {
    try {
      // 从通用配置中获取参数
      final productLine = TestConfig.productLine;
      final factoryCode = TestConfig.factoryCode;
      final lineCode = TestConfig.lineCode;
      final hardwareVersion = TestConfig.hardwareVersion;
      
      // 构建URL（POST方法不带查询参数）
      final url = Uri.parse('$baseUrl/fetch-sn');
      
      // 构建请求体
      final requestBody = {
        'sn_code': snCode,
        'product_line': productLine,
        'factory_code': factoryCode,
        'line_code': lineCode,
        'hardware_version': hardwareVersion,
      };
      
      // 打印请求信息
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📡 API请求信息:');
      print('   方法: POST');
      print('   URL: $url');
      print('   Headers:');
      print('     - Content-Type: application/json');
      print('     - Token: $token');
      print('     - User-Agent: $userAgent');
      print('   请求体: ${json.encode(requestBody)}');
      print('   参数:');
      print('     - sn_code: $snCode');
      print('     - product_line: $productLine');
      print('     - factory_code: $factoryCode');
      print('     - line_code: $lineCode');
      print('     - hardware_version: $hardwareVersion');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Token': token,
          'User-Agent': userAgent,
        },
        body: json.encode(requestBody),
      ).timeout(
        const Duration(seconds: 10),
      );

      // 打印响应信息
      print('📥 API响应信息:');
      print('   状态码: ${response.statusCode}');
      print('   响应体: ${response.body}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        
        print('📦 解析后的JSON:');
        print('   error_code: ${jsonData['error_code']}');
        print('   msg: ${jsonData['msg']}');
        print('   data类型: ${jsonData['data'].runtimeType}');
        print('   data内容: ${jsonData['data']}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        
        final errorCode = jsonData['error_code'] as int;
        if (errorCode == 0) {
          final data = jsonData['data'];
          
          // 检查data是否为String类型
          if (data is String) {
            print('⚠️  警告: data字段是String类型，尝试解析...');
            final dataMap = json.decode(data) as Map<String, dynamic>;
            print('   解析后的data: $dataMap');
            return ProductSNInfo.fromJson(dataMap);
          } else if (data is Map<String, dynamic>) {
            print('✅ data字段是Map类型，直接解析');
            return ProductSNInfo.fromJson(data);
          } else {
            throw Exception('未知的data类型: ${data.runtimeType}');
          }
        } else {
          throw Exception('API错误: ${jsonData['msg']}');
        }
      } else {
        throw Exception('HTTP错误: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ API调用异常: $e');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      rethrow;
    }
  }
}
