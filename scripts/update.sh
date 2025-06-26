#!/bin/bash

# 服务器部署更新脚本
# 在服务器上运行此脚本来应用最新的代码修改

set -e

# 检查sudo命令是否可用
HAS_SUDO=false
if command -v sudo >/dev/null 2>&1; then
    HAS_SUDO=true
fi

# 定义安全的sudo函数
safe_sudo() {
    if [[ $EUID -eq 0 ]]; then
        # 如果是root用户，直接执行命令
        "$@"
    elif [ "$HAS_SUDO" = true ]; then
        # 如果有sudo且不是root，使用sudo
        sudo "$@"
    else
        echo "❌ 错误：需要root权限或sudo命令来执行: $*"
        echo "   请以root用户运行此脚本，或安装sudo命令"
        exit 1
    fi
}

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
    safe_sudo systemctl restart "$SERVICE_NAME"
    
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
    safe_sudo systemctl start "$SERVICE_NAME"
    
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
if [[ $EUID -eq 0 ]]; then
    echo "   journalctl -u $SERVICE_NAME -f"
else
    if [ "$HAS_SUDO" = true ]; then
        echo "   sudo journalctl -u $SERVICE_NAME -f"
    else
        echo "   journalctl -u $SERVICE_NAME -f (需要root权限)"
    fi
fi
