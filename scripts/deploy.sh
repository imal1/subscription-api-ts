#!/bin/bash

# 部署脚本
set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 引入公共函数库
source "$SCRIPT_DIR/common.sh"

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
if ! safe_sudo systemctl is-active --quiet subconverter; then
    echo "启动 subconverter..."
    safe_sudo systemctl start subconverter
fi

# 构建项目
echo "🏗️ 构建项目..."
# 检测 bun 路径
if command -v bun >/dev/null 2>&1; then
    BUN_CMD="bun"
elif [ -f "$HOME/.local/bin/bun" ]; then
    BUN_CMD="$HOME/.local/bin/bun"
elif [ -f "/usr/local/bin/bun" ]; then
    BUN_CMD="/usr/local/bin/bun"
else
    echo "❌ 未找到 bun，请先运行 bash scripts/install.sh"
    exit 1
fi
"$BUN_CMD" run build

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