#!/bin/bash

# 快速修复 systemd 服务启动问题
# 专门解决 WorkingDirectory 和 Node.js 路径相关的问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

SERVICE_NAME="subscription-api-ts"

# 检查是否是 Linux 系统
if [[ "$(uname)" != "Linux" ]]; then
    print_warning "此脚本仅适用于 Linux 系统"
    exit 1
fi

print_status "快速修复 systemd 服务问题..."

# 停止服务（如果正在运行）
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    print_status "停止当前服务..."
    if [[ $EUID -eq 0 ]]; then
        systemctl stop "$SERVICE_NAME"
    else
        sudo systemctl stop "$SERVICE_NAME"
    fi
fi

# 查找项目目录
PROJECT_DIRS=(
    "/opt/subscription-api-ts"
    "/opt/subscription-api"
    "/home/$(whoami)/subscription-api-ts"
    "$HOME/subscription-api-ts"
    "$(pwd)"
)

FOUND_PROJECT=""
for dir in "${PROJECT_DIRS[@]}"; do
    if [ -d "$dir" ] && [ -f "$dir/package.json" ]; then
        # 验证是否是正确的项目
        if grep -q "subscription-api-ts" "$dir/package.json" 2>/dev/null; then
            FOUND_PROJECT="$dir"
            break
        fi
    fi
done

if [ -z "$FOUND_PROJECT" ]; then
    print_error "未找到项目目录"
    exit 1
fi

WORKING_DIR="$(cd "$FOUND_PROJECT" && pwd)"
print_success "找到项目目录: $WORKING_DIR"

# 查找 Node.js 并处理 fnm 安装
print_status "查找和修复 Node.js 路径..."

# 首先检查系统路径中是否已有可用的 Node.js
SYSTEM_NODE_PATHS=(
    "/usr/bin/node"
    "/usr/local/bin/node"
    "/opt/node/bin/node"
)

FOUND_SYSTEM_NODE=""
for path in "${SYSTEM_NODE_PATHS[@]}"; do
    if [ -f "$path" ] && [ -x "$path" ]; then
        FOUND_SYSTEM_NODE="$path"
        print_success "找到系统 Node.js: $FOUND_SYSTEM_NODE"
        break
    fi
done

# 如果没有系统 Node.js，查找当前环境的 Node.js
CURRENT_NODE=""
if [ -z "$FOUND_SYSTEM_NODE" ]; then
    CURRENT_NODE=$(which node 2>/dev/null || true)
    if [ -n "$CURRENT_NODE" ] && [ -f "$CURRENT_NODE" ] && [ -x "$CURRENT_NODE" ]; then
        print_status "找到当前环境 Node.js: $CURRENT_NODE"
        
        # 检查是否是 fnm 或其他版本管理器路径
        if [[ "$CURRENT_NODE" == *"fnm"* ]] || [[ "$CURRENT_NODE" == *"nvm"* ]] || [[ "$CURRENT_NODE" == *".local"* ]] || [[ "$CURRENT_NODE" == *"/run/user/"* ]] || [[ "$CURRENT_NODE" == *"node-versions"* ]]; then
            print_warning "检测到版本管理器路径，需要复制到系统路径"
            
            # 复制到系统路径
            TARGET_PATH="/usr/local/bin/node"
            print_status "复制 Node.js 到 $TARGET_PATH..."
            
            if [[ $EUID -eq 0 ]]; then
                if cp "$CURRENT_NODE" "$TARGET_PATH" && chmod +x "$TARGET_PATH"; then
                    print_success "Node.js 已复制到系统路径"
                    
                    # 验证复制的文件
                    if [ -f "$TARGET_PATH" ] && [ -x "$TARGET_PATH" ]; then
                        NODE_VERSION=$("$TARGET_PATH" --version 2>/dev/null || echo "unknown")
                        print_success "验证成功，Node.js 版本: $NODE_VERSION"
                        FOUND_SYSTEM_NODE="$TARGET_PATH"
                    else
                        print_error "复制的 Node.js 文件无效"
                        exit 1
                    fi
                else
                    print_error "复制 Node.js 失败"
                    exit 1
                fi
            else
                if sudo cp "$CURRENT_NODE" "$TARGET_PATH" && sudo chmod +x "$TARGET_PATH"; then
                    print_success "Node.js 已复制到系统路径"
                    
                    # 验证复制的文件
                    if [ -f "$TARGET_PATH" ] && [ -x "$TARGET_PATH" ]; then
                        NODE_VERSION=$("$TARGET_PATH" --version 2>/dev/null || echo "unknown")
                        print_success "验证成功，Node.js 版本: $NODE_VERSION"
                        FOUND_SYSTEM_NODE="$TARGET_PATH"
                    else
                        print_error "复制的 Node.js 文件无效"
                        exit 1
                    fi
                else
                    print_error "复制 Node.js 失败"
                    exit 1
                fi
            fi
        else
            print_warning "Node.js 路径可能在 systemd 中不可用，建议复制到系统路径"
            FOUND_SYSTEM_NODE="$CURRENT_NODE"
        fi
    else
        print_error "未找到 Node.js，请先安装 Node.js"
        exit 1
    fi
fi

# 最终使用的 Node.js 路径
FINAL_NODE_PATH="$FOUND_SYSTEM_NODE"
print_success "将使用 Node.js: $FINAL_NODE_PATH"

# 验证 Node.js 可执行性
if ! "$FINAL_NODE_PATH" --version >/dev/null 2>&1; then
    print_error "Node.js 无法执行: $FINAL_NODE_PATH"
    exit 1
fi

# 确保项目已编译
if [ ! -f "$WORKING_DIR/dist/index.js" ]; then
    print_status "编译项目..."
    cd "$WORKING_DIR"
    if command -v npm >/dev/null; then
        npm run build
    elif command -v yarn >/dev/null; then
        yarn build
    elif command -v bun >/dev/null; then
        bun run build
    else
        print_error "未找到包管理器"
        exit 1
    fi
fi

# 确保环境文件存在
if [ ! -f "$WORKING_DIR/.env" ] && [ -f "$WORKING_DIR/.env.example" ]; then
    print_status "创建环境文件..."
    cp "$WORKING_DIR/.env.example" "$WORKING_DIR/.env"
fi

# 创建最小化的服务文件
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
TEMP_SERVICE="/tmp/$SERVICE_NAME.service"

print_status "生成服务文件..."

cat > "$TEMP_SERVICE" << EOF
[Unit]
Description=TypeScript Subscription API Service
After=network.target
Documentation=https://github.com/imal1/subscription-api-ts

[Service]
Type=simple
User=$(whoami)
Group=$(whoami)
WorkingDirectory=$WORKING_DIR
Environment=NODE_ENV=production
EnvironmentFile=$WORKING_DIR/.env
ExecStart=$FINAL_NODE_PATH $WORKING_DIR/dist/index.js
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
SyslogIdentifier=subscription-api-ts

[Install]
WantedBy=multi-user.target
EOF

# 安装服务文件
print_status "安装服务文件..."
if [[ $EUID -eq 0 ]]; then
    cp "$TEMP_SERVICE" "$SERVICE_FILE"
    systemctl daemon-reload
else
    sudo cp "$TEMP_SERVICE" "$SERVICE_FILE"
    sudo systemctl daemon-reload
fi

# 启动服务
print_status "启动服务..."
if [[ $EUID -eq 0 ]]; then
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
else
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl start "$SERVICE_NAME"
fi

# 等待服务启动
sleep 3

# 检查状态
if systemctl is-active --quiet "$SERVICE_NAME"; then
    print_success "服务启动成功！"
    print_status "服务状态:"
    systemctl status "$SERVICE_NAME" --no-pager --lines=5
else
    print_error "服务启动失败"
    print_status "错误日志:"
    journalctl -u "$SERVICE_NAME" --no-pager --lines=10
fi

# 清理
rm -f "$TEMP_SERVICE"

print_success "快速修复完成"
