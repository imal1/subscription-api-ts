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

echo "🔍 Node.js 路径: $NODE_PATH"

# 生成服务文件
SERVICE_TEMPLATE="$PROJECT_ROOT/config/subscription-api-ts.service.template"
SERVICE_OUTPUT="/tmp/subscription-api-ts.service"

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
echo "sudo systemctl enable subscription-api-ts"
echo "sudo systemctl start subscription-api-ts"
