# 📦 依赖包修复

## 问题描述

在 Windows 平台构建时遇到以下错误：

```
CUSTOMBUILD : error : Couldn't resolve the package 'path_provider' in 'package:path_provider/path_provider.dart'
CUSTOMBUILD : error : Couldn't resolve the package 'intl' in 'package:intl/intl.dart'
```

**原因**: `SNManagerService` 使用了 `path_provider` 和 `intl` 包，但这些包未在 `pubspec.yaml` 中声明。

---

## 解决方案

### 1. 添加缺失的依赖

在 `pubspec.yaml` 中添加以下依赖：

```yaml
dependencies:
  flutter:
    sdk: flutter
  file_picker: ^6.1.1
  provider: ^6.1.1
  flutter_libserialport: ^0.4.0
  flutter_bluetooth_serial: ^0.4.0
  flutter_bluetooth_classic_serial: ^1.3.1
  shared_preferences: ^2.2.2
  path_provider: ^2.1.1    # ← 新增
  intl: ^0.18.1            # ← 新增
```

### 2. 安装依赖

```bash
flutter pub get
```

---

## 依赖包说明

### path_provider (^2.1.1)

**用途**: 获取应用程序文档目录路径

**使用位置**: `lib/services/sn_manager_service.dart`

```dart
import 'package:path_provider/path_provider.dart';

// 初始化服务时获取数据文件路径
Future<void> init() async {
  final directory = await getApplicationDocumentsDirectory();
  _dataFilePath = '${directory.path}/sn_records.json';
  await _loadRecords();
}
```

**功能**:
- 获取应用文档目录
- 存储 SN 记录数据库文件 (`sn_records.json`)
- 跨平台支持（Windows、macOS、Linux、Android、iOS）

---

### intl (^0.18.1)

**用途**: 国际化和日期格式化

**使用位置**: `lib/services/sn_manager_service.dart`

```dart
import 'package:intl/intl.dart';

// 获取下一个流水号时格式化日期
int getNextSequenceNumber({
  required String productLine,
  required String factory,
  required String productionLine,
}) {
  // 查找今天的最大流水号
  final today = DateFormat('yMMdd').format(DateTime.now());
  final year = today.substring(2, 3);
  final monthDay = today.substring(3);
  
  // ... 查询逻辑
}
```

**功能**:
- 日期格式化 (`DateFormat`)
- 用于生成 SN 码中的日期部分
- 支持多种日期格式

---

## 验证

### 检查依赖是否安装成功

```bash
flutter pub get
```

**预期输出**:
```
Resolving dependencies...
Got dependencies!
```

### 检查包是否可用

```bash
flutter pub deps
```

**应该看到**:
```
|-- path_provider 2.1.1
|   |-- path_provider_android 2.2.1
|   |-- path_provider_foundation 2.5.1
|   |-- path_provider_linux 2.2.1
|   |-- path_provider_windows 2.3.0
|   ...
|-- intl 0.18.1
```

---

## 构建测试

### Windows 平台

```bash
flutter build windows --release
```

### 其他平台

```bash
# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

---

## 相关文件

### 修改的文件

- **`pubspec.yaml`**: 添加 `path_provider` 和 `intl` 依赖

### 使用这些包的文件

- **`lib/services/sn_manager_service.dart`**:
  - 使用 `path_provider` 获取文档目录
  - 使用 `intl` 格式化日期

---

## 注意事项

### 1. **版本兼容性**

当前使用的版本：
- `path_provider: ^2.1.1`
- `intl: ^0.18.1`

这些版本与 Flutter SDK `>=3.0.0 <4.0.0` 兼容。

### 2. **平台支持**

`path_provider` 支持所有主流平台：
- ✅ Windows
- ✅ macOS
- ✅ Linux
- ✅ Android
- ✅ iOS

### 3. **数据存储位置**

不同平台的文档目录：

| 平台 | 路径 |
|------|------|
| **Windows** | `C:\Users\<用户名>\AppData\Roaming\<应用名>\Documents` |
| **macOS** | `~/Library/Application Support/<应用名>` |
| **Linux** | `~/.local/share/<应用名>` |
| **Android** | `/data/data/<包名>/app_flutter` |
| **iOS** | `<应用沙盒>/Documents` |

### 4. **数据文件**

SN 记录数据库文件：
- **文件名**: `sn_records.json`
- **格式**: JSON
- **内容**: SN 码、MAC 地址、硬件版本等

**示例**:
```json
{
  "6371512161000010000": {
    "sn": "6371512161000010000",
    "hardware_version": "1.0.0",
    "wifi_mac": "48:08:EB:50:00:50",
    "bt_mac": "48:08:EB:60:00:50",
    "created_at": "2026-03-07T10:30:00.000",
    "updated_at": "2026-03-07T10:30:00.000"
  }
}
```

---

## 故障排查

### 问题 1: 依赖下载失败

**症状**:
```
Error: Unable to find package path_provider
```

**解决**:
```bash
# 清理缓存
flutter clean
flutter pub cache repair

# 重新获取依赖
flutter pub get
```

### 问题 2: 版本冲突

**症状**:
```
Because package_a depends on intl ^0.17.0 and package_b depends on intl ^0.18.0, version solving failed.
```

**解决**:
```yaml
# 在 pubspec.yaml 中指定具体版本
dependencies:
  intl: 0.18.1  # 移除 ^ 符号
```

### 问题 3: 平台特定问题

**Windows**:
```bash
# 确保 Visual Studio 已安装
# 运行 flutter doctor 检查环境
flutter doctor -v
```

**macOS**:
```bash
# 确保 Xcode 已安装
xcode-select --install
```

---

## 总结

✅ **已修复**:
1. 在 `pubspec.yaml` 中添加 `path_provider: ^2.1.1`
2. 在 `pubspec.yaml` 中添加 `intl: ^0.18.1`
3. 运行 `flutter pub get` 安装依赖

✅ **依赖用途**:
- **path_provider**: 获取应用文档目录，存储 SN 记录数据库
- **intl**: 日期格式化，用于 SN 码生成

✅ **影响范围**:
- `lib/services/sn_manager_service.dart`
- SN 码管理和数据库功能

现在可以成功构建 Windows 应用了！🎉
