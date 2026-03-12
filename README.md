# JN Production Line Test Application

生产线测试应用程序 - 支持单板产测和整机产测

## 构建

### Linux 构建

```bash
# 使用构建脚本
chmod +x scripts/build-linux.sh
./scripts/build-linux.sh

# 或使用 Docker
chmod +x scripts/docker-build.sh
./scripts/docker-build.sh
```

### GitHub Actions

推送代码到 main/master/develop 分支自动触发构建。

构建产物可在 Actions 页面下载。

## 系统要求

### Linux
- Flutter 3.24.0+
- BlueZ 蓝牙栈
- GTK 3.0+

详见 [CI 构建指南](docs/CI_BUILD_GUIDE.md)

## 文档

- [Linux 蓝牙 SPP 使用指南](docs/LINUX_BLUETOOTH_SPP.md)
- [CI 构建指南](docs/CI_BUILD_GUIDE.md)

## License

Copyright © 2024
