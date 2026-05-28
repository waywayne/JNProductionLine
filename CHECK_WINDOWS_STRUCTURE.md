# Flutter Windows 应用正确的目录结构

## 标准结构（必须严格遵守）

```
Release/
├── jn_production_line.exe          ← 主程序
├── flutter_windows.dll              ← Flutter 引擎（必须在根目录）
├── data/                            ← 数据目录
│   ├── icudtl.dat                  ← ICU 数据（必须在 data 目录）
│   ├── app.so                      ← AOT 编译的代码（Release 模式）
│   └── flutter_assets/             ← Flutter 资源
│       ├── AssetManifest.json
│       ├── FontManifest.json
│       ├── NOTICES
│       ├── fonts/
│       ├── packages/
│       └── ...
└── [插件 DLLs]                      ← 各种插件的 DLL
    ├── flutter_bluetooth_classic_serial_plugin.dll
    ├── flutter_libserialport_plugin.dll
    └── ...
```

## 常见错误导致程序崩溃

### ❌ 错误 1: icudtl.dat 位置错误
```
Release/
├── icudtl.dat          ← 错误！不应该在根目录
└── data/
    └── (空)            ← 错误！应该在这里
```

**症状**: 程序启动立即崩溃，提示 "error 程序异常退出"

### ❌ 错误 2: 缺少 app.so
```
Release/
└── data/
    ├── icudtl.dat
    └── flutter_assets/
        └── (没有 app.so)  ← 错误！Release 模式必须有
```

**症状**: 程序启动后白屏或崩溃

### ❌ 错误 3: flutter_assets 路径错误
```
Release/
└── flutter_assets/     ← 错误！应该在 data 目录下
```

**症状**: 找不到资源文件，程序崩溃

### ❌ 错误 4: 缺少插件 DLL
```
Release/
├── jn_production_line.exe
├── flutter_windows.dll
└── data/
    └── (缺少插件 DLL)
```

**症状**: 调用蓝牙/串口功能时崩溃

## Flutter Windows 构建输出位置

### flutter build windows --release 的输出

```
build/windows/
├── runner/
│   └── Release/                    ← Visual Studio 构建
│       ├── jn_production_line.exe
│       ├── flutter_windows.dll
│       └── data/
│           ├── icudtl.dat
│           ├── app.so
│           └── flutter_assets/
│
└── x64/
    └── runner/
        └── Release/                ← Ninja 构建（可能）
            └── (同上)
```

### 插件 DLL 位置

```
build/windows/
├── runner/
│   └── Release/
│       └── plugins/
│           └── [plugin_name]/
│               └── [plugin_name]_plugin.dll
│
└── x64/
    └── plugins/
        └── [plugin_name]/
            └── Release/
                └── [plugin_name]_plugin.dll
```

## 关键文件说明

| 文件 | 位置 | 必须 | 说明 |
|------|------|------|------|
| `jn_production_line.exe` | 根目录 | ✅ | 主程序 |
| `flutter_windows.dll` | 根目录 | ✅ | Flutter 引擎 |
| `icudtl.dat` | `data/` | ✅ | ICU 国际化数据 |
| `app.so` | `data/` | ✅ | AOT 编译代码（Release） |
| `flutter_assets/` | `data/` | ✅ | 应用资源 |
| 插件 DLL | 根目录 | ⚠️ | 使用插件时必须 |

## 验证方法

### 检查完整性
```powershell
# 检查必要文件
Test-Path "jn_production_line.exe"
Test-Path "flutter_windows.dll"
Test-Path "data/icudtl.dat"
Test-Path "data/app.so"
Test-Path "data/flutter_assets"

# 检查文件大小
(Get-Item "flutter_windows.dll").Length / 1MB  # 应该约 10MB
(Get-Item "data/icudtl.dat").Length / 1MB      # 应该约 10MB
(Get-Item "data/app.so").Length / 1MB          # 应该约 5-20MB
```

### 检查插件
```powershell
# 列出所有 DLL
Get-ChildItem -Filter "*.dll" | Select-Object Name, Length
```

## 常见崩溃原因排查

### 1. 立即崩溃（0秒）
- ❌ 缺少 `flutter_windows.dll`
- ❌ 缺少 VC++ 运行时
- ❌ `icudtl.dat` 位置错误

### 2. 启动后崩溃（1-2秒）
- ❌ 缺少 `app.so`
- ❌ `flutter_assets` 路径错误
- ❌ 资源文件损坏

### 3. 使用功能时崩溃
- ❌ 缺少插件 DLL
- ❌ 插件版本不匹配
- ❌ 权限不足

## 正确的打包流程

1. **构建应用**
   ```bash
   flutter build windows --release
   ```

2. **定位输出目录**
   ```powershell
   # 优先查找
   build/windows/runner/Release/
   # 或者
   build/windows/x64/runner/Release/
   ```

3. **验证结构**
   - ✅ EXE 在根目录
   - ✅ flutter_windows.dll 在根目录
   - ✅ icudtl.dat 在 data/ 目录
   - ✅ app.so 在 data/ 目录
   - ✅ flutter_assets 在 data/ 目录

4. **复制插件**
   ```powershell
   # 从插件目录复制所有 DLL 到根目录
   Copy-Item "build/windows/**/plugins/**/Release/*.dll" -Destination "Release/"
   ```

5. **打包**
   - 整个 Release 目录打包成 ZIP
   - 不要只打包部分文件
