# PCI GPIB 卡修复指南

## 🎯 当前状态分析

### ✅ 已正常的部分
1. ✅ **硬件识别** - PCI GPIB卡已被系统识别
   ```
   05:00.0 Communication controller: National Instruments PCI-GPIB (rev 02)
   ```

2. ✅ **设备文件存在** - `/dev/gpib0` 已创建且权限正确
   ```
   crw-rw-rw- 1 root root 160, 0 Apr 28 13:52 /dev/gpib0
   ```

3. ✅ **NI-VISA工作** - 能够识别GPIB设备
   ```
   GPIB0::5::INSTR
   ```

4. ✅ **PyVISA已安装** - Python环境正常

### ❌ 存在的问题

1. ❌ **配置错误** - `/etc/gpib.conf`配置为USB适配器
   ```
   当前: board_type = "ni_usb_b"  # 错误！
   应该: board_type = "ni_pci"    # 正确
   ```

2. ❌ **内核模块未加载** - PCI驱动模块未加载
   ```
   需要: tnt4882 或 nec7210
   当前: 无GPIB模块
   ```

3. ⚠️ **网络问题** - 无法下载linux-gpib包（但不影响使用NI-VISA）

---

## 🚀 快速修复方案

### 方案1: 使用NI-VISA（推荐，无需linux-gpib）✅

**原理**: NI-VISA已经能识别设备，直接使用即可

**步骤**:

#### 1. 修正配置文件
```bash
sudo tee /etc/gpib.conf > /dev/null << 'EOF'
interface {
    minor = 0
    board_type = "ni_pci"  /* PCI卡 */
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

#### 2. 在代码中强制使用NI-VISA后端
```python
import pyvisa

# 强制使用NI-VISA（@ivi是新名称，@ni是旧名称）
rm = pyvisa.ResourceManager('@ni')  
inst = rm.open_resource('GPIB0::5::INSTR')
inst.timeout = 30000

# 测试
inst.write('*CLS')
print("写入成功")

inst.close()
rm.close()
```

#### 3. 测试
```bash
python3 << 'EOF'
import pyvisa
rm = pyvisa.ResourceManager('@ni')
print("资源:", rm.list_resources())
inst = rm.open_resource('GPIB0::5::INSTR')
inst.timeout = 30000
inst.write('*CLS')
print("✅ 写入成功")
inst.close()
rm.close()
EOF
```

---

### 方案2: 修复linux-gpib（需要网络）

**仅在需要使用@py后端时执行**

#### 1. 修复网络
```bash
# 检查网络
ping -c 3 mirrors.aliyun.com

# 如果网络正常，重新运行
sudo apt-get update
sudo apt-get install linux-gpib linux-gpib-user
```

#### 2. 加载PCI驱动
```bash
# NI PCI-GPIB使用tnt4882驱动
sudo modprobe tnt4882

# 或者使用nec7210
sudo modprobe nec7210

# 验证
lsmod | grep gpib
```

---

## 🔧 修改应用代码

### 修改1: gpib_service.dart - 强制使用NI-VISA

找到Python脚本部分，修改ResourceManager初始化：

```dart
// 在 _createGpibBridgeScript 方法中
String _createGpibBridgeScript(String address) {
  return '''
import pyvisa
import sys
import time

# 强制使用NI-VISA后端（适用于PCI GPIB卡）
try:
    rm = pyvisa.ResourceManager('@ni')  # 使用NI-VISA
    print("DEBUG: Using NI-VISA backend", file=sys.stderr)
except Exception as e:
    print(f"ERROR: Cannot use NI-VISA: {e}", file=sys.stderr)
    sys.exit(1)

# ... 其余代码保持不变
''';
}
```

### 修改2: gpib_service_v2.dart - 同样修改

```dart
final script = '''
import pyvisa
import sys

# 强制使用NI-VISA
rm = pyvisa.ResourceManager('@ni')
print(f"INFO: Using NI-VISA backend", file=sys.stderr)

# ... 其余代码
''';
```

### 修改3: gpib_diagnostic_service.dart - 添加PCI测试

在所有测试方法中，尝试NI-VISA后端：

```dart
final script = '''
import pyvisa

# 优先使用NI-VISA（适用于PCI卡）
try:
    rm = pyvisa.ResourceManager('@ni')
except:
    rm = pyvisa.ResourceManager()  # 回退到默认

# ... 其余代码
''';
```

---

## 📝 完整测试脚本

创建 `test_pci_gpib.py`:

```python
#!/usr/bin/env python3
"""PCI GPIB 测试脚本"""

import pyvisa
import sys

def test_ni_visa():
    """测试NI-VISA后端"""
    print("=" * 60)
    print("测试 NI-VISA 后端（PCI GPIB卡）")
    print("=" * 60)
    
    try:
        # 使用NI-VISA
        rm = pyvisa.ResourceManager('@ni')
        print("✅ NI-VISA后端初始化成功")
        
        # 列出资源
        resources = rm.list_resources()
        print(f"✅ 找到 {len(resources)} 个资源:")
        for res in resources:
            print(f"  - {res}")
        
        # 连接GPIB设备
        if 'GPIB0::5::INSTR' in resources:
            print("\n连接到 GPIB0::5::INSTR...")
            inst = rm.open_resource('GPIB0::5::INSTR')
            inst.timeout = 30000
            print("✅ 连接成功")
            
            # 测试写入
            print("\n测试写入命令 (*CLS)...")
            try:
                inst.write('*CLS')
                print("✅ 写入成功")
            except Exception as e:
                print(f"❌ 写入失败: {e}")
            
            # 测试查询
            print("\n测试查询命令 (*IDN?)...")
            try:
                result = inst.query('*IDN?')
                print(f"✅ 查询成功: {result.strip()}")
            except Exception as e:
                print(f"⚠️  查询失败: {e}")
                print("   (设备可能不支持查询命令)")
            
            # 测试WFP60H命令
            print("\n测试WFP60H写入命令...")
            commands = [
                ':SOURce1:VOLTage 5.0',
                ':SOURce1:CURRent:LIMit 0.1',
                ':OUTPut1 ON',
                ':OUTPut1 OFF',
            ]
            
            for cmd in commands:
                try:
                    inst.write(cmd)
                    print(f"✅ {cmd}")
                except Exception as e:
                    print(f"❌ {cmd}: {e}")
            
            inst.close()
        else:
            print("❌ 未找到 GPIB0::5::INSTR")
        
        rm.close()
        return True
        
    except Exception as e:
        print(f"❌ NI-VISA测试失败: {e}")
        return False

def test_pyvisa_py():
    """测试pyvisa-py后端"""
    print("\n" + "=" * 60)
    print("测试 pyvisa-py 后端（纯Python）")
    print("=" * 60)
    
    try:
        rm = pyvisa.ResourceManager('@py')
        print("✅ pyvisa-py后端初始化成功")
        
        resources = rm.list_resources()
        gpib_resources = [r for r in resources if 'GPIB' in r]
        
        if gpib_resources:
            print(f"✅ 找到 {len(gpib_resources)} 个GPIB资源:")
            for res in gpib_resources:
                print(f"  - {res}")
        else:
            print("⚠️  未找到GPIB资源（pyvisa-py可能不支持PCI卡）")
        
        rm.close()
        return True
        
    except Exception as e:
        print(f"❌ pyvisa-py测试失败: {e}")
        return False

if __name__ == '__main__':
    print("\nPCI GPIB 综合测试\n")
    
    # 测试NI-VISA（主要方案）
    ni_ok = test_ni_visa()
    
    # 测试pyvisa-py（备选方案）
    py_ok = test_pyvisa_py()
    
    print("\n" + "=" * 60)
    print("测试总结")
    print("=" * 60)
    print(f"NI-VISA:    {'✅ 通过' if ni_ok else '❌ 失败'}")
    print(f"pyvisa-py:  {'✅ 通过' if py_ok else '❌ 失败'}")
    
    if ni_ok:
        print("\n✅ 推荐使用 NI-VISA 后端 (@ni)")
        print("   在代码中使用: ResourceManager('@ni')")
    elif py_ok:
        print("\n⚠️  使用 pyvisa-py 后端 (@py)")
        print("   在代码中使用: ResourceManager('@py')")
    else:
        print("\n❌ 所有后端都失败，请检查:")
        print("   1. GPIB设备是否连接")
        print("   2. 设备电源是否打开")
        print("   3. GPIB地址是否为5")
    
    sys.exit(0 if (ni_ok or py_ok) else 1)
```

保存并运行:
```bash
chmod +x test_pci_gpib.py
python3 test_pci_gpib.py
```

---

## 🎯 推荐的最终方案

### 对于你的情况（PCI GPIB卡 + NI-VISA已安装）

**最佳方案**: 直接使用NI-VISA，无需linux-gpib

#### 步骤1: 修正配置
```bash
./scripts/fix_pci_gpib.sh
```

#### 步骤2: 修改代码
在所有GPIB服务中，强制使用`@ni`后端：

```dart
// gpib_service.dart
// gpib_service_v2.dart
// gpib_diagnostic_service.dart

// 修改所有 ResourceManager() 为:
rm = pyvisa.ResourceManager('@ni')
```

#### 步骤3: 测试
```bash
python3 test_pci_gpib.py
```

#### 步骤4: 如果成功，更新应用
```bash
flutter run
```

---

## ❓ 常见问题

### Q: 为什么@py后端找不到GPIB设备？

**A**: pyvisa-py主要支持USB/串口设备，对PCI卡支持有限。PCI GPIB卡应该使用NI-VISA。

### Q: 是否必须安装linux-gpib？

**A**: 不需要！如果NI-VISA已安装且工作正常，直接使用NI-VISA即可。

### Q: 配置文件中的board_type有什么作用？

**A**: 
- `ni_usb_b`: USB GPIB适配器
- `ni_pci`: PCI GPIB卡
- `agilent_82357a`: Agilent USB适配器

必须与实际硬件匹配！

### Q: 如何确认使用的是哪个后端？

**A**: 
```python
import pyvisa
rm = pyvisa.ResourceManager('@ni')
print(rm.visalib)  # 显示使用的库
```

---

## 📊 状态检查清单

运行以下命令检查状态：

```bash
# 1. 硬件
lspci | grep -i gpib
# 预期: 05:00.0 Communication controller: National Instruments PCI-GPIB

# 2. 设备文件
ls -l /dev/gpib0
# 预期: crw-rw-rw- 1 root root 160, 0 ...

# 3. NI-VISA
visaconf --version
# 预期: 显示版本号

# 4. PyVISA
python3 -c "import pyvisa; print(pyvisa.__version__)"
# 预期: 显示版本号

# 5. 资源列表
python3 -c "import pyvisa; rm=pyvisa.ResourceManager('@ni'); print(rm.list_resources())"
# 预期: 包含 GPIB0::5::INSTR
```

---

## 🎉 成功标志

当看到以下输出时，表示配置成功：

```
✅ NI-VISA后端初始化成功
✅ 找到 2 个资源:
  - ASRL1::INSTR
  - GPIB0::5::INSTR
✅ 连接成功
✅ 写入成功
```

---

**关键点**: 你的系统已经有PCI GPIB卡和NI-VISA，只需要：
1. 修正配置文件（USB → PCI）
2. 在代码中使用`@ni`后端
3. 无需安装linux-gpib

**最后更新**: 2026-04-29
