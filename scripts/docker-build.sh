#!/bin/bash
# Docker 构建脚本

set -e

echo "================================"
echo "Docker Build for Linux"
echo "================================"

# 构建 Docker 镜像
echo "🐳 Building Docker image..."
docker build -f Dockerfile.linux -t jn-production-line:linux .

# 创建容器并复制构建产物
echo ""
echo "📦 Extracting build artifacts..."
docker create --name jn-build-temp jn-production-line:linux
docker cp jn-build-temp:/app/jn-production-line-linux-x64.tar.gz .
docker rm jn-build-temp

echo ""
echo "✅ Build completed!"
echo "📦 Package: jn-production-line-linux-x64.tar.gz"
ls -lh jn-production-line-linux-x64.tar.gz
