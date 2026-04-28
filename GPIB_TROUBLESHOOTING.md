# GPIB 连接问题全面排查和解决方案

## 🔍 问题诊断结果

根据诊断日志，发现以下关键问题：

### 1. **VI_ERROR_TMO 超时错误** ❌
```
pyvisa.errors.VisaIOError: VI_ERROR_TMO (-1073807339): Timeout expired before operation completed.
```

**原因**：
- 设备响应时间过长
- GPIB通讯配置不正确
- 硬件连接问题

### 2. **VI_ERROR_INV_RSRC_NAME 无效资源** ❌
```
VI_ERROR_INV_RSRC_NAME (-1073807342): Invalid resource reference specified. Parsing error.
```

**原因**：
- 终止符配置错误（LF/LF, CRLF/CRLF, CR/CR都失败）
- VISA后端不支持该设备
- 设备地址格式问题

### 3. **Linux权限问题** ⚠️
```
- 用户不在gpib或dialout组中
- GPIB内核模块未加载
- 未找到/dev/gpib*设备文件
```

---

## 🛠️ 解决方案

### 方案1: 修复Linux权限和驱动（最重要）

#### 自动修复脚本：
```bash
cd /Users/liangshanshan/git/JNProductionLine
chmod +x scripts/fix_gpib_linux.sh
./scripts/fix_gpib_linux.sh
```

#### 手动修复步骤：

**步骤1: 添加用户到GPIB组**
```bash
sudo usermod -a -G gpib $USER
sudo usermod -a -G dialout $USER
```

**步骤2: 重新登录**
```bash
# 注销并重新登录，或者重启系统
# 验证用户组:
groups
# 应该看到: ... gpib dialout ...
```

**步骤3: 加载GPIB内核模块**
```bash
sudo modprobe gpib_common
sudo modprobe ni_usb_gpib  # 如果使用NI USB-GPIB适配器
```

**步骤4: 验证设备文件**
```bash
ls -l /dev/gpib*
# 应该看到类似: crw-rw---- 1 root gpib /dev/gpib0
```

**步骤5: 设置开机自动加载**
```bash
echo "gpib_common" | sudo tee -a /etc/modules
echo "ni_usb_gpib" | sudo tee -a /etc/modules
```

---

### 方案2: 安装NI-VISA驱动

#### Ubuntu/Debian:
```bash
# 1. 下载NI-VISA
wget https://download.ni.com/support/softlib/visa/NI-VISA/21.5/NI-VISA_21.5.0_Linux_x64.deb

# 2. 安装
sudo dpkg -i NI-VISA_21.5.0_Linux_x64.deb
sudo apt-get install -f

# 3. 验证
visaconf --version
```

#### 或者使用linux-gpib:
```bash
# 安装linux-gpib
sudo apt-get install linux-gpib linux-gpib-user

# 配置GPIB
sudo gpib_config
```

---

### 方案3: 调整超时和终止符配置

根据诊断结果，设备需要**更长的超时时间**和**特定的终止符**。

#### 修改V1实现的超时：

编辑 `lib/services/gpib_service.dart`:

```dart
// 将超时从3秒增加到30秒
instrument.timeout = 30000  // 30秒超时
```

#### 尝试不同的终止符：

```python
# 方案A: 不使用终止符
inst.read_termination = None
inst.write_termination = None

# 方案B: 仅使用LF
inst.read_termination = '\n'
inst.write_termination = '\n'

# 方案C: 使用CRLF
inst.read_termination = '\r\n'
inst.write_termination = '\r\n'
```

---

### 方案4: 使用简化的测试命令

从诊断日志看，`*IDN?` 和 `*OPC?` 都超时，尝试更简单的命令：

```python
# 1. 先清除状态（写入命令，不读取）
inst.write('*CLS')

# 2. 使用设备特定的命令
inst.query(':READ[1]?')  # WFP60H读取电流
inst.query(':OUTPut1:STATe?')  # 查询输出状态
```

---

### 方案5: 检查硬件连接

1. **验证GPIB地址**：
   - 检查设备背面的GPIB地址设置
   - 确认是否为5（GPIB0::5::INSTR）

2. **检查GPIB线缆**：
   - 确保线缆两端连接牢固
   - 尝试更换GPIB线缆

3. **检查GPIB适配器**：
   - 确认USB-GPIB适配器已连接
   - 检查适配器指示灯状态

4. **设备电源**：
   - 确认WFP60H电源已打开
   - 等待设备完全启动（约30秒）

---

## 📊 诊断结果分析

从日志看，成功率为 **3/8 (38%)**：

### ✅ 成功的测试：
1. **linux_diagnostics** (550ms) - Linux诊断成功
2. **list_resources** (550ms) - 资源列表成功
3. **write_only** (378ms) - 写入命令成功

### ❌ 失败的测试：
1. **simple_query** (1552ms) - 简单查询超时
2. **timeout_test** (27973ms) - 所有超时配置都失败
3. **terminator_test** (4826ms) - 所有终止符配置都失败
4. **direct_command** (5749ms) - 直接命令超时
5. **script_file** (5686ms) - 脚本文件超时

### 关键发现：
- ✅ **写入成功** - 说明GPIB通讯通道正常
- ❌ **读取全部超时** - 说明问题在读取响应环节
- ⚠️ **Linux权限问题** - 需要修复用户组和内核模块

---

## 🎯 推荐的修复顺序

### 第一步：修复Linux权限（必须）
```bash
./scripts/fix_gpib_linux.sh
# 然后重新登录系统
```

### 第二步：增加超时时间
修改代码，将所有超时从3秒增加到30秒：
```dart
instrument.timeout = 30000  // 30秒
```

### 第三步：使用仅写入模式测试
先确认写入功能正常：
```python
inst.write('*CLS')  # 清除状态
inst.write(':OUTPut1 ON')  # 打开输出
```

### 第四步：尝试设备特定命令
使用WFP60H的原生命令：
```python
inst.query(':READ[1]?')  # 读取通道1电流
inst.query(':SOURce1:VOLTage?')  # 查询电压
```

### 第五步：检查硬件
如果软件修复无效，检查：
- GPIB地址设置
- 线缆连接
- 设备状态

---

## 📝 日志导出功能

现已添加日志导出功能：

### 使用方法：
1. 在GPIB诊断页面右上角点击 **下载图标** 📥
2. 选择保存位置
3. 日志将保存为 `gpib_diagnostic_xxxxx.txt`

### 或者复制到剪贴板：
1. 点击 **复制图标** 📋
2. 日志将复制到剪贴板
3. 可以粘贴到任何文本编辑器

---

## 🔧 下一步操作

1. **立即执行**：
   ```bash
   cd /Users/liangshanshan/git/JNProductionLine
   chmod +x scripts/fix_gpib_linux.sh
   ./scripts/fix_gpib_linux.sh
   ```

2. **重新登录系统**（使用户组生效）

3. **重新运行诊断**：
   - 打开"GPIB诊断"页面
   - 点击"运行全部诊断"
   - 导出日志查看改进

4. **如果仍然失败**：
   - 导出完整日志
   - 检查硬件连接
   - 联系设备厂商技术支持

---

## 📞 技术支持

如果问题仍未解决，请提供：
1. 导出的完整诊断日志
2. `groups` 命令输出
3. `lsmod | grep gpib` 输出
4. 设备型号和GPIB地址
5. GPIB适配器型号

---

**最后更新**: 2026-04-28
**版本**: 1.0
