# API更新总结

## 更新内容

### 1. fetch-sn 接口增加硬件版本参数

#### 修改前
```json
{
  "product_line": "637",
  "factory_code": "1",
  "line_code": "1",
  "sn": ""
}
```

#### 修改后
```json
{
  "product_line": "637",
  "factory_code": "1",
  "line_code": "1",
  "hardware_version": "1.0.0",  // 新增：从通用配置读取
  "sn": ""
}
```

**数据来源**：`ProductionConfig().hardwareVersion`

### 2. 新增 update-sn-status 接口

#### 接口信息
- **URL**: `http://api.jiananai.com/api/v1/product-sn/update-sn-status`
- **方法**: POST
- **Content-Type**: application/json

#### 请求头
```
Token: YOUR_TOKEN_HERE
User-Agent: JNProductionLine/1.0.0
```

#### 请求参数
```json
{
  "sn": "6371603071000025951",
  "status": 4
}
```

#### 响应格式
```json
{
  "error_code": 0,
  "msg": "操作成功",
  "now_time": 1772859109
}
```

#### 状态码说明
- **4**: 产测通过

### 3. 调用时机

#### fetch-sn 接口
**调用位置**：`test_state.dart` - `generateDeviceIdentity()`

**调用时机**：
1. SN读取测试时，设备未写入SN
2. SN读取测试时，设备已写入SN（传入现有SN验证）

**代码**：
```dart
final result = await SNApiService.fetchSN(
  productLine: productLine,
  factoryCode: factoryCode,
  lineCode: lineCode,
  hardwareVersion: config.hardwareVersion,  // 新增
  existingSn: existingSn,
);
```

#### update-sn-status 接口
**调用位置**：`test_state.dart` - `_finalizeTestReport()`

**调用时机**：产测整体通过后

**条件**：
- `_currentTestReport!.allTestsPassed == true`
- `deviceSN != '待分配'`
- `deviceSN != 'UNKNOWN'`

**代码**：
```dart
if (_currentTestReport!.allTestsPassed && deviceSN != '待分配' && deviceSN != 'UNKNOWN') {
  final updateSuccess = await SNApiService.updateSNStatus(
    sn: deviceSN,
    status: 4,
  );
  
  if (updateSuccess) {
    _logState?.success('✅ 服务端SN状态已更新为"产测通过"', type: LogType.debug);
  } else {
    _logState?.warning('⚠️  服务端SN状态更新失败', type: LogType.debug);
  }
}
```

## 工作流程

### 完整测试流程

```
1. 开始测试
   ↓
2. SN读取测试
   ↓
3. 调用 fetch-sn API（带硬件版本）
   ├─ 设备未写入SN → 获取新SN
   └─ 设备已写入SN → 验证SN
   ↓
4. 缓存SN和MAC地址
   ↓
5. 保存到CSV（状态：未测试）
   ↓
6. 执行其他测试项...
   ↓
7. 测试完成
   ↓
8. _finalizeTestReport()
   ├─ 更新CSV（状态：通过/失败）
   └─ 如果测试通过 → 调用 update-sn-status API（status=4）
   ↓
9. 保存测试报告
```

### 日志输出示例

#### SN分配时
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📡 请求SN码API
   URL: http://api.jiananai.com/api/v1/product-sn/fetch-sn
   产品线: 637
   工厂: 1
   产线: 1
   硬件版本: 1.0.0
   现有SN: 6371603071000025951
   状态码: 200
   响应: {"error_code":0,"msg":"操作成功",...}
✅ 成功获取SN码
   SN: 6371603071000025951
   蓝牙MAC: 48-08-EB-60-00-02
   WiFi MAC: 48-08-EB-50-00-02
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### 测试通过时
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 测试完成
   设备SN: 6371603071000025951
   WiFi MAC: 48:08:EB:50:00:02
   蓝牙MAC: 48:08:EB:60:00:02
   测试结果: 通过 (100.0%)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 已更新CSV设备记录
   📋 SN: 6371603071000025951
   📊 状态: 未测试 → 通过
   📈 通过率: 100.0%
   📁 文件: ~/Documents/JNProductionLine/device_records.csv
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📤 更新服务端SN状态...
   URL: http://api.jiananai.com/api/v1/product-sn/update-sn-status
   SN: 6371603071000025951
   状态: 4
   状态码: 200
   响应: {"error_code":0,"msg":"操作成功",...}
✅ SN状态更新成功
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 服务端SN状态已更新为"产测通过"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 修改文件清单

### 1. `/lib/services/sn_api_service.dart`
- ✅ `fetchSN()` 增加 `hardwareVersion` 参数
- ✅ 新增 `updateSNStatus()` 方法
- ✅ 新增 `updateSnStatusEndpoint` 常量

### 2. `/lib/models/test_state.dart`
- ✅ `generateDeviceIdentity()` 调用API时传入硬件版本
- ✅ `_finalizeTestReport()` 改为异步方法
- ✅ `_finalizeTestReport()` 中添加状态更新逻辑
- ✅ 所有调用 `_finalizeTestReport()` 的地方改为 `await`

## 异常处理

### API调用失败
- **fetch-sn失败**：测试流程中断，不继续后续测试
- **update-sn-status失败**：记录警告日志，不影响测试报告保存

### 网络超时
- 超时时间：10秒
- 超时处理：返回失败，记录错误日志

### 错误码处理
- `error_code != 0`：解析错误消息，返回失败

## 配置要求

### Token配置
在 `sn_api_service.dart` 中配置实际的Token：
```dart
static const String token = 'YOUR_TOKEN_HERE'; // 第12行
```

### 硬件版本配置
在通用配置UI中设置硬件版本号（默认：1.0.0）

## 测试验证

### 验证步骤
1. ✅ 配置Token
2. ✅ 设置硬件版本号
3. ✅ 测试SN分配（fetch-sn带硬件版本）
4. ✅ 测试产测通过（update-sn-status调用）
5. ✅ 验证CSV文件更新
6. ✅ 检查日志输出

### 预期结果
- SN分配成功，硬件版本正确传递
- 测试通过后，服务端SN状态更新为4
- CSV文件状态从"未测试"更新为"通过"
- 日志清晰显示API调用过程

## 注意事项

1. **硬件版本来源**：从 `ProductionConfig().hardwareVersion` 读取
2. **状态更新条件**：仅在测试全部通过时调用
3. **异步处理**：`_finalizeTestReport()` 现在是异步方法，确保CSV和API调用完成
4. **错误容错**：API调用失败不影响测试报告保存
5. **SN验证**：排除"待分配"和"UNKNOWN"状态的SN
