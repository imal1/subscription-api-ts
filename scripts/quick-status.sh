#!/bin/bash

# subscription-api-ts 快速状态检查脚本
# 功能：快速检查服务核心状态，用于日常监控

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 读取环境配置
if [ -f "$PROJECT_DIR/.env" ]; then
    while IFS='=' read -r key value; do
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z $key ]] && continue
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        export "$key"="$value"
    done < <(grep -v '^[[:space:]]*#' "$PROJECT_DIR/.env" | grep -v '^[[:space:]]*$')
fi

# 设置默认值
PORT="${PORT:-3000}"
SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"

# 检测操作系统
OS=""
case "$(uname -s)" in
    Linux*)     OS=Linux;;
    Darwin*)    OS=Mac;;
    *)          OS="UNKNOWN";;
esac

echo "🚀 $SERVICE_NAME 快速状态检查 [$OS]"
echo "───────────────────────────────────────"

# 检查进程状态
if [ "$OS" = "Linux" ]; then
    if systemctl is-active --quiet ${SERVICE_NAME} 2>/dev/null; then
        echo "✅ 服务状态: 运行中"
    else
        echo "❌ 服务状态: 停止"
    fi
elif [ "$OS" = "Mac" ]; then
    if pgrep -f "node.*dist/index.js" >/dev/null 2>&1; then
        echo "✅ 进程状态: 运行中"
    else
        echo "❌ 进程状态: 停止"
    fi
fi

# 检查端口
if [ "$OS" = "Linux" ]; then
    PORT_STATUS=$(netstat -tuln 2>/dev/null | grep ":${PORT} " | head -1)
elif [ "$OS" = "Mac" ]; then
    PORT_STATUS=$(lsof -i tcp:$PORT 2>/dev/null | head -2 | tail -1)
fi

if [ -n "$PORT_STATUS" ]; then
    echo "✅ 端口 $PORT: 已占用"
else
    echo "❌ 端口 $PORT: 未占用"
fi

# 检查服务响应
if curl -s --max-time 3 "http://localhost:$PORT/health" >/dev/null 2>&1; then
    echo "✅ 健康检查: 正常"
else
    echo "❌ 健康检查: 失败"
fi

# 检查编译文件
if [ -f "$PROJECT_DIR/dist/index.js" ]; then
    echo "✅ 编译文件: 存在"
else
    echo "❌ 编译文件: 缺失"
fi

echo "───────────────────────────────────────"

# 根据状态给出简单建议
if [ "$OS" = "Linux" ]; then
    if ! systemctl is-active --quiet ${SERVICE_NAME} 2>/dev/null; then
        echo "💡 启动服务: sudo systemctl start ${SERVICE_NAME}"
    fi
elif [ "$OS" = "Mac" ]; then
    if ! pgrep -f "node.*dist/index.js" >/dev/null 2>&1; then
        echo "💡 启动服务: npm start 或 pm2 start dist/index.js --name ${SERVICE_NAME}"
    fi
fi

if [ ! -f "$PROJECT_DIR/dist/index.js" ]; then
    echo "💡 编译项目: npm run build"
fi

echo "🔍 详细检查: ./scripts/check-service-status.sh"
