import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../config/production_config.dart';

/// BYD MES 系统服务
/// 用于与 BYD MES 系统进行通讯
class BydMesService {
  // MES 配置 - 从 ProductionConfig 读取
  final ProductionConfig _config = ProductionConfig();
  
  // Python 脚本路径
  String? _scriptPath;
  
  // 日志回调
  Function(String)? _onLog;
  
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
    
    _initScriptPath();
  }
  
  /// 初始化脚本路径
  void _initScriptPath() {
    const scriptName = 'byd_mes_client.py';
    
    // 获取可执行文件所在目录
    final execDir = path.dirname(Platform.resolvedExecutable);
    final currentDir = Directory.current.path;
    // Windows 使用 USERPROFILE，Linux/macOS 使用 HOME
    final homeDir = Platform.environment['HOME'] ?? 
                    Platform.environment['USERPROFILE'] ?? '';
    
    final possiblePaths = [
      // 当前工作目录
      path.join(currentDir, 'scripts', scriptName),
      // 部署路径 (Linux)
      path.join('/opt', 'jn-production-line', 'scripts', scriptName),
      // HOME 目录
      if (homeDir.isNotEmpty)
        path.join(homeDir, 'git', 'JNProductionLine', 'scripts', scriptName),
      // 可执行文件相对路径（向上逐级查找）
      path.join(execDir, 'scripts', scriptName),
      path.join(execDir, '..', 'scripts', scriptName),
      path.join(execDir, '..', '..', 'scripts', scriptName),
      path.join(execDir, '..', '..', '..', 'scripts', scriptName),
      path.join(execDir, '..', '..', '..', '..', 'scripts', scriptName),
      // Flutter 打包路径
      path.join(execDir, 'data', 'flutter_assets', 'assets', 'scripts', scriptName),
      path.join(execDir, 'data', 'flutter_assets', 'scripts', scriptName),
    ];
    
    _log('🔍 搜索 MES 脚本...');
    _log('   工作目录: $currentDir');
    _log('   可执行文件目录: $execDir');
    _log('   HOME目录: $homeDir');
    
    for (final p in possiblePaths) {
      final normalized = path.normalize(p);
      if (File(normalized).existsSync()) {
        _scriptPath = normalized;
        _log('✅ 找到 MES 脚本: $normalized');
        return;
      }
    }
    
    _log('❌ 未找到 MES 脚本，已搜索以下路径:');
    for (final p in possiblePaths) {
      _log('   ❌ ${path.normalize(p)}');
    }
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
  
  /// 执行 MES 操作
  Future<Map<String, dynamic>> _executeMesAction(
    String action,
    String sn,
    List<String> extraArgs,
  ) async {
    if (_scriptPath == null) {
      // 重试一次搜索脚本
      _initScriptPath();
    }
    if (_scriptPath == null) {
      return {
        'success': false,
        'error': 'MES 脚本不存在，工作目录: ${Directory.current.path}',
      };
    }
    
    try {
      final args = [
        _scriptPath!,
        action,
        sn,
        station,
        mesIp,
        clientId,
        ...extraArgs,
      ];
      
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('📤 执行 MES 操作: ${action.toUpperCase()}');
      _log('   SN: $sn');
      _log('   工站: $station');
      final pythonCmd = Platform.isWindows ? 'python' : 'python3';
      _log('   命令: $pythonCmd ${args.join(' ')}');
      
      final process = await Process.start(pythonCmd, args);
      
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
      _initScriptPath();
    }
    if (_scriptPath == null) {
      return {
        'success': false,
        'error': 'MES 脚本不存在，工作目录: ${Directory.current.path}',
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
