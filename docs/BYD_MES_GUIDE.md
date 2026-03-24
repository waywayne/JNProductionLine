# BYD MES 系统集成指南

## 📋 概述

BYD MES 系统集成模块用于与 BYD MES 系统进行通讯，支持产测开始、完成（良品/不良品）等操作。

---

## 🚀 快速开始

### 1. 安装 Python 依赖

```bash
pip3 install requests configparser
```

### 2. 打开 MES 测试界面

在应用顶部菜单栏点击 **"BYD MES 测试"**

---

## 🔧 配置说明

### MES 配置项

| 配置项 | 说明 | 示例 |
|--------|------|------|
| **MES IP** | MES 服务器 IP 地址 | `192.168.1.100` |
| **Client ID** | 客户端 ID | `DEFAULT_CLIENT` |
| **工站名称** | 当前工站名称 | `STATION1` |

---

## 📝 操作说明

### 1. 开始 (Start)

**用途：** 开始产测

**步骤：**
1. 输入 SN 号码
2. 选择操作类型：**开始 (Start)**
3. 点击 **"执行操作"**

**MES 接口：**
```
GET /Service.action?method=Start
```

---

### 2. 完成-良品 (Complete)

**用途：** 产测完成，良品

**步骤：**
1. 输入 SN 号码
2. 选择操作类型：**完成-良品 (Complete)**
3. 点击 **"执行操作"**

**MES 接口：**
```
GET /Service.action?method=Complete
```

---

### 3. 完成-不良品 (NC Complete)

**用途：** 产测完成，不良品

**步骤：**
1. 输入 SN 号码
2. 选择操作类型：**完成-不良品 (NC Complete)**
3. 填写不良品参数：
   - 不良代码（如：`NC001`）
   - 不良描述（如：`测试不良`）
   - 失败项目（如：`LED测试`）
   - 失败值（如：`亮度不足`）
4. 点击 **"执行操作"**

**MES 接口：**
```
GET /Service.action?method=NcComplete
```

---

## 🧪 测试连接

点击 **"测试连接"** 按钮可以验证 MES 服务器连接是否正常。

---

## 📊 日志查看

右侧日志面板实时显示：
- ✅ 成功操作（绿色）
- ❌ 失败操作（红色）
- ⚠️ 警告信息（橙色）
- 📤 请求信息（蓝色）

---

## 🔍 故障排查

### 问题 1：连接超时

**原因：** MES 服务器 IP 配置错误或网络不通

**解决：**
1. 检查 MES IP 配置
2. ping MES 服务器验证网络
3. 检查防火墙设置

---

### 问题 2：SN 不存在

**原因：** 输入的 SN 在 MES 系统中不存在

**解决：**
1. 确认 SN 号码正确
2. 在 MES 系统中查询该 SN

---

### 问题 3：操作失败

**原因：** MES 系统返回 FAIL

**解决：**
1. 查看日志中的详细错误信息
2. 检查 MES 系统状态
3. 联系 MES 管理员

---

## 📁 文件说明

| 文件 | 说明 |
|------|------|
| `scripts/byd_mes_client.py` | Python MES 客户端脚本 |
| `lib/services/byd_mes_service.dart` | Dart MES 服务类 |
| `lib/widgets/byd_mes_test_dialog.dart` | MES 测试界面 |

---

## 💡 使用示例

### 命令行测试

```bash
# 开始
python3 scripts/byd_mes_client.py start SN123456 STATION1 192.168.1.100 CLIENT001

# 完成（良品）
python3 scripts/byd_mes_client.py complete SN123456 STATION1 192.168.1.100 CLIENT001

# 完成（不良品）
python3 scripts/byd_mes_client.py nccomplete SN123456 STATION1 192.168.1.100 CLIENT001 NC001 "测试不良" "LED测试" "亮度不足"
```

---

## 📝 日志文件

日志自动保存到：`YYYY-MM-DD_mes.log`

示例：`2024-03-24_mes.log`
