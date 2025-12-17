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
      
      // 监听标准输出
      _stdoutSubscription = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _handleOutput(line);
      });
      
      // 监听标准错误
      _stderrSubscription = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _logState?.error('GPIB 错误: $line', type: LogType.gpib);
      });
      
      // 等待连接确认
      await Future.delayed(const Duration(seconds: 2));
      
      // 检查进程是否还在运行
      if (_process == null || _process!.exitCode != null) {
        _logState?.error('❌ Python 桥接进程启动失败', type: LogType.gpib);
        return false;
      }
      
      _currentAddress = address;
      _isConnected = true;
      _logState?.success('GPIB 设备连接成功: $address', type: LogType.gpib);
      
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
import json

def main():
    if len(sys.argv) < 2:
        print("ERROR: No GPIB address provided", file=sys.stderr)
        sys.exit(1)
    
    address = sys.argv[1]
    
    try:
        # 初始化 VISA 资源管理器
        rm = pyvisa.ResourceManager()
        instrument = rm.open_resource(address)
        print(f"INFO: Connected to {address}")
        
        # 命令处理循环
        while True:
            try:
                line = sys.stdin.readline().strip()
                if not line:
                    continue
                
                if line == "EXIT":
                    break
                
                # 解析命令格式：commandId|command
                if '|' in line:
                    command_id, command = line.split('|', 1)
                    
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
                        print(f"{command_id}|ERROR:{str(e)}")
                        sys.stdout.flush()
                        
            except KeyboardInterrupt:
                break
            except Exception as e:
                print(f"ERROR: {str(e)}", file=sys.stderr)
        
        # 清理
        instrument.close()
        rm.close()
        print("INFO: GPIB connection closed")
        
    except Exception as e:
        print(f"ERROR: Failed to connect: {str(e)}", file=sys.stderr)
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
