#!/bin/bash

# 快速检查 fnm 相关问题
# 用于快速识别和提供解决方案

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

print_header() { echo -e "${PURPLE}🔍 $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

print_header "FNM 问题快速检查"
echo

# 检查是否是 Linux 系统
if [[ "$(uname)" != "Linux" ]]; then
    print_warning "此检查主要针对 Linux systemd 环境"
    print_info "当前系统: $(uname)"
    echo
fi

# 检查 Node.js 是否安装
if ! command -v node >/dev/null 2>&1; then
    print_error "Node.js 未安装或不在 PATH 中"
    echo "请先安装 Node.js:"
    echo "  - 使用 fnm: fnm install --lts && fnm use --lts"
    echo "  - 或访问: https://nodejs.org/"
    exit 1
fi

NODE_PATH=$(which node)
NODE_VERSION=$(node --version)

print_success "Node.js 已安装: $NODE_VERSION"
print_info "路径: $NODE_PATH"
echo

# 检查是否是 fnm 安装
IS_FNM=false
if is_fnm_installed; then
    print_success "检测到 fnm"
    IS_FNM=true
    
    if command -v fnm >/dev/null 2>&1; then
        FNM_VERSION=$(fnm --version 2>/dev/null || echo "unknown")
        print_info "fnm 版本: $FNM_VERSION"
    fi
else
    print_info "未检测到 fnm"
fi

echo

# 检查 Node.js 路径是否适合 systemd
if is_version_manager_path "$NODE_PATH"; then
    print_warning "检测到版本管理器路径"
    print_error "此路径不适合 systemd 服务使用"
    
    if [[ "$NODE_PATH" == *"fnm"* ]]; then
        print_info "确认为 fnm 管理的 Node.js"
        echo
        echo "🔧 解决方案:"
        echo "  1. 【推荐】使用专用修复脚本:"
        echo "     bash scripts/fix-fnm-systemd.sh"
        echo
        echo "  2. 使用管理工具:"
        echo "     ./manage.sh fix-fnm"
        echo
        echo "  3. 手动复制到系统路径:"
        echo "     sudo cp \$(which node) /usr/local/bin/node"
        echo "     sudo chmod +x /usr/local/bin/node"
    else
        print_info "检测到其他版本管理器 (nvm 等)"
        echo
        echo "🔧 解决方案:"
        echo "  1. 复制到系统路径:"
        echo "     sudo cp \$(which node) /usr/local/bin/node"
        echo
        echo "  2. 使用通用修复:"
        echo "     ./manage.sh fix-systemd-workdir"
    fi
    
    PROBLEM_DETECTED=true
else
    print_success "Node.js 路径适合 systemd 使用"
    PROBLEM_DETECTED=false
fi

echo

# 检查系统路径中是否有 Node.js
print_info "检查系统路径..."
if SYSTEM_NODE=$(find_system_node); then
    SYSTEM_VERSION=$("$SYSTEM_NODE" --version)
    print_success "系统路径有 Node.js: $SYSTEM_NODE ($SYSTEM_VERSION)"
    
    if [ "$NODE_VERSION" != "$SYSTEM_VERSION" ]; then
        print_warning "版本不匹配"
        echo "  当前环境: $NODE_VERSION"
        echo "  系统路径: $SYSTEM_VERSION"
        print_info "建议更新系统路径中的 Node.js"
    fi
else
    print_warning "系统路径中无 Node.js"
    print_error "systemd 服务将无法启动"
    PROBLEM_DETECTED=true
fi

echo

# 如果是 Linux，检查 systemd 服务
if [[ "$(uname)" == "Linux" ]] && command -v systemctl >/dev/null 2>&1; then
    SERVICE_NAME="subscription-api-ts"
    print_info "检查 systemd 服务状态..."
    
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        print_success "服务文件存在"
        
        if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
            print_success "服务正在运行"
        else
            print_warning "服务未运行"
            
            # 检查最近的错误
            if journalctl -u "$SERVICE_NAME" --since "1 hour ago" --no-pager -q 2>/dev/null | grep -q "No such file or directory"; then
                print_error "检测到路径相关错误"
                print_info "这很可能是 Node.js 路径问题"
            fi
        fi
    else
        print_warning "systemd 服务文件不存在"
        print_info "请先运行安装脚本: bash scripts/install.sh"
    fi
fi

echo

# 总结和建议
print_header "检查总结"

if [ "$PROBLEM_DETECTED" = true ]; then
    print_error "发现问题，需要修复"
    echo
    if [ "$IS_FNM" = true ] && is_version_manager_path "$NODE_PATH"; then
        echo "🎯 针对 FNM 用户的最佳解决方案:"
        echo
        echo "   bash scripts/fix-fnm-systemd.sh"
        echo
        echo "   这个脚本会:"
        echo "   • 自动检测 fnm 安装的 Node.js"
        echo "   • 将其复制到 /usr/local/bin/node"
        echo "   • 重新生成 systemd 服务配置"
        echo "   • 启动服务并验证状态"
    else
        echo "🛠️ 通用解决方案:"
        echo
        echo "   1. 复制 Node.js: sudo cp \$(which node) /usr/local/bin/node"
        echo "   2. 修复服务: ./manage.sh fix-systemd-workdir"
    fi
else
    print_success "未发现明显问题"
    print_info "Node.js 配置适合 systemd 使用"
fi

echo

# 显示更多工具
print_info "其他有用的诊断工具:"
echo "  • 完整诊断: ./manage.sh diagnose-node"
echo "  • 服务检查: ./manage.sh check"
echo "  • 状态查看: ./manage.sh status"

print_header "检查完成"
