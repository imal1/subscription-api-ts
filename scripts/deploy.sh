#!/bin/bash

# 部署脚本
set -e

echo "🚀 开始部署 Subscription API..."

# 确保subconverter运行
if ! systemctl is-active --quiet subconverter; then
    echo "启动 subconverter..."
    sudo systemctl start subconverter
fi

# 构建项目
echo "🏗️ 构建项目..."
npm run build

# 重启服务
echo "🔄 重启服务..."
sudo systemctl restart subscription-api-ts

# 等待服务启动
sleep 3

# 检查服务状态
if systemctl is-active --quiet subscription-api-ts; then
    echo "✅ 服务部署成功！"
    echo "📊 服务状态: $(systemctl is-active subscription-api-ts)"
    echo "🌐 访问地址: http://localhost:5000"
else
    echo "❌ 服务启动失败"
    sudo systemctl status subscription-api-ts
    exit 1
fi