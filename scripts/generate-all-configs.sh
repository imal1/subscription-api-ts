#!/bin/bash

# 一键生成所有配置文件
set -e

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# 读取环境变量（如果存在）
if [ -f "$PROJECT_ROOT/.env" ]; then
    # 读取 .env 文件，忽略注释和空行
    while IFS='=' read -r key value; do
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z $key ]] && continue
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        export "$key"="$value"
    done < <(grep -v '^[[:space:]]*#' "$PROJECT_ROOT/.env" | grep -v '^[[:space:]]*$')
fi

# 服务名称，可通过环境变量覆盖
SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"

echo "🔧 一键生成所有配置文件..."

# 检查参数
INSTALL_DIR="${1:-$PROJECT_ROOT}"

echo "📁 项目目录: $PROJECT_ROOT"
echo "📂 安装目录: $INSTALL_DIR"

# 1. 生成nginx配置
echo ""
echo "🌐 生成Nginx配置..."
bash scripts/generate-nginx-config.sh

# 2. 生成systemd服务配置
echo ""
echo "⚙️ 生成Systemd服务配置..."
bash scripts/generate-systemd-service.sh "$INSTALL_DIR"

echo ""
echo "✅ 所有配置文件生成完成！"
echo ""
echo "📋 生成的文件:"
echo "  - Nginx配置: config/nginx.conf 或 config/nginx.dev.conf"
echo "  - Systemd服务: /tmp/${SERVICE_NAME}.service"
echo ""
echo "🚀 下一步操作:"
echo "1. 检查并编辑 .env 文件"
echo "2. 构建项目: npm run build"
echo "3. 安装配置文件:"
echo "   # Nginx (可选)"
echo "   sudo cp config/nginx.conf /etc/nginx/sites-available/${SERVICE_NAME}"
echo "   sudo ln -sf /etc/nginx/sites-available/${SERVICE_NAME} /etc/nginx/sites-enabled/"
echo "   sudo nginx -t && sudo systemctl reload nginx"
echo ""
echo "   # Systemd服务 (Linux)"
echo "   sudo cp /tmp/${SERVICE_NAME}.service /etc/systemd/system/"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl enable ${SERVICE_NAME}"
echo "   sudo systemctl start ${SERVICE_NAME}"
