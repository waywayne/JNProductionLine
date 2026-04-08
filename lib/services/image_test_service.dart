import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// FFI 绑定 image_test 原生库
/// 对应 image_test.h 中的接口

// C 函数类型定义
typedef _ImagetestGetversionC = Pointer<Utf8> Function();
typedef _ImagetestGetversionDart = Pointer<Utf8> Function();

typedef _ImagetestChessboardC = Int32 Function(
  Pointer<Utf8> imagePath,
  Int32 gridX,
  Int32 gridY,
  Double threshold,
  Pointer<Double> output,
);
typedef _ImagetestChessboardDart = int Function(
  Pointer<Utf8> imagePath,
  int gridX,
  int gridY,
  double threshold,
  Pointer<Double> output,
);

typedef _ImagetestColorChartC = Int32 Function(
  Pointer<Utf8> imagePath,
  Double threshold,
  Pointer<Double> output,
);
typedef _ImagetestColorChartDart = int Function(
  Pointer<Utf8> imagePath,
  double threshold,
  Pointer<Double> output,
);

typedef _ImagetestResolutionChartC = Int32 Function(
  Pointer<Utf8> imagePath,
  Double threshold,
  Pointer<Double> output,
);
typedef _ImagetestResolutionChartDart = int Function(
  Pointer<Utf8> imagePath,
  double threshold,
  Pointer<Double> output,
);

typedef _ImagetestGreyboardC = Int32 Function(
  Pointer<Utf8> imagePath,
  Double threshold,
  Pointer<Double> output,
);
typedef _ImagetestGreyboardDart = int Function(
  Pointer<Utf8> imagePath,
  double threshold,
  Pointer<Double> output,
);

/// ImageTest 原生库服务
/// 封装 image_test.h 中所有检测接口
class ImageTestService {
  static ImageTestService? _instance;
  DynamicLibrary? _lib;
  bool _isLoaded = false;

  _ImagetestGetversionDart? _getVersion;
  _ImagetestChessboardDart? _chessboard;
  _ImagetestColorChartDart? _colorChart;
  _ImagetestResolutionChartDart? _resolutionChart;
  _ImagetestGreyboardDart? _greyboard;

  ImageTestService._();

  static ImageTestService get instance {
    _instance ??= ImageTestService._();
    return _instance!;
  }

  bool get isLoaded => _isLoaded;

  /// 加载原生库
  /// 搜索多个路径查找 libimage_test.so
  /// [searchLog] 可选回调，用于输出搜索过程日志
  bool load({void Function(String message)? searchLog}) {
    if (_isLoaded) return true;

    final executableDir = File(Platform.resolvedExecutable).parent.path;

    final candidates = [
      '$executableDir/lib/libimage_test.so',
      '$executableDir/libimage_test.so',
      '/opt/jn-production-line/lib/libimage_test.so',
      '/usr/local/lib/libimage_test.so',
      '/usr/lib/libimage_test.so',
      '${Platform.environment['HOME']}/git/JNProductionLine/lib/image_detect/libimage_test.so',
      'lib/image_detect/libimage_test.so',
    ];

    searchLog?.call('🔍 搜索 libimage_test.so ...');
    searchLog?.call('   可执行文件目录: $executableDir');

    for (final path in candidates) {
      try {
        final exists = File(path).existsSync();
        searchLog?.call('   ${exists ? "✅" : "❌"} $path');
        if (exists) {
          _lib = DynamicLibrary.open(path);
          _bindFunctions();
          _isLoaded = true;
          searchLog?.call('   ✅ 成功加载: $path');
          return true;
        }
      } catch (e) {
        searchLog?.call('   ⚠️  $path 存在但加载失败: $e');
      }
    }

    searchLog?.call('❌ 所有路径均未找到 libimage_test.so');
    return false;
  }

  void _bindFunctions() {
    _getVersion = _lib!
        .lookupFunction<_ImagetestGetversionC, _ImagetestGetversionDart>(
            'imagetest_getversion');

    _chessboard = _lib!
        .lookupFunction<_ImagetestChessboardC, _ImagetestChessboardDart>(
            'imagetest_chessboard');

    _colorChart = _lib!
        .lookupFunction<_ImagetestColorChartC, _ImagetestColorChartDart>(
            'imagetest_color_chart');

    _resolutionChart = _lib!.lookupFunction<_ImagetestResolutionChartC,
        _ImagetestResolutionChartDart>('imagetest_resolution_chart');

    _greyboard = _lib!
        .lookupFunction<_ImagetestGreyboardC, _ImagetestGreyboardDart>(
            'imagetest_greyboard');
  }

  /// 获取库版本
  String? getVersion() {
    if (!_isLoaded || _getVersion == null) return null;
    final ptr = _getVersion!();
    if (ptr == nullptr) return null;
    return ptr.toDartString();
  }

  /// 棋盘格检测
  /// [imagePath] 图片文件路径
  /// [gridX] X方向网格数，默认17
  /// [gridY] Y方向网格数，默认29
  /// [threshold] 阈值，默认1.0
  /// 返回 {ret: int, output: double}，ret==0 表示 PASS
  Map<String, dynamic>? testChessboard(
    String imagePath, {
    int gridX = 17,
    int gridY = 29,
    double threshold = 1.0,
  }) {
    if (!_isLoaded || _chessboard == null) return null;

    final pathPtr = imagePath.toNativeUtf8();
    final outputPtr = calloc<Double>();

    try {
      final ret = _chessboard!(pathPtr, gridX, gridY, threshold, outputPtr);
      return {
        'ret': ret,
        'output': outputPtr.value,
        'pass': ret == 0,
      };
    } finally {
      calloc.free(pathPtr);
      calloc.free(outputPtr);
    }
  }

  /// 色卡检测
  Map<String, dynamic>? testColorChart(
    String imagePath, {
    double threshold = 11.0,
  }) {
    if (!_isLoaded || _colorChart == null) return null;

    final pathPtr = imagePath.toNativeUtf8();
    final outputPtr = calloc<Double>();

    try {
      final ret = _colorChart!(pathPtr, threshold, outputPtr);
      return {
        'ret': ret,
        'output': outputPtr.value,
        'pass': ret == 0,
      };
    } finally {
      calloc.free(pathPtr);
      calloc.free(outputPtr);
    }
  }

  /// 分辨率图卡检测
  Map<String, dynamic>? testResolutionChart(
    String imagePath, {
    double threshold = 700.0,
  }) {
    if (!_isLoaded || _resolutionChart == null) return null;

    final pathPtr = imagePath.toNativeUtf8();
    final outputPtr = calloc<Double>();

    try {
      final ret = _resolutionChart!(pathPtr, threshold, outputPtr);
      return {
        'ret': ret,
        'output': outputPtr.value,
        'pass': ret == 0,
      };
    } finally {
      calloc.free(pathPtr);
      calloc.free(outputPtr);
    }
  }

  /// 灰板检测
  Map<String, dynamic>? testGreyboard(
    String imagePath, {
    double threshold = 0.68,
  }) {
    if (!_isLoaded || _greyboard == null) return null;

    final pathPtr = imagePath.toNativeUtf8();
    final outputPtr = calloc<Double>();

    try {
      final ret = _greyboard!(pathPtr, threshold, outputPtr);
      return {
        'ret': ret,
        'output': outputPtr.value,
        'pass': ret == 0,
      };
    } finally {
      calloc.free(pathPtr);
      calloc.free(outputPtr);
    }
  }
}
