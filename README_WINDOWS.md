# Windows 版本使用说明

## 🚀 快速开始

### 1. 解压文件
将下载的 ZIP 文件解压到任意目录（建议路径不包含中文）。

### 2. 运行程序

**方法一：直接运行**
- 双击 `jn_production_line.exe`

**方法二：使用诊断工具（推荐）**
- 双击 `diagnose_windows.bat` 进行系统检查
- 如果有问题，会自动提示解决方法

## ❌ 常见问题

### 问题 1: 双击程序没有任何反应

**最常见原因：缺少 Visual C++ 运行时库**

#### 解决方法：

**自动安装（推荐）：**
```
双击运行 install_vc_redist.bat
```

**手动安装：**
1. 下载 [Visual C++ Redistributable](https://aka.ms/vs/17/release/vc_redist.x64.exe)
2. 运行安装程序
3. 重启应用

### 问题 2: Windows Defender SmartScreen 阻止

如果看到"Windows 已保护你的电脑"提示：

1. 点击"更多信息"
2. 点击"仍要运行"

或者：
1. 右键点击 `jn_production_line.exe`
2. 选择"属性"
3. 勾选"解除锁定"
4. 点击"确定"

### 问题 3: 防病毒软件误报

某些防病毒软件可能会误报 Flutter 应用。请：
1. 将程序添加到白名单
2. 或临时禁用防病毒软件进行测试

### 问题 4: 缺少文件

确保解压后的目录包含以下文件：
```
jn_production_line.exe          (主程序)
flutter_windows.dll             (Flutter 引擎，约 10MB)
data/                           (资源目录)
  ├── icudtl.dat               (ICU 数据)
  └── flutter_assets/          (应用资源)
```

如果缺少文件，请重新下载并完整解压 ZIP 包。

## 🔧 诊断工具

### diagnose_windows.bat
自动检查系统环境和必要文件：
- ✓ 检查必要文件是否完整
- ✓ 检查 Visual C++ 运行时库
- ✓ 检查系统架构
- ✓ 尝试启动程序并捕获错误

### install_vc_redist.bat
自动下载并安装 Visual C++ Redistributable：
- 自动下载最新版本
- 静默安装（需要管理员权限）
- 安装后即可运行程序

## 📋 系统要求

- **操作系统**: Windows 10 或更高版本（64位）
- **运行时**: Visual C++ 2015-2022 Redistributable (x64)
- **内存**: 建议 4GB 以上
- **磁盘空间**: 约 50MB

## 🔌 GPIB 功能

如果需要使用 GPIB 功能，请：
1. 运行 `install_gpib_dependencies.bat` 安装 Python 依赖
2. 参考 `GPIB_TROUBLESHOOTING.md` 了解详细配置

## 📞 技术支持

如果以上方法都无法解决问题：

1. **运行诊断工具**：
   ```
   diagnose_windows.bat
   ```
   
2. **查看错误日志**：
   - 打开命令提示符（CMD）
   - 进入程序目录
   - 运行：`jn_production_line.exe`
   - 查看错误信息

3. **联系技术支持**：
   - 提供诊断工具的输出
   - 提供错误截图
   - 说明 Windows 版本

## 📝 版本信息

- **Flutter 版本**: 3.24.0
- **构建日期**: 见文件名中的时间戳
- **架构**: x64 (64位)

## ⚠️ 重要提示

1. **首次运行**：可能需要几秒钟初始化
2. **路径限制**：建议解压到路径不包含中文的目录
3. **权限要求**：某些功能可能需要管理员权限
4. **网络连接**：GPIB 功能需要安装 Python 依赖（需要网络）

## 🎯 快速诊断流程

```
双击程序没反应？
    ↓
运行 diagnose_windows.bat
    ↓
提示缺少 VC++ 运行时？
    ↓
运行 install_vc_redist.bat
    ↓
重新启动程序
    ↓
成功！
```
