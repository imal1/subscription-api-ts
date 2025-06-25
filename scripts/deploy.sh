#!/bin/bash

# 部署脚本
set -e

echo "🚀 开始部署 Subscription API..."

# 读取环境变量
if [ -f ".env" ]; then
    # 读取 .env 文件，忽略注释和空行
    while IFS='=' read -r key value; do
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z $key ]] && continue
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        export "$key"="$value"
    done < <(grep -v '^[[:space:]]*#' .env | grep -v '^[[:space:]]*$')
fi

# 服务名称，可通过环境变量覆盖
SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"

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
sudo systemctl restart "$SERVICE_NAME"

# 等待服务启动
sleep 3

# 检查服务状态
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "✅ 服务部署成功！"
    echo "📊 服务状态: $(systemctl is-active "$SERVICE_NAME")"
    # 从环境变量读取端口号
    PORT="${PORT:-3000}"
    echo "🌐 访问地址: http://localhost:${PORT}"
else
    echo "❌ 服务启动失败"
    sudo systemctl status "$SERVICE_NAME"
    exit 1
fi