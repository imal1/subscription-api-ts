#!/bin/bash

# Node.js 系统路径修复脚本
# 解决 systemd 服务中 Node.js 路径问题

echo "🔧 修复 Node.js systemd 服务路径问题..."

# 检查当前 Node.js 路径
CURRENT_NODE=$(which node)
if [ -z "$CURRENT_NODE" ]; then
    echo "❌ 未找到 Node.js"
    exit 1
fi

echo "📍 当前 Node.js 路径: $CURRENT_NODE"

# 检查是否已有系统路径的 Node.js
SYSTEM_PATHS=(
    "/usr/bin/node"
    "/usr/local/bin/node"
)

SYSTEM_NODE=""
for path in "${SYSTEM_PATHS[@]}"; do
    if [ -f "$path" ] && [ -x "$path" ]; then
        SYSTEM_NODE="$path"
        echo "✅ 找到系统 Node.js: $SYSTEM_NODE"
        break
    fi
done

# 如果没有系统路径的 Node.js，复制当前的到系统路径
if [ -z "$SYSTEM_NODE" ]; then
    echo "📦 将 Node.js 复制到系统路径..."
    
    # 检查权限
    if [[ $EUID -eq 0 ]]; then
        cp "$CURRENT_NODE" /usr/local/bin/node
        chmod +x /usr/local/bin/node
        SYSTEM_NODE="/usr/local/bin/node"
    else
        sudo cp "$CURRENT_NODE" /usr/local/bin/node
        sudo chmod +x /usr/local/bin/node
        SYSTEM_NODE="/usr/local/bin/node"
    fi
    
    echo "✅ Node.js 已复制到: $SYSTEM_NODE"
fi

# 重新生成 systemd 服务文件
echo "🔄 重新生成 systemd 服务文件..."
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 临时设置 NODE_PATH 环境变量
export NODE_PATH="$SYSTEM_NODE"

# 重新生成服务文件
bash "$PROJECT_ROOT/scripts/generate-systemd-service.sh" "$PROJECT_ROOT"

SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"

echo ""
echo "🚀 现在可以安装和启动服务:"
if [[ $EUID -eq 0 ]]; then
    echo "  cp /tmp/${SERVICE_NAME}.service /etc/systemd/system/"
    echo "  systemctl daemon-reload"
    echo "  systemctl enable $SERVICE_NAME"
    echo "  systemctl start $SERVICE_NAME"
    echo "  systemctl status $SERVICE_NAME"
else
    echo "  sudo cp /tmp/${SERVICE_NAME}.service /etc/systemd/system/"
    echo "  sudo systemctl daemon-reload"
    echo "  sudo systemctl enable $SERVICE_NAME"
    echo "  sudo systemctl start $SERVICE_NAME"
    echo "  sudo systemctl status $SERVICE_NAME"
fi
