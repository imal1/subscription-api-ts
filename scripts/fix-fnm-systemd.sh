#!/bin/bash

# 专门为 fnm 用户修复 systemd 服务的脚本
# 解决 Node.js 路径问题和工作目录问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_header() { echo -e "${PURPLE}🚀 $1${NC}"; }
print_status() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

SERVICE_NAME="subscription-api-ts"

print_header "FNM 用户专用 systemd 服务修复工具"
echo

# 检查是否是 Linux 系统
if [[ "$(uname)" != "Linux" ]]; then
    print_error "此脚本仅适用于 Linux 系统"
    exit 1
fi

# 检查是否有 systemd
if ! command -v systemctl >/dev/null 2>&1; then
    print_error "系统不支持 systemd"
    exit 1
fi

# 检查是否安装了 fnm
FNM_DETECTED=false
if command -v fnm >/dev/null 2>&1; then
    print_success "检测到 fnm"
    FNM_DETECTED=true
elif [ -d "$HOME/.local/share/fnm" ] || [ -d "$HOME/.fnm" ]; then
    print_success "检测到 fnm 安装目录"
    FNM_DETECTED=true
fi

if [ "$FNM_DETECTED" = false ]; then
    print_warning "未检测到 fnm，但脚本仍会尝试修复 Node.js 路径问题"
fi

print_status "第1步：停止现有服务"
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    sudo systemctl stop "$SERVICE_NAME"
    print_success "服务已停止"
else
    print_status "服务未运行"
fi

print_status "第2步：查找项目目录"
PROJECT_CANDIDATES=(
    "/opt/subscription-api-ts"
    "/opt/subscription-api"
    "/home/$(whoami)/subscription-api-ts"
    "$HOME/subscription-api-ts"
    "$(pwd)"
)

WORKING_DIR=""
for dir in "${PROJECT_CANDIDATES[@]}"; do
    if [ -d "$dir" ] && [ -f "$dir/package.json" ]; then
        if grep -q "subscription-api-ts\|subscription-api" "$dir/package.json" 2>/dev/null; then
            WORKING_DIR="$(cd "$dir" && pwd)"
            break
        fi
    fi
done

if [ -z "$WORKING_DIR" ]; then
    print_error "未找到项目目录"
    print_status "请确保在项目目录中运行此脚本，或项目已安装到 /opt/subscription-api-ts"
    exit 1
fi

print_success "找到项目目录: $WORKING_DIR"

print_status "第3步：处理 Node.js 路径"

# 获取当前环境的 Node.js
CURRENT_NODE=$(which node 2>/dev/null || true)
if [ -z "$CURRENT_NODE" ]; then
    print_error "未找到 Node.js，请确保 fnm 已正确配置"
    exit 1
fi

print_status "当前 Node.js 路径: $CURRENT_NODE"

# 检查是否是 fnm 路径
if [[ "$CURRENT_NODE" == *"fnm"* ]] || [[ "$CURRENT_NODE" == *".local/share/fnm"* ]]; then
    print_warning "检测到 fnm 管理的 Node.js，systemd 服务无法直接使用此路径"
    
    # 检查系统路径中是否已有 Node.js
    SYSTEM_NODE="/usr/local/bin/node"
    if [ -f "$SYSTEM_NODE" ] && [ -x "$SYSTEM_NODE" ]; then
        print_status "系统路径已有 Node.js: $SYSTEM_NODE"
        
        # 检查版本是否匹配
        CURRENT_VERSION=$("$CURRENT_NODE" --version 2>/dev/null || echo "unknown")
        SYSTEM_VERSION=$("$SYSTEM_NODE" --version 2>/dev/null || echo "unknown")
        
        print_status "当前版本: $CURRENT_VERSION"
        print_status "系统版本: $SYSTEM_VERSION"
        
        if [ "$CURRENT_VERSION" != "$SYSTEM_VERSION" ]; then
            print_warning "版本不匹配，将更新系统 Node.js"
            sudo cp "$CURRENT_NODE" "$SYSTEM_NODE"
            sudo chmod +x "$SYSTEM_NODE"
            print_success "已更新系统 Node.js 到版本: $CURRENT_VERSION"
        else
            print_success "版本匹配，无需更新"
        fi
    else
        print_status "复制 Node.js 到系统路径..."
        sudo cp "$CURRENT_NODE" "$SYSTEM_NODE"
        sudo chmod +x "$SYSTEM_NODE"
        
        if [ -f "$SYSTEM_NODE" ] && [ -x "$SYSTEM_NODE" ]; then
            VERSION=$("$SYSTEM_NODE" --version)
            print_success "Node.js 已复制到系统路径: $SYSTEM_NODE (版本: $VERSION)"
        else
            print_error "复制失败"
            exit 1
        fi
    fi
    
    FINAL_NODE_PATH="$SYSTEM_NODE"
else
    print_success "Node.js 路径可用于 systemd"
    FINAL_NODE_PATH="$CURRENT_NODE"
fi

print_status "第4步：验证项目编译"
MAIN_FILE="$WORKING_DIR/dist/index.js"
if [ ! -f "$MAIN_FILE" ]; then
    print_warning "项目未编译，开始编译..."
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
    
    if [ -f "$MAIN_FILE" ]; then
        print_success "项目编译完成"
    else
        print_error "编译失败"
        exit 1
    fi
else
    print_success "项目已编译"
fi

print_status "第5步：检查环境文件"
ENV_FILE="$WORKING_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$WORKING_DIR/.env.example" ]; then
        print_status "创建环境文件..."
        cp "$WORKING_DIR/.env.example" "$ENV_FILE"
        print_success "已创建 .env 文件"
    else
        print_warning "缺少环境文件，服务可能无法正常启动"
    fi
else
    print_success "环境文件存在"
fi

print_status "第6步：生成 systemd 服务文件"

# 确定服务用户
SERVICE_USER=$(whoami)
if [ "$SERVICE_USER" = "root" ]; then
    print_warning "当前用户是 root，建议使用普通用户运行服务"
    SERVICE_USER="www-data"  # 或其他合适的系统用户
fi

SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
TEMP_SERVICE="/tmp/$SERVICE_NAME.service"

cat > "$TEMP_SERVICE" << EOF
[Unit]
Description=TypeScript Subscription API Service (fnm-fixed)
After=network.target
Documentation=https://github.com/imal1/subscription-api-ts

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$WORKING_DIR
Environment=NODE_ENV=production
Environment=PATH=/usr/local/bin:/usr/bin:/bin
EnvironmentFile=-$WORKING_DIR/.env
ExecStart=$FINAL_NODE_PATH $WORKING_DIR/dist/index.js
Restart=always
RestartSec=3
StartLimitInterval=60s
StartLimitBurst=3
StandardOutput=journal
StandardError=journal
SyslogIdentifier=subscription-api-ts

# 安全设置
NoNewPrivileges=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF

print_status "第7步：安装并启动服务"
sudo cp "$TEMP_SERVICE" "$SERVICE_FILE"
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"

print_status "启动服务..."
sudo systemctl start "$SERVICE_NAME"

# 等待服务启动
sleep 3

print_status "第8步：验证服务状态"
if systemctl is-active --quiet "$SERVICE_NAME"; then
    print_success "🎉 服务启动成功！"
    echo
    print_status "服务信息:"
    systemctl status "$SERVICE_NAME" --no-pager --lines=8
    
    echo
    print_status "服务配置总结:"
    echo "  服务名称: $SERVICE_NAME"
    echo "  工作目录: $WORKING_DIR"
    echo "  Node.js 路径: $FINAL_NODE_PATH"
    echo "  服务用户: $SERVICE_USER"
    echo "  配置文件: $SERVICE_FILE"
    
    echo
    print_success "常用管理命令:"
    echo "  查看状态: sudo systemctl status $SERVICE_NAME"
    echo "  查看日志: sudo journalctl -u $SERVICE_NAME -f"
    echo "  重启服务: sudo systemctl restart $SERVICE_NAME"
    echo "  停止服务: sudo systemctl stop $SERVICE_NAME"
else
    print_error "❌ 服务启动失败"
    echo
    print_status "错误日志:"
    journalctl -u "$SERVICE_NAME" --no-pager --lines=15
    
    echo
    print_status "排查建议:"
    echo "  1. 检查工作目录权限: ls -la $WORKING_DIR"
    echo "  2. 检查 Node.js 路径: $FINAL_NODE_PATH --version"
    echo "  3. 手动运行服务: cd $WORKING_DIR && $FINAL_NODE_PATH dist/index.js"
    echo "  4. 查看完整日志: sudo journalctl -u $SERVICE_NAME"
fi

# 清理临时文件
rm -f "$TEMP_SERVICE"

echo
print_header "修复完成"
