# GitHub Actions CI/CD

## 工作流说明

### build-linux.yml

自动构建 Linux 版本的生产线测试应用程序。

#### 触发条件
- Push 到 main/master/develop 分支
- Pull Request 到 main/master/develop 分支
- 手动触发 (workflow_dispatch)

#### 构建步骤
1. **安装系统依赖**: 安装 Linux 开发工具和蓝牙相关依赖
2. **设置 Flutter**: 安装 Flutter SDK (3.24.0 stable)
3. **启用 Linux 桌面**: 配置 Flutter Linux 支持
4. **获取依赖**: 运行 `flutter pub get`
5. **代码分析**: 运行 `flutter analyze`
6. **构建应用**: 编译 Linux release 版本
7. **打包**: 创建 tar.gz 压缩包
8. **上传产物**: 保存构建结果 30 天

#### 构建产物
- `jn-production-line-linux-x64.tar.gz`: 应用程序压缩包
- `*.AppImage`: AppImage 格式 (可选)

## 本地测试

在推送代码前，可以本地测试构建：

```bash
# 安装依赖
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev \
  liblzma-dev bluez bluez-tools libbluetooth-dev socat

# 启用 Linux 桌面
flutter config --enable-linux-desktop

# 获取依赖
flutter pub get

# 构建
flutter build linux --release
```

## 系统要求

### 蓝牙依赖
- `bluez`: BlueZ 蓝牙栈
- `bluez-tools`: 蓝牙工具集
- `libbluetooth-dev`: 蓝牙开发库
- `socat`: 数据转发工具

### 构建工具
- `clang`: C/C++ 编译器
- `cmake`: 构建系统
- `ninja-build`: 构建工具
- `pkg-config`: 包配置工具
- `libgtk-3-dev`: GTK3 开发库

## 故障排查

### 构建失败
- 检查 Flutter 版本是否正确
- 确认所有系统依赖已安装
- 查看构建日志中的错误信息

### 蓝牙功能问题
- 确认 bluez 和相关工具已安装
- 检查运行时是否有蓝牙权限
- 验证 `/dev/rfcomm*` 设备文件权限

## 手动触发构建

1. 进入 GitHub 仓库
2. 点击 "Actions" 标签
3. 选择 "Build Linux Application"
4. 点击 "Run workflow"
5. 选择分支并运行
