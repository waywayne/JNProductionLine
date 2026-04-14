import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../services/serial_service.dart';
import '../services/production_test_commands.dart';
import '../config/production_config.dart';
import 'log_state.dart';

/// OTA升级步骤枚举
enum OTAStep {
  idle,           // 空闲
  selectFile,     // 选择文件
  connectWiFi,    // 连接WiFi
  uploadFile,     // FTP上传文件
  startTest,      // 发送产测开始指令
  sendOTARequest, // 发送OTA请求
  upgrading,      // 升级中（监听状态）
  success,        // 升级成功
  failed,         // 升级失败
}

/// OTA升级状态管理
class OTAState extends ChangeNotifier {
  // 服务引用
  SerialService? _serialService;
  // Linux蓝牙服务引用（动态类型，兼容不同实现）
  dynamic _linuxBtService;
  LogState? _logState;
  
  // OTA状态
  OTAStep _currentStep = OTAStep.idle;
  bool _isUpgrading = false;
  String? _selectedFilePath;
  String? _selectedFileName;
  String? _deviceIP;
  String? _errorMessage;
  String _statusMessage = '';
  int? _lastOTAStatus;
  
  // 监听订阅
  StreamSubscription<Uint8List>? _pushSubscription;
  Timer? _otaTimeoutTimer;
  Completer<int>? _otaCompleter;
  
  // Getters
  OTAStep get currentStep => _currentStep;
  bool get isUpgrading => _isUpgrading;
  String? get selectedFilePath => _selectedFilePath;
  String? get selectedFileName => _selectedFileName;
  String? get deviceIP => _deviceIP;
  String? get errorMessage => _errorMessage;
  String get statusMessage => _statusMessage;
  int? get lastOTAStatus => _lastOTAStatus;
  
  bool get isConnected {
    if (_linuxBtService != null) {
      try {
        return (_linuxBtService as dynamic).isConnected == true;
      } catch (_) {}
    }
    return _serialService?.isConnected ?? false;
  }
  
  bool get _useLinuxBluetooth {
    if (_linuxBtService != null) {
      try {
        return (_linuxBtService as dynamic).isConnected == true;
      } catch (_) {}
    }
    return false;
  }
  
  /// 设置服务引用
  void setServices(SerialService serialService, dynamic linuxBtService) {
    _serialService = serialService;
    _linuxBtService = linuxBtService;
  }
  
  void setLogState(LogState logState) {
    _logState = logState;
  }
  
  /// 选择OTA文件
  void setSelectedFile(String filePath) {
    _selectedFilePath = filePath;
    _selectedFileName = path.basename(filePath);
    _errorMessage = null;
    notifyListeners();
  }
  
  /// 清除选择的文件
  void clearSelectedFile() {
    _selectedFilePath = null;
    _selectedFileName = null;
    notifyListeners();
  }
  
  /// 重置状态
  void reset() {
    _currentStep = OTAStep.idle;
    _isUpgrading = false;
    _deviceIP = null;
    _errorMessage = null;
    _statusMessage = '';
    _lastOTAStatus = null;
    _pushSubscription?.cancel();
    _pushSubscription = null;
    _otaTimeoutTimer?.cancel();
    _otaTimeoutTimer = null;
    _otaCompleter = null;
    notifyListeners();
  }
  
  /// 开始OTA升级流程
  Future<void> startOTAUpgrade() async {
    if (_selectedFilePath == null || _selectedFileName == null) {
      _errorMessage = '请先选择OTA文件';
      notifyListeners();
      return;
    }
    
    if (!isConnected) {
      _errorMessage = '设备未连接（串口或蓝牙均未连接）';
      notifyListeners();
      return;
    }
    
    _isUpgrading = true;
    _errorMessage = null;
    _lastOTAStatus = null;
    notifyListeners();
    
    try {
      // 步骤1: 连接WiFi获取IP
      _updateStep(OTAStep.connectWiFi, '正在连接WiFi...');
      final wifiSuccess = await _connectWiFiAndGetIP();
      if (!wifiSuccess) {
        _fail('WiFi连接失败，未获取到设备IP');
        return;
      }
      
      // 步骤2: FTP上传文件
      _updateStep(OTAStep.uploadFile, '正在上传OTA文件到设备...');
      final uploadSuccess = await _uploadFileViaFTP();
      if (!uploadSuccess) {
        _fail('FTP文件上传失败');
        return;
      }
      
      // 步骤3: 发送产测开始指令 0x00
      _updateStep(OTAStep.startTest, '发送产测开始指令...');
      final startSuccess = await _sendStartTestCommand();
      if (!startSuccess) {
        _fail('产测开始指令发送失败');
        return;
      }
      
      // 步骤4: 发送OTA请求 0xFA + 路径
      _updateStep(OTAStep.sendOTARequest, '发送OTA升级请求...');
      final otaRequestSuccess = await _sendOTARequest();
      if (!otaRequestSuccess) {
        _fail('OTA请求发送失败');
        return;
      }
      
      // 步骤5: 监听OTA状态推送
      _updateStep(OTAStep.upgrading, '设备升级中，请等待...');
      final otaResult = await _listenForOTAStatus();
      
      if (otaResult == ProductionTestCommands.otaStatusComplete ||
          otaResult == ProductionTestCommands.otaStatusSuccess) {
        _updateStep(OTAStep.success, 'OTA升级成功！');
        _logState?.success('OTA升级成功！', type: LogType.debug);
      } else {
        final statusName = ProductionTestCommands.getOTAStatusName(otaResult);
        _fail('OTA升级失败: $statusName');
      }
    } catch (e) {
      _fail('OTA升级异常: $e');
    } finally {
      _isUpgrading = false;
      _pushSubscription?.cancel();
      _pushSubscription = null;
      _otaTimeoutTimer?.cancel();
      _otaTimeoutTimer = null;
      notifyListeners();
    }
  }
  
  void _updateStep(OTAStep step, String message) {
    _currentStep = step;
    _statusMessage = message;
    _logState?.info('📦 OTA: $message', type: LogType.debug);
    notifyListeners();
  }
  
  void _fail(String message) {
    _currentStep = OTAStep.failed;
    _errorMessage = message;
    _statusMessage = message;
    _isUpgrading = false;
    _logState?.error('❌ OTA: $message', type: LogType.debug);
    notifyListeners();
  }
  
  /// 步骤1: 连接WiFi获取设备IP
  /// 复用现有WiFi多步骤流程：开始测试(0x00) → 等待10秒 → 连接热点(0x01 + SSID\0 + PWD\0) → 获取IP
  Future<bool> _connectWiFiAndGetIP() async {
    final config = ProductionConfig();
    final ssid = config.wifiSsid;
    final password = config.wifiPassword;
    
    if (ssid.isEmpty) {
      _logState?.error('❌ WiFi SSID未配置', type: LogType.debug);
      return false;
    }
    
    _logState?.info('📶 连接WiFi - SSID: "$ssid"', type: LogType.debug);
    
    // 第一步：发送WiFi开始测试指令 (0x04 + 0x00)
    _statusMessage = '发送WiFi开始测试...';
    notifyListeners();
    
    final startCommand = ProductionTestCommands.createControlWifiCommand(0x00);
    final startResponse = await _sendCommand(startCommand, timeout: const Duration(seconds: 5));
    
    if (startResponse == null || startResponse.containsKey('error')) {
      _logState?.error('❌ WiFi开始测试指令失败', type: LogType.debug);
      return false;
    }
    _logState?.success('✅ WiFi开始测试成功', type: LogType.debug);
    
    // 等待10秒让WiFi模块初始化
    _statusMessage = '等待WiFi模块初始化 (10秒)...';
    notifyListeners();
    _logState?.info('⏳ 等待10秒让WiFi模块初始化...', type: LogType.debug);
    await Future.delayed(const Duration(seconds: 10));
    
    // 第二步：连接热点 (0x04 + 0x01 + SSID\0 + PWD\0)
    final ssidBytes = ssid.codeUnits.toList();
    ssidBytes.add(0x00);
    final pwdBytes = password.codeUnits.toList();
    pwdBytes.add(0x00);
    final wifiData = [...ssidBytes, ...pwdBytes];
    final connectCommand = ProductionTestCommands.createControlWifiCommand(0x01, data: wifiData);
    
    for (int retry = 0; retry < 3; retry++) {
      if (retry > 0) {
        _logState?.info('   WiFi连接重试 ($retry/3)...', type: LogType.debug);
        _statusMessage = 'WiFi连接重试 ($retry/3)...';
        notifyListeners();
        await Future.delayed(const Duration(seconds: 2));
      }
      
      _statusMessage = '正在连接WiFi热点...';
      notifyListeners();
      
      try {
        final response = await _sendCommand(
          connectCommand,
          timeout: const Duration(seconds: 15),
        );
        
        if (response != null && !response.containsKey('error')) {
          if (response.containsKey('payload') && response['payload'] != null) {
            final responsePayload = response['payload'] as Uint8List;
            final wifiResult = ProductionTestCommands.parseWifiResponse(responsePayload, 0x01);
            
            if (wifiResult != null && wifiResult['success'] == true && wifiResult.containsKey('ip')) {
              _deviceIP = wifiResult['ip'];
              _logState?.success('✅ 获取到设备IP: $_deviceIP', type: LogType.debug);
              _statusMessage = '已获取设备IP: $_deviceIP';
              notifyListeners();
              return true;
            } else if (wifiResult != null && wifiResult['success'] == true) {
              // 连接成功但没有返回IP，可能需要等待
              _logState?.info('⏳ WiFi连接成功但未返回IP，等待...', type: LogType.debug);
            }
          }
        }
      } catch (e) {
        _logState?.warning('⚠️ WiFi连接异常: $e', type: LogType.debug);
      }
    }
    
    // 最后发送WiFi结束测试指令
    _logState?.info('🛑 WiFi连接失败，发送结束指令...', type: LogType.debug);
    final endCommand = ProductionTestCommands.createControlWifiCommand(0xFF);
    await _sendCommand(endCommand, timeout: const Duration(seconds: 2));
    
    return false;
  }
  
  /// 步骤2: FTP上传文件到设备
  Future<bool> _uploadFileViaFTP() async {
    if (_deviceIP == null || _selectedFilePath == null || _selectedFileName == null) {
      return false;
    }
    
    final file = File(_selectedFilePath!);
    if (!await file.exists()) {
      _logState?.error('❌ 文件不存在: $_selectedFilePath', type: LogType.debug);
      return false;
    }
    
    final fileSize = await file.length();
    _logState?.info('📤 开始FTP上传: $_selectedFileName (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)', type: LogType.debug);
    
    // 等待3秒让FTP服务启动
    _statusMessage = '等待设备FTP服务启动...';
    notifyListeners();
    await Future.delayed(const Duration(seconds: 3));
    
    final ftpUrl = 'ftp://$_deviceIP:21/customer/ota/$_selectedFileName';
    _logState?.info('   FTP URL: $ftpUrl', type: LogType.debug);
    
    for (int retry = 0; retry < 3; retry++) {
      if (retry > 0) {
        _logState?.info('🔄 FTP上传重试 $retry/3...', type: LogType.debug);
        _statusMessage = 'FTP上传重试 ($retry/3)...';
        notifyListeners();
        await Future.delayed(Duration(seconds: retry));
      }
      
      try {
        final curlArgs = [
          '-v',
          '--ftp-pasv',
          '--disable-epsv',
          '--ftp-create-dirs',
          '-T', _selectedFilePath!,
          '--connect-timeout', '10',
          '--max-time', '300', // 5分钟超时，大文件可能需要更长时间
          ftpUrl,
        ];
        
        _logState?.info('🔧 执行: curl ${curlArgs.join(" ")}', type: LogType.debug);
        _statusMessage = '正在上传文件... (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)';
        notifyListeners();
        
        final result = await Process.run('curl', curlArgs);
        
        if (result.stderr.toString().isNotEmpty) {
          _logState?.info('📋 curl输出:\n${result.stderr}', type: LogType.debug);
        }
        
        if (result.exitCode == 0) {
          _logState?.success('✅ FTP上传成功！', type: LogType.debug);
          return true;
        } else {
          _logState?.warning('⚠️ FTP上传失败 (退出码: ${result.exitCode})', type: LogType.debug);
        }
      } catch (e) {
        _logState?.warning('⚠️ FTP上传异常: $e', type: LogType.debug);
      }
    }
    
    return false;
  }
  
  /// 步骤3: 发送产测开始指令
  Future<bool> _sendStartTestCommand() async {
    _logState?.info('📤 发送产测开始指令 (0x00)', type: LogType.debug);
    
    final command = Uint8List.fromList([ProductionTestCommands.cmdStartTest]);
    final response = await _sendCommand(command, timeout: const Duration(seconds: 5));
    
    if (response != null && !response.containsKey('error')) {
      _logState?.success('✅ 产测开始指令发送成功', type: LogType.debug);
      return true;
    } else {
      _logState?.error('❌ 产测开始指令失败: ${response?['error'] ?? '超时'}', type: LogType.debug);
      return false;
    }
  }
  
  /// 步骤4: 发送OTA请求命令
  Future<bool> _sendOTARequest() async {
    final otaPath = '/customer/ota/$_selectedFileName';
    _logState?.info('📤 发送OTA请求: $otaPath', type: LogType.debug);
    
    final command = ProductionTestCommands.createOTARequestCommand(otaPath);
    final commandHex = command.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
    _logState?.info('   命令: [$commandHex]', type: LogType.debug);
    
    final response = await _sendCommand(command, timeout: const Duration(seconds: 10));
    
    if (response != null && !response.containsKey('error')) {
      // 检查回复 0xFA 0x00 0x00
      if (response.containsKey('payload') && response['payload'] != null) {
        final payload = response['payload'] as Uint8List;
        final payloadHex = payload.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        _logState?.info('📥 OTA响应: [$payloadHex]', type: LogType.debug);
        
        if (payload.length >= 3 &&
            payload[0] == ProductionTestCommands.cmdOTA &&
            payload[1] == ProductionTestCommands.otaSubRequest &&
            payload[2] == 0x00) {
          _logState?.success('✅ OTA请求已接受', type: LogType.debug);
          return true;
        } else if (payload.length >= 2 &&
            payload[0] == ProductionTestCommands.cmdOTA) {
          // 宽松匹配：只要是OTA回复就认为成功
          _logState?.success('✅ OTA请求已回复', type: LogType.debug);
          return true;
        }
      }
      // 没有payload也认为成功（有些设备可能不回payload）
      _logState?.success('✅ OTA请求已发送', type: LogType.debug);
      return true;
    } else {
      _logState?.error('❌ OTA请求失败: ${response?['error'] ?? '超时'}', type: LogType.debug);
      return false;
    }
  }
  
  /// 步骤5: 监听OTA状态推送
  /// 等待 0xFA 0x01 0xXX 状态推送
  Future<int> _listenForOTAStatus() async {
    _otaCompleter = Completer<int>();
    
    // 选择推送流
    final Stream<Uint8List> pushStream;
    if (_useLinuxBluetooth) {
      pushStream = (_linuxBtService as dynamic).dataStream as Stream<Uint8List>;
    } else {
      pushStream = _serialService!.pushPayloadStream;
    }
    
    // 5分钟总超时
    _otaTimeoutTimer = Timer(const Duration(minutes: 5), () {
      if (_otaCompleter != null && !_otaCompleter!.isCompleted) {
        _logState?.error('❌ OTA升级超时（5分钟）', type: LogType.debug);
        _otaCompleter!.complete(ProductionTestCommands.otaStatusTimeout);
      }
    });
    
    _pushSubscription = pushStream.listen((payload) {
      try {
        final payloadHex = payload.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        
        // 检查是否为OTA状态推送: 0xFA 0x01 0xXX
        if (payload.length >= 3 &&
            payload[0] == ProductionTestCommands.cmdOTA &&
            payload[1] == ProductionTestCommands.otaSubStatus) {
          
          final status = payload[2];
          _lastOTAStatus = status;
          final statusName = ProductionTestCommands.getOTAStatusName(status);
          _logState?.info('📦 OTA状态: $statusName (0x${status.toRadixString(16).toUpperCase().padLeft(2, '0')})', type: LogType.debug);
          
          _statusMessage = 'OTA: $statusName';
          notifyListeners();
          
          // 判断是否为终止状态
          if (status == ProductionTestCommands.otaStatusComplete ||
              status == ProductionTestCommands.otaStatusSuccess) {
            // 升级成功
            _otaTimeoutTimer?.cancel();
            _pushSubscription?.cancel();
            if (_otaCompleter != null && !_otaCompleter!.isCompleted) {
              _otaCompleter!.complete(status);
            }
          } else if (ProductionTestCommands.isOTAError(status)) {
            // 升级失败
            _otaTimeoutTimer?.cancel();
            _pushSubscription?.cancel();
            if (_otaCompleter != null && !_otaCompleter!.isCompleted) {
              _otaCompleter!.complete(status);
            }
          }
          // 其他中间状态（0x04, 0x05）继续等待
        }
      } catch (e) {
        _logState?.warning('⚠️ 解析OTA推送数据出错: $e', type: LogType.debug);
      }
    });
    
    return _otaCompleter!.future;
  }
  
  /// 通用发送命令方法
  Future<Map<String, dynamic>?> _sendCommand(
    Uint8List command, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_useLinuxBluetooth) {
      return await (_linuxBtService as dynamic).sendCommandAndWaitResponse(
        command,
        timeout: timeout,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );
    } else {
      return await _serialService!.sendCommandAndWaitResponse(
        command,
        timeout: timeout,
        moduleId: ProductionTestCommands.moduleId,
        messageId: ProductionTestCommands.messageId,
      );
    }
  }
  
  /// 停止OTA升级
  void stopOTA() {
    _otaTimeoutTimer?.cancel();
    _pushSubscription?.cancel();
    if (_otaCompleter != null && !_otaCompleter!.isCompleted) {
      _otaCompleter!.complete(ProductionTestCommands.otaStatusTimeout);
    }
    _isUpgrading = false;
    _currentStep = OTAStep.idle;
    _statusMessage = '升级已取消';
    notifyListeners();
  }
  
  @override
  void dispose() {
    _pushSubscription?.cancel();
    _otaTimeoutTimer?.cancel();
    super.dispose();
  }
}
