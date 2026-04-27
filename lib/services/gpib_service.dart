import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/log_state.dart';
import '../config/test_config.dart';

/// GPIB 通讯服务
/// 通过 PyVISA 桥接实现 GPIB 设备通讯
class GpibService {
  Process? _process;
  StreamSubscription? _stdoutSubscription;
  StreamSubscription? _stderrSubscription;
  
  String? _currentAddress;
  bool _isConnected = false;
  bool _isDisconnecting = false;
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
      
      // 创建临时 Python 脚本来列出资源（多后端探测）
      final scriptContent = '''
import sys
import os
import pyvisa

backends = []
if os.name != 'nt':
    backends = ['@ni', '@py']
else:
    backends = ['', '@ni', '@py']

found_resources = set()
for backend in backends:
    try:
        if backend:
            rm = pyvisa.ResourceManager(backend)
        else:
            rm = pyvisa.ResourceManager()
        resources = rm.list_resources()
        for res in resources:
            found_resources.add(res)
        rm.close()
    except Exception:
        continue

for res in sorted(found_resources):
    print(res)
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
      
      // Linux (Debian/Ubuntu) Python 3.12+ 使用 externally-managed-environment，
      // 需要 --break-system-packages 才能 pip install
      final pipArgs = ['-m', 'pip', 'install', 'pyvisa', 'pyvisa-py', '--user'];
      if (Platform.isLinux) {
        pipArgs.add('--break-system-packages');
      }
      
      final pyvisaResult = await Process.run(pythonCmd, pipArgs);
      
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
  /// address: GPIB 地址，格式如 "GPIB0::5::INSTR"
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
        _logState?.warning('⚠️ PyVISA 未安装，正在自动安装...', type: LogType.gpib);
        final installed = await installPythonDependencies();
        if (!installed) {
          _logState?.error('❌ PyVISA 自动安装失败，请手动安装', type: LogType.gpib);
          return false;
        }
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
        runInShell: Platform.isWindows, // Windows 需要在 shell 中运行
      );
      
      // 创建连接确认的 Completer
      final connectionCompleter = Completer<bool>();
      
      // 监听进程退出
      _process!.exitCode.then((exitCode) {
        if (!_isDisconnecting) {
          _logState?.warning('Python 桥接进程退出，退出码: $exitCode', type: LogType.gpib);
        }
        if (!connectionCompleter.isCompleted) {
          connectionCompleter.complete(false);
        }
      });
      
      // 监听标准输出
      _stdoutSubscription = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          _logState?.debug('Python stdout: $line', type: LogType.gpib);
          // 检查是否是连接成功信号
          if (line.startsWith('CONNECTED|')) {
            if (!connectionCompleter.isCompleted) {
              _logState?.success('收到连接确认信号', type: LogType.gpib);
              connectionCompleter.complete(true);
            }
          }
          _handleOutput(line);
        },
        onError: (error) {
          _logState?.error('Python stdout 错误: $error', type: LogType.gpib);
        },
        onDone: () {
          _logState?.debug('Python stdout 流已关闭', type: LogType.gpib);
        },
      );
      
      // 监听标准错误
      _stderrSubscription = _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          _logState?.info('Python: $line', type: LogType.gpib);
        },
        onError: (error) {
          _logState?.error('Python stderr 错误: $error', type: LogType.gpib);
        },
        onDone: () {
          _logState?.debug('Python stderr 流已关闭', type: LogType.gpib);
        },
      );
      
      // 等待连接确认或超时（增加到40秒，因为设备初始化+多后端探测+*IDN?查询可能耗时较长）
      _logState?.debug('等待 GPIB 设备响应...', type: LogType.gpib);
      
      final connected = await connectionCompleter.future.timeout(
        const Duration(seconds: 40),
        onTimeout: () {
          _logState?.error('⏱️  连接超时：设备未响应', type: LogType.gpib);
          return false;
        },
      );
      
      // 检查连接结果
      if (!connected) {
        _logState?.error('❌ GPIB 设备连接失败', type: LogType.gpib);
        
        // 检查进程是否还在运行
        final exitCode = _process?.exitCode;
        if (exitCode != null) {
          await exitCode.then((code) {
            _logState?.error('Python 桥接进程已退出，退出码: $code', type: LogType.gpib);
          });
        }
        
        await disconnect();
        return false;
      }
      
      _currentAddress = address;
      _isConnected = true;
      _logState?.success('✅ GPIB 设备连接成功: $address', type: LogType.gpib);
      
      // 发送一个测试命令确保通信正常
      _logState?.debug('测试 GPIB 通信...', type: LogType.gpib);
      try {
        final testId = 'test_${DateTime.now().millisecondsSinceEpoch}';
        _process!.stdin.writeln('$testId|*IDN?');
        await _process!.stdin.flush();
        _logState?.debug('测试命令已发送', type: LogType.gpib);
      } catch (e) {
        _logState?.warning('测试命令发送失败: $e', type: LogType.gpib);
      }
      
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
    _isDisconnecting = true;
    try {
      if (_process != null) {
        // 发送退出命令
        try {
          _process!.stdin.writeln('EXIT');
          await _process!.stdin.flush();
        } catch (_) {}
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
    } finally {
      _isDisconnecting = false;
    }
  }
  
  /// 发送命令
  Future<String?> sendCommand(String command, {Duration timeout = TestConfig.defaultTimeout}) async {
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
  Future<String?> query(String command, {Duration timeout = TestConfig.defaultTimeout}) async {
    return await sendCommand(command, timeout: timeout);
  }
  
  /// 初始化程控电源（WFP60H系列）
  /// 设置输出电压、电流限制等参数
  Future<bool> initializePowerSupply({
    double voltage = 5.0,
    double currentLimit = 3.0,
  }) async {
    if (!_isConnected || _process == null) {
      _logState?.error('GPIB 设备未连接', type: LogType.gpib);
      return false;
    }
    
    try {
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
      _logState?.info('初始化程控电源 (WFP60H)...', type: LogType.gpib);
      
      // 1. 选择输出通道1
      await sendCommand(':SOURce1:VOLTage $voltage');
      _logState?.info('✓ 设置电压: ${voltage}V', type: LogType.gpib);
      
      // 2. 设置电流限制
      await sendCommand(':SOURce1:CURRent:LIMit $currentLimit');
      _logState?.info('✓ 设置电流限制: ${currentLimit}A', type: LogType.gpib);
      
      // 3. 配置电流测量功能
      await sendCommand(':SENSe1:FUNCtion CURR');
      _logState?.info('✓ 配置测量功能: 电流', type: LogType.gpib);
      
      // 4. 设置电流测量范围为自动
      await sendCommand(':SENSe1:CURRent:RANGe:AUTO ON');
      _logState?.info('✓ 电流测量范围: 自动', type: LogType.gpib);
      
      // 5. 启用输出
      await sendCommand(':OUTPut1 ON');
      _logState?.info('✓ 输出已启用', type: LogType.gpib);
      
      _logState?.success('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
      _logState?.success('程控电源初始化完成', type: LogType.gpib);
      
      return true;
    } catch (e) {
      _logState?.error('程控电源初始化失败: $e', type: LogType.gpib);
      return false;
    }
  }
  
  /// 关闭输出
  Future<bool> disableOutput() async {
    if (!_isConnected || _process == null) {
      _logState?.error('GPIB 设备未连接', type: LogType.gpib);
      return false;
    }
    
    try {
      await sendCommand(':OUTPut1 OFF');
      _logState?.info('输出已关闭', type: LogType.gpib);
      return true;
    } catch (e) {
      _logState?.error('关闭输出失败: $e', type: LogType.gpib);
      return false;
    }
  }
  
  /// 测量电流（多次采样并计算平均值）
  /// 使用新版WFP60H SCPI命令
  /// sampleCount: 采样次数
  /// sampleRate: 采样率 (Hz)
  /// 返回平均电流值（安培 A），如果失败返回 null
  Future<double?> measureCurrent({
    required int sampleCount,
    required int sampleRate,
  }) async {
    if (!_isConnected || _process == null) {
      _logState?.error('GPIB 设备未连接', type: LogType.gpib);
      return null;
    }
    
    try {
      final sampleIntervalMs = 1000 ~/ sampleRate;
      final samples = <double>[];
      
      _logState?.info('开始电流采样: $sampleCount 次, ${sampleRate}Hz', type: LogType.gpib);
      _logState?.debug('采样间隔: ${sampleIntervalMs}ms', type: LogType.gpib);
      
      for (int i = 0; i < sampleCount; i++) {
        // 使用WFP60H READ命令读取电流: :READ[1]? (方括号表示通道1)
        _logState?.debug('正在采样 ${i + 1}/$sampleCount...', type: LogType.gpib);
        final response = await query(':READ[1]?', timeout: const Duration(seconds: 10));
        
        if (response == null || response == 'TIMEOUT') {
          _logState?.warning('采样 ${i + 1}/$sampleCount 超时（10秒）', type: LogType.gpib);
          _logState?.warning('可能原因：GPIB设备响应慢或未正确连接', type: LogType.gpib);
          continue;
        }
        
        // 解析电流值
        try {
          final current = double.parse(response.trim());
          samples.add(current);
          _logState?.debug('采样 ${i + 1}/$sampleCount: ${(current * 1000).toStringAsFixed(3)} mA', type: LogType.gpib);
        } catch (e) {
          _logState?.warning('采样 ${i + 1}/$sampleCount 解析失败: $response', type: LogType.gpib);
        }
        
        // 等待下一次采样（最后一次不需要等待）
        if (i < sampleCount - 1) {
          await Future.delayed(Duration(milliseconds: sampleIntervalMs));
        }
      }
      
      if (samples.isEmpty) {
        _logState?.error('未获取到有效的电流采样数据', type: LogType.gpib);
        return null;
      }
      
      // 计算平均值
      final average = samples.reduce((a, b) => a + b) / samples.length;
      
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
      _logState?.info('📊 电流采样统计:', type: LogType.gpib);
      _logState?.info('   有效采样数: ${samples.length}/$sampleCount', type: LogType.gpib);
      _logState?.info('   平均电流: ${(average * 1000).toStringAsFixed(3)} mA', type: LogType.gpib);
      _logState?.info('   最小值: ${(samples.reduce((a, b) => a < b ? a : b) * 1000).toStringAsFixed(3)} mA', type: LogType.gpib);
      _logState?.info('   最大值: ${(samples.reduce((a, b) => a > b ? a : b) * 1000).toStringAsFixed(3)} mA', type: LogType.gpib);
      _logState?.info('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', type: LogType.gpib);
      
      return average;
    } catch (e) {
      _logState?.error('电流测量失败: $e', type: LogType.gpib);
      return null;
    }
  }
  
  /// 读取单次电流值（快速读取）
  Future<double?> readCurrent() async {
    if (!_isConnected || _process == null) {
      _logState?.error('GPIB 设备未连接', type: LogType.gpib);
      return null;
    }
    
    try {
      final response = await query(':READ[1]?', timeout: const Duration(seconds: 5));
      
      if (response == null || response == 'TIMEOUT') {
        _logState?.warning('读取电流超时', type: LogType.gpib);
        return null;
      }
      
      final current = double.parse(response.trim());
      return current;
    } catch (e) {
      _logState?.error('读取电流失败: $e', type: LogType.gpib);
      return null;
    }
  }
  
  /// 设置输出电压
  Future<bool> setVoltage(double voltage) async {
    if (!_isConnected || _process == null) {
      _logState?.error('GPIB 设备未连接', type: LogType.gpib);
      return false;
    }
    
    try {
      await sendCommand(':SOURce1:VOLTage $voltage');
      _logState?.info('电压已设置: ${voltage}V', type: LogType.gpib);
      return true;
    } catch (e) {
      _logState?.error('设置电压失败: $e', type: LogType.gpib);
      return false;
    }
  }
  
  /// 设置电流限制
  Future<bool> setCurrentLimit(double currentLimit) async {
    if (!_isConnected || _process == null) {
      _logState?.error('GPIB 设备未连接', type: LogType.gpib);
      return false;
    }
    
    try {
      await sendCommand(':SOURce1:CURRent:LIMit $currentLimit');
      _logState?.info('电流限制已设置: ${currentLimit}A', type: LogType.gpib);
      return true;
    } catch (e) {
      _logState?.error('设置电流限制失败: $e', type: LogType.gpib);
      return false;
    }
  }
  
  /// 查询输出状态
  Future<bool?> getOutputState() async {
    if (!_isConnected || _process == null) {
      _logState?.error('GPIB 设备未连接', type: LogType.gpib);
      return null;
    }
    
    try {
      final response = await query(':OUTPut1:STATe?', timeout: const Duration(seconds: 5));
      
      if (response == null || response == 'TIMEOUT') {
        return null;
      }
      
      // 响应可能是 "1" 或 "0", 或 "ON" 或 "OFF"
      final state = response.trim().toUpperCase();
      return state == '1' || state == 'ON';
    } catch (e) {
      _logState?.error('查询输出状态失败: $e', type: LogType.gpib);
      return null;
    }
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
import os
import pyvisa
import time

def try_open_resource_manager():
    """尝试打开 VISA Resource Manager，优先使用 NI-VISA 后端"""
    backends = []
    
    # Linux 上优先尝试 NI-VISA (@ni)，然后 linux-gpib，最后 pyvisa-py (@py)
    # Windows 上默认就是 NI-VISA
    if os.name != 'nt':  # Linux/macOS
        backends = ['@ni', '@py']
    else:  # Windows
        backends = ['', '@ni', '@py']  # 空字符串 = 默认后端
    
    last_error = None
    for backend in backends:
        try:
            if backend:
                print(f"INFO: Trying VISA backend: {backend}", file=sys.stderr)
                rm = pyvisa.ResourceManager(backend)
            else:
                print(f"INFO: Trying default VISA backend", file=sys.stderr)
                rm = pyvisa.ResourceManager()
            
            # 验证能列出资源
            try:
                resources = rm.list_resources()
                print(f"INFO: Backend {backend or 'default'}: Available resources: {resources}", file=sys.stderr)
                
                # 检查是否有 GPIB 资源（而不是只有 ASRL 串口资源）
                gpib_resources = [r for r in resources if 'GPIB' in r.upper() or 'USB' in r.upper() or 'TCPIP' in r.upper()]
                if gpib_resources:
                    print(f"INFO: Found instrument resources: {gpib_resources}", file=sys.stderr)
                    return rm, backend
                else:
                    # 没有 GPIB 资源但可以列出资源 - 如果是最后一个后端也返回
                    if backend == backends[-1]:
                        print(f"WARNING: No GPIB/USB/TCPIP resources found with any backend", file=sys.stderr)
                        return rm, backend
                    else:
                        print(f"INFO: No instrument resources with backend {backend or 'default'}, trying next...", file=sys.stderr)
                        rm.close()
                        continue
            except Exception as e:
                print(f"WARNING: Could not list resources with {backend or 'default'}: {e}", file=sys.stderr)
                return rm, backend  # 仍然返回，让后续 open_resource 尝试
                
        except Exception as e:
            last_error = e
            print(f"WARNING: Backend {backend or 'default'} failed: {e}", file=sys.stderr)
            continue
    
    # 所有后端都失败，最后尝试默认
    print(f"WARNING: All preferred backends failed, trying default...", file=sys.stderr)
    try:
        rm = pyvisa.ResourceManager()
        return rm, 'default-fallback'
    except Exception as e:
        raise RuntimeError(f"Cannot initialize any VISA backend: {last_error}; final: {e}")

def main():
    if len(sys.argv) < 2:
        print("ERROR: No GPIB address provided", file=sys.stderr)
        sys.exit(1)
    
    address = sys.argv[1]
    
    try:
        # 初始化 VISA 资源管理器（自动选择后端）
        print(f"INFO: Initializing VISA Resource Manager...", file=sys.stderr)
        rm, backend_used = try_open_resource_manager()
        print(f"INFO: Using VISA backend: {backend_used or 'default'}", file=sys.stderr)
        
        # 列出所有可用资源并检查目标资源是否存在
        target_found = False
        try:
            resources = rm.list_resources()
            print(f"INFO: Available resources: {resources}", file=sys.stderr)
            
            # 检查目标地址是否在资源列表中
            for res in resources:
                if res.upper() == address.upper():
                    target_found = True
                    break
            
            if not target_found:
                print(f"WARNING: Target resource '{address}' not found in available resources: {resources}", file=sys.stderr)
                print(f"INFO: Will attempt to connect anyway...", file=sys.stderr)
        except Exception as e:
            print(f"WARNING: Could not list resources: {e}", file=sys.stderr)
        
        # 连接到设备
        print(f"INFO: Connecting to {address}...", file=sys.stderr)
        instrument = rm.open_resource(address)
        
        # 设置超时（增加到15秒，因为电流测量可能需要更长时间）
        instrument.timeout = 15000  # 15秒超时
        
        # 测试连接 - 发送 *IDN? 查询
        idn_ok = False
        try:
            idn = instrument.query("*IDN?").strip()
            print(f"INFO: Device identified: {idn}", file=sys.stderr)
            idn_ok = True
        except Exception as e:
            print(f"WARNING: Could not query *IDN?: {e}", file=sys.stderr)
            # 如果 *IDN? 失败且不是 GPIB 资源，说明连接到了错误的设备
            if not address.upper().startswith('GPIB'):
                print(f"ERROR: Connected to non-GPIB resource and *IDN? failed, likely wrong device", file=sys.stderr)
                instrument.close()
                rm.close()
                sys.exit(1)
        
        # 发送连接成功信号
        if idn_ok:
            print("CONNECTED|OK")
        else:
            # *IDN? 失败但资源打开成功（某些设备不支持 *IDN?）
            print("CONNECTED|OK")
            print(f"WARNING: Device connected but *IDN? failed - commands may not work", file=sys.stderr)
        sys.stdout.flush()
        
        # 等待一小段时间确保信号被接收
        time.sleep(0.1)
        
        # 命令处理循环
        print("INFO: Entering command loop", file=sys.stderr)
        sys.stderr.flush()
        
        # 保持循环运行，等待命令
        while True:
            try:
                # 尝试读取一行，设置较短的超时
                # 在 Windows 上，readline 是阻塞的
                # 我们需要检查 stdin 是否仍然打开
                try:
                    line = sys.stdin.readline()
                except Exception as e:
                    print(f"ERROR: Failed to read from stdin: {e}", file=sys.stderr)
                    break
                
                # 如果 readline 返回空字符串，说明 stdin 已关闭
                if line == '':
                    print("INFO: stdin closed (EOF received), exiting", file=sys.stderr)
                    break
                
                line = line.strip()
                
                # 跳过空行
                if not line:
                    continue
                
                # 处理退出命令
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
                    except pyvisa.errors.VisaIOError as e:
                        # VISA 超时或通信错误
                        error_msg = str(e).replace('|', '_')
                        print(f"{command_id}|TIMEOUT")
                        sys.stdout.flush()
                        print(f"ERROR: VISA error for command '{command}': {e}", file=sys.stderr)
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
