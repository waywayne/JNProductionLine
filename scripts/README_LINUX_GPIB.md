# Linux GPIB 工具集

## 📦 包含工具

### 1. 综合测试脚本 ⭐
**文件**: `linux_gpib_comprehensive_test.py`

**功能**: 12项完整的GPIB系统测试
- ✅ 系统信息检查
- ✅ 硬件检测（USB/PCI）
- ✅ 内核模块检查
- ✅ 设备文件检查
- ✅ 用户权限检查
- ✅ GPIB配置检查
- ✅ NI-VISA检查
- ✅ PyVISA环境检查
- ✅ VISA后端测试
- ✅ GPIB连接测试
- ✅ SCPI命令测试
- ✅ 系统日志检查

**使用方法**:
```bash
# 基本用法
python3 linux_gpib_comprehensive_test.py

# 指定设备地址
python3 linux_gpib_comprehensive_test.py GPIB0::5::INSTR

# 查看帮助
python3 linux_gpib_comprehensive_test.py --help
```

**输出示例**:
```
╔════════════════════════════════════════════════════════════╗
║         Linux GPIB 综合测试系统                            ║
╚════════════════════════════════════════════════════════════╝

测试设备地址: GPIB0::5::INSTR

============================================================
测试1: 系统信息
============================================================
✅ 系统: Linux ubuntu 5.15.0-58-generic
✅ 发行版: Ubuntu 22.04.1 LTS
✅ 内核版本: 5.15.0-58-generic

============================================================
测试2: GPIB硬件检测
============================================================
✅ 找到USB设备: Bus 001 Device 005: ID 3923:709b National Instruments

...

============================================================
测试总结
============================================================

测试结果:
  ✅ 系统信息           PASS
  ✅ 硬件检测           PASS
  ❌ 内核模块           FAIL
  ❌ 设备文件           FAIL
  ⚠️  用户权限           ERROR
  ...

统计:
  总测试数: 12
  通过: 8
  失败: 4
  成功率: 66.7%

建议:
⚠️  内核模块未加载
  1. 安装 linux-gpib: sudo apt-get install linux-gpib
  2. 加载模块: sudo modprobe gpib_common
  3. 重启系统
```

---

### 2. 深度修复脚本 🔧
**文件**: `linux_gpib_deep_fix.sh`

**功能**: 自动诊断和修复所有GPIB问题
- ✅ 检测GPIB硬件
- ✅ 安装缺失的驱动
- ✅ 加载内核模块
- ✅ 创建设备文件
- ✅ 配置用户权限
- ✅ 安装pyvisa-py
- ✅ 创建测试脚本
- ✅ 设置开机自动加载

**使用方法**:
```bash
# 运行修复脚本
./linux_gpib_deep_fix.sh

# 重新登录系统（重要！）
logout

# 或重启系统
sudo reboot
```

**执行步骤**:
1. 检查GPIB适配器硬件
2. 检查并安装GPIB驱动
3. 加载GPIB内核模块
4. 配置GPIB设备
5. 检查设备文件
6. 配置用户组权限
7. 测试GPIB通讯
8. 应急解决方案
9. 创建快速测试脚本
10. 设置开机自动加载

---

### 3. 快速测试脚本 🚀
**文件**: `/tmp/test_gpib.py` (由深度修复脚本自动创建)

**功能**: 快速验证GPIB连接
- 测试3种VISA后端（@ni, @py, 默认）
- 测试写入命令
- 测试查询命令

**使用方法**:
```bash
# 使用默认地址
python3 /tmp/test_gpib.py

# 指定地址
python3 /tmp/test_gpib.py GPIB0::5::INSTR
```

---

## 🚀 快速开始

### 首次使用（推荐流程）

```bash
# 1. 进入项目目录
cd /path/to/JNProductionLine/scripts

# 2. 运行综合测试（了解问题）
python3 linux_gpib_comprehensive_test.py

# 3. 运行深度修复（自动修复）
./linux_gpib_deep_fix.sh

# 4. 重新登录系统（使权限生效）
logout

# 5. 再次运行综合测试（验证修复）
python3 linux_gpib_comprehensive_test.py

# 6. 如果仍有问题，重启系统
sudo reboot
```

---

## 📋 常见使用场景

### 场景1: 新系统首次配置

```bash
# 一键修复
./linux_gpib_deep_fix.sh

# 重新登录
logout

# 测试
python3 /tmp/test_gpib.py
```

---

### 场景2: 诊断现有问题

```bash
# 运行综合测试
python3 linux_gpib_comprehensive_test.py

# 查看哪些测试失败
# 根据建议进行修复
```

---

### 场景3: 验证修复效果

```bash
# 修复后测试
python3 /tmp/test_gpib.py GPIB0::5::INSTR

# 或使用综合测试
python3 linux_gpib_comprehensive_test.py
```

---

### 场景4: 开发调试

```bash
# 启用详细日志
python3 << 'EOF'
import pyvisa
import logging
logging.basicConfig(level=logging.DEBUG)

rm = pyvisa.ResourceManager('@py')
inst = rm.open_resource('GPIB0::5::INSTR')
inst.timeout = 30000

# 测试命令
inst.write('*CLS')
print("Success")

inst.close()
rm.close()
EOF
```

---

## 🔍 故障排除

### 问题1: 综合测试失败率高

**解决**:
```bash
# 运行深度修复
./linux_gpib_deep_fix.sh

# 重新登录
logout
```

---

### 问题2: 内核模块加载失败

**解决**:
```bash
# 重新安装驱动
sudo apt-get purge linux-gpib*
sudo apt-get install linux-gpib linux-gpib-user linux-gpib-modules-dkms

# 重新编译
sudo dpkg-reconfigure linux-gpib-modules-dkms

# 查看错误
dmesg | tail -50
```

---

### 问题3: 设备文件不存在

**解决**:
```bash
# 手动创建
sudo mknod /dev/gpib0 c 160 0
sudo chmod 666 /dev/gpib0

# 或运行配置
sudo gpib_config
```

---

### 问题4: 权限不足

**解决**:
```bash
# 添加用户组
sudo usermod -a -G gpib,dialout $USER

# 必须重新登录！
logout
```

---

## 📊 测试结果解读

### 成功率 > 80% ✅
- 系统基本正常
- 可能只需要微调
- 重新登录或重启即可

### 成功率 50-80% ⚠️
- 部分组件有问题
- 需要针对性修复
- 运行深度修复脚本

### 成功率 < 50% ❌
- 严重配置问题
- 需要完整修复
- 运行深度修复脚本
- 可能需要重装驱动

---

## 🛠️ 手动修复步骤

如果自动脚本失败，可以手动执行：

### 步骤1: 安装驱动
```bash
sudo apt-get update
sudo apt-get install linux-gpib linux-gpib-user linux-gpib-modules-dkms
```

### 步骤2: 加载模块
```bash
sudo modprobe gpib_common
sudo modprobe ni_usb_gpib  # 或 agilent_82357a
```

### 步骤3: 创建配置
```bash
sudo tee /etc/gpib.conf > /dev/null << 'EOF'
interface {
    minor = 0
    board_type = "ni_usb_b"
    name = "gpib0"
    pad = 0
    sad = 0
    timeout = T30s
    eos = 0x0a
    set-reos = yes
    set-bin = no
    set-xeos = no
    set-eot = yes
}
EOF
```

### 步骤4: 运行配置
```bash
sudo gpib_config
```

### 步骤5: 配置权限
```bash
sudo usermod -a -G gpib,dialout $USER
logout
```

---

## 📚 相关文档

- **完整指南**: `../LINUX_GPIB_COMPLETE_GUIDE.md`
- **问题分析**: `../GPIB_WRITE_SUCCESS_READ_FAIL_ANALYSIS.md`
- **故障排查**: `../GPIB_TROUBLESHOOTING.md`

---

## 💡 提示

1. **用户组权限**: 添加后必须重新登录！
2. **内核模块**: 每次重启后需要重新加载（除非设置了开机自动加载）
3. **设备地址**: 确认WFP60H的GPIB地址设置为5
4. **超时设置**: Linux下建议使用30秒超时
5. **后端选择**: 优先使用`@py`后端（更稳定）

---

## 🔗 快速链接

```bash
# 综合测试
python3 scripts/linux_gpib_comprehensive_test.py

# 深度修复
./scripts/linux_gpib_deep_fix.sh

# 快速测试
python3 /tmp/test_gpib.py

# 查看日志
sudo dmesg | grep -i gpib
sudo journalctl -u nivisa
```

---

**最后更新**: 2026-04-29  
**版本**: 1.0
