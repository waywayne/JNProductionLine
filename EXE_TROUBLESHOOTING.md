# Windows EXE 无法打开问题排查指南

## 快速诊断

运行诊断脚本：
```batch
diagnose_exe.bat
```

## 常见问题和解决方法

### 1. 双击 EXE 没有任何反应

**可能原因：**
- 缺少 Visual C++ Runtime
- 缺少必需的 DLL 文件
- data 目录不完整

**解决方法：**

#### 步骤 1: 安装 Visual C++ Runtime
```batch
install_vc_redist.bat
```

或手动下载安装：
- [Visual C++ 2015-2022 Redistributable (x64)](https://aka.ms/vs/17/release/vc_redist.x64.exe)

#### 步骤 2: 检查文件完整性
确保以下文件存在：
```
jn_production_line.exe          ← 主程序
flutter_windows.dll             ← Flutter 引擎
data/
  ├── icudtl.dat               ← ICU 数据文件
  └── flutter_assets/          ← 应用资源
```

#### 步骤 3: 使用控制台模式启动
```batch
start_with_console.bat
```

这会显示错误信息，帮助定位问题。

### 2. 提示缺少 DLL 文件

**错误信息示例：**
```
无法启动此程序，因为计算机中丢失 VCRUNTIME140.dll
```

**解决方法：**
1. 运行 `install_vc_redist.bat`
2. 重启计算机
3. 重新尝试运行

### 3. 应用启动后立即崩溃

**可能原因：**
- `icudtl.dat` 文件位置错误
- `data` 目录结构不完整

**解决方法：**

检查 `data` 目录结构：
```
data/
  ├── icudtl.dat              ← 必须在 data 目录内
  ├── flutter_assets/
  │   ├── AssetManifest.json
  │   ├── FontManifest.json
  │   └── fonts/
  └── app.so                  ← 可选
```

**重要：** `icudtl.dat` 必须在 `data/` 目录内，不能在根目录！

### 4. 防火墙或杀毒软件阻止

**症状：**
- 应用启动但无窗口
- 杀毒软件报警

**解决方法：**
1. 临时禁用杀毒软件
2. 将应用添加到白名单
3. 以管理员权限运行

### 5. Windows Defender SmartScreen 警告

**提示信息：**
```
Windows 已保护你的电脑
```

**解决方法：**
1. 点击"更多信息"
2. 点击"仍要运行"

这是因为应用未签名，属于正常现象。

## 手动测试步骤

### 1. 检查文件完整性

打开命令提示符（CMD）：
```batch
cd /d "C:\path\to\app"
dir
```

确认以下文件存在：
- `jn_production_line.exe`
- `flutter_windows.dll`
- `data\icudtl.dat`
- `data\flutter_assets\`

### 2. 检查 DLL 依赖

使用 [Dependency Walker](http://www.dependencywalker.com/) 或 PowerShell：
```powershell
Get-Item jn_production_line.exe | Select-Object *
```

### 3. 查看 Windows 事件日志

1. 按 `Win + R`
2. 输入 `eventvwr.msc`
3. 查看"Windows 日志" → "应用程序"
4. 查找与 `jn_production_line.exe` 相关的错误

### 4. 使用控制台模式启动

创建 `run_debug.bat`：
```batch
@echo off
jn_production_line.exe
pause
```

双击运行，查看错误信息。

## 系统要求

### 最低要求
- **操作系统**: Windows 10 (64-bit) 或更高版本
- **内存**: 4 GB RAM
- **磁盘空间**: 500 MB 可用空间
- **运行时**: Visual C++ 2015-2022 Redistributable

### 推荐配置
- **操作系统**: Windows 11 (64-bit)
- **内存**: 8 GB RAM
- **磁盘空间**: 1 GB 可用空间

## 已知问题

### 1. Windows 7 不支持
应用需要 Windows 10 或更高版本。

### 2. 32 位系统不支持
应用仅支持 64 位 Windows。

### 3. ARM64 Windows
目前不支持 ARM64 Windows（如 Surface Pro X）。

## 获取帮助

如果以上方法都无法解决问题，请：

1. **运行诊断脚本**
   ```batch
   diagnose_exe.bat
   ```

2. **收集以下信息**
   - Windows 版本（`winver`）
   - 错误截图
   - 诊断脚本输出
   - Windows 事件日志中的错误

3. **提交问题**
   - 在 GitHub Issues 中创建新问题
   - 附上收集的信息

## 开发者调试

### 使用 Visual Studio 调试

1. 安装 Visual Studio 2022
2. 打开项目：
   ```
   windows\runner.sln
   ```
3. 设置断点
4. 按 F5 调试

### 查看崩溃转储

如果应用崩溃，Windows 会生成转储文件：
```
%LOCALAPPDATA%\CrashDumps\
```

使用 Visual Studio 或 WinDbg 分析转储文件。

### 启用详细日志

设置环境变量：
```batch
set FLUTTER_ENGINE_SWITCH_LOG_LEVEL=info
jn_production_line.exe
```

## 相关文档

- [Windows 构建指南](WINDOWS_BUILD_GUIDE.md)
- [GPIB 故障排查](GPIB_TROUBLESHOOTING.md)
- [安装 VC Runtime](install_vc_redist.bat)
