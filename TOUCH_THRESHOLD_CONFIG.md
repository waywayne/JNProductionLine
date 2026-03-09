# Touch 阈值配置修复

## 问题描述

Touch 测试中的 CDC 阈值之前是硬编码在 `TouchTestConfig` 类中的固定值（500），没有使用通用配置中的 `ProductionConfig.touchThreshold` 配置。

## 修复内容

### 修改文件
`lib/models/touch_test_step.dart`

### 修改前
```dart
/// Touch测试配置
class TouchTestConfig {
  // Touch ID
  static const int touchLeft = 0x00;   // 左Touch
  static const int touchRight = 0x01;  // 右Touch
  
  // CDC阈值配置
  static const int cdcThreshold = 500; // CDC差值阈值 (硬编码)
  
  // ...
}
```

### 修改后
```dart
import '../config/production_config.dart';

/// Touch测试配置
class TouchTestConfig {
  // Touch ID
  static const int touchLeft = 0x00;   // 左Touch
  static const int touchRight = 0x01;  // 右Touch
  
  // CDC阈值配置 - 从 ProductionConfig 读取
  static int get cdcThreshold => ProductionConfig().touchThreshold;
  
  // ...
}
```

## Touch 阈值说明

### 什么是 Touch CDC 阈值？

Touch CDC（Capacitive Detection Circuit，电容检测电路）阈值用于判断用户的触摸操作是否有效。

### 工作原理

1. **基线值**: 未触摸时的 CDC 值（基线）
2. **触摸值**: 触摸时的 CDC 值
3. **差值计算**: `CDC差值 = |触摸值 - 基线值|`
4. **阈值判断**: 如果 `CDC差值 >= touchThreshold`，则认为触摸有效

### 测试流程

```
1. 读取基线 CDC 值（未触摸状态）
   ↓
2. 提示用户执行触摸操作
   ↓
3. 读取触摸后的 CDC 值
   ↓
4. 计算 CDC 差值
   ↓
5. 判断: CDC差值 >= touchThreshold?
   ├─ YES → 触摸有效 ✅
   └─ NO  → 触摸无效 ❌ (重试)
```

## 配置方式

### 1. 通过通用配置页面
1. 点击菜单栏 **"通用配置"**
2. 找到 **"Touch阈值变化量"** 配置项
3. 修改阈值（默认 500）
4. 点击 **"保存配置"**

### 2. 配置存储
- **存储位置**: SharedPreferences / 注册表
- **配置键**: `touch_threshold`
- **默认值**: `500`
- **数据类型**: `int`

### 3. 配置读取
```dart
// 读取配置
int threshold = ProductionConfig().touchThreshold;

// Touch 测试中使用
int cdcThreshold = TouchTestConfig.cdcThreshold;
// 实际上调用的是: ProductionConfig().touchThreshold
```

## 使用场景

### 左 Touch 测试
- **未触摸**: 基线值
- **单击**: CDC 差值 >= 阈值
- **双击**: CDC 差值 >= 阈值（两次）
- **长按**: CDC 差值 >= 阈值（持续 3 秒）
- **佩戴检测**: CDC 差值 >= 阈值

### 右 Touch 测试
- **未触摸**: 基线值
- **TK1 区域**: CDC 差值 >= 阈值
- **TK2 区域**: CDC 差值 >= 阈值
- **TK3 区域**: CDC 差值 >= 阈值

## 日志示例

### 触摸有效（差值 >= 阈值）
```
📖 开始右Touch测试
📊 基线 CDC: 1000
👆 请触摸右侧TK1区域
⏳ 等待用户操作中...
📊 触摸 CDC: 1650 (差值: +650) ✅
✅ CDC差值 650 达到阈值 500
✅ 右侧TK1区域 测试通过
```

### 触摸无效（差值 < 阈值）
```
📖 开始右Touch测试
📊 基线 CDC: 1000
👆 请触摸右侧TK1区域
⏳ 等待用户操作中...
📊 触摸 CDC: 1350 (差值: +350) ❌
❌ CDC差值 350 未达阈值 500
⚠️  右侧TK1区域 失败，准备重试 (尝试 1/10)
```

## 阈值调整建议

### 默认值: 500
- 适用于大多数正常情况
- 能有效区分触摸和非触摸状态

### 调高阈值（例如 800）
- **优点**: 减少误触发
- **缺点**: 可能导致轻触无法识别
- **适用**: 环境干扰较大时

### 调低阈值（例如 300）
- **优点**: 提高灵敏度
- **缺点**: 可能增加误触发
- **适用**: Touch 灵敏度较低时

## 注意事项

1. **阈值过高**: 可能导致正常触摸无法识别
2. **阈值过低**: 可能导致误触发（环境干扰）
3. **建议范围**: 300 - 1000
4. **测试验证**: 修改后需要实际测试验证效果

## 技术细节

### 代码位置
- **配置定义**: `lib/config/production_config.dart`
- **Touch 配置**: `lib/models/touch_test_step.dart`
- **Touch 测试**: `lib/models/test_state.dart`

### 关键代码
```dart
// ProductionConfig
int get touchThreshold => 
  _prefs?.getInt(_keyTouchThreshold) ?? defaultTouchThreshold;

// TouchTestConfig
static int get cdcThreshold => ProductionConfig().touchThreshold;

// Touch 测试判断
if (cdcDiff != null && cdcDiff < TouchTestConfig.cdcThreshold) {
  thresholdMet = false;
  details += ' [未达阈值 ${TouchTestConfig.cdcThreshold}]';
}
```

## 优势

### ✅ 统一配置
- 所有阈值统一在通用配置中管理
- 避免硬编码，便于调整

### ✅ 持久化保存
- 配置保存在注册表/SharedPreferences
- 应用更新不会丢失配置

### ✅ 灵活调整
- 可根据实际情况调整阈值
- 无需修改代码重新编译

### ✅ 即时生效
- 配置保存后立即生效
- 新的测试使用新阈值

---

**修复日期**: 2026-03-09
**版本**: 1.0
