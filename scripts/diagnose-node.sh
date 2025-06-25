#!/bin/bash

# 快速诊断 Node.js 和 systemd 服务问题

set -e

# 获取脚本目录并加载工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

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

# 使用工具函数进行诊断
diagnose_node_environment

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
    if is_user_env_path "$NODE_PATH"; then
        echo
        print_warning "主要问题: 用户环境路径"
        echo "🔧 推荐解决方案:"
        echo "   1. 使用通用修复: ./manage.sh fix-systemd-workdir"
        echo "   2. 手动复制: sudo cp \$(which node) /usr/local/bin/node"
    elif ! find_system_node >/dev/null 2>&1; then
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
