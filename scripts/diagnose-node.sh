#!/bin/bash

# 快速诊断 Node.js 和 systemd 服务问题
# 特别针对 fnm 用户

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_header() { echo -e "${PURPLE}📋 $1${NC}"; }
print_status() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

SERVICE_NAME="subscription-api-ts"

print_header "Node.js 和 systemd 服务诊断"
echo

print_status "检查操作系统..."
OS=$(uname -s)
if [ "$OS" = "Linux" ]; then
    print_success "Linux 系统"
else
    print_warning "非 Linux 系统 ($OS)，systemd 诊断将跳过"
fi

echo
print_status "检查 Node.js 安装..."

# 检查 Node.js
if command -v node >/dev/null 2>&1; then
    NODE_PATH=$(which node)
    NODE_VERSION=$(node --version)
    print_success "Node.js 已安装: $NODE_VERSION"
    print_status "Node.js 路径: $NODE_PATH"
    
    # 检查是否是版本管理器路径
    if [[ "$NODE_PATH" == *"fnm"* ]]; then
        print_warning "检测到 fnm 管理的 Node.js"
        print_status "fnm 路径在 systemd 中可能不可用"
        
        # 检查 fnm 信息
        if command -v fnm >/dev/null 2>&1; then
            FNM_VERSION=$(fnm --version 2>/dev/null || echo "unknown")
            print_status "fnm 版本: $FNM_VERSION"
        fi
        
        echo "  💡 建议: 使用 fix-fnm-systemd.sh 脚本修复"
    elif [[ "$NODE_PATH" == *"nvm"* ]]; then
        print_warning "检测到 nvm 管理的 Node.js"
        print_status "nvm 路径在 systemd 中可能不可用"
        echo "  💡 建议: 将 Node.js 复制到系统路径"
    elif [[ "$NODE_PATH" == *".local"* ]] || [[ "$NODE_PATH" == *"/run/user/"* ]]; then
        print_warning "检测到用户环境路径"
        print_status "此路径在 systemd 中可能不可用"
    else
        print_success "Node.js 路径适合 systemd"
    fi
else
    print_error "Node.js 未安装或不在 PATH 中"
fi

# 检查系统路径中的 Node.js
echo
print_status "检查系统路径中的 Node.js..."

SYSTEM_PATHS=(
    "/usr/bin/node"
    "/usr/local/bin/node"
    "/opt/node/bin/node"
)

FOUND_SYSTEM=false
for path in "${SYSTEM_PATHS[@]}"; do
    if [ -f "$path" ] && [ -x "$path" ]; then
        VERSION=$("$path" --version 2>/dev/null || echo "unknown")
        print_success "找到系统 Node.js: $path (版本: $VERSION)"
        FOUND_SYSTEM=true
    fi
done

if [ "$FOUND_SYSTEM" = false ]; then
    print_warning "系统路径中未找到 Node.js"
    print_status "systemd 服务可能无法启动"
fi

# 如果是 Linux，检查 systemd 服务
if [ "$OS" = "Linux" ] && command -v systemctl >/dev/null 2>&1; then
    echo
    print_status "检查 systemd 服务..."
    
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
    if [ -f "$SERVICE_FILE" ]; then
        print_success "服务文件存在: $SERVICE_FILE"
        
        # 检查服务状态
        if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
            print_success "服务已启用"
        else
            print_warning "服务未启用"
        fi
        
        if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
            print_success "服务正在运行"
        else
            print_warning "服务未运行"
            
            # 获取最后几行日志
            print_status "最近的错误日志:"
            journalctl -u "$SERVICE_NAME" --no-pager --lines=3 2>/dev/null || echo "  无法获取日志"
        fi
        
        # 检查服务文件中的路径
        echo
        print_status "分析服务配置..."
        
        WORKING_DIR=$(grep "^WorkingDirectory=" "$SERVICE_FILE" 2>/dev/null | cut -d'=' -f2 || echo "")
        EXEC_START=$(grep "^ExecStart=" "$SERVICE_FILE" 2>/dev/null | cut -d'=' -f2- || echo "")
        
        if [ -n "$WORKING_DIR" ]; then
            if [ -d "$WORKING_DIR" ]; then
                print_success "工作目录存在: $WORKING_DIR"
                
                # 检查关键文件
                if [ -f "$WORKING_DIR/dist/index.js" ]; then
                    print_success "主文件存在: $WORKING_DIR/dist/index.js"
                else
                    print_warning "主文件缺失: $WORKING_DIR/dist/index.js"
                fi
                
                if [ -f "$WORKING_DIR/.env" ]; then
                    print_success "环境文件存在"
                else
                    print_warning "环境文件缺失: $WORKING_DIR/.env"
                fi
            else
                print_error "工作目录不存在: $WORKING_DIR"
            fi
        fi
        
        if [ -n "$EXEC_START" ]; then
            NODE_IN_SERVICE=$(echo "$EXEC_START" | awk '{print $1}')
            if [ -f "$NODE_IN_SERVICE" ] && [ -x "$NODE_IN_SERVICE" ]; then
                print_success "服务中的 Node.js 路径有效: $NODE_IN_SERVICE"
            else
                print_error "服务中的 Node.js 路径无效: $NODE_IN_SERVICE"
            fi
        fi
    else
        print_warning "服务文件不存在: $SERVICE_FILE"
    fi
fi

echo
print_header "诊断总结和建议"

# 生成建议
if command -v node >/dev/null 2>&1; then
    NODE_PATH=$(which node)
    if [[ "$NODE_PATH" == *"fnm"* ]]; then
        echo
        print_warning "主要问题: fnm 管理的 Node.js 路径"
        echo "🔧 推荐解决方案:"
        echo "   1. 使用专用修复脚本: bash scripts/fix-fnm-systemd.sh"
        echo "   2. 或使用管理工具: ./manage.sh fix-fnm"
        echo "   3. 手动复制: sudo cp \$(which node) /usr/local/bin/node"
    elif [ "$FOUND_SYSTEM" = false ]; then
        echo
        print_warning "主要问题: 系统路径中无 Node.js"
        echo "🔧 推荐解决方案:"
        echo "   1. 复制到系统路径: sudo cp \$(which node) /usr/local/bin/node"
        echo "   2. 使用通用修复: ./manage.sh fix-systemd-workdir"
    else
        print_success "Node.js 配置看起来正常"
    fi
fi

if [ "$OS" = "Linux" ] && [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
    if ! systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo
        print_status "服务管理命令:"
        echo "   启动服务: sudo systemctl start $SERVICE_NAME"
        echo "   查看状态: sudo systemctl status $SERVICE_NAME"
        echo "   查看日志: sudo journalctl -u $SERVICE_NAME -f"
        echo "   重新生成: bash scripts/generate-systemd-service.sh \$(pwd)"
    fi
fi

echo
print_header "诊断完成"
