#!/bin/bash

# 修复 systemd 工作目录和 Node.js 路径问题
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 输出函数
print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 获取当前项目路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVICE_NAME="subscription-api-ts"

print_status "修复 systemd 工作目录和 Node.js 路径问题"
echo

# 检查是否是 Linux 系统
if [[ "$(uname)" != "Linux" ]]; then
    print_warning "此脚本仅适用于 Linux 系统"
    exit 1
fi

# 检查是否有 systemd
if ! command -v systemctl >/dev/null 2>&1; then
    print_error "系统不支持 systemd"
    exit 1
fi

# 查找服务文件
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
if [ ! -f "$SERVICE_FILE" ]; then
    print_error "服务文件不存在: $SERVICE_FILE"
    print_status "请先运行安装脚本生成服务文件"
    exit 1
fi

print_status "找到服务文件: $SERVICE_FILE"

# 读取服务文件中的 WorkingDirectory
WORKING_DIR=$(grep "^WorkingDirectory=" "$SERVICE_FILE" | cut -d'=' -f2)
NODE_PATH=$(grep "^ExecStart=" "$SERVICE_FILE" | cut -d'=' -f2 | awk '{print $1}')

print_status "当前配置:"
echo "  WorkingDirectory: $WORKING_DIR"
echo "  Node.js 路径: $NODE_PATH"
echo

# 检查工作目录
if [ -z "$WORKING_DIR" ]; then
    print_error "服务文件中未找到 WorkingDirectory"
    exit 1
fi

if [ ! -d "$WORKING_DIR" ]; then
    print_error "工作目录不存在: $WORKING_DIR"
    
    # 尝试找到正确的项目目录
    print_status "尝试查找正确的项目目录..."
    
    POSSIBLE_DIRS=(
        "/opt/subscription-api-ts"
        "/opt/subscription-api"
        "/home/$(whoami)/subscription-api-ts"
        "$HOME/subscription-api-ts"
        "$PROJECT_ROOT"
    )
    
    FOUND_DIR=""
    for dir in "${POSSIBLE_DIRS[@]}"; do
        if [ -d "$dir" ] && [ -f "$dir/package.json" ]; then
            FOUND_DIR="$dir"
            print_success "找到项目目录: $FOUND_DIR"
            break
        fi
    done
    
    if [ -z "$FOUND_DIR" ]; then
        print_error "未找到有效的项目目录"
        print_status "请手动创建或指定正确的项目目录"
        exit 1
    fi
    
    # 更新工作目录
    WORKING_DIR="$FOUND_DIR"
fi

# 检查 Node.js 路径
if [ ! -f "$NODE_PATH" ] || [ ! -x "$NODE_PATH" ]; then
    print_error "Node.js 路径无效: $NODE_PATH"
    
    # 查找有效的 Node.js 路径
    print_status "查找有效的 Node.js 路径..."
    
    # 优先检查系统路径
    SYSTEM_NODE_PATHS=(
        "/usr/bin/node"
        "/usr/local/bin/node"
        "/opt/node/bin/node"
    )
    
    FOUND_NODE=""
    for path in "${SYSTEM_NODE_PATHS[@]}"; do
        if [ -f "$path" ] && [ -x "$path" ]; then
            FOUND_NODE="$path"
            print_success "找到系统 Node.js: $FOUND_NODE"
            break
        fi
    done
    
    # 如果没有系统 Node.js，处理当前环境的 Node.js
    if [ -z "$FOUND_NODE" ]; then
        CURRENT_NODE=$(which node 2>/dev/null || true)
        if [ -n "$CURRENT_NODE" ] && [ -f "$CURRENT_NODE" ]; then
            print_status "找到当前环境 Node.js: $CURRENT_NODE"
            
            # 检查是否是用户环境路径
            if [[ "$CURRENT_NODE" == *".local"* ]] || [[ "$CURRENT_NODE" == *"/run/user/"* ]]; then
                print_status "检测到用户环境路径，复制到系统路径..."
                TARGET_PATH="/usr/local/bin/node"
                
                if [[ $EUID -eq 0 ]]; then
                    cp "$CURRENT_NODE" "$TARGET_PATH"
                    chmod +x "$TARGET_PATH"
                else
                    sudo cp "$CURRENT_NODE" "$TARGET_PATH"
                    sudo chmod +x "$TARGET_PATH"
                fi
                
                if [ -f "$TARGET_PATH" ] && [ -x "$TARGET_PATH" ]; then
                    FOUND_NODE="$TARGET_PATH"
                    print_success "Node.js 已复制到: $FOUND_NODE"
                else
                    print_error "复制失败"
                    exit 1
                fi
            else
                FOUND_NODE="$CURRENT_NODE"
            fi
        else
            print_error "未找到有效的 Node.js 安装"
            exit 1
        fi
    fi
    
    NODE_PATH="$FOUND_NODE"
fi

# 验证关键文件
MAIN_FILE="$WORKING_DIR/dist/index.js"
if [ ! -f "$MAIN_FILE" ]; then
    print_error "主文件不存在: $MAIN_FILE"
    
    # 检查是否需要编译
    if [ -f "$WORKING_DIR/src/index.ts" ]; then
        print_status "尝试编译 TypeScript..."
        cd "$WORKING_DIR"
        
        if command -v npm >/dev/null 2>&1; then
            npm run build
        elif command -v yarn >/dev/null 2>&1; then
            yarn build
        elif command -v bun >/dev/null 2>&1; then
            bun run build
        else
            print_error "未找到包管理器进行编译"
            exit 1
        fi
        
        if [ -f "$MAIN_FILE" ]; then
            print_success "编译完成"
        else
            print_error "编译失败"
            exit 1
        fi
    else
        print_error "源文件也不存在，请检查项目结构"
        exit 1
    fi
fi

# 检查环境文件
ENV_FILE="$WORKING_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    print_warning "环境文件不存在: $ENV_FILE"
    
    if [ -f "$WORKING_DIR/.env.example" ]; then
        print_status "复制示例环境文件..."
        cp "$WORKING_DIR/.env.example" "$ENV_FILE"
        print_success "已创建环境文件"
    else
        print_warning "请创建 .env 文件"
    fi
fi

# 重新生成服务文件
print_status "重新生成服务文件..."

# 获取绝对路径
WORKING_DIR="$(cd "$WORKING_DIR" && pwd)"
SERVICE_USER="${SERVICE_USER:-$(whoami)}"
SERVICE_GROUP="${SERVICE_GROUP:-$SERVICE_USER}"

# 创建临时服务文件
TEMP_SERVICE="/tmp/${SERVICE_NAME}.service.fixed"

cat > "$TEMP_SERVICE" << EOF
[Unit]
Description=TypeScript Subscription API Service
After=network.target subconverter.service
Requires=subconverter.service
Documentation=https://github.com/imal1/subscription-api-ts

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
WorkingDirectory=$WORKING_DIR
Environment=NODE_ENV=production
Environment=PATH=/usr/bin:/usr/local/bin:/opt/node/bin:$WORKING_DIR/node_modules/.bin
EnvironmentFile=$WORKING_DIR/.env
ExecStart=$NODE_PATH $WORKING_DIR/dist/index.js
ExecReload=/bin/kill -s HUP \$MAINPID
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
ProtectSystem=strict
ProtectHome=yes

[Install]
WantedBy=multi-user.target
EOF

print_success "新的服务文件已生成"
echo
print_status "新配置内容:"
echo "----------------------------------------"
cat "$TEMP_SERVICE"
echo "----------------------------------------"
echo

# 询问是否应用修复
echo
read -p "是否应用修复并重启服务? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "停止服务..."
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        if [[ $EUID -eq 0 ]]; then
            systemctl stop "$SERVICE_NAME"
        else
            sudo systemctl stop "$SERVICE_NAME"
        fi
        print_success "服务已停止"
    fi
    
    print_status "安装新的服务文件..."
    if [[ $EUID -eq 0 ]]; then
        cp "$TEMP_SERVICE" "$SERVICE_FILE"
        systemctl daemon-reload
    else
        sudo cp "$TEMP_SERVICE" "$SERVICE_FILE"
        sudo systemctl daemon-reload
    fi
    print_success "服务文件已更新"
    
    print_status "启动服务..."
    if [[ $EUID -eq 0 ]]; then
        systemctl start "$SERVICE_NAME"
    else
        sudo systemctl start "$SERVICE_NAME"
    fi
    
    # 检查服务状态
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "服务启动成功！"
        
        print_status "服务状态:"
        systemctl status "$SERVICE_NAME" --no-pager --lines=10
    else
        print_error "服务启动失败"
        print_status "查看错误日志:"
        journalctl -u "$SERVICE_NAME" --no-pager --lines=20
    fi
else
    print_status "修复已准备好，但未应用"
    print_status "手动应用命令:"
    echo "  sudo cp $TEMP_SERVICE $SERVICE_FILE"
    echo "  sudo systemctl daemon-reload"
    echo "  sudo systemctl restart $SERVICE_NAME"
fi

# 清理临时文件
rm -f "$TEMP_SERVICE"

print_success "修复脚本执行完成"
