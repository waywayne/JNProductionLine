import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/image_test_service.dart';
import '../models/log_state.dart';

/// 图像算法测试组件
/// 测试 image_test.h 中的各种图像检测算法
class ImageAlgorithmTestWidget extends StatefulWidget {
  const ImageAlgorithmTestWidget({super.key});

  @override
  State<ImageAlgorithmTestWidget> createState() => _ImageAlgorithmTestWidgetState();
}

class _ImageAlgorithmTestWidgetState extends State<ImageAlgorithmTestWidget> {
  final ImageTestService _imageTestService = ImageTestService.instance;
  String? _selectedImagePath;
  String _libraryStatus = '未加载';
  String _libraryVersion = '';
  final List<TestResult> _testResults = [];
  bool _isTesting = false;

  // 测试参数
  int _gridX = 17;
  int _gridY = 29;
  double _chessboardThreshold = 1.0;
  double _colorChartThreshold = 11.0;
  double _resolutionThreshold = 700.0;
  double _greyboardThreshold = 0.68;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  void _loadLibrary() {
    final logMessages = <String>[];
    final loaded = _imageTestService.load(
      searchLog: (msg) => logMessages.add(msg),
    );
    setState(() {
      _libraryStatus = loaded ? '已加载' : '加载失败';
      if (loaded) {
        _libraryVersion = _imageTestService.getVersion() ?? '未知版本';
      }
    });
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedImagePath = result.files.single.path;
        _testResults.clear();
      });
    }
  }

  Future<void> _runTest(String testType) async {
    if (_selectedImagePath == null) {
      _showError('请先选择图片');
      return;
    }

    if (!_imageTestService.isLoaded) {
      _showError('图像检测库未加载');
      return;
    }

    setState(() {
      _isTesting = true;
    });

    Map<String, dynamic>? result;
    final stopwatch = Stopwatch()..start();

    try {
      switch (testType) {
        case 'chessboard':
          result = _imageTestService.testChessboard(
            _selectedImagePath!,
            gridX: _gridX,
            gridY: _gridY,
            threshold: _chessboardThreshold,
          );
          break;
        case 'color_chart':
          result = _imageTestService.testColorChart(
            _selectedImagePath!,
            threshold: _colorChartThreshold,
          );
          break;
        case 'resolution_chart':
          result = _imageTestService.testResolutionChart(
            _selectedImagePath!,
            threshold: _resolutionThreshold,
          );
          break;
        case 'greyboard':
          result = _imageTestService.testGreyboard(
            _selectedImagePath!,
            threshold: _greyboardThreshold,
          );
          break;
      }
    } catch (e) {
      _showError('测试异常: $e');
    } finally {
      stopwatch.stop();
    }

    setState(() {
      _isTesting = false;
      if (result != null) {
        _testResults.insert(0, TestResult(
          testType: testType,
          ret: result['ret'] as int,
          output: result['output'] as double,
          pass: result['pass'] as bool,
          duration: stopwatch.elapsedMilliseconds,
        ));
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _getTestName(String testType) {
    switch (testType) {
      case 'chessboard':
        return '棋盘格检测';
      case 'color_chart':
        return '色卡检测';
      case 'resolution_chart':
        return '分辨率图卡检测';
      case 'greyboard':
        return '灰板检测';
      default:
        return testType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade50, Colors.white],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 库状态卡片
            _buildLibraryStatusCard(),
            const SizedBox(height: 16),

            // 图片选择区域
            _buildImageSelector(),
            const SizedBox(height: 16),

            // 测试参数设置
            _buildParameterSettings(),
            const SizedBox(height: 16),

            // 测试按钮
            _buildTestButtons(),
            const SizedBox(height: 16),

            // 测试结果
            Expanded(child: _buildResultsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryStatusCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _imageTestService.isLoaded ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _imageTestService.isLoaded ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _imageTestService.isLoaded ? Icons.check_circle : Icons.error,
            color: _imageTestService.isLoaded ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '图像检测库状态: $_libraryStatus',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _imageTestService.isLoaded ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
                if (_libraryVersion.isNotEmpty)
                  Text(
                    '版本: $_libraryVersion',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          if (!_imageTestService.isLoaded)
            ElevatedButton(
              onPressed: _loadLibrary,
              child: const Text('重新加载'),
            ),
        ],
      ),
    );
  }

  Widget _buildImageSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                '测试图片',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.file_upload),
                label: const Text('选择图片'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedImagePath != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedImagePath!,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () => setState(() {
                      _selectedImagePath = null;
                      _testResults.clear();
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_selectedImagePath!),
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
          ] else ...[
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('未选择图片', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParameterSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: Colors.orange),
              const SizedBox(width: 8),
              const Text(
                '测试参数',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 棋盘格参数
          _buildParamRow(
            '棋盘格网格 X',
            _gridX.toString(),
            (value) => setState(() => _gridX = int.tryParse(value) ?? _gridX),
          ),
          _buildParamRow(
            '棋盘格网格 Y',
            _gridY.toString(),
            (value) => setState(() => _gridY = int.tryParse(value) ?? _gridY),
          ),
          _buildParamRow(
            '棋盘格阈值',
            _chessboardThreshold.toString(),
            (value) => setState(() => _chessboardThreshold = double.tryParse(value) ?? _chessboardThreshold),
          ),
          _buildParamRow(
            '色卡阈值',
            _colorChartThreshold.toString(),
            (value) => setState(() => _colorChartThreshold = double.tryParse(value) ?? _colorChartThreshold),
          ),
          _buildParamRow(
            '分辨率阈值',
            _resolutionThreshold.toString(),
            (value) => setState(() => _resolutionThreshold = double.tryParse(value) ?? _resolutionThreshold),
          ),
          _buildParamRow(
            '灰板阈值',
            _greyboardThreshold.toString(),
            (value) => setState(() => _greyboardThreshold = double.tryParse(value) ?? _greyboardThreshold),
          ),
        ],
      ),
    );
  }

  Widget _buildParamRow(String label, String value, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: value),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButtons() {
    final tests = [
      {'type': 'chessboard', 'name': '棋盘格检测', 'icon': Icons.grid_on, 'color': Colors.blue},
      {'type': 'color_chart', 'name': '色卡检测', 'icon': Icons.palette, 'color': Colors.purple},
      {'type': 'resolution_chart', 'name': '分辨率检测', 'icon': Icons.high_quality, 'color': Colors.green},
      {'type': 'greyboard', 'name': '灰板检测', 'icon': Icons.gradient, 'color': Colors.orange},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: tests.map((test) {
        return ElevatedButton.icon(
          onPressed: _isTesting ? null : () => _runTest(test['type'] as String),
          icon: _isTesting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(test['icon'] as IconData),
          label: Text(test['name'] as String),
          style: ElevatedButton.styleFrom(
            backgroundColor: (test['color'] as Color).withOpacity(0.1),
            foregroundColor: test['color'] as Color,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResultsList() {
    if (_testResults.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('暂无测试结果', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 8),
              Text('选择图片后点击上方测试按钮', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('测试结果', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _testResults.clear()),
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('清空'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _testResults.length,
              itemBuilder: (context, index) {
                final result = _testResults[index];
                return _buildResultItem(result);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(TestResult result) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        color: result.pass ? Colors.green.shade50 : Colors.red.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.pass ? Icons.check_circle : Icons.error,
                color: result.pass ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getTestName(result.testType),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: result.pass ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  result.pass ? 'PASS' : 'FAIL',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildResultMetric('返回值', result.ret.toString()),
              ),
              Expanded(
                child: _buildResultMetric('输出值', result.output.toStringAsFixed(4)),
              ),
              Expanded(
                child: _buildResultMetric('耗时', '${result.duration}ms'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

/// 测试结果数据类
class TestResult {
  final String testType;
  final int ret;
  final double output;
  final bool pass;
  final int duration;

  TestResult({
    required this.testType,
    required this.ret,
    required this.output,
    required this.pass,
    required this.duration,
  });
}
