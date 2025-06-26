#!/bin/bash

# 部署脚本
set -e

echo "🚀 开始部署 Subscription API..."

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
if ! safe_sudo systemctl is-active --quiet subconverter; then
    echo "启动 subconverter..."
    safe_sudo systemctl start subconverter
fi

# 构建项目
echo "🏗️ 构建项目..."
npm run build

# 重启服务
echo "🔄 重启服务..."
safe_sudo systemctl restart "$SERVICE_NAME"

# 等待服务启动
sleep 3

# 检查服务状态
if safe_sudo systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "✅ 服务部署成功！"
    echo "📊 服务状态: $(safe_sudo systemctl is-active "$SERVICE_NAME")"
    # 从环境变量读取端口号
    PORT="${PORT:-3000}"
    echo "🌐 访问地址: http://localhost:${PORT}"
else
    echo "❌ 服务启动失败"
    safe_sudo systemctl status "$SERVICE_NAME"
    exit 1
fi