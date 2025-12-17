import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/log_state.dart';

/// GPIB 通讯服务
/// 通过 PyVISA 桥接实现 GPIB 设备通讯
class GpibService {
  Process? _process;
  StreamSubscription? _stdoutSubscription;
  StreamSubscription? _stderrSubscription;
  
  String? _currentAddress;
  bool _isConnected = false;
  LogState? _logState;
  
  // 数据流控制器
  final StreamController<Map<String, dynamic>> _dataController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // 命令响应等待
  final Map<String, Completer<String>> _pendingCommands = {};
  
  void setLogState(LogState logState) {
    _logState = logState;
  }
  
  /// 检查是否已连接
  bool get isConnected => _isConnected;
  
  /// 获取当前地址
  String? get currentAddress => _currentAddress;
  
  /// 获取数据流
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;
  
  /// 列出所有可用的 GPIB 资源
  Future<List<String>> listResources() async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
      _logState?.info('扫描可用的 GPIB 设备...', type: LogType.gpib);
      
      // 检查 Python 环境
      final envCheck = await checkPythonEnvironment();
      if (!(envCheck['pythonInstalled'] as bool) || !(envCheck['pyvisaInstalled'] as bool)) {
        _logState?.error('❌ Python 或 PyVISA 未安装', type: LogType.gpib);
        return [];
      }
      
      final pythonCmd = envCheck['pythonCommand'] as String;
      
      // 创建临时 Python 脚本来列出资源
      final scriptContent = '''
import pyvisa
try:
    rm = pyvisa.ResourceManager()
    resources = rm.list_resources()
    for res in resources:
        print(res)
    rm.close()
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
''';
      
      final tempDir = Directory.systemTemp;
      final scriptFile = File('${tempDir.path}/list_gpib_resources.py');
      await scriptFile.writeAsString(scriptContent);
      
      // 执行脚本
      final result = await Process.run(pythonCmd, [scriptFile.path]);
      
      if (result.exitCode == 0) {
        final resources = result.stdout.toString().trim().split('\n')
            .where((line) => line.isNotEmpty)
            .toList();
        
        if (resources.isEmpty) {
          _logState?.warning('⚠️  未找到任何 GPIB 设备', type: LogType.gpib);
          _logState?.info('请检查：', type: LogType.gpib);
          _logState?.info('1. 设备是否已连接并开机', type: LogType.gpib);
          _logState?.info('2. NI-VISA 驱动是否正确安装', type: LogType.gpib);
          _logState?.info('3. 在 NI MAX 中是否能看到设备', type: LogType.gpib);
        } else {
          _logState?.success('✅ 找到 ${resources.length} 个设备：', type: LogType.gpib);
          for (final res in resources) {
            _logState?.info('   📍 $res', type: LogType.gpib);
          }
        }
        
        _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
        return resources;
      } else {
        _logState?.error('❌ 扫描失败: ${result.stderr}', type: LogType.gpib);
        return [];
      }
    } catch (e) {
      _logState?.error('扫描 GPIB 设备失败: $e', type: LogType.gpib);
      return [];
    }
  }
  
  /// 检查 Python 环境
  Future<Map<String, dynamic>> checkPythonEnvironment() async {
    final result = {
      'pythonInstalled': false,
      'pythonCommand': '',
      'pyvisaInstalled': false,
      'error': '',
    };
    
    try {
      // 尝试不同的 Python 命令
      final pythonCommands = ['python', 'python3', 'py'];
      
      for (final cmd in pythonCommands) {
        try {
          final processResult = await Process.run(cmd, ['--version']);
          if (processResult.exitCode == 0) {
            result['pythonInstalled'] = true;
            result['pythonCommand'] = cmd;
            _logState?.info('找到 Python: ${processResult.stdout.toString().trim()} (命令: $cmd)', type: LogType.gpib);
            break;
          }
        } catch (e) {
          // 继续尝试下一个命令
        }
      }
      
      if (!(result['pythonInstalled'] as bool)) {
        result['error'] = 'Python 未安装';
        return result;
      }
      
      // 检查 pyvisa 是否安装
      try {
        final pyvisaCheck = await Process.run(
          result['pythonCommand'] as String,
          ['-c', 'import pyvisa; print(pyvisa.__version__)'],
        );
        
        if (pyvisaCheck.exitCode == 0) {
          result['pyvisaInstalled'] = true;
          _logState?.info('PyVISA 已安装: ${pyvisaCheck.stdout.toString().trim()}', type: LogType.gpib);
        } else {
          result['error'] = 'PyVISA 未安装';
        }
      } catch (e) {
        result['error'] = 'PyVISA 未安装';
      }
      
    } catch (e) {
      result['error'] = '检查环境失败: $e';
    }
    
    return result;
  }
  
  /// 安装 Python 依赖
  Future<bool> installPythonDependencies() async {
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
      _logState?.info('开始安装 Python 依赖...', type: LogType.gpib);
      
      // 检查 Python
      final envCheck = await checkPythonEnvironment();
      if (!(envCheck['pythonInstalled'] as bool)) {
        _logState?.error('❌ Python 未安装，请先安装 Python 3.7+', type: LogType.gpib);
        _logState?.info('下载地址: https://www.python.org/downloads/', type: LogType.gpib);
        return false;
      }
      
      final pythonCmd = envCheck['pythonCommand'] as String;
      
      // 安装 pyvisa 和 pyvisa-py
      _logState?.info('正在安装 PyVISA...', type: LogType.gpib);
      final pyvisaResult = await Process.run(
        pythonCmd,
        ['-m', 'pip', 'install', 'pyvisa', 'pyvisa-py', '--user'],
      );
      
      if (pyvisaResult.exitCode == 0) {
        _logState?.success('✅ PyVISA 安装成功', type: LogType.gpib);
        _logState?.debug(pyvisaResult.stdout.toString(), type: LogType.gpib);
      } else {
        _logState?.error('❌ PyVISA 安装失败', type: LogType.gpib);
        _logState?.error(pyvisaResult.stderr.toString(), type: LogType.gpib);
        return false;
      }
      
      _logState?.success('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
      _logState?.success('Python 依赖安装完成！', type: LogType.gpib);
      return true;
    } catch (e) {
      _logState?.error('安装依赖失败: $e', type: LogType.gpib);
      return false;
    }
  }
  
  /// 连接到 GPIB 设备
  /// address: GPIB 地址，格式如 "GPIB0::10::INSTR"
  Future<bool> connect(String address) async {
    try {
      _logState?.info('开始连接 GPIB 设备: $address', type: LogType.gpib);
      
      // 检查 Python 环境
      _logState?.debug('检查 Python 环境...', type: LogType.gpib);
      final envCheck = await checkPythonEnvironment();
      
      if (!(envCheck['pythonInstalled'] as bool)) {
        _logState?.error('❌ Python 未安装！', type: LogType.gpib);
        _logState?.error('请先安装 Python 3.7+ 或点击"安装 Python 依赖"按钮', type: LogType.gpib);
        _logState?.info('Python 下载: https://www.python.org/downloads/', type: LogType.gpib);
        return false;
      }
      
      if (!(envCheck['pyvisaInstalled'] as bool)) {
        _logState?.error('❌ PyVISA 未安装！', type: LogType.gpib);
        _logState?.error('请点击"安装 Python 依赖"按钮安装所需依赖', type: LogType.gpib);
        return false;
      }
      
      final pythonCmd = envCheck['pythonCommand'] as String;
      _logState?.info('使用 Python 命令: $pythonCmd', type: LogType.gpib);
      
      // 断开现有连接
      await disconnect();
      
      // 启动 Python 桥接进程
      _logState?.debug('启动 Python GPIB 桥接进程...', type: LogType.gpib);
      
      // 创建 Python 脚本来处理 GPIB 通讯
      final scriptPath = await _createGpibBridgeScript();
      
      _process = await Process.start(
        pythonCmd,
        [scriptPath, address],
        mode: ProcessStartMode.normal,
      );
      
      // 创建连接确认的 Completer
      final connectionCompleter = Completer<bool>();
      
      // 监听标准输出
      _stdoutSubscription = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        // 检查是否是连接成功信号
        if (line.startsWith('CONNECTED|')) {
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.complete(true);
          }
        }
        _handleOutput(line);
      });
      
      // 监听标准错误
      _stderrSubscription = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _logState?.info('Python: $line', type: LogType.gpib);
      });
      
      // 等待连接确认或超时
      _logState?.debug('等待 GPIB 设备响应...', type: LogType.gpib);
      
      final connected = await connectionCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _logState?.error('⏱️  连接超时：设备未响应', type: LogType.gpib);
          return false;
        },
      );
      
      // 检查进程是否还在运行
      if (_process == null || _process!.exitCode != null) {
        _logState?.error('❌ Python 桥接进程已退出', type: LogType.gpib);
        return false;
      }
      
      if (!connected) {
        _logState?.error('❌ GPIB 设备连接失败', type: LogType.gpib);
        await disconnect();
        return false;
      }
      
      _currentAddress = address;
      _isConnected = true;
      _logState?.success('✅ GPIB 设备连接成功: $address', type: LogType.gpib);
      
      return true;
    } catch (e) {
      _logState?.error('GPIB 连接失败: $e', type: LogType.gpib);
      _logState?.error('请确保：', type: LogType.gpib);
      _logState?.error('1. Python 已正确安装', type: LogType.gpib);
      _logState?.error('2. PyVISA 已安装 (pip install pyvisa pyvisa-py)', type: LogType.gpib);
      _logState?.error('3. NI-VISA 驱动已安装', type: LogType.gpib);
      return false;
    }
  }
  
  /// 断开连接
  Future<void> disconnect() async {
    try {
      if (_process != null) {
        // 发送退出命令
        await sendCommand('EXIT');
        await Future.delayed(const Duration(milliseconds: 500));
        
        _process?.kill();
        await _stdoutSubscription?.cancel();
        await _stderrSubscription?.cancel();
        
        _process = null;
        _stdoutSubscription = null;
        _stderrSubscription = null;
      }
      
      _currentAddress = null;
      _isConnected = false;
      _logState?.info('GPIB 设备已断开', type: LogType.gpib);
    } catch (e) {
      _logState?.error('断开 GPIB 连接时出错: $e', type: LogType.gpib);
    }
  }
  
  /// 发送命令
  Future<String?> sendCommand(String command, {Duration timeout = const Duration(seconds: 5)}) async {
    if (!_isConnected || _process == null) {
      _logState?.error('GPIB 设备未连接', type: LogType.gpib);
      return null;
    }
    
    try {
      _logState?.debug('发送 GPIB 命令: $command', type: LogType.gpib);
      
      // 创建 completer 等待响应
      final completer = Completer<String>();
      final commandId = DateTime.now().millisecondsSinceEpoch.toString();
      _pendingCommands[commandId] = completer;
      
      // 发送命令（格式：commandId|command）
      _process!.stdin.writeln('$commandId|$command');
      await _process!.stdin.flush();
      
      // 等待响应或超时
      final response = await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingCommands.remove(commandId);
          _logState?.warning('GPIB 命令超时: $command', type: LogType.gpib);
          return 'TIMEOUT';
        },
      );
      
      _pendingCommands.remove(commandId);
      
      if (response != 'TIMEOUT') {
        _logState?.debug('GPIB 响应: $response', type: LogType.gpib);
      }
      
      return response;
    } catch (e) {
      _logState?.error('发送 GPIB 命令失败: $e', type: LogType.gpib);
      return null;
    }
  }
  
  /// 查询命令（发送并等待响应）
  Future<String?> query(String command, {Duration timeout = const Duration(seconds: 5)}) async {
    return await sendCommand(command, timeout: timeout);
  }
  
  /// 处理输出
  void _handleOutput(String line) {
    try {
      if (line.isEmpty) return;
      
      // 解析响应格式：commandId|response
      if (line.contains('|')) {
        final parts = line.split('|');
        if (parts.length >= 2) {
          final commandId = parts[0];
          final response = parts.sublist(1).join('|');
          
          // 完成对应的命令
          if (_pendingCommands.containsKey(commandId)) {
            _pendingCommands[commandId]?.complete(response);
          }
        }
      } else {
        // 日志或数据输出
        if (line.startsWith('INFO:')) {
          _logState?.info(line.substring(5).trim(), type: LogType.gpib);
        } else if (line.startsWith('ERROR:')) {
          _logState?.error(line.substring(6).trim(), type: LogType.gpib);
        } else if (line.startsWith('DATA:')) {
          // 解析数据
          final data = line.substring(5).trim();
          _parseData(data);
        } else {
          _logState?.debug(line, type: LogType.gpib);
        }
      }
    } catch (e) {
      _logState?.error('解析 GPIB 输出失败: $e', type: LogType.gpib);
    }
  }
  
  /// 解析数据
  void _parseData(String data) {
    try {
      // 假设数据格式为 JSON
      final jsonData = jsonDecode(data);
      _dataController.add(jsonData);
    } catch (e) {
      _logState?.debug('数据: $data', type: LogType.gpib);
    }
  }
  
  /// 创建 Python 桥接脚本
  Future<String> _createGpibBridgeScript() async {
    final scriptContent = '''
import sys
import pyvisa
import time

def main():
    if len(sys.argv) < 2:
        print("ERROR: No GPIB address provided", file=sys.stderr)
        sys.exit(1)
    
    address = sys.argv[1]
    
    try:
        # 初始化 VISA 资源管理器
        print(f"INFO: Initializing VISA Resource Manager...", file=sys.stderr)
        rm = pyvisa.ResourceManager()
        
        # 列出所有可用资源
        try:
            resources = rm.list_resources()
            print(f"INFO: Available resources: {resources}", file=sys.stderr)
        except Exception as e:
            print(f"WARNING: Could not list resources: {e}", file=sys.stderr)
        
        # 连接到设备
        print(f"INFO: Connecting to {address}...", file=sys.stderr)
        instrument = rm.open_resource(address)
        
        # 设置超时
        instrument.timeout = 5000  # 5秒超时
        
        # 测试连接 - 发送 *IDN? 查询
        try:
            idn = instrument.query("*IDN?").strip()
            print(f"INFO: Device identified: {idn}", file=sys.stderr)
        except Exception as e:
            print(f"WARNING: Could not query *IDN?: {e}", file=sys.stderr)
        
        # 发送连接成功信号
        print("CONNECTED|OK")
        sys.stdout.flush()
        
        # 命令处理循环
        while True:
            try:
                line = sys.stdin.readline()
                if not line:
                    time.sleep(0.01)
                    continue
                
                line = line.strip()
                if not line:
                    continue
                
                if line == "EXIT":
                    print("INFO: Received EXIT command", file=sys.stderr)
                    break
                
                # 解析命令格式：commandId|command
                if '|' in line:
                    parts = line.split('|', 1)
                    if len(parts) != 2:
                        continue
                    
                    command_id, command = parts
                    
                    try:
                        # 判断是写命令还是查询命令
                        if '?' in command:
                            response = instrument.query(command).strip()
                            print(f"{command_id}|{response}")
                        else:
                            instrument.write(command)
                            print(f"{command_id}|OK")
                        
                        sys.stdout.flush()
                    except Exception as e:
                        error_msg = str(e).replace('|', '_')
                        print(f"{command_id}|ERROR:{error_msg}")
                        sys.stdout.flush()
                        print(f"ERROR: Command failed: {e}", file=sys.stderr)
                        
            except KeyboardInterrupt:
                print("INFO: Keyboard interrupt", file=sys.stderr)
                break
            except Exception as e:
                print(f"ERROR: Loop error: {str(e)}", file=sys.stderr)
        
        # 清理
        print("INFO: Closing connection...", file=sys.stderr)
        instrument.close()
        rm.close()
        print("INFO: GPIB connection closed", file=sys.stderr)
        
    except Exception as e:
        print(f"ERROR: Failed to connect to {address}: {str(e)}", file=sys.stderr)
        print(f"ERROR: Make sure NI-VISA is installed and the device is accessible", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
''';
    
    // 创建临时脚本文件
    final tempDir = Directory.systemTemp;
    final scriptFile = File('${tempDir.path}/gpib_bridge.py');
    await scriptFile.writeAsString(scriptContent);
    
    _logState?.debug('Python 桥接脚本已创建: ${scriptFile.path}', type: LogType.gpib);
    
    return scriptFile.path;
  }
  
  /// 释放资源
  void dispose() {
    disconnect();
    _dataController.close();
  }
}
