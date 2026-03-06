import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import '../models/log_state.dart';

/// Python 蓝牙服务
/// 通过调用 Python 脚本实现蓝牙 SPP 通信
/// 支持自定义 UUID 和 RFCOMM channel
class PythonBluetoothService {
  LogState? _logState;
  String? _pythonPath;
  String? _scriptPath;
  bool _isInitialized = false;

  /// 设置日志状态
  void setLogState(LogState logState) {
    _logState = logState;
  }

  /// 初始化 Python 环境
  Future<bool> initialize() async {
    try {
      _logState?.info('📋 步骤 1/3: 检查 Python 环境');

      // 查找 Python 可执行文件
      _pythonPath = await _findPython();
      if (_pythonPath == null) {
        _logState?.error('   ❌ 未找到 Python 环境');
        _logState?.warning('   请安装 Python 3.7+ 并添加到 PATH');
        return false;
      }

      _logState?.success('   ✅ Python: $_pythonPath');

      // 查找脚本文件
      _logState?.info('📋 步骤 2/3: 查找蓝牙测试脚本');
      _scriptPath = await _findScript();
      if (_scriptPath == null) {
        _logState?.error('   ❌ 未找到蓝牙测试脚本');
        _logState?.info('   脚本路径: scripts/bluetooth_spp_test.py');
        return false;
      }

      _logState?.success('   ✅ 脚本: $_scriptPath');

      // 检查 PyBluez 是否安装
      _logState?.info('📋 步骤 3/3: 检查 PyBluez 安装状态');
      final hasPyBluez = await _checkPyBluez();
      
      if (!hasPyBluez) {
        _logState?.warning('   ⚠️  PyBluez 未安装');
        _logState?.info('');
        _logState?.info('🔧 开始自动安装 PyBluez...');
        _logState?.info('   这可能需要 30-60 秒，请稍候...');
        
        final installed = await _autoInstallPyBluez();
        
        if (!installed) {
          _logState?.error('');
          _logState?.error('❌ 自动安装失败');
          _logState?.info('');
          _logState?.info('请手动安装 PyBluez:');
          _logState?.info('   方法 1: pip install pybluez --user');
          _logState?.info('   方法 2: python scripts/setup_bluetooth.py --install');
          _logState?.info('   方法 3: 下载预编译 wheel 文件');
          _logState?.info('           https://www.lfd.uci.edu/~gohlke/pythonlibs/#pybluez');
          return false;
        }
        
        _logState?.info('');
        _logState?.success('✅ PyBluez 自动安装成功');
      } else {
        _logState?.success('   ✅ PyBluez 已安装');
      }

      _isInitialized = true;
      _logState?.info('');
      _logState?.success('🎉 Python 蓝牙服务初始化完成');
      return true;
    } catch (e) {
      _logState?.error('❌ 初始化失败: $e');
      return false;
    }
  }

  /// 查找 Python 可执行文件
  Future<String?> _findPython() async {
    final candidates = ['python', 'python3', 'py'];

    for (final cmd in candidates) {
      try {
        final result = await Process.run(cmd, ['--version']);
        if (result.exitCode == 0) {
          final version = result.stdout.toString().trim();
          _logState?.debug('   版本: $version');
          return cmd;
        }
      } catch (e) {
        continue;
      }
    }

    return null;
  }

  /// 查找脚本文件
  Future<String?> _findScript() async {
    // 获取当前可执行文件目录
    final exeDir = path.dirname(Platform.resolvedExecutable);

    // 可能的脚本位置
    final candidates = [
      path.join(exeDir, 'data', 'flutter_assets', 'scripts', 'bluetooth_spp_test.py'),
      path.join(exeDir, 'scripts', 'bluetooth_spp_test.py'),
      path.join(Directory.current.path, 'scripts', 'bluetooth_spp_test.py'),
    ];

    for (final scriptPath in candidates) {
      if (await File(scriptPath).exists()) {
        return scriptPath;
      }
    }

    return null;
  }

  /// 检查 PyBluez 是否安装
  Future<bool> _checkPyBluez() async {
    try {
      final result = await Process.run(
        _pythonPath!,
        ['-c', 'import bluetooth; print("OK")'],
      );
      return result.exitCode == 0 && result.stdout.toString().contains('OK');
    } catch (e) {
      return false;
    }
  }

  /// 自动安装 PyBluez
  Future<bool> _autoInstallPyBluez() async {
    try {
      _logState?.info('   方法 1: 尝试使用 pip 安装...');
      
      // 尝试使用 pip 安装
      final result = await Process.run(
        _pythonPath!,
        ['-m', 'pip', 'install', 'pybluez', '--user'],
        runInShell: true,
      ).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw TimeoutException('安装超时');
        },
      );

      if (result.exitCode == 0) {
        _logState?.success('   ✅ pip 安装成功');
        
        // 验证安装
        final installed = await _checkPyBluez();
        if (installed) {
          return true;
        }
      } else {
        _logState?.warning('   ⚠️  pip 安装失败');
        _logState?.debug('   错误: ${result.stderr}');
      }

      // 方法 2: 尝试使用 setup_bluetooth.py 脚本
      _logState?.info('   方法 2: 尝试使用安装脚本...');
      
      final setupScriptPath = await _findSetupScript();
      if (setupScriptPath != null) {
        final setupResult = await Process.run(
          _pythonPath!,
          [setupScriptPath, '--install'],
          runInShell: true,
        ).timeout(
          const Duration(minutes: 5),
          onTimeout: () {
            throw TimeoutException('安装超时');
          },
        );

        if (setupResult.exitCode == 0) {
          _logState?.success('   ✅ 脚本安装成功');
          
          // 验证安装
          final installed = await _checkPyBluez();
          if (installed) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      _logState?.error('   ❌ 自动安装异常: $e');
      return false;
    }
  }

  /// 查找 setup_bluetooth.py 脚本
  Future<String?> _findSetupScript() async {
    final exeDir = path.dirname(Platform.resolvedExecutable);

    final candidates = [
      path.join(exeDir, 'data', 'flutter_assets', 'scripts', 'setup_bluetooth.py'),
      path.join(exeDir, 'scripts', 'setup_bluetooth.py'),
      path.join(Directory.current.path, 'scripts', 'setup_bluetooth.py'),
    ];

    for (final scriptPath in candidates) {
      if (await File(scriptPath).exists()) {
        return scriptPath;
      }
    }

    return null;
  }

  /// 扫描蓝牙设备
  Future<List<Map<String, String>>> scanDevices() async {
    if (!_isInitialized) {
      throw Exception('服务未初始化，请先调用 initialize()');
    }

    _logState?.info('🔍 扫描蓝牙设备...');

    try {
      final result = await Process.run(
        _pythonPath!,
        [_scriptPath!, '--scan'],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        _logState?.error('❌ 扫描失败: ${result.stderr}');
        return [];
      }

      // 解析输出
      final output = result.stdout.toString();
      final devices = _parseDevices(output);

      _logState?.success('✅ 找到 ${devices.length} 个设备');
      return devices;
    } catch (e) {
      _logState?.error('❌ 扫描异常: $e');
      return [];
    }
  }

  /// 查找设备服务
  Future<List<Map<String, dynamic>>> findServices(String deviceAddress) async {
    if (!_isInitialized) {
      throw Exception('服务未初始化，请先调用 initialize()');
    }

    _logState?.info('🔍 查找设备服务: $deviceAddress');

    try {
      final result = await Process.run(
        _pythonPath!,
        [_scriptPath!, '--services', deviceAddress],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        _logState?.error('❌ 查找服务失败: ${result.stderr}');
        return [];
      }

      final output = result.stdout.toString();
      final services = _parseServices(output);

      _logState?.success('✅ 找到 ${services.length} 个服务');
      return services;
    } catch (e) {
      _logState?.error('❌ 查找服务异常: $e');
      return [];
    }
  }

  /// 连接设备并发送 GTP 命令
  Future<Map<String, dynamic>> sendGTPCommand({
    required String deviceAddress,
    required Uint8List commandPayload,
    String? uuid,
    int? channel,
    int moduleId = 0x0000,
    int messageId = 0x0000,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_isInitialized) {
      throw Exception('服务未初始化，请先调用 initialize()');
    }

    _logState?.info('📡 通过 Python 发送 GTP 命令...');
    _logState?.info('   设备: $deviceAddress');
    if (uuid != null) _logState?.info('   UUID: $uuid');
    if (channel != null) _logState?.info('   Channel: $channel');

    try {
      // 构建命令参数
      final args = <String>[
        _scriptPath!,
        '--connect', deviceAddress,
        '--env-cmd',  // 使用环境变量传递命令
      ];

      if (uuid != null) {
        args.addAll(['--uuid', uuid]);
      }

      if (channel != null) {
        args.addAll(['--channel', channel.toString()]);
      }

      // 添加命令数据（通过环境变量传递）
      final env = <String, String>{
        'BT_CMD_PAYLOAD': commandPayload.map((b) => b.toRadixString(16).padLeft(2, '0')).join(''),
        'BT_MODULE_ID': moduleId.toRadixString(16).padLeft(4, '0'),
        'BT_MESSAGE_ID': messageId.toRadixString(16).padLeft(4, '0'),
      };

      // 执行 Python 脚本
      final process = await Process.start(
        _pythonPath!,
        args,
        environment: env,
        runInShell: true,
      );

      // 收集输出
      final stdout = StringBuffer();
      final stderr = StringBuffer();

      process.stdout.transform(utf8.decoder).listen((data) {
        stdout.write(data);
        _logState?.debug('   Python: $data');
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        stderr.write(data);
      });

      // 等待完成或超时
      final exitCode = await process.exitCode.timeout(
        timeout,
        onTimeout: () {
          process.kill();
          throw TimeoutException('命令执行超时');
        },
      );

      if (exitCode != 0) {
        _logState?.error('❌ 命令执行失败');
        _logState?.error('   错误: ${stderr.toString()}');
        return {
          'success': false,
          'error': stderr.toString(),
        };
      }

      // 解析响应
      final output = stdout.toString();
      final response = _parseResponse(output);

      if (response['success'] == true) {
        _logState?.success('✅ 命令执行成功');
      } else {
        _logState?.warning('⚠️  命令执行完成但可能有问题');
      }

      return response;
    } catch (e) {
      _logState?.error('❌ 发送命令异常: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 测试读取蓝牙 MAC 地址
  Future<String?> testReadBluetoothMAC({
    required String deviceAddress,
    String? uuid,
    int? channel,
  }) async {
    _logState?.info('📖 测试读取蓝牙 MAC 地址...');

    // CMD: 0x0D (蓝牙命令), OPT: 0x01 (读取)
    final cmdPayload = Uint8List.fromList([0x0D, 0x01]);

    final response = await sendGTPCommand(
      deviceAddress: deviceAddress,
      commandPayload: cmdPayload,
      uuid: uuid,
      channel: channel,
    );

    if (response['success'] == true && response['mac'] != null) {
      final mac = response['mac'] as String;
      _logState?.success('✅ 读取成功: $mac');
      return mac;
    } else {
      _logState?.error('❌ 读取失败');
      return null;
    }
  }

  /// 解析设备列表
  List<Map<String, String>> _parseDevices(String output) {
    final devices = <Map<String, String>>[];
    final lines = output.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // 查找设备名称行（格式: "1. DeviceName"）
      if (RegExp(r'^\d+\.\s+.+').hasMatch(line)) {
        final name = line.replaceFirst(RegExp(r'^\d+\.\s+'), '');
        
        // 下一行应该是地址（格式: "   地址: XX:XX:XX:XX:XX:XX"）
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          final addrMatch = RegExp(r'地址:\s*([0-9A-Fa-f:]+)').firstMatch(nextLine);
          
          if (addrMatch != null) {
            devices.add({
              'name': name,
              'address': addrMatch.group(1)!,
            });
          }
        }
      }
    }

    return devices;
  }

  /// 解析服务列表
  List<Map<String, dynamic>> _parseServices(String output) {
    final services = <Map<String, dynamic>>[];
    final lines = output.split('\n');

    Map<String, dynamic>? currentService;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('服务 ')) {
        if (currentService != null) {
          services.add(currentService);
        }
        currentService = {};
      } else if (currentService != null) {
        if (trimmed.startsWith('名称:')) {
          currentService['name'] = trimmed.replaceFirst('名称:', '').trim();
        } else if (trimmed.startsWith('RFCOMM Channel:')) {
          final channelStr = trimmed.replaceFirst('RFCOMM Channel:', '').trim();
          currentService['channel'] = int.tryParse(channelStr);
        } else if (trimmed.startsWith('服务 ID:')) {
          currentService['uuid'] = trimmed.replaceFirst('服务 ID:', '').trim();
        }
      }
    }

    if (currentService != null) {
      services.add(currentService);
    }

    return services;
  }

  /// 解析响应
  Map<String, dynamic> _parseResponse(String output) {
    final result = <String, dynamic>{
      'success': false,
      'output': output,
    };

    // 检查是否连接成功
    if (output.contains('✅ 连接成功')) {
      result['connected'] = true;
    }

    // 检查是否发送成功
    if (output.contains('✅ 发送成功')) {
      result['sent'] = true;
    }

    // 检查是否收到响应
    if (output.contains('📥 收到数据')) {
      result['received'] = true;
      
      // 尝试提取 MAC 地址（格式: "0D AA BB CC DD EE FF"）
      final macMatch = RegExp(r'0D\s+([0-9A-Fa-f]{2}\s+){6}').firstMatch(output);
      if (macMatch != null) {
        final macBytes = macMatch.group(0)!.split(' ').skip(1).take(6).join(':');
        result['mac'] = macBytes.toUpperCase();
      }
    }

    // 检查是否测试完成
    if (output.contains('✅ 测试完成')) {
      result['success'] = true;
    }

    // 检查错误
    if (output.contains('❌')) {
      result['success'] = false;
      final errorMatch = RegExp(r'❌\s+(.+)').firstMatch(output);
      if (errorMatch != null) {
        result['error'] = errorMatch.group(1);
      }
    }

    return result;
  }

  /// 检查服务是否可用
  bool get isAvailable => _isInitialized;

  /// 获取 Python 路径
  String? get pythonPath => _pythonPath;

  /// 获取脚本路径
  String? get scriptPath => _scriptPath;
}
