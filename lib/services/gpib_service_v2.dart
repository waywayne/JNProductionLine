import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/log_state.dart';
import '../config/test_config.dart';

/// GPIB服务 V2 - 简化版本，使用直接的PyVISA调用
class GpibServiceV2 {
  Process? _process;
  StreamSubscription? _stdoutSubscription;
  StreamSubscription? _stderrSubscription;
  
  bool _isConnected = false;
  String? _currentAddress;
  LogState? _logState;
  
  final _responseController = StreamController<String>.broadcast();
  final Map<String, Completer<String>> _pendingCommands = {};
  
  bool get isConnected => _isConnected;
  String? get currentAddress => _currentAddress;
  
  void setLogState(LogState logState) {
    _logState = logState;
  }
  
  /// 检查Python环境
  Future<Map<String, dynamic>> checkPythonEnvironment() async {
    final result = {
      'pythonInstalled': false,
      'pythonCommand': '',
      'pyvisaInstalled': false,
    };
    
    // 检查Python
    for (final cmd in ['python3', 'python']) {
      try {
        final versionResult = await Process.run(cmd, ['--version']);
        if (versionResult.exitCode == 0) {
          result['pythonInstalled'] = true;
          result['pythonCommand'] = cmd;
          
          // 检查PyVISA
          final pyvisaResult = await Process.run(cmd, ['-c', 'import pyvisa; print(pyvisa.__version__)']);
          if (pyvisaResult.exitCode == 0) {
            result['pyvisaInstalled'] = true;
          }
          break;
        }
      } catch (_) {}
    }
    
    return result;
  }
  
  /// 安装PyVISA
  Future<bool> installPyVISA() async {
    _logState?.info('开始安装 PyVISA...', type: LogType.gpib);
    
    final pythonCmd = await _getPythonCommand();
    if (pythonCmd == null) {
      _logState?.error('未找到Python', type: LogType.gpib);
      return false;
    }
    
    try {
      final process = await Process.start(pythonCmd, ['-m', 'pip', 'install', 'pyvisa', 'pyvisa-py']);
      
      process.stdout.transform(utf8.decoder).listen((data) {
        _logState?.info(data.trim(), type: LogType.gpib);
      });
      
      process.stderr.transform(utf8.decoder).listen((data) {
        _logState?.warning(data.trim(), type: LogType.gpib);
      });
      
      final exitCode = await process.exitCode;
      
      if (exitCode == 0) {
        _logState?.success('PyVISA 安装成功', type: LogType.gpib);
        return true;
      } else {
        _logState?.error('PyVISA 安装失败', type: LogType.gpib);
        return false;
      }
    } catch (e) {
      _logState?.error('安装失败: $e', type: LogType.gpib);
      return false;
    }
  }
  
  /// 列出GPIB资源
  Future<List<String>> listResources() async {
    _logState?.info('扫描 GPIB 设备...', type: LogType.gpib);
    
    final pythonCmd = await _getPythonCommand();
    if (pythonCmd == null) {
      _logState?.error('未找到Python', type: LogType.gpib);
      return [];
    }
    
    try {
      final result = await Process.run(pythonCmd, [
        '-c',
        '''
import pyvisa
rm = pyvisa.ResourceManager()
resources = rm.list_resources()
for res in resources:
    print(res)
rm.close()
'''
      ]);
      
      if (result.exitCode == 0) {
        final resources = (result.stdout as String)
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();
        
        _logState?.info('找到 ${resources.length} 个设备:', type: LogType.gpib);
        for (final res in resources) {
          _logState?.info('  - $res', type: LogType.gpib);
        }
        
        return resources;
      } else {
        _logState?.error('扫描失败: ${result.stderr}', type: LogType.gpib);
        return [];
      }
    } catch (e) {
      _logState?.error('扫描失败: $e', type: LogType.gpib);
      return [];
    }
  }
  
  /// 连接到GPIB设备
  Future<bool> connect(String address) async {
    if (_isConnected) {
      _logState?.warning('已经连接到设备', type: LogType.gpib);
      return true;
    }
    
    _logState?.info('正在连接到 $address...', type: LogType.gpib);
    
    final pythonCmd = await _getPythonCommand();
    if (pythonCmd == null) {
      _logState?.error('未找到Python', type: LogType.gpib);
      return false;
    }
    
    try {
      // 启动Python进程
      _process = await Process.start(pythonCmd, ['-u', '-c', _createSimplePythonScript(address)]);
      
      // 监听stdout
      _stdoutSubscription = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleStdout);
      
      // 监听stderr
      _stderrSubscription = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleStderr);
      
      // 等待连接成功信号
      final connected = await _waitForConnection();
      
      if (connected) {
        _isConnected = true;
        _currentAddress = address;
        _logState?.success('✅ GPIB 设备连接成功', type: LogType.gpib);
        return true;
      } else {
        _logState?.error('❌ GPIB 设备连接失败', type: LogType.gpib);
        await disconnect();
        return false;
      }
    } catch (e) {
      _logState?.error('连接失败: $e', type: LogType.gpib);
      await disconnect();
      return false;
    }
  }
  
  /// 断开连接
  Future<void> disconnect() async {
    if (_process != null) {
      try {
        _process!.stdin.writeln('EXIT');
        await _process!.stdin.flush();
      } catch (_) {}
      
      await Future.delayed(const Duration(milliseconds: 300));
      _process?.kill();
      
      await _stdoutSubscription?.cancel();
      await _stderrSubscription?.cancel();
      
      _process = null;
      _stdoutSubscription = null;
      _stderrSubscription = null;
    }
    
    _isConnected = false;
    _currentAddress = null;
    _pendingCommands.clear();
    
    _logState?.info('GPIB 设备已断开', type: LogType.gpib);
  }
  
  /// 发送命令（写入）
  Future<String?> sendCommand(String command, {Duration timeout = TestConfig.defaultTimeout}) async {
    if (!_isConnected || _process == null) {
      _logState?.error('GPIB 设备未连接', type: LogType.gpib);
      return null;
    }
    
    try {
      final commandId = DateTime.now().millisecondsSinceEpoch.toString();
      final completer = Completer<String>();
      _pendingCommands[commandId] = completer;
      
      _process!.stdin.writeln('WRITE|$commandId|$command');
      await _process!.stdin.flush();
      
      final response = await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingCommands.remove(commandId);
          return 'TIMEOUT';
        },
      );
      
      return response == 'TIMEOUT' ? null : response;
    } catch (e) {
      _logState?.error('发送命令失败: $e', type: LogType.gpib);
      return null;
    }
  }
  
  /// 查询命令（读取）
  Future<String?> query(String command, {Duration timeout = TestConfig.defaultTimeout}) async {
    if (!_isConnected || _process == null) {
      _logState?.error('GPIB 设备未连接', type: LogType.gpib);
      return null;
    }
    
    try {
      final commandId = DateTime.now().millisecondsSinceEpoch.toString();
      final completer = Completer<String>();
      _pendingCommands[commandId] = completer;
      
      _process!.stdin.writeln('QUERY|$commandId|$command');
      await _process!.stdin.flush();
      
      final response = await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingCommands.remove(commandId);
          return 'TIMEOUT';
        },
      );
      
      return response == 'TIMEOUT' ? null : response;
    } catch (e) {
      _logState?.error('查询失败: $e', type: LogType.gpib);
      return null;
    }
  }
  
  void _handleStdout(String line) {
    if (line.isEmpty) return;
    
    // 解析响应格式：commandId|response
    if (line.contains('|')) {
      final parts = line.split('|');
      if (parts.length >= 2) {
        final commandId = parts[0];
        final response = parts.sublist(1).join('|');
        
        final completer = _pendingCommands.remove(commandId);
        if (completer != null && !completer.isCompleted) {
          completer.complete(response);
        }
      }
    } else if (line == 'CONNECTED') {
      _responseController.add('CONNECTED');
    }
  }
  
  void _handleStderr(String line) {
    if (line.isEmpty) return;
    
    if (line.startsWith('ERROR:')) {
      _logState?.error(line.substring(6).trim(), type: LogType.gpib);
    } else if (line.startsWith('WARNING:')) {
      _logState?.warning(line.substring(8).trim(), type: LogType.gpib);
    } else if (line.startsWith('INFO:')) {
      _logState?.info(line.substring(5).trim(), type: LogType.gpib);
    } else if (line.startsWith('DEBUG:')) {
      _logState?.debug(line.substring(6).trim(), type: LogType.gpib);
    } else {
      _logState?.debug(line, type: LogType.gpib);
    }
  }
  
  Future<bool> _waitForConnection() async {
    try {
      await _responseController.stream
          .firstWhere((msg) => msg == 'CONNECTED')
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (e) {
      return false;
    }
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
  
  String _createSimplePythonScript(String address) {
    return '''
import sys
import pyvisa

try:
    # 初始化VISA
    rm = pyvisa.ResourceManager('@py')
    print("INFO: Using pyvisa-py backend", file=sys.stderr)
    
    # 连接设备
    print(f"INFO: Connecting to $address...", file=sys.stderr)
    inst = rm.open_resource('$address')
    
    # 配置超时和终止符
    inst.timeout = 5000  # 5秒超时
    inst.read_termination = '\\\\n'
    inst.write_termination = '\\\\n'
    
    print("INFO: Connection successful", file=sys.stderr)
    print("CONNECTED")
    sys.stdout.flush()
    
    # 命令循环
    while True:
        try:
            line = sys.stdin.readline().strip()
            if not line or line == 'EXIT':
                break
            
            parts = line.split('|', 2)
            if len(parts) < 3:
                continue
            
            cmd_type, cmd_id, command = parts
            
            try:
                if cmd_type == 'QUERY':
                    response = inst.query(command).strip()
                    print(f"{cmd_id}|{response}")
                elif cmd_type == 'WRITE':
                    inst.write(command)
                    print(f"{cmd_id}|OK")
                sys.stdout.flush()
            except Exception as e:
                print(f"{cmd_id}|ERROR:{str(e)}")
                sys.stdout.flush()
                print(f"ERROR: Command failed: {e}", file=sys.stderr)
                
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"ERROR: Loop error: {e}", file=sys.stderr)
            break
    
    inst.close()
    rm.close()
    
except Exception as e:
    print(f"ERROR: Failed to connect: {e}", file=sys.stderr)
    sys.exit(1)
''';
  }
  
  void dispose() {
    disconnect();
    _responseController.close();
  }
}
