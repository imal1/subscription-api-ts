#!/bin/bash

# 生成systemd服务配置文件
set -e

# 获取当前项目路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 检查参数
if [ $# -ne 1 ]; then
    echo "用法: $0 <安装目录>"
    echo "示例: $0 /opt/subscription-api-ts"
    echo "      $0 $PROJECT_ROOT"
    exit 1
fi

INSTALL_DIR="$1"
SERVICE_USER="${SERVICE_USER:-$(whoami)}"
SERVICE_GROUP="${SERVICE_GROUP:-$SERVICE_USER}"

echo "🔧 生成systemd服务配置..."
echo "📁 安装目录: $INSTALL_DIR"
echo "👤 运行用户: $SERVICE_USER"
echo "👥 运行组: $SERVICE_GROUP"

# 检查安装目录是否存在
if [ ! -d "$INSTALL_DIR" ]; then
    echo "❌ 安装目录不存在: $INSTALL_DIR"
    exit 1
fi

# 检查是否有node可执行文件路径
NODE_PATH=$(which node)
if [ -z "$NODE_PATH" ]; then
    echo "❌ 未找到 node 可执行文件"
    exit 1
fi

# 如果使用了版本管理器，尝试使用系统路径
echo "🔍 检测到的 Node.js 路径: $NODE_PATH"

# 检查是否使用了版本管理器（fnm, nvm等）
if [[ "$NODE_PATH" == *"fnm"* ]] || [[ "$NODE_PATH" == *"nvm"* ]] || [[ "$NODE_PATH" == *"/run/user/"* ]]; then
    echo "⚠️  检测到版本管理器路径，尝试查找系统 Node.js..."
    
    # 尝试常见的系统路径
    SYSTEM_PATHS=(
        "/usr/bin/node"
        "/usr/local/bin/node"
        "/opt/node/bin/node"
    )
    
    for path in "${SYSTEM_PATHS[@]}"; do
        if [ -f "$path" ] && [ -x "$path" ]; then
            NODE_PATH="$path"
            echo "✅ 使用系统 Node.js 路径: $NODE_PATH"
            break
        fi
    done
    
    # 如果还是版本管理器路径，尝试复制到系统路径
    if [[ "$NODE_PATH" == *"fnm"* ]] || [[ "$NODE_PATH" == *"nvm"* ]] || [[ "$NODE_PATH" == *"/run/user/"* ]]; then
        echo "⚠️  仍然是版本管理器路径，建议安装系统级 Node.js"
        echo "   或者将当前 node 复制到系统路径："
        echo "   sudo cp $(which node) /usr/local/bin/node"
        echo "   继续使用当前路径，但可能在 systemd 中失败"
    fi
fi

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

echo "🔍 Node.js 路径: $NODE_PATH"

# 生成服务文件
SERVICE_TEMPLATE="$PROJECT_ROOT/config/subscription-api-ts.service.template"
SERVICE_OUTPUT="/tmp/${SERVICE_NAME}.service"

if [ ! -f "$SERVICE_TEMPLATE" ]; then
    echo "❌ 服务模板文件不存在: $SERVICE_TEMPLATE"
    exit 1
fi

# 导出环境变量供envsubst使用
export SERVICE_USER SERVICE_GROUP INSTALL_DIR NODE_PATH

# 生成服务文件
envsubst '${SERVICE_USER} ${SERVICE_GROUP} ${INSTALL_DIR} ${NODE_PATH}' < "$SERVICE_TEMPLATE" > "$SERVICE_OUTPUT"

echo "✅ 服务文件已生成: $SERVICE_OUTPUT"
echo ""
echo "📋 生成的服务配置:"
echo "----------------------------------------"
cat "$SERVICE_OUTPUT"
echo "----------------------------------------"
echo ""
echo "🚀 安装命令:"
echo "sudo cp $SERVICE_OUTPUT /etc/systemd/system/"
echo "sudo systemctl daemon-reload"
echo "sudo systemctl enable $SERVICE_NAME"
echo "sudo systemctl start $SERVICE_NAME"
