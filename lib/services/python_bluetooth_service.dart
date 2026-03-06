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
    final currentDir = Directory.current.path;

    // 可能的脚本位置
    final candidates = [
      // Flutter 打包后的位置
      path.join(exeDir, 'data', 'flutter_assets', 'assets', 'scripts', 'bluetooth_spp_test.py'),
      path.join(exeDir, 'data', 'flutter_assets', 'scripts', 'bluetooth_spp_test.py'),
      
      // 与可执行文件同级的 scripts 目录
      path.join(exeDir, 'scripts', 'bluetooth_spp_test.py'),
      
      // 可执行文件上一级的 scripts 目录
      path.join(path.dirname(exeDir), 'scripts', 'bluetooth_spp_test.py'),
      
      // 当前工作目录
      path.join(currentDir, 'scripts', 'bluetooth_spp_test.py'),
      
      // 开发环境路径
      path.join(currentDir, 'assets', 'scripts', 'bluetooth_spp_test.py'),
    ];

    _logState?.debug('   搜索脚本文件...');
    _logState?.debug('   可执行文件目录: $exeDir');
    _logState?.debug('   当前工作目录: $currentDir');

    for (final scriptPath in candidates) {
      _logState?.debug('   检查: $scriptPath');
      if (await File(scriptPath).exists()) {
        _logState?.debug('   ✓ 找到脚本');
        return scriptPath;
      }
    }

    _logState?.debug('   ✗ 所有路径都不存在');
    
    // 尝试从 assets 复制
    _logState?.debug('   尝试从 assets 复制脚本...');
    try {
      final scriptContent = await _loadScriptFromAssets();
      if (scriptContent != null) {
        final tempDir = Directory.systemTemp;
        final tempScriptPath = path.join(tempDir.path, 'bluetooth_spp_test.py');
        final tempFile = File(tempScriptPath);
        await tempFile.writeAsString(scriptContent);
        _logState?.debug('   ✓ 复制到临时目录: $tempScriptPath');
        
        // 同时复制 setup_bluetooth.py
        final setupContent = await _loadSetupScriptFromAssets();
        if (setupContent != null) {
          final tempSetupPath = path.join(tempDir.path, 'setup_bluetooth.py');
          await File(tempSetupPath).writeAsString(setupContent);
        }
        
        return tempScriptPath;
      }
    } catch (e) {
      _logState?.debug('   ✗ 从 assets 复制失败: $e');
    }
    
    return null;
  }
  
  /// 从 assets 加载脚本内容
  Future<String?> _loadScriptFromAssets() async {
    try {
      // 这里需要使用 rootBundle 加载 assets
      // 但由于我们在 service 中，需要通过其他方式
      // 暂时返回 null，让用户手动部署脚本
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// 从 assets 加载安装脚本内容
  Future<String?> _loadSetupScriptFromAssets() async {
    try {
      return null;
    } catch (e) {
      return null;
    }
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
      // 检查 Python 版本
      final versionResult = await Process.run(_pythonPath!, ['--version']);
      final versionStr = versionResult.stdout.toString();
      _logState?.debug('   Python 版本: $versionStr');
      
      // 检查是否是 Python 3.13+（PyBluez 不兼容）
      if (versionStr.contains('3.13') || versionStr.contains('3.14') || versionStr.contains('3.15')) {
        _logState?.warning('   ⚠️  检测到 Python 3.13+');
        _logState?.warning('   PyBluez 不支持 Python 3.13+（use_2to3 已废弃）');
        _logState?.info('');
        _logState?.info('   尝试使用 Python 3.12 的预编译包...');
        
        // 尝试安装 Python 3.12 的 wheel（通常可以在 3.13 上工作）
        final wheelInstalled = await _installPrecompiledWheel('3.12');
        if (wheelInstalled) {
          return true;
        }
        
        _logState?.error('');
        _logState?.error('   ❌ 无法自动安装');
        _logState?.info('   建议: 降级到 Python 3.9-3.12');
        return false;
      }
      
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
        final stderr = result.stderr.toString();
        _logState?.debug('   错误: $stderr');
        
        // 检查是否是 use_2to3 错误
        if (stderr.contains('use_2to3 is invalid')) {
          _logState?.warning('');
          _logState?.warning('   检测到 use_2to3 错误');
          _logState?.warning('   这是 Python 版本兼容性问题');
        }
      }

      // 方法 2: 尝试使用预编译 wheel
      _logState?.info('   方法 2: 尝试使用预编译包...');
      
      // 提取 Python 版本号
      String? pyVer;
      if (versionStr.contains('3.8')) pyVer = '3.8';
      else if (versionStr.contains('3.9')) pyVer = '3.9';
      else if (versionStr.contains('3.10')) pyVer = '3.10';
      else if (versionStr.contains('3.11')) pyVer = '3.11';
      else if (versionStr.contains('3.12')) pyVer = '3.12';
      
      if (pyVer != null) {
        _logState?.info('   检测到 Python $pyVer');
        final wheelInstalled = await _installPrecompiledWheel(pyVer);
        if (wheelInstalled) {
          return true;
        }
      } else {
        _logState?.warning('   ⚠️  无法识别 Python 版本: $versionStr');
      }

      // 方法 3: 尝试使用 setup_bluetooth.py 脚本
      _logState?.info('   方法 3: 尝试使用安装脚本...');
      
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
      path.join(exeDir, 'data', 'flutter_assets', 'assets', 'scripts', 'setup_bluetooth.py'),
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

  /// 安装预编译的 wheel 文件
  Future<bool> _installPrecompiledWheel(String pythonVersion) async {
    try {
      _logState?.info('   尝试使用 pip download 下载预编译包...');
      
      // 使用临时目录
      final tempDir = Directory.systemTemp;
      final downloadDir = path.join(tempDir.path, 'pybluez_wheels');
      await Directory(downloadDir).create(recursive: true);
      
      // 方法 1: 使用 pip download 下载 wheel（使用国内镜像）
      final mirrors = [
        'https://pypi.tuna.tsinghua.edu.cn/simple',  // 清华镜像
        'https://mirrors.aliyun.com/pypi/simple/',   // 阿里云镜像
        null,  // 默认PyPI
      ];
      
      ProcessResult? downloadResult;
      for (int i = 0; i < mirrors.length; i++) {
        final mirror = mirrors[i];
        final mirrorName = mirror == null 
            ? '默认PyPI' 
            : (mirror.contains('tsinghua') ? '清华镜像' : '阿里云镜像');
        
        _logState?.debug('   尝试 $mirrorName...');
        
        final args = [
          '-m', 'pip', 'download',
          '--only-binary=:all:',  // 只下载二进制包
          '--dest', downloadDir,
          '--no-deps',  // 不下载依赖
          if (mirror != null) ...['-i', mirror],  // 指定镜像源
          'pybluez==0.23',
        ];
        
        try {
          downloadResult = await Process.run(
            _pythonPath!,
            args,
            runInShell: true,
          ).timeout(
            const Duration(minutes: 2),
            onTimeout: () {
              throw TimeoutException('下载超时');
            },
          );
          
          if (downloadResult.exitCode == 0) {
            _logState?.debug('   ✓ $mirrorName 下载成功');
            break;
          } else {
            _logState?.debug('   ✗ $mirrorName 失败');
          }
        } catch (e) {
          _logState?.debug('   ✗ $mirrorName 异常: $e');
        }
      }
      
      if (downloadResult != null && downloadResult.exitCode == 0) {
        _logState?.debug('   ✓ pip download 成功');
        
        // 查找下载的 wheel 文件
        final wheelFiles = Directory(downloadDir)
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.whl'))
            .toList();
        
        if (wheelFiles.isNotEmpty) {
          final wheelPath = wheelFiles.first.path;
          _logState?.success('   ✅ 找到 wheel: ${path.basename(wheelPath)}');
          _logState?.info('   正在安装...');
          
          // 安装下载的 wheel
          final installResult = await Process.run(
            _pythonPath!,
            ['-m', 'pip', 'install', wheelPath, '--user', '--force-reinstall'],
            runInShell: true,
          ).timeout(
            const Duration(minutes: 2),
            onTimeout: () {
              throw TimeoutException('安装超时');
            },
          );
          
          if (installResult.exitCode == 0) {
            _logState?.success('   ✅ 预编译包安装成功');
            
            // 验证安装
            final installed = await _checkPyBluez();
            if (installed) {
              // 清理临时文件
              try {
                await Directory(downloadDir).delete(recursive: true);
              } catch (_) {}
              return true;
            }
          } else {
            _logState?.warning('   ⚠️  安装失败');
            _logState?.debug('   错误: ${installResult.stderr}');
          }
        } else {
          _logState?.warning('   ⚠️  未找到下载的 wheel 文件');
        }
      } else {
        _logState?.warning('   ⚠️  所有镜像源都失败');
        if (downloadResult != null) {
          _logState?.debug('   最后错误: ${downloadResult.stderr}');
        }
      }
      
      // 清理
      try {
        await Directory(downloadDir).delete(recursive: true);
      } catch (_) {}
      
      return false;
    } catch (e) {
      _logState?.error('   ❌ 预编译包安装异常: $e');
      return false;
    }
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
