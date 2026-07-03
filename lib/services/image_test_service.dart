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
  String? _libPath;
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

  /// 定位原生库路径（不在主 Isolate 中打开动态库，避免与 Isolate 检测重复加载 OpenCV 导致崩溃）
  /// [searchLog] 可选回调，用于输出搜索过程日志
  bool load({void Function(String message)? searchLog}) {
    if (_isLoaded) return true;

    final executableDir = File(Platform.resolvedExecutable).parent.path;

    searchLog?.call('🔍 搜索 libimage_test.so ...');
    searchLog?.call('   可执行文件目录: $executableDir');

    for (final path in _libSearchCandidates(executableDir)) {
      final exists = File(path).existsSync();
      searchLog?.call('   ${exists ? "✅" : "❌"} $path');
      if (exists) {
        _libPath = path;
        _isLoaded = true;
        searchLog?.call('   ✅ 已找到库文件: $path');
        searchLog?.call('   ℹ️  算法检测将在独立 Isolate 中加载库（避免主线程重复加载）');
        return true;
      }
    }

    searchLog?.call('❌ 所有路径均未找到 libimage_test.so');
    return false;
  }

  /// 同步检测接口需在主 Isolate 打开库；异步检测仅标记路径即可
  bool _ensureMainLibLoaded({void Function(String message)? searchLog}) {
    if (_lib != null) return true;
    if (!_isLoaded) return false;

    final path = _libPath ?? _resolveLibPath();
    if (path == null) return false;

    try {
      _lib = DynamicLibrary.open(path);
      _libPath = path;
      _bindFunctions(searchLog: searchLog);
      return true;
    } catch (e) {
      searchLog?.call('   ⚠️  主线程打开库失败: $e');
      _lib = null;
      return false;
    }
  }

  List<String> _libSearchCandidates(String executableDir) => [
        '$executableDir/lib/libimage_test.so',
        '$executableDir/libimage_test.so',
        '/opt/jn-production-line/lib/libimage_test.so',
        '/usr/local/lib/libimage_test.so',
        '/usr/lib/libimage_test.so',
        '${Platform.environment['HOME']}/git/JNProductionLine/lib/image_detect/libimage_test.so',
        'lib/image_detect/libimage_test.so',
      ];

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

  /// 获取库版本（同步接口，需在主 Isolate 打开库）
  String? getVersion() {
    if (!_ensureMainLibLoaded() || _getVersion == null) return null;
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
    if (!_ensureMainLibLoaded() || _chessboard == null) return null;

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
    if (!_ensureMainLibLoaded() || _colorChart == null) return null;

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
    if (!_ensureMainLibLoaded() || _resolutionChart == null) return null;

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
    if (!_ensureMainLibLoaded() || _greyboard == null) return null;

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

  /// 查找 libimage_test.so 路径（Isolate 中需重新打开动态库）
  String? _resolveLibPath() {
    if (_libPath != null && File(_libPath!).existsSync()) {
      return _libPath;
    }

    final executableDir = File(Platform.resolvedExecutable).parent.path;
    for (final path in _libSearchCandidates(executableDir)) {
      if (File(path).existsSync()) {
        _libPath = path;
        return path;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _runInIsolate(
    Map<String, dynamic> params,
    Map<String, dynamic>? Function(Map<String, dynamic>) runner,
  ) async {
    try {
      return await Isolate.run(() => runner(params));
    } catch (e) {
      return {'ret': -1, 'output': 0.0, 'pass': false, 'error': e.toString()};
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
    if (!_isLoaded) return null;

    final libPath = _resolveLibPath();
    if (libPath == null) return null;

    return _runInIsolate(
      {
        'libPath': libPath,
        'imagePath': imagePath,
        'gridX': gridX,
        'gridY': gridY,
        'threshold': threshold,
      },
      _runChessboardInIsolate,
    );
  }

  /// 在 Isolate 中运行分辨率图卡检测（避免原生库异常导致整个应用闪退）
  Future<Map<String, dynamic>?> testResolutionChartAsync(
    String imagePath, {
    double threshold = 700.0,
  }) async {
    if (!_isLoaded) return null;

    final libPath = _resolveLibPath();
    if (libPath == null) return null;

    return _runInIsolate(
      {
        'libPath': libPath,
        'imagePath': imagePath,
        'threshold': threshold,
      },
      _runResolutionChartInIsolate,
    );
  }

  /// 在 Isolate 中运行色卡检测（避免原生库异常导致整个应用闪退）
  Future<Map<String, dynamic>?> testColorChartAsync(
    String imagePath, {
    double threshold = 11.0,
  }) async {
    if (!_isLoaded) return null;

    final libPath = _resolveLibPath();
    if (libPath == null) return null;

    return _runInIsolate(
      {
        'libPath': libPath,
        'imagePath': imagePath,
        'threshold': threshold,
      },
      _runColorChartInIsolate,
    );
  }

  /// 在 Isolate 中运行灰板检测（避免原生库异常导致整个应用闪退）
  Future<Map<String, dynamic>?> testGreyboardAsync(
    String imagePath, {
    double threshold = 0.68,
  }) async {
    if (!_isLoaded) return null;

    final libPath = _resolveLibPath();
    if (libPath == null) return null;

    return _runInIsolate(
      {
        'libPath': libPath,
        'imagePath': imagePath,
        'threshold': threshold,
      },
      _runGreyboardInIsolate,
    );
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

  static Map<String, dynamic>? _runResolutionChartInIsolate(Map<String, dynamic> params) {
    final libPath = params['libPath'] as String;
    final imagePath = params['imagePath'] as String;
    final threshold = params['threshold'] as double;

    try {
      final lib = DynamicLibrary.open(libPath);

      late final int Function(Pointer<Utf8>, double, Pointer<Double>) resolutionFn;
      try {
        resolutionFn = lib.lookupFunction<_ImagetestResolutionChartC, _ImagetestResolutionChartDart>(
            'imagetest_resolution_chart');
      } catch (_) {
        resolutionFn = lib.lookupFunction<_ImagetestResolutionChartC, _ImagetestResolutionChartDart>(
            '_Z26imagetest_resolution_chartPKcdPd');
      }

      final pathPtr = imagePath.toNativeUtf8();
      final outputPtr = calloc<Double>();

      try {
        final ret = resolutionFn(pathPtr, threshold, outputPtr);
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

  static Map<String, dynamic>? _runColorChartInIsolate(Map<String, dynamic> params) {
    final libPath = params['libPath'] as String;
    final imagePath = params['imagePath'] as String;
    final threshold = params['threshold'] as double;

    try {
      final lib = DynamicLibrary.open(libPath);

      late final int Function(Pointer<Utf8>, double, Pointer<Double>) colorChartFn;
      try {
        colorChartFn = lib.lookupFunction<_ImagetestColorChartC, _ImagetestColorChartDart>(
            'imagetest_color_chart');
      } catch (_) {
        colorChartFn = lib.lookupFunction<_ImagetestColorChartC, _ImagetestColorChartDart>(
            '_Z21imagetest_color_chartPKcdPd');
      }

      final pathPtr = imagePath.toNativeUtf8();
      final outputPtr = calloc<Double>();

      try {
        final ret = colorChartFn(pathPtr, threshold, outputPtr);
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

  static Map<String, dynamic>? _runGreyboardInIsolate(Map<String, dynamic> params) {
    final libPath = params['libPath'] as String;
    final imagePath = params['imagePath'] as String;
    final threshold = params['threshold'] as double;

    try {
      final lib = DynamicLibrary.open(libPath);

      late final int Function(Pointer<Utf8>, double, Pointer<Double>) greyboardFn;
      try {
        greyboardFn = lib.lookupFunction<_ImagetestGreyboardC, _ImagetestGreyboardDart>(
            'imagetest_greyboard');
      } catch (_) {
        greyboardFn = lib.lookupFunction<_ImagetestGreyboardC, _ImagetestGreyboardDart>(
            '_Z19imagetest_greyboardPKcdPd');
      }

      final pathPtr = imagePath.toNativeUtf8();
      final outputPtr = calloc<Double>();

      try {
        final ret = greyboardFn(pathPtr, threshold, outputPtr);
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
