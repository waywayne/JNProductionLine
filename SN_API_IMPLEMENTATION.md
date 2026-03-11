# SN码服务端API实现方案

## 概述

将SN码预分配从本地方案全面替换为服务端API方案，通过调用服务端API获取SN码和MAC地址。

## API规格

### 接口信息
- **URL**: `http://api.jiananai.com/api/v1/product-sn/fetch-sn`
- **方法**: POST
- **Content-Type**: application/json

### 请求头
```
Token: YOUR_TOKEN_HERE
User-Agent: JNProductionLine/1.0.0
```

### 请求参数
```json
{
  "product_line": "637",     // 产品线代码（从通用配置获取）
  "factory_code": "1",       // 工厂代码（从通用配置获取）
  "line_code": "1",          // 产线代码（从通用配置获取）
  "sn": "6371603071000025951"  // 可选，设备读取到的现有SN，没有则传空字符串
}
```

### 响应格式
```json
{
  "error_code": 0,
  "msg": "操作成功",
  "now_time": 1772859109,
  "data": {
    "sn_code": "6371603071000025951",
    "bluetooth_address": "48-08-EB-60-00-02",
    "mac_address": "48-08-EB-50-00-02"
  }
}
```

## 实现内容

### 1. 新增文件

#### `/lib/services/sn_api_service.dart`
- 封装SN码API调用逻辑
- 处理HTTP请求和响应
- MAC地址格式转换（`-` → `:`）
- 错误处理和超时控制

### 2. 修改文件

#### `/lib/models/test_state.dart`
- 修改 `generateDeviceIdentity()` 方法
  - 添加可选参数 `existingSn`
  - 从通用配置读取产品线、工厂、产线信息
  - 调用API获取SN和MAC地址
  - 缓存返回的数据到 `_currentDeviceIdentity`
- 修改 `_autoTestReadSN()` 方法
  - 读取到SN后调用API验证
  - 传入读取到的SN给服务端
  - 由服务端决定使用现有SN还是分配新SN
- 添加import: `import '../services/sn_api_service.dart';`

#### `/lib/config/production_config.dart`
- 已包含产品线、工厂、产线配置
- 默认值：
  - 产品线: `637`
  - 工厂: `1`
  - 产线: `1`

#### `/pubspec.yaml`
- 添加依赖: `http: ^1.1.0`

### 3. 配置项

在通用配置UI中已有以下配置项：
- **产品线** (product_line): 默认 "637"
- **工厂** (factory): 默认 "1"
- **产线** (production_line): 默认 "1"

## 工作流程

### 场景1：设备未写入SN
1. SN读取测试返回空
2. 调用API，不传入`existingSn`
3. 服务端分配新的SN和MAC地址
4. 缓存到 `_currentDeviceIdentity`
5. 后续SN写入测试使用此SN

### 场景2：设备已写入SN
1. SN读取测试返回SN码
2. 调用API，传入读取到的SN作为`existingSn`
3. 服务端验证SN：
   - 如果SN有效，返回对应的MAC地址
   - 如果SN无效，分配新的SN和MAC地址
4. 缓存到 `_currentDeviceIdentity`
5. 后续测试使用服务端返回的SN和MAC

### 场景3：API调用失败
1. 网络超时或服务端错误
2. 记录错误日志
3. 测试失败，不继续后续流程

## 数据缓存

从API获取的数据缓存在 `_currentDeviceIdentity` 中：
```dart
{
  'sn': '6371603071000025951',
  'wifiMac': '48:08:EB:50:00:02',
  'bluetoothMac': '48:08:EB:60:00:02',
  'hardwareVersion': 'V1.0',
  'productLine': '637',
  'factory': '1',
  'productionLine': '1',
}
```

后续所有测试（SN写入、MAC写入、蓝牙测试等）都使用此缓存数据。

## 注意事项

1. **Token配置**: 需要在 `sn_api_service.dart` 中配置实际的Token
   ```dart
   static const String token = 'YOUR_TOKEN_HERE'; // TODO: 配置实际的Token
   ```

2. **网络依赖**: 测试流程依赖网络连接，需确保测试环境可访问API

3. **超时设置**: API请求超时时间设置为10秒

4. **错误处理**: API调用失败会导致测试失败，不会使用本地生成的SN

5. **MAC地址格式**: API返回的MAC地址格式为 `48-08-EB-60-00-02`，会自动转换为 `48:08:EB:60:00:02`

## 测试验证

1. 运行 `flutter pub get` 安装http依赖
2. 配置Token
3. 测试场景1：设备未写入SN
4. 测试场景2：设备已写入有效SN
5. 测试场景3：网络断开情况

## 移除的功能

- 本地SN生成逻辑（`SNMacConfig.generateDeviceIdentity()`）不再使用
- 本地SN校验逻辑不再使用
- 本地MAC地址生成逻辑不再使用
- 所有SN和MAC地址统一由服务端API提供
