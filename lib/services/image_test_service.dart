import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
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
          searchLog?.call('   ✅ 库文件已打开: $path');
          try {
            _bindFunctions(searchLog: searchLog);
          } catch (e) {
            searchLog?.call('   ⚠️  绑定函数时异常(已忽略): $e');
          }
          _isLoaded = true;
          searchLog?.call('   ✅ 成功加载并绑定函数');
          return true;
        }
      } catch (e) {
        searchLog?.call('   ⚠️  $path 加载异常: $e');
        _lib = null;
      }
    }

    searchLog?.call('❌ 所有路径均未找到或加载失败 libimage_test.so');
    return false;
  }

  void _bindFunctions({void Function(String message)? searchLog}) {
    // 注意: 库是 C++ 编译的，头文件无 extern "C"，符号被 C++ name mangling。
    // 优先尝试 C 符号名，如果失败则使用 C++ mangled 符号名。

    // imagetest_getversion
    try {
      _getVersion = _lib!.lookupFunction<_ImagetestGetversionC, _ImagetestGetversionDart>(
          'imagetest_getversion');
      searchLog?.call('   ✅ 绑定 imagetest_getversion (C符号)');
    } catch (_) {
      try {
        _getVersion = _lib!.lookupFunction<_ImagetestGetversionC, _ImagetestGetversionDart>(
            '_Z20imagetest_getversionv');
        searchLog?.call('   ✅ 绑定 imagetest_getversion (C++符号)');
      } catch (_) {
        searchLog?.call('   ❌ 绑定 imagetest_getversion 失败');
      }
    }

    // imagetest_chessboard
    try {
      _chessboard = _lib!.lookupFunction<_ImagetestChessboardC, _ImagetestChessboardDart>(
          'imagetest_chessboard');
      searchLog?.call('   ✅ 绑定 imagetest_chessboard (C符号)');
    } catch (_) {
      try {
        _chessboard = _lib!.lookupFunction<_ImagetestChessboardC, _ImagetestChessboardDart>(
            '_Z20imagetest_chessboardPKciidPd');
        searchLog?.call('   ✅ 绑定 imagetest_chessboard (C++符号)');
      } catch (_) {
        searchLog?.call('   ❌ 绑定 imagetest_chessboard 失败');
      }
    }

    // imagetest_color_chart
    try {
      _colorChart = _lib!.lookupFunction<_ImagetestColorChartC, _ImagetestColorChartDart>(
          'imagetest_color_chart');
      searchLog?.call('   ✅ 绑定 imagetest_color_chart (C符号)');
    } catch (_) {
      try {
        _colorChart = _lib!.lookupFunction<_ImagetestColorChartC, _ImagetestColorChartDart>(
            '_Z21imagetest_color_chartPKcdPd');
        searchLog?.call('   ✅ 绑定 imagetest_color_chart (C++符号)');
      } catch (_) {
        searchLog?.call('   ❌ 绑定 imagetest_color_chart 失败');
      }
    }

    // imagetest_resolution_chart
    try {
      _resolutionChart = _lib!.lookupFunction<_ImagetestResolutionChartC,
          _ImagetestResolutionChartDart>('imagetest_resolution_chart');
      searchLog?.call('   ✅ 绑定 imagetest_resolution_chart (C符号)');
    } catch (_) {
      try {
        _resolutionChart = _lib!.lookupFunction<_ImagetestResolutionChartC,
            _ImagetestResolutionChartDart>('_Z26imagetest_resolution_chartPKcdPd');
        searchLog?.call('   ✅ 绑定 imagetest_resolution_chart (C++符号)');
      } catch (_) {
        searchLog?.call('   ❌ 绑定 imagetest_resolution_chart 失败');
      }
    }

    // imagetest_greyboard
    try {
      _greyboard = _lib!.lookupFunction<_ImagetestGreyboardC, _ImagetestGreyboardDart>(
          'imagetest_greyboard');
      searchLog?.call('   ✅ 绑定 imagetest_greyboard (C符号)');
    } catch (_) {
      try {
        _greyboard = _lib!.lookupFunction<_ImagetestGreyboardC, _ImagetestGreyboardDart>(
            '_Z19imagetest_greyboardPKcdPd');
        searchLog?.call('   ✅ 绑定 imagetest_greyboard (C++符号)');
      } catch (_) {
        searchLog?.call('   ❌ 绑定 imagetest_greyboard 失败');
      }
    }
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

  /// 在 Isolate 中运行棋盘格检测（避免阻塞 UI 线程）
  /// 参数通过 Map 传递，因为 Isolate 不能传递 FFI 对象
  Future<Map<String, dynamic>?> testChessboardAsync(
    String imagePath, {
    int gridX = 17,
    int gridY = 29,
    double threshold = 1.0,
  }) async {
    // 获取库文件路径（需要在 isolate 中重新打开）
    if (!_isLoaded || _lib == null) return null;

    // 找到已加载的库路径
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

    String? libPath;
    for (final path in candidates) {
      if (File(path).existsSync()) {
        libPath = path;
        break;
      }
    }

    if (libPath == null) return null;

    final params = {
      'libPath': libPath,
      'imagePath': imagePath,
      'gridX': gridX,
      'gridY': gridY,
      'threshold': threshold,
    };

    try {
      return await Isolate.run(() => _runChessboardInIsolate(params));
    } catch (e) {
      return null;
    }
  }

  /// Isolate 中执行的棋盘格检测（顶层静态方法）
  static Map<String, dynamic>? _runChessboardInIsolate(Map<String, dynamic> params) {
    final libPath = params['libPath'] as String;
    final imagePath = params['imagePath'] as String;
    final gridX = params['gridX'] as int;
    final gridY = params['gridY'] as int;
    final threshold = params['threshold'] as double;

    try {
      final lib = DynamicLibrary.open(libPath);

      // 尝试 C 符号名，失败则用 C++ mangled 符号名
      late final int Function(Pointer<Utf8>, int, int, double, Pointer<Double>) chessboardFn;
      try {
        chessboardFn = lib.lookupFunction<_ImagetestChessboardC, _ImagetestChessboardDart>(
            'imagetest_chessboard');
      } catch (_) {
        chessboardFn = lib.lookupFunction<_ImagetestChessboardC, _ImagetestChessboardDart>(
            '_Z20imagetest_chessboardPKciidPd');
      }

      final pathPtr = imagePath.toNativeUtf8();
      final outputPtr = calloc<Double>();

      try {
        final ret = chessboardFn(pathPtr, gridX, gridY, threshold, outputPtr);
        return {
          'ret': ret,
          'output': outputPtr.value,
          'pass': ret == 0,
        };
      } finally {
        calloc.free(pathPtr);
        calloc.free(outputPtr);
      }
    } catch (e) {
      return {'ret': -1, 'output': 0.0, 'pass': false, 'error': e.toString()};
    }
  }
}
