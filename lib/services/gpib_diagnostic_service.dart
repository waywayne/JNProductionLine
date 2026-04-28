import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/log_state.dart';

/// GPIB诊断服务 - 提供多种方式测试GPIB连接
class GpibDiagnosticService {
  LogState? _logState;
  
  void setLogState(LogState logState) {
    _logState = logState;
  }
  
  /// 方法1: 直接使用python -c 单次命令测试
  Future<Map<String, dynamic>> testMethod1_DirectCommand(String address) async {
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
    _logState?.info('方法1: 直接Python命令测试', type: LogType.gpib);
    
    final stopwatch = Stopwatch()..start();
    
    final pythonCmd = await _getPythonCommand();
    if (pythonCmd == null) {
      return {'success': false, 'error': 'Python未安装'};
    }
    
    try {
      final script = '''
import pyvisa
rm = pyvisa.ResourceManager()
inst = rm.open_resource('$address')
inst.timeout = 3000
result = inst.query('*IDN?')
print(result)
inst.close()
rm.close()
''';
      
      final result = await Process.run(
        pythonCmd,
        ['-c', script],
      ).timeout(const Duration(seconds: 10));
      
      stopwatch.stop();
      
      if (result.exitCode == 0) {
        final response = (result.stdout as String).trim();
        _logState?.success('✅ 成功 (${stopwatch.elapsedMilliseconds}ms): $response', type: LogType.gpib);
        return {'success': true, 'time': stopwatch.elapsedMilliseconds, 'response': response};
      } else {
        final error = (result.stderr as String).trim();
        _logState?.error('❌ 失败 (${stopwatch.elapsedMilliseconds}ms): $error', type: LogType.gpib);
        return {'success': false, 'time': stopwatch.elapsedMilliseconds, 'error': error};
      }
    } catch (e) {
      stopwatch.stop();
      _logState?.error('❌ 异常 (${stopwatch.elapsedMilliseconds}ms): $e', type: LogType.gpib);
      return {'success': false, 'time': stopwatch.elapsedMilliseconds, 'error': e.toString()};
    }
  }
  
  /// 方法2: 使用临时脚本文件
  Future<Map<String, dynamic>> testMethod2_ScriptFile(String address) async {
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
    _logState?.info('方法2: 临时脚本文件测试', type: LogType.gpib);
    
    final stopwatch = Stopwatch()..start();
    
    final pythonCmd = await _getPythonCommand();
    if (pythonCmd == null) {
      return {'success': false, 'error': 'Python未安装'};
    }
    
    File? scriptFile;
    try {
      // 创建临时脚本
      final tempDir = Directory.systemTemp;
      scriptFile = File('${tempDir.path}/gpib_test_${DateTime.now().millisecondsSinceEpoch}.py');
      
      await scriptFile.writeAsString('''
import sys
import pyvisa

try:
    print("Initializing VISA...", file=sys.stderr)
    rm = pyvisa.ResourceManager()
    
    print("Opening resource: $address", file=sys.stderr)
    inst = rm.open_resource('$address')
    inst.timeout = 3000
    
    print("Sending *IDN? query...", file=sys.stderr)
    result = inst.query('*IDN?')
    
    print(result)
    
    inst.close()
    rm.close()
    print("Success", file=sys.stderr)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
''');
      
      final result = await Process.run(
        pythonCmd,
        [scriptFile.path],
      ).timeout(const Duration(seconds: 10));
      
      stopwatch.stop();
      
      // 输出stderr日志
      final stderr = (result.stderr as String).trim();
      if (stderr.isNotEmpty) {
        for (final line in stderr.split('\n')) {
          _logState?.debug('  $line', type: LogType.gpib);
        }
      }
      
      if (result.exitCode == 0) {
        final response = (result.stdout as String).trim();
        _logState?.success('✅ 成功 (${stopwatch.elapsedMilliseconds}ms): $response', type: LogType.gpib);
        return {'success': true, 'time': stopwatch.elapsedMilliseconds, 'response': response};
      } else {
        _logState?.error('❌ 失败 (${stopwatch.elapsedMilliseconds}ms)', type: LogType.gpib);
        return {'success': false, 'time': stopwatch.elapsedMilliseconds, 'error': stderr};
      }
    } catch (e) {
      stopwatch.stop();
      _logState?.error('❌ 异常 (${stopwatch.elapsedMilliseconds}ms): $e', type: LogType.gpib);
      return {'success': false, 'time': stopwatch.elapsedMilliseconds, 'error': e.toString()};
    } finally {
      // 清理临时文件
      try {
        await scriptFile?.delete();
      } catch (_) {}
    }
  }
  
  /// 方法3: 测试VISA资源列表
  Future<Map<String, dynamic>> testMethod3_ListResources() async {
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
    _logState?.info('方法3: VISA资源列表测试', type: LogType.gpib);
    
    final stopwatch = Stopwatch()..start();
    
    final pythonCmd = await _getPythonCommand();
    if (pythonCmd == null) {
      return {'success': false, 'error': 'Python未安装'};
    }
    
    try {
      final script = '''
import pyvisa
import sys

try:
    # 尝试不同的后端
    backends = ['@ni', '@py', None]
    
    for backend in backends:
        try:
            if backend:
                print(f"Trying backend: {backend}", file=sys.stderr)
                rm = pyvisa.ResourceManager(backend)
            else:
                print("Trying default backend", file=sys.stderr)
                rm = pyvisa.ResourceManager()
            
            resources = rm.list_resources()
            print(f"Backend {backend or 'default'}: {len(resources)} resources", file=sys.stderr)
            
            for res in resources:
                print(res)
            
            rm.close()
            break
        except Exception as e:
            print(f"Backend {backend or 'default'} failed: {e}", file=sys.stderr)
            continue
            
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
''';
      
      final result = await Process.run(
        pythonCmd,
        ['-c', script],
      ).timeout(const Duration(seconds: 15));
      
      stopwatch.stop();
      
      // 输出stderr日志
      final stderr = (result.stderr as String).trim();
      if (stderr.isNotEmpty) {
        for (final line in stderr.split('\n')) {
          _logState?.debug('  $line', type: LogType.gpib);
        }
      }
      
      if (result.exitCode == 0) {
        final resources = (result.stdout as String)
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();
        
        _logState?.success('✅ 找到 ${resources.length} 个资源 (${stopwatch.elapsedMilliseconds}ms)', type: LogType.gpib);
        for (final res in resources) {
          _logState?.info('  - $res', type: LogType.gpib);
        }
        
        return {'success': true, 'time': stopwatch.elapsedMilliseconds, 'resources': resources};
      } else {
        _logState?.error('❌ 失败 (${stopwatch.elapsedMilliseconds}ms)', type: LogType.gpib);
        return {'success': false, 'time': stopwatch.elapsedMilliseconds, 'error': stderr};
      }
    } catch (e) {
      stopwatch.stop();
      _logState?.error('❌ 异常 (${stopwatch.elapsedMilliseconds}ms): $e', type: LogType.gpib);
      return {'success': false, 'time': stopwatch.elapsedMilliseconds, 'error': e.toString()};
    }
  }
  
  /// 方法4: 测试写入命令（不读取响应）
  Future<Map<String, dynamic>> testMethod4_WriteOnly(String address) async {
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
    _logState?.info('方法4: 仅写入测试（*CLS清除状态）', type: LogType.gpib);
    
    final stopwatch = Stopwatch()..start();
    
    final pythonCmd = await _getPythonCommand();
    if (pythonCmd == null) {
      return {'success': false, 'error': 'Python未安装'};
    }
    
    try {
      final script = '''
import pyvisa
rm = pyvisa.ResourceManager()
inst = rm.open_resource('$address')
inst.timeout = 2000
inst.write('*CLS')  # 清除状态，不需要响应
print("Write successful")
inst.close()
rm.close()
''';
      
      final result = await Process.run(
        pythonCmd,
        ['-c', script],
      ).timeout(const Duration(seconds: 5));
      
      stopwatch.stop();
      
      if (result.exitCode == 0) {
        _logState?.success('✅ 写入成功 (${stopwatch.elapsedMilliseconds}ms)', type: LogType.gpib);
        return {'success': true, 'time': stopwatch.elapsedMilliseconds};
      } else {
        final error = (result.stderr as String).trim();
        _logState?.error('❌ 失败 (${stopwatch.elapsedMilliseconds}ms): $error', type: LogType.gpib);
        return {'success': false, 'time': stopwatch.elapsedMilliseconds, 'error': error};
      }
    } catch (e) {
      stopwatch.stop();
      _logState?.error('❌ 异常 (${stopwatch.elapsedMilliseconds}ms): $e', type: LogType.gpib);
      return {'success': false, 'time': stopwatch.elapsedMilliseconds, 'error': e.toString()};
    }
  }
  
  /// 方法5: 测试简单查询（*OPC?）
  Future<Map<String, dynamic>> testMethod5_SimpleQuery(String address) async {
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
    _logState?.info('方法5: 简单查询测试（*OPC?）', type: LogType.gpib);
    
    final stopwatch = Stopwatch()..start();
    
    final pythonCmd = await _getPythonCommand();
    if (pythonCmd == null) {
      return {'success': false, 'error': 'Python未安装'};
    }
    
    try {
      final script = '''
import pyvisa
rm = pyvisa.ResourceManager()
inst = rm.open_resource('$address')
inst.timeout = 2000
result = inst.query('*OPC?')  # 操作完成查询，应该返回1
print(result)
inst.close()
rm.close()
''';
      
      final result = await Process.run(
        pythonCmd,
        ['-c', script],
      ).timeout(const Duration(seconds: 5));
      
      stopwatch.stop();
      
      if (result.exitCode == 0) {
        final response = (result.stdout as String).trim();
        _logState?.success('✅ 成功 (${stopwatch.elapsedMilliseconds}ms): $response', type: LogType.gpib);
        return {'success': true, 'time': stopwatch.elapsedMilliseconds, 'response': response};
      } else {
        final error = (result.stderr as String).trim();
        _logState?.error('❌ 失败 (${stopwatch.elapsedMilliseconds}ms): $error', type: LogType.gpib);
        return {'success': false, 'time': stopwatch.elapsedMilliseconds, 'error': error};
      }
    } catch (e) {
      stopwatch.stop();
      _logState?.error('❌ 异常 (${stopwatch.elapsedMilliseconds}ms): $e', type: LogType.gpib);
      return {'success': false, 'time': stopwatch.elapsedMilliseconds, 'error': e.toString()};
    }
  }
  
  /// 方法6: 测试不同的终止符配置
  Future<Map<String, dynamic>> testMethod6_Terminators(String address) async {
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
    _logState?.info('方法6: 终止符配置测试', type: LogType.gpib);
    
    final stopwatch = Stopwatch()..start();
    
    final pythonCmd = await _getPythonCommand();
    if (pythonCmd == null) {
      return {'success': false, 'error': 'Python未安装'};
    }
    
    try {
      final script = '''
import pyvisa
import sys

terminators = [
    ('\\\\n', '\\\\n', 'LF/LF'),
    ('\\\\r\\\\n', '\\\\r\\\\n', 'CRLF/CRLF'),
    ('\\\\r', '\\\\r', 'CR/CR'),
    (None, None, 'None/None'),
]

rm = pyvisa.ResourceManager()

for read_term, write_term, name in terminators:
    try:
        print(f"Testing {name}...", file=sys.stderr)
        inst = rm.open_resource('$address')
        inst.timeout = 2000
        
        if read_term:
            inst.read_termination = read_term
        if write_term:
            inst.write_termination = write_term
        
        result = inst.query('*OPC?')
        print(f"{name}: {result.strip()}")
        inst.close()
        
    except Exception as e:
        print(f"{name}: FAILED - {e}", file=sys.stderr)

rm.close()
''';
      
      final result = await Process.run(
        pythonCmd,
        ['-c', script],
      ).timeout(const Duration(seconds: 15));
      
      stopwatch.stop();
      
      // 输出所有日志
      final stderr = (result.stderr as String).trim();
      if (stderr.isNotEmpty) {
        for (final line in stderr.split('\n')) {
          _logState?.debug('  $line', type: LogType.gpib);
        }
      }
      
      final stdout = (result.stdout as String).trim();
      if (stdout.isNotEmpty) {
        _logState?.success('✅ 测试完成 (${stopwatch.elapsedMilliseconds}ms)', type: LogType.gpib);
        for (final line in stdout.split('\n')) {
          _logState?.info('  $line', type: LogType.gpib);
        }
        return {'success': true, 'time': stopwatch.elapsedMilliseconds, 'results': stdout};
      } else {
        _logState?.error('❌ 所有配置都失败 (${stopwatch.elapsedMilliseconds}ms)', type: LogType.gpib);
        return {'success': false, 'time': stopwatch.elapsedMilliseconds, 'error': stderr};
      }
    } catch (e) {
      stopwatch.stop();
      _logState?.error('❌ 异常 (${stopwatch.elapsedMilliseconds}ms): $e', type: LogType.gpib);
      return {'success': false, 'time': stopwatch.elapsedMilliseconds, 'error': e.toString()};
    }
  }
  
  /// 方法7: 测试超时配置
  Future<Map<String, dynamic>> testMethod7_Timeouts(String address) async {
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
    _logState?.info('方法7: 超时配置测试', type: LogType.gpib);
    
    final stopwatch = Stopwatch()..start();
    
    final pythonCmd = await _getPythonCommand();
    if (pythonCmd == null) {
      return {'success': false, 'error': 'Python未安装'};
    }
    
    try {
      final script = '''
import pyvisa
import sys
import time

timeouts = [1000, 2000, 3000, 5000, 10000]  # 1s, 2s, 3s, 5s, 10s

rm = pyvisa.ResourceManager()

for timeout_ms in timeouts:
    try:
        print(f"Testing {timeout_ms}ms timeout...", file=sys.stderr)
        inst = rm.open_resource('$address')
        inst.timeout = timeout_ms
        
        start = time.time()
        result = inst.query('*IDN?')
        elapsed = (time.time() - start) * 1000
        
        print(f"{timeout_ms}ms: SUCCESS in {elapsed:.0f}ms - {result.strip()[:50]}")
        inst.close()
        break  # 成功后退出
        
    except Exception as e:
        print(f"{timeout_ms}ms: FAILED - {type(e).__name__}", file=sys.stderr)
        try:
            inst.close()
        except:
            pass

rm.close()
''';
      
      final result = await Process.run(
        pythonCmd,
        ['-c', script],
      ).timeout(const Duration(seconds: 30));
      
      stopwatch.stop();
      
      // 输出所有日志
      final stderr = (result.stderr as String).trim();
      if (stderr.isNotEmpty) {
        for (final line in stderr.split('\n')) {
          _logState?.debug('  $line', type: LogType.gpib);
        }
      }
      
      final stdout = (result.stdout as String).trim();
      if (stdout.isNotEmpty) {
        _logState?.success('✅ 找到工作的超时配置 (${stopwatch.elapsedMilliseconds}ms)', type: LogType.gpib);
        _logState?.info('  $stdout', type: LogType.gpib);
        return {'success': true, 'time': stopwatch.elapsedMilliseconds, 'result': stdout};
      } else {
        _logState?.error('❌ 所有超时配置都失败 (${stopwatch.elapsedMilliseconds}ms)', type: LogType.gpib);
        return {'success': false, 'time': stopwatch.elapsedMilliseconds, 'error': stderr};
      }
    } catch (e) {
      stopwatch.stop();
      _logState?.error('❌ 异常 (${stopwatch.elapsedMilliseconds}ms): $e', type: LogType.gpib);
      return {'success': false, 'time': stopwatch.elapsedMilliseconds, 'error': e.toString()};
    }
  }
  
  /// 方法8: Linux特定测试 - 检查权限和设备文件
  Future<Map<String, dynamic>> testMethod8_LinuxDiagnostics() async {
    _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
    _logState?.info('方法8: Linux系统诊断', type: LogType.gpib);
    
    if (!Platform.isLinux) {
      _logState?.warning('⚠️  非Linux系统，跳过', type: LogType.gpib);
      return {'success': false, 'error': '非Linux系统'};
    }
    
    final results = <String, dynamic>{};
    
    // 检查GPIB设备文件
    try {
      final gpibDevices = Directory('/dev').listSync()
          .where((entity) => entity.path.contains('gpib'))
          .toList();
      
      if (gpibDevices.isEmpty) {
        _logState?.warning('⚠️  未找到/dev/gpib*设备文件', type: LogType.gpib);
        results['gpib_devices'] = [];
      } else {
        _logState?.success('✅ 找到GPIB设备文件:', type: LogType.gpib);
        for (final dev in gpibDevices) {
          final stat = await FileStat.stat(dev.path);
          _logState?.info('  ${dev.path} (${stat.modeString()})', type: LogType.gpib);
        }
        results['gpib_devices'] = gpibDevices.map((e) => e.path).toList();
      }
    } catch (e) {
      _logState?.error('检查设备文件失败: $e', type: LogType.gpib);
    }
    
    // 检查用户组
    try {
      final groupsResult = await Process.run('groups', []);
      final groups = (groupsResult.stdout as String).trim();
      _logState?.info('当前用户组: $groups', type: LogType.gpib);
      results['user_groups'] = groups;
      
      if (!groups.contains('gpib') && !groups.contains('dialout')) {
        _logState?.warning('⚠️  用户不在gpib或dialout组中', type: LogType.gpib);
        _logState?.info('建议执行: sudo usermod -a -G gpib \$USER', type: LogType.gpib);
      }
    } catch (e) {
      _logState?.error('检查用户组失败: $e', type: LogType.gpib);
    }
    
    // 检查GPIB驱动模块
    try {
      final lsmodResult = await Process.run('lsmod', []);
      final modules = (lsmodResult.stdout as String);
      
      if (modules.contains('gpib')) {
        _logState?.success('✅ GPIB内核模块已加载', type: LogType.gpib);
        results['gpib_module_loaded'] = true;
      } else {
        _logState?.warning('⚠️  GPIB内核模块未加载', type: LogType.gpib);
        _logState?.info('建议执行: sudo modprobe gpib_common', type: LogType.gpib);
        results['gpib_module_loaded'] = false;
      }
    } catch (e) {
      _logState?.error('检查内核模块失败: $e', type: LogType.gpib);
    }
    
    return {'success': true, 'results': results};
  }
  
  /// 运行所有诊断测试
  Future<Map<String, dynamic>> runAllDiagnostics(String address) async {
    _logState?.info('', type: LogType.gpib);
    _logState?.info('═══════════════════════════════════', type: LogType.gpib);
    _logState?.info('开始GPIB全面诊断测试', type: LogType.gpib);
    _logState?.info('设备地址: $address', type: LogType.gpib);
    _logState?.info('═══════════════════════════════════', type: LogType.gpib);
    
    final results = <String, dynamic>{};
    
    // Linux系统诊断（如果适用）
    if (Platform.isLinux) {
      results['linux_diagnostics'] = await testMethod8_LinuxDiagnostics();
    }
    
    // VISA资源列表
    results['list_resources'] = await testMethod3_ListResources();
    
    // 写入测试
    results['write_only'] = await testMethod4_WriteOnly(address);
    
    // 简单查询
    results['simple_query'] = await testMethod5_SimpleQuery(address);
    
    // 超时测试
    results['timeout_test'] = await testMethod7_Timeouts(address);
    
    // 终止符测试
    results['terminator_test'] = await testMethod6_Terminators(address);
    
    // 直接命令测试
    results['direct_command'] = await testMethod1_DirectCommand(address);
    
    // 脚本文件测试
    results['script_file'] = await testMethod2_ScriptFile(address);
    
    _logState?.info('', type: LogType.gpib);
    _logState?.info('═══════════════════════════════════', type: LogType.gpib);
    _logState?.info('诊断测试完成', type: LogType.gpib);
    _logState?.info('═══════════════════════════════════', type: LogType.gpib);
    
    // 统计成功率
    int successCount = 0;
    int totalCount = 0;
    
    results.forEach((key, value) {
      if (value is Map && value.containsKey('success')) {
        totalCount++;
        if (value['success'] == true) {
          successCount++;
        }
      }
    });
    
    _logState?.info('成功率: $successCount/$totalCount', type: LogType.gpib);
    
    return results;
  }
  
  Future<String?> _getPythonCommand() async {
    for (final cmd in ['python3', 'python']) {
      try {
        final result = await Process.run(cmd, ['--version']);
        if (result.exitCode == 0) {
          return cmd;
        }
      } catch (_) {}
    }
    return null;
  }
}
