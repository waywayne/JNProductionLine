# 📊 SN 记录存储和导出指南

## 📁 SN 记录存储位置

### 存储文件

**文件名**: `sn_records.json`

**格式**: JSON

### 不同操作系统的存储路径

| 操作系统 | 路径 |
|---------|------|
| **Windows** | `C:\Users\<用户名>\AppData\Roaming\jn_production_line\Documents\sn_records.json` |
| **macOS** | `~/Library/Application Support/jn_production_line/sn_records.json` |
| **Linux** | `~/.local/share/jn_production_line/sn_records.json` |

### 查看文件位置

1. 打开应用
2. 点击菜单栏的 **"SN记录管理"**
3. 点击工具栏的 **📁 文件夹图标**
4. 弹窗会显示完整路径
5. 可以点击 **"复制路径"** 复制到剪贴板

---

## 📄 JSON 文件格式

### 文件结构

```json
{
  "SN码1": {
    "sn": "SN码",
    "hardware_version": "硬件版本",
    "wifi_mac": "WiFi MAC地址",
    "bt_mac": "蓝牙MAC地址",
    "created_at": "创建时间",
    "updated_at": "更新时间"
  },
  "SN码2": { ... }
}
```

### 示例

```json
{
  "6371512161000010000": {
    "sn": "6371512161000010000",
    "hardware_version": "1.0.0",
    "wifi_mac": "48:08:EB:50:00:50",
    "bt_mac": "48:08:EB:60:00:50",
    "created_at": "2026-03-07T10:30:00.000",
    "updated_at": "2026-03-07T10:30:00.000"
  },
  "6371512161000020000": {
    "sn": "6371512161000020000",
    "hardware_version": "1.0.0",
    "wifi_mac": "48:08:EB:50:00:51",
    "bt_mac": "48:08:EB:60:00:51",
    "created_at": "2026-03-07T11:00:00.000",
    "updated_at": "2026-03-07T11:00:00.000"
  }
}
```

---

## 📤 导出 CSV 文件

### 方法 1: 使用 UI 界面（推荐）

#### 步骤

1. **打开 SN 记录管理页面**
   - 点击菜单栏的 **"SN记录管理"** 按钮
   - 或使用快捷键（如果配置了）

2. **查看记录**
   - 页面会显示所有 SN 记录
   - 顶部显示统计信息：
     - 总记录数
     - WiFi MAC 索引
     - 蓝牙 MAC 索引
     - 下一个可用的 MAC 地址

3. **导出 CSV**
   - 点击工具栏的 **📥 下载图标**
   - 选择保存位置
   - 输入文件名（默认：`sn_records_<时间戳>.csv`）
   - 点击 **"保存"**

4. **确认导出**
   - 成功后会显示绿色提示：`CSV 文件已导出到: <路径>`
   - 失败会显示红色错误提示

#### 界面功能

| 按钮 | 图标 | 功能 |
|------|------|------|
| **查看文件位置** | 📁 | 显示 JSON 文件路径 |
| **导出 CSV** | 📥 | 导出所有记录为 CSV |
| **刷新** | 🔄 | 重新加载记录 |

---

### 方法 2: 手动从 JSON 转换

#### 使用在线工具

1. 打开 JSON 文件
2. 访问 JSON 转 CSV 工具（如 https://www.convertcsv.com/json-to-csv.htm）
3. 粘贴 JSON 内容
4. 转换并下载 CSV

#### 使用 Python 脚本

```python
import json
import csv

# 读取 JSON 文件
with open('sn_records.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# 写入 CSV 文件
with open('sn_records.csv', 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    
    # 写入表头
    writer.writerow(['SN', '硬件版本', 'WiFi MAC', '蓝牙 MAC', '创建时间', '更新时间'])
    
    # 写入数据
    for record in data.values():
        writer.writerow([
            record['sn'],
            record['hardware_version'],
            record['wifi_mac'],
            record['bt_mac'],
            record['created_at'],
            record['updated_at']
        ])

print('CSV 文件已生成')
```

---

## 📊 CSV 文件格式

### 表头

```
SN,硬件版本,WiFi MAC,蓝牙 MAC,创建时间,更新时间
```

### 数据示例

```csv
SN,硬件版本,WiFi MAC,蓝牙 MAC,创建时间,更新时间
6371512161000010000,1.0.0,48:08:EB:50:00:50,48:08:EB:60:00:50,2026-03-07 10:30:00.000,2026-03-07 10:30:00.000
6371512161000020000,1.0.0,48:08:EB:50:00:51,48:08:EB:60:00:51,2026-03-07 11:00:00.000,2026-03-07 11:00:00.000
6371512161000030000,1.0.0,48:08:EB:50:00:52,48:08:EB:60:00:52,2026-03-07 11:30:00.000,2026-03-07 11:30:00.000
```

### 在 Excel 中打开

1. 打开 Excel
2. 文件 → 打开 → 选择 CSV 文件
3. 选择编码：**UTF-8**
4. 分隔符：**逗号**
5. 点击 **"完成"**

---

## 🔍 SN 记录管理界面

### 统计信息卡片

显示以下信息：

```
┌─────────────────────────────────────────────────┐
│ 统计信息                                         │
├─────────────────────────────────────────────────┤
│ 总记录数: 150                                    │
│ WiFi MAC 索引: 150                               │
│ 蓝牙 MAC 索引: 150                               │
│                                                  │
│ 下一个 WiFi MAC: 48:08:EB:50:00:C6              │
│ 下一个蓝牙 MAC: 48:08:EB:60:00:C6               │
└─────────────────────────────────────────────────┘
```

### 记录列表

每条记录显示：

```
┌─────────────────────────────────────────────────┐
│ ▼ 6371512161000010000                           │
│   硬件版本: 1.0.0                                │
│   ─────────────────────────────────────────     │
│   WiFi MAC:    48:08:EB:50:00:50               │
│   蓝牙 MAC:    48:08:EB:60:00:50               │
│   创建时间:    2026-03-07 10:30:00              │
│   更新时间:    2026-03-07 10:30:00              │
└─────────────────────────────────────────────────┘
```

---

## 💡 使用场景

### 1. **质量追溯**

导出 CSV 后可以：
- 在 Excel 中分析生产数据
- 按日期筛选记录
- 统计每日产量
- 查找特定 SN 的设备信息

### 2. **数据备份**

定期导出 CSV 作为备份：
```bash
# 建议备份频率
每日备份: sn_records_2026-03-07.csv
每周备份: sn_records_week_10.csv
每月备份: sn_records_2026-03.csv
```

### 3. **数据分析**

使用 Excel 或 Python 分析：
- MAC 地址分配情况
- 生产趋势
- 硬件版本分布
- 测试时间统计

### 4. **报表生成**

基于 CSV 数据生成：
- 日报表
- 周报表
- 月报表
- 质量报告

---

## 🔧 高级操作

### 批量导入记录

如果需要从其他系统导入记录：

1. 准备 CSV 文件（格式同导出格式）
2. 转换为 JSON 格式
3. 合并到 `sn_records.json`
4. 重启应用加载新数据

### 数据迁移

从旧系统迁移到新系统：

1. 在旧系统导出 CSV
2. 在新系统导入 JSON
3. 验证数据完整性
4. 更新 MAC 地址索引

### 数据清理

定期清理无效记录：

1. 导出 CSV
2. 在 Excel 中筛选和清理
3. 转换回 JSON
4. 替换原文件

---

## ⚠️ 注意事项

### 1. **数据安全**

- ✅ 定期备份 JSON 文件
- ✅ 导出 CSV 存档
- ✅ 使用版本控制（如 Git）
- ❌ 不要手动编辑 JSON 文件（可能破坏格式）

### 2. **文件编码**

- CSV 文件使用 **UTF-8** 编码
- Excel 打开时选择正确的编码
- 避免中文乱码

### 3. **并发访问**

- 同一时间只能有一个应用实例访问文件
- 多实例可能导致数据冲突

### 4. **数据一致性**

- 导出的 CSV 是快照，不会自动更新
- 需要重新导出获取最新数据

---

## 📋 快速参考

### 常用路径

**Windows**:
```
C:\Users\<用户名>\AppData\Roaming\jn_production_line\Documents\sn_records.json
```

**macOS**:
```
~/Library/Application Support/jn_production_line/sn_records.json
```

### 快速导出

1. 菜单栏 → **SN记录管理**
2. 工具栏 → **📥 导出 CSV**
3. 选择位置 → **保存**

### CSV 格式

```csv
SN,硬件版本,WiFi MAC,蓝牙 MAC,创建时间,更新时间
```

---

## 🔗 相关文档

- **SN 管理系统**: `SN_MANAGEMENT.md`
- **数据库查询**: `SN_DATABASE_QUERY.md`
- **测试序列**: `TEST_SEQUENCE_UPDATE.md`

---

## 总结

✅ **存储位置**:
- Windows: `AppData\Roaming\jn_production_line\Documents\sn_records.json`
- macOS: `~/Library/Application Support/jn_production_line/sn_records.json`
- Linux: `~/.local/share/jn_production_line/sn_records.json`

✅ **导出方式**:
1. UI 界面导出（推荐）
2. 手动转换 JSON

✅ **CSV 格式**:
```
SN,硬件版本,WiFi MAC,蓝牙 MAC,创建时间,更新时间
```

✅ **使用场景**:
- 质量追溯
- 数据备份
- 数据分析
- 报表生成

现在你可以轻松管理和导出 SN 记录了！🎉
