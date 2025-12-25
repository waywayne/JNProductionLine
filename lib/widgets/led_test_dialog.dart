import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/test_state.dart';

class LEDTestDialog extends StatefulWidget {
  final String ledType; // "内侧" 或 "外侧"
  final VoidCallback onTestPassed;

  const LEDTestDialog({
    Key? key,
    required this.ledType,
    required this.onTestPassed,
  }) : super(key: key);

  @override
  State<LEDTestDialog> createState() => _LEDTestDialogState();
}

class _LEDTestDialogState extends State<LEDTestDialog> {
  bool _isTestStarted = false;
  bool _isStarting = false;
  bool _isStopping = false;
  int _retryCount = 0;
  static const int maxRetries = 10;

  @override
  void initState() {
    super.initState();
    // 弹窗打开时自动开始LED测试
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLEDTest();
    });
  }

  Future<void> _startLEDTest() async {
    if (_isStarting) return;
    
    setState(() {
      _isStarting = true;
      _retryCount = 0;
    });

    final testState = context.read<TestState>();
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        setState(() {
          _retryCount = attempt;
        });
        
        // 发送开始LED测试命令
        bool success = await testState.startLEDTest(widget.ledType);
        
        if (success) {
          setState(() {
            _isTestStarted = true;
            _isStarting = false;
          });
          return;
        }
        
        if (attempt < maxRetries) {
          // 等待1秒后重试
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        print('LED测试启动失败 (尝试 $attempt/$maxRetries): $e');
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    
    // 所有重试都失败了
    setState(() {
      _isStarting = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('LED${widget.ledType}测试启动失败，已重试$maxRetries次'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleTestResult(bool testPassed) async {
    if (_isStopping) return;
    
    setState(() {
      _isStopping = true;
      _retryCount = 0;
    });

    final testState = context.read<TestState>();
    
    // 先发送停止LED测试命令
    bool stopSuccess = false;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        setState(() {
          _retryCount = attempt;
        });
        
        // 发送停止LED测试命令
        bool success = await testState.stopLEDTest(widget.ledType);
        
        if (success) {
          stopSuccess = true;
          break;
        }
        
        if (attempt < maxRetries) {
          // 等待1秒后重试
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        print('LED测试停止失败 (尝试 $attempt/$maxRetries): $e');
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    
    setState(() {
      _isStopping = false;
    });
    
    if (!stopSuccess) {
      // 停止命令发送失败
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('LED${widget.ledType}测试停止失败，已重试$maxRetries次'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // 即使停止失败，也通知测试结果
      testState.confirmLEDTestResult(false);
      return;
    }
    
    // 记录测试结果
    await testState.recordLEDTestResult(widget.ledType, testPassed);
    
    // 通知测试状态测试结果（不再手动关闭弹窗，由TestState的finally块处理）
    testState.confirmLEDTestResult(testPassed);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(
          maxHeight: 600, // 设置最大高度
          minHeight: 400, // 设置最小高度
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 标题
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LED${widget.ledType}测试',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    // 关闭弹窗时先停止LED测试
                    final testState = context.read<TestState>();
                    if (testState.currentLEDType != null) {
                      await testState.stopLEDTest(widget.ledType);
                    }
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            
            // 可滚动的内容区域
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // LED图标
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isTestStarted ? Colors.amber : Colors.grey[300],
                boxShadow: _isTestStarted ? [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ] : null,
              ),
              child: Icon(
                Icons.lightbulb,
                size: 40,
                color: _isTestStarted ? Colors.white : Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 状态显示
            if (_isStarting) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                '正在启动LED${widget.ledType}测试...',
                style: const TextStyle(fontSize: 16),
              ),
              if (_retryCount > 1)
                Text(
                  '重试中 ($_retryCount/$maxRetries)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange[700],
                  ),
                ),
            ] else if (_isStopping) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                '正在停止LED${widget.ledType}测试...',
                style: const TextStyle(fontSize: 16),
              ),
              if (_retryCount > 1)
                Text(
                  '重试中 ($_retryCount/$maxRetries)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange[700],
                  ),
                ),
            ] else if (_isTestStarted) ...[
              const Text(
                '🔄 LED测试进行中',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 24,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'LED灯将会循环执行以下动作：',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. 快速点亮\n2. 快速熄灭\n3. 缓慢点亮\n4. 缓慢熄灭',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '请观察LED灯是否按预期工作',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                '测试启动失败',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
            ],
                  ],
                ),
              ),
            ),
            
            // 固定在底部的按钮区域
            const SizedBox(height: 16),
            if (!_isTestStarted && !_isStarting) ...[
              // 测试未开始或失败时显示重新开始按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _startLEDTest,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新开始'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      // 关闭弹窗时先停止LED测试
                      final testState = context.read<TestState>();
                      if (testState.currentLEDType != null) {
                        await testState.stopLEDTest(widget.ledType);
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ] else if (_isTestStarted && !_isStopping) ...[
              // 测试进行中时显示测试结果按钮
              Column(
                children: [
                  const Text(
                    '请观察LED灯是否按预期工作',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 测试通过按钮
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ElevatedButton.icon(
                            onPressed: () => _handleTestResult(true),
                            icon: const Icon(Icons.check_circle),
                            label: const Text('测试通过'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 测试未通过按钮
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ElevatedButton.icon(
                            onPressed: () => _handleTestResult(false),
                            icon: const Icon(Icons.cancel),
                            label: const Text('测试未通过'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ] else if (_isStopping) ...[
              // 正在停止测试时显示加载状态
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('正在处理测试结果...'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
