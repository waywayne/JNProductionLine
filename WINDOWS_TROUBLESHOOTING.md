# Windows 应用故障排除完整指南

## 🔍 问题诊断流程

### 第一步：运行诊断工具

**双击运行** `diagnose_windows.bat`

这会自动检查：
- ✅ 必要文件是否完整
- ✅ Visual C++ 运行时库
- ✅ 系统架构
- ✅ 尝试启动程序

---

## ❌ 常见问题和解决方案

### 问题 1: 双击 EXE 没有任何反应

**原因**: 缺少 Visual C++ 2015-2022 Redistributable (x64)

**解决方法**:

**方法一（推荐）**:
```
双击运行 install_vc_redist.bat
```

**方法二（手动）**:
1. 下载: https://aka.ms/vs/17/release/vc_redist.x64.exe
2. 双击安装
3. 重启应用

**验证是否安装**:
```cmd
where vcruntime140.dll
where msvcp140.dll
```

如果找到路径，说明已安装。

---

### 问题 2: BAT 文件显示乱码

**原因**: 文件编码问题

**解决方法**:

**临时解决**:
```cmd
chcp 65001
```
然后重新运行 bat 文件。

**永久解决**:
重新下载最新版本（已修复编码问题）

---

### 问题 3: Windows Defender SmartScreen 阻止

**现象**: 显示 "Windows 已保护你的电脑"

**解决方法**:

**方法一**:
1. 点击 "更多信息"
2. 点击 "仍要运行"

**方法二**:
1. 右键点击 `jn_production_line.exe`
2. 选择 "属性"
3. 勾选 "解除锁定"
4. 点击 "应用" 和 "确定"

---

### 问题 4: 程序闪退（一闪而过）

**原因**: 可能是配置文件错误或缺少依赖

**诊断方法**:

**使用控制台模式启动**:
```
双击运行 start_with_console.bat
```

这会保持控制台窗口打开，显示错误信息。

**常见错误信息**:

| 错误信息 | 原因 | 解决方法 |
|---------|------|---------|
| `VCRUNTIME140.dll not found` | 缺少 VC++ 运行时 | 运行 `install_vc_redist.bat` |
| `flutter_windows.dll not found` | 文件不完整 | 重新解压 ZIP |
| `Failed to load data` | data 目录缺失 | 重新解压 ZIP |
| `Access denied` | 权限不足 | 右键 → 以管理员身份运行 |

---

### 问题 5: 防病毒软件误报

**现象**: 杀毒软件删除或隔离了 EXE 文件

**解决方法**:

1. **恢复文件**:
   - 打开杀毒软件
   - 找到隔离区/病毒库
   - 恢复 `jn_production_line.exe`

2. **添加白名单**:
   - 将整个应用目录添加到白名单
   - 或者临时禁用实时保护

3. **常见杀毒软件设置**:
   - **Windows Defender**: 设置 → 病毒和威胁防护 → 排除项
   - **360安全卫士**: 信任区 → 添加信任文件
   - **火绒**: 信任区 → 添加信任文件

---

### 问题 6: 缺少文件

**检查必要文件**:

解压后的目录应该包含：

```
✓ jn_production_line.exe          (主程序，约 100KB)
✓ flutter_windows.dll              (Flutter 引擎，约 10MB)
✓ data/                            (资源目录)
  ✓ icudtl.dat                    (ICU 数据，约 10MB)
  ✓ flutter_assets/               (应用资源)
✓ diagnose_windows.bat             (诊断工具)
✓ install_vc_redist.bat            (VC++ 安装)
✓ start_with_console.bat           (控制台启动)
✓ START_HERE.txt                   (快速指南)
✓ README_WINDOWS.md                (使用文档)
```

**如果缺少文件**:
1. 重新下载 ZIP 包
2. 使用 Windows 自带的解压工具（不要用第三方工具）
3. 确保完整解压所有文件

---

### 问题 7: 32位系统

**检查系统架构**:
```cmd
echo %PROCESSOR_ARCHITECTURE%
```

应该显示 `AMD64`（64位）

**如果是 x86**:
- 本程序仅支持 64位 Windows
- 需要升级到 64位系统

---

### 问题 8: 路径包含中文或特殊字符

**问题**: 解压到包含中文的路径可能导致问题

**解决方法**:
1. 将程序移动到纯英文路径
2. 例如: `C:\JNProductionLine\`

---

## 🔧 高级诊断

### 手动检查依赖

**检查 DLL 依赖**:
```cmd
dumpbin /dependents jn_production_line.exe
```

**使用 Dependency Walker**:
1. 下载: https://www.dependencywalker.com/
2. 打开 `jn_production_line.exe`
3. 查看缺少的 DLL

---

### 查看事件日志

1. 按 `Win + R`
2. 输入 `eventvwr.msc`
3. 查看 "Windows 日志" → "应用程序"
4. 查找与程序相关的错误

---

### 使用 Process Monitor

1. 下载 Process Monitor: https://learn.microsoft.com/sysinternals/downloads/procmon
2. 运行 Process Monitor
3. 启动应用
4. 查看文件访问失败的记录

---

## 📋 完整检查清单

在联系技术支持前，请完成以下检查：

- [ ] 运行 `diagnose_windows.bat` 并截图结果
- [ ] 运行 `start_with_console.bat` 并截图错误信息
- [ ] 确认系统是 64位 Windows 10/11
- [ ] 确认已安装 Visual C++ Redistributable
- [ ] 确认所有文件完整（特别是 flutter_windows.dll 和 data 目录）
- [ ] 确认已解除 Windows Defender SmartScreen 阻止
- [ ] 确认杀毒软件没有隔离文件
- [ ] 尝试以管理员身份运行
- [ ] 尝试在纯英文路径下运行

---

## 🆘 仍然无法解决？

### 收集诊断信息

运行以下命令并保存输出：

```cmd
REM 系统信息
systeminfo > system_info.txt

REM 已安装的 VC++ 运行时
wmic product where "name like '%%Visual C++%%'" get name,version > vc_installed.txt

REM 环境变量
set > env_vars.txt

REM 运行诊断
diagnose_windows.bat > diagnose_output.txt 2>&1

REM 控制台启动
start_with_console.bat > console_output.txt 2>&1
```

### 联系技术支持时提供

1. 上述所有 txt 文件
2. 错误截图
3. Windows 版本（Win + R → `winver`）
4. 是否使用虚拟机
5. 杀毒软件名称和版本

---

## 💡 预防措施

### 首次安装建议

1. **关闭杀毒软件**: 安装时临时禁用
2. **使用英文路径**: 解压到 `C:\JNProductionLine\`
3. **完整解压**: 确保所有文件都解压
4. **安装运行时**: 先运行 `install_vc_redist.bat`
5. **解除阻止**: 右键 EXE → 属性 → 解除锁定
6. **测试启动**: 使用 `start_with_console.bat` 测试

### 更新建议

1. **备份配置**: 保存旧版本的配置文件
2. **完全替换**: 删除旧版本，解压新版本
3. **重新配置**: 如果配置文件格式变化，需要重新配置

---

## 📞 快速参考

| 问题 | 快速解决 |
|------|---------|
| 双击无反应 | `install_vc_redist.bat` |
| BAT 乱码 | 重新下载最新版 |
| SmartScreen | 更多信息 → 仍要运行 |
| 闪退 | `start_with_console.bat` |
| 缺少文件 | 重新解压 ZIP |
| 杀毒误报 | 添加白名单 |

---

## 🎯 最常见的解决方案

**90% 的问题都是缺少 Visual C++ 运行时库！**

**一键解决**:
```
双击 install_vc_redist.bat
```

如果这个不行，再尝试其他方法。
