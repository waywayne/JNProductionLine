import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// BYD MES 系统服务
/// 用于与 BYD MES 系统进行通讯
class BydMesService {
  // MES 配置
  String _mesIp = '192.168.1.100';
  String _clientId = 'DEFAULT_CLIENT';
  String _station = 'STATION1';
  
  // Python 脚本路径
  String? _scriptPath;
  
  // 日志回调
  Function(String)? _onLog;
  
  BydMesService({
    String? mesIp,
    String? clientId,
    String? station,
    Function(String)? onLog,
  }) {
    if (mesIp != null) _mesIp = mesIp;
    if (clientId != null) _clientId = clientId;
    if (station != null) _station = station;
    _onLog = onLog;
    
    _initScriptPath();
  }
  
  /// 初始化脚本路径
  void _initScriptPath() {
    final possiblePaths = [
      'scripts/byd_mes_client.py',
      '/opt/jn-production-line/scripts/byd_mes_client.py',
      '${Platform.environment['HOME']}/git/JNProductionLine/scripts/byd_mes_client.py',
    ];
    
    for (final path in possiblePaths) {
      if (File(path).existsSync()) {
        _scriptPath = path;
        _log('✅ 找到 MES 脚本: $path');
        break;
      }
    }
    
    if (_scriptPath == null) {
      _log('❌ 未找到 MES 脚本');
    }
  }
  
  /// 更新配置
  void updateConfig({
    String? mesIp,
    String? clientId,
    String? station,
  }) {
    if (mesIp != null) _mesIp = mesIp;
    if (clientId != null) _clientId = clientId;
    if (station != null) _station = station;
    
    _log('🔧 MES 配置已更新:');
    _log('   MES IP: $_mesIp');
    _log('   Client ID: $_clientId');
    _log('   工站: $_station');
  }
  
  /// 日志输出
  void _log(String message) {
    debugPrint('[BYD MES] $message');
    _onLog?.call(message);
  }
  
  /// 执行 MES 操作
  Future<Map<String, dynamic>> _executeMesAction(
    String action,
    String sn,
    List<String> extraArgs,
  ) async {
    if (_scriptPath == null) {
      return {
        'success': false,
        'error': 'MES 脚本不存在',
      };
    }
    
    try {
      final args = [
        _scriptPath!,
        action,
        sn,
        _station,
        _mesIp,
        _clientId,
        ...extraArgs,
      ];
      
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('📤 执行 MES 操作: ${action.toUpperCase()}');
      _log('   SN: $sn');
      _log('   工站: $_station');
      _log('   命令: python3 ${args.join(' ')}');
      
      final process = await Process.start('python3', args);
      
      final stdout = <String>[];
      final stderr = <String>[];
      
      // 监听 stdout
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        stdout.add(line);
        _log('   [STDOUT] $line');
      });
      
      // 监听 stderr（Python 脚本的日志输出）
      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        stderr.add(line);
        _log('   $line');
      });
      
      // 等待进程结束
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
      
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      if (exitCode == 0) {
        _log('✅ MES 操作成功');
        return {
          'success': true,
          'stdout': stdout,
          'stderr': stderr,
        };
      } else if (exitCode == -1) {
        _log('❌ MES 操作超时');
        return {
          'success': false,
          'error': '操作超时',
          'stdout': stdout,
          'stderr': stderr,
        };
      } else {
        _log('❌ MES 操作失败 (退出码: $exitCode)');
        return {
          'success': false,
          'error': 'MES 操作失败',
          'exitCode': exitCode,
          'stdout': stdout,
          'stderr': stderr,
        };
      }
    } catch (e) {
      _log('❌ 执行 MES 操作异常: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// MES 开始
  Future<Map<String, dynamic>> start(String sn) async {
    _log('🚀 MES 开始: $sn');
    return await _executeMesAction('start', sn, []);
  }
  
  /// MES 完成（良品）
  Future<Map<String, dynamic>> complete(String sn, {String testTime = '0'}) async {
    _log('✅ MES 完成（良品）: $sn');
    return await _executeMesAction('complete', sn, [testTime]);
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
    return await _executeMesAction('nccomplete', sn, [
      ncCode,
      ncContext,
      failItem,
      failValue,
      testTime,
    ]);
  }
  
  /// 测试 MES 连接
  Future<Map<String, dynamic>> testConnection(String testSn) async {
    _log('🧪 测试 MES 连接');
    _log('   测试 SN: $testSn');
    
    // 只获取 SFC 信息，不执行实际操作
    if (_scriptPath == null) {
      return {
        'success': false,
        'error': 'MES 脚本不存在',
      };
    }
    
    try {
      // 使用 start 操作测试（不会真正开始，只是验证连接）
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
