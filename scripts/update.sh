#!/bin/bash

# 服务器部署更新脚本
# 在服务器上运行此脚本来应用最新的代码修改

set -e

echo "🚀 开始更新 Subscription API..."

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# 检查是否是git仓库
if [ -d ".git" ]; then
    echo "📥 拉取最新代码..."
    git pull origin main || git pull origin master || echo "⚠️  Git pull 失败，继续使用本地代码"
else
    echo "ℹ️  不是 Git 仓库，跳过代码拉取"
fi

# 安装依赖（如果需要）
if [ -f "package.json" ]; then
    echo "📦 检查依赖..."
    if [ -f "package-lock.json" ]; then
        npm ci --production=false
    else
        npm install --include=dev
    fi
fi

# 构建项目
echo "🏗️ 构建项目..."
npm run build

# 检查服务是否正在运行
SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "🔄 重启服务..."
    sudo systemctl restart "$SERVICE_NAME"
    
    # 等待服务启动
    sleep 3
    
    # 检查服务状态
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "✅ 服务重启成功"
        systemctl status "$SERVICE_NAME" --no-pager -l
    else
        echo "❌ 服务重启失败"
        systemctl status "$SERVICE_NAME" --no-pager -l
        exit 1
    fi
else
    echo "🚀 启动服务..."
    sudo systemctl start "$SERVICE_NAME"
    
    # 等待服务启动
    sleep 3
    
    # 检查服务状态
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "✅ 服务启动成功"
        systemctl status "$SERVICE_NAME" --no-pager -l
    else
        echo "❌ 服务启动失败"
        systemctl status "$SERVICE_NAME" --no-pager -l
        exit 1
    fi
fi

echo ""
echo "🎉 更新完成！"
echo ""
echo "📋 测试命令："
NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"
echo "   curl http://localhost:${NGINX_PROXY_PORT}/api/update"
echo "   curl http://localhost:${NGINX_PROXY_PORT}/api/diagnose/clash"
echo "   curl http://localhost:${NGINX_PROXY_PORT}/clash.yaml"
echo ""
echo "📊 查看日志："
echo "   sudo journalctl -u $SERVICE_NAME -f"
