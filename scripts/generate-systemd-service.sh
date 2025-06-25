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

# 获取安装目录的绝对路径（在其他检查之前）
if [ ! -d "$INSTALL_DIR" ]; then
    echo "❌ 安装目录不存在: $INSTALL_DIR"
    exit 1
fi

INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd)"
echo "📁 绝对路径: $INSTALL_DIR"

# 验证安装目录的可访问性
if [ ! -r "$INSTALL_DIR" ]; then
    echo "❌ 安装目录无法读取: $INSTALL_DIR"
    echo "   请检查目录权限"
    exit 1
fi

# 检查关键文件是否存在
if [ ! -f "$INSTALL_DIR/dist/index.js" ]; then
    echo "❌ 未找到编译后的主文件: $INSTALL_DIR/dist/index.js"
    echo "   请确保项目已正确编译"
    
    # 检查是否有源文件，提示编译
    if [ -f "$INSTALL_DIR/src/index.ts" ]; then
        echo "💡 提示：检测到 TypeScript 源文件，请先编译项目:"
        echo "   cd $INSTALL_DIR"
        echo "   npm run build"
    fi
    exit 1
fi

# 验证环境文件
if [ ! -f "$INSTALL_DIR/.env" ]; then
    echo "⚠️  环境文件不存在: $INSTALL_DIR/.env"
    if [ -f "$INSTALL_DIR/.env.example" ]; then
        echo "� 提示：可以复制示例环境文件:"
        echo "   cp $INSTALL_DIR/.env.example $INSTALL_DIR/.env"
    fi
    echo "   服务可能无法正常启动"
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
if [[ "$NODE_PATH" == *"fnm"* ]] || [[ "$NODE_PATH" == *"nvm"* ]] || [[ "$NODE_PATH" == *".local"* ]] || [[ "$NODE_PATH" == *"/run/user/"* ]]; then
    echo "⚠️  检测到版本管理器路径，尝试查找或创建系统 Node.js..."
    
    # 尝试常见的系统路径
    SYSTEM_PATHS=(
        "/usr/bin/node"
        "/usr/local/bin/node"
        "/opt/node/bin/node"
    )
    
    FOUND_SYSTEM_NODE=""
    for path in "${SYSTEM_PATHS[@]}"; do
        if [ -f "$path" ] && [ -x "$path" ]; then
            FOUND_SYSTEM_NODE="$path"
            echo "✅ 找到系统 Node.js: $FOUND_SYSTEM_NODE"
            break
        fi
    done
    
    if [ -n "$FOUND_SYSTEM_NODE" ]; then
        NODE_PATH="$FOUND_SYSTEM_NODE"
    else
        echo "⚠️  未找到系统 Node.js，需要复制当前 Node.js"
        echo "   当前 Node.js 路径: $NODE_PATH"
        echo "   systemd 服务可能无法在此路径下找到 Node.js"
        
        # 询问是否自动复制
        echo ""
        read -p "是否自动复制 Node.js 到 /usr/local/bin/node? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            echo "⚠️  继续使用版本管理器路径，服务可能启动失败"
        else
            echo "📝 复制 Node.js 到系统路径..."
            TARGET_PATH="/usr/local/bin/node"
            if [[ $EUID -eq 0 ]]; then
                if cp "$NODE_PATH" "$TARGET_PATH" && chmod +x "$TARGET_PATH"; then
                    NODE_PATH="$TARGET_PATH"
                    echo "✅ Node.js 已复制到: $NODE_PATH"
                else
                    echo "❌ 复制失败，继续使用原路径"
                fi
            else
                if sudo cp "$NODE_PATH" "$TARGET_PATH" && sudo chmod +x "$TARGET_PATH"; then
                    NODE_PATH="$TARGET_PATH"
                    echo "✅ Node.js 已复制到: $NODE_PATH"
                else
                    echo "❌ 复制失败，继续使用原路径"
                fi
            fi
        fi
    fi
fi

# 最终验证 Node.js 路径
if [ ! -f "$NODE_PATH" ] || [ ! -x "$NODE_PATH" ]; then
    echo "❌ Node.js 路径无效: $NODE_PATH"
    exit 1
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
