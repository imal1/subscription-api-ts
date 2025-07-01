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

# 安装依赖（monorepo方式）
if [ -f "package.json" ]; then
    echo "📦 安装 monorepo 依赖..."
    if [ -f "package-lock.json" ]; then
        npm ci --include=dev
    else
        npm install --include=dev
    fi
fi

# 重新生成配置文件
echo "🔧 重新生成配置文件..."

# 加载环境变量
if [ -f ".env" ]; then
    # 安全地导出环境变量，只导出有效的变量名
    while IFS='=' read -r key value; do
        if [[ $key =~ ^[A-Z_][A-Z0-9_]*$ ]] && [[ ! $key =~ ^# ]]; then
            export "$key"="$value"
        fi
    done < <(grep -E '^[A-Z_][A-Z0-9_]*=' .env | grep -v '^#')
fi

# 设置默认值
export API_PORT="${PORT:-3000}"
export NGINX_PORT="${NGINX_PORT:-3080}"
export NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"

# 检测操作系统并设置数据目录
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    export DATA_DIR="${STATIC_DIR:-./data}"
    export LOG_DIR="${LOG_DIR:-./logs}"
else
    # Linux
    export DATA_DIR="${STATIC_DIR:-/var/www/subscription}"
    export LOG_DIR="${LOG_DIR:-/var/log/subscription}"
fi

# 获取项目绝对路径（用于nginx配置）
export ABSOLUTE_PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

# 检查并安装envsubst (如果需要)
if ! command -v envsubst >/dev/null 2>&1; then
    echo "🔧 安装 envsubst 工具..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            safe_sudo apt-get update && safe_sudo apt-get install -y gettext-base
        elif command -v yum >/dev/null 2>&1; then
            safe_sudo yum install -y gettext
        elif command -v dnf >/dev/null 2>&1; then
            safe_sudo dnf install -y gettext
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install gettext
            export PATH="/usr/local/opt/gettext/bin:$PATH"
        fi
    fi
fi

# 使用envsubst生成配置文件
if command -v envsubst >/dev/null 2>&1; then
    # 只替换指定的环境变量，避免nginx变量被误替换
    envsubst '${API_PORT} ${NGINX_PORT} ${NGINX_PROXY_PORT} ${DATA_DIR} ${ABSOLUTE_PROJECT_ROOT}' < config/nginx.conf.template > config/nginx.conf
    echo "✅ 使用 envsubst 重新生成 nginx.conf"
else
    # 如果没有envsubst，使用sed替换
    sed "s/\${API_PORT}/${API_PORT}/g; s/\${NGINX_PORT}/${NGINX_PORT}/g; s/\${NGINX_PROXY_PORT}/${NGINX_PROXY_PORT}/g; s|\${DATA_DIR}|${DATA_DIR}|g; s|\${ABSOLUTE_PROJECT_ROOT}|${ABSOLUTE_PROJECT_ROOT}|g" config/nginx.conf.template > config/nginx.conf
    echo "✅ 使用 sed 重新生成 nginx.conf"
fi

# 构建项目
echo "🏗️ 构建项目..."
npm run build:all

# 设置前端文件权限（Linux）
if [[ "$OSTYPE" == "linux-gnu"* ]] && [ -d "frontend/dist" ]; then
    echo "🔧 设置前端文件权限..."
    # 确保nginx用户可以访问
    NGINX_USER="www-data"
    if ! id "$NGINX_USER" >/dev/null 2>&1; then
        for user in nginx http; do
            if id "$user" >/dev/null 2>&1; then
                NGINX_USER="$user"
                break
            fi
        done
    fi
    
    # 设置适当的权限
    safe_sudo chown -R "$NGINX_USER:$NGINX_USER" frontend/dist/ 2>/dev/null || true
    safe_sudo chmod -R 755 frontend/dist/ 2>/dev/null || true
    safe_sudo find frontend/dist/ -type f -exec chmod 644 {} \; 2>/dev/null || true
    echo "   ✅ 前端文件权限设置完成"
fi

# 检查服务是否正在运行
SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"

# 检测操作系统
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux系统 - 更新nginx配置
    if command -v nginx >/dev/null 2>&1; then
        echo "🔧 更新 Nginx 配置..."
        
        # 复制配置文件到nginx目录
        safe_sudo cp config/nginx.conf /etc/nginx/sites-available/$SERVICE_NAME
        
        # 创建软链接
        if [ ! -L "/etc/nginx/sites-enabled/$SERVICE_NAME" ]; then
            safe_sudo ln -sf /etc/nginx/sites-available/$SERVICE_NAME /etc/nginx/sites-enabled/
        fi
        
        # 测试nginx配置
        if safe_sudo nginx -t; then
            echo "🔄 重新加载 Nginx 配置..."
            safe_sudo systemctl reload nginx || safe_sudo systemctl restart nginx
            echo "✅ Nginx 配置更新成功"
        else
            echo "❌ Nginx 配置测试失败"
        fi
    fi
fi

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
echo "   API更新: curl http://localhost:${NGINX_PROXY_PORT}/api/update"
echo "   Clash诊断: curl http://localhost:${NGINX_PROXY_PORT}/api/diagnose/clash"
echo "   Clash配置: curl http://localhost:${NGINX_PROXY_PORT}/clash.yaml"
echo "   Dashboard: http://localhost:${NGINX_PROXY_PORT}/dashboard/"
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
