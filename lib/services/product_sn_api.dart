import 'dart:convert';
import 'package:http/http.dart' as http;

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
  static const String baseUrl = 'http://api.jiananai.com/api/v1/product-sn';

  /// 获取产品SN信息
  static Future<ProductSNInfo?> getProductSNInfo(String snCode) async {
    try {
      final url = Uri.parse('$baseUrl/product-sn-info?sn_code=$snCode');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        
        final errorCode = jsonData['error_code'] as int;
        if (errorCode == 0) {
          final data = jsonData['data'] as Map<String, dynamic>;
          return ProductSNInfo.fromJson(data);
        } else {
          throw Exception('API错误: ${jsonData['msg']}');
        }
      } else {
        throw Exception('HTTP错误: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
