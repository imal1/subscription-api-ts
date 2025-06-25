#!/bin/bash

# 生成nginx配置文件的脚本
# 根据 .env 文件中的环境变量生成对应的nginx配置

set -e

# 检查 .env 文件是否存在
if [ ! -f ".env" ]; then
    echo "错误: .env 文件不存在，请先创建配置文件"
    exit 1
fi

# 手动读取环境变量
API_PORT=$(grep '^PORT=' .env | cut -d'=' -f2 | tr -d '"' || echo "5000")
NGINX_PORT=$(grep '^NGINX_PORT=' .env | cut -d'=' -f2 | tr -d '"' || echo "8080")
NODE_ENV=$(grep '^NODE_ENV=' .env | cut -d'=' -f2 | tr -d '"' || echo "development")
STATIC_DIR=$(grep '^STATIC_DIR=' .env | cut -d'=' -f2 | tr -d '"' || echo "./data")
LOG_DIR=$(grep '^LOG_DIR=' .env | cut -d'=' -f2 | tr -d '"' || echo "./logs")
NGINX_PORT_STATIC=$((NGINX_PORT + 1))
STATIC_DIR=${STATIC_DIR:-./data}
LOG_DIR=${LOG_DIR:-./logs}

echo "🔧 生成nginx配置文件..."
echo "API端口: $API_PORT"
echo "Nginx端口: $NGINX_PORT"
echo "静态文件端口: $NGINX_PORT_STATIC"
echo "静态文件目录: $STATIC_DIR"

# 生成开发环境配置
if [ "$NODE_ENV" = "development" ] || [ "$NODE_ENV" = "" ]; then
    echo "📝 生成开发环境nginx配置..."
    envsubst '${API_PORT} ${NGINX_PORT} ${NGINX_PORT_STATIC}' < config/nginx.dev.conf.template > config/nginx.dev.conf
    echo "✅ 开发环境配置已生成: config/nginx.dev.conf"
fi

# 生成生产环境配置
if [ "$NODE_ENV" = "production" ]; then
    echo "📝 生成生产环境nginx配置..."
    export API_PORT NGINX_PORT
    envsubst '${API_PORT} ${NGINX_PORT}' < config/nginx.conf.template > config/nginx.conf
    echo "✅ 生产环境配置已生成: config/nginx.conf"
fi

echo "🎉 Nginx配置文件生成完成！"
