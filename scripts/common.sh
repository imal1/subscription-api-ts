#!/bin/bash

# 公共函数库
# 提供所有脚本共用的函数和变量定义
# 使用方法: source "$(dirname "$0")/common.sh" 或 source "$SCRIPT_DIR/common.sh"

# 颜色定义
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export NC='\033[0m' # No Color

# 检查sudo命令是否可用
detect_sudo() {
    if command -v sudo >/dev/null 2>&1; then
        echo "true"
    else
        echo "false"
    fi
}

# 全局变量：是否有sudo命令
HAS_SUDO=$(detect_sudo)

# 定义安全的sudo函数
safe_sudo() {
    if [[ $EUID -eq 0 ]]; then
        # 如果是root用户，直接执行命令
        "$@"
    elif [ "$HAS_SUDO" = "true" ]; then
        # 如果有sudo且不是root，使用sudo
        sudo "$@"
    else
        echo -e "${RED}❌ 错误：需要root权限或sudo命令来执行: $*${NC}"
        echo -e "${RED}   请以root用户运行此脚本，或安装sudo命令${NC}"
        exit 1
    fi
}

# 定义用户切换函数
safe_sudo_user() {
    local target_user="$1"
    shift
    
    if [[ $EUID -eq 0 ]]; then
        if [ "$target_user" = "root" ]; then
            # root用户直接执行
            "$@"
        else
            # root用户切换到目标用户
            if command -v su >/dev/null 2>&1; then
                su -c "$(printf '%q ' "$@")" "$target_user"
            else
                echo -e "${RED}❌ 错误：无法切换用户，缺少su命令${NC}"
                exit 1
            fi
        fi
    elif [ "$HAS_SUDO" = "true" ]; then
        # 非root用户使用sudo切换
        sudo -u "$target_user" "$@"
    else
        echo -e "${RED}❌ 错误：需要sudo命令来切换用户执行: $*${NC}"
        echo -e "${RED}   请安装sudo命令或以root用户运行此脚本${NC}"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "Linux";;
        Darwin*)    echo "Mac";;
        *)          echo "Unknown";;
    esac
}

# 检测 bun 命令
detect_bun() {
    if command -v bun >/dev/null 2>&1; then
        echo "bun"
    elif [ -f "$HOME/.local/bin/bun" ]; then
        echo "$HOME/.local/bin/bun"
    elif [ -f "/usr/local/bin/bun" ]; then
        echo "/usr/local/bin/bun"
    else
        echo ""
    fi
}

# 打印带颜色的状态消息
print_status() {
    local status="$1"
    local message="$2"
    
    case "$status" in
        "info")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
        "success")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "error")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "debug")
            echo -e "${PURPLE}🔍 $message${NC}"
            ;;
        *)
            echo -e "$message"
            ;;
    esac
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查文件是否存在且可执行
is_executable() {
    [ -f "$1" ] && [ -x "$1" ]
}

# 获取项目根目录（相对于scripts目录）
get_project_root() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "$script_dir" == */scripts ]]; then
        echo "$(cd "$script_dir/.." && pwd)"
    else
        echo "$script_dir"
    fi
}

# 检查必需文件是否存在
check_required_file() {
    local file="$1"
    local description="${2:-文件}"
    
    if [ ! -f "$file" ]; then
        print_status "error" "$description 不存在: $file"
        return 1
    fi
    return 0
}

# 检查必需目录是否存在
check_required_dir() {
    local dir="$1"
    local description="${2:-目录}"
    
    if [ ! -d "$dir" ]; then
        print_status "error" "$description 不存在: $dir"
        return 1
    fi
    return 0
}

# 系统服务管理函数（仅适用于 Linux）
service_is_active() {
    local service_name="$1"
    if [ "$(detect_os)" = "Linux" ]; then
        safe_sudo systemctl is-active --quiet "$service_name"
    else
        return 1
    fi
}

# 启动系统服务
service_start() {
    local service_name="$1"
    if [ "$(detect_os)" = "Linux" ]; then
        print_status "info" "启动服务: $service_name"
        safe_sudo systemctl start "$service_name"
    else
        print_status "warning" "服务管理功能仅适用于 Linux 系统"
        return 1
    fi
}

# 重启系统服务
service_restart() {
    local service_name="$1"
    if [ "$(detect_os)" = "Linux" ]; then
        print_status "info" "重启服务: $service_name"
        safe_sudo systemctl restart "$service_name"
    else
        print_status "warning" "服务管理功能仅适用于 Linux 系统"
        return 1
    fi
}

# 显示服务状态
service_status() {
    local service_name="$1"
    if [ "$(detect_os)" = "Linux" ]; then
        safe_sudo systemctl status "$service_name" --no-pager -l
    else
        print_status "warning" "服务状态查看功能仅适用于 Linux 系统"
        return 1
    fi
}

# 启用系统服务
service_enable() {
    local service_name="$1"
    if [ "$(detect_os)" = "Linux" ]; then
        print_status "info" "启用服务: $service_name"
        safe_sudo systemctl enable "$service_name"
    else
        print_status "warning" "服务管理功能仅适用于 Linux 系统"
        return 1
    fi
}

# 重新加载 systemd 配置
systemd_reload() {
    if [ "$(detect_os)" = "Linux" ]; then
        print_status "info" "重新加载 systemd 配置"
        safe_sudo systemctl daemon-reload
    else
        print_status "warning" "systemd 功能仅适用于 Linux 系统"
        return 1
    fi
}

# 确保目录存在（如果不存在则创建）
ensure_dir_exists() {
    local dir="$1"
    local description="${2:-目录}"
    
    if [ ! -d "$dir" ]; then
        print_status "info" "创建$description: $dir"
        mkdir -p "$dir"
    fi
}

# 加载环境变量文件
load_env_file() {
    local env_file="${1:-.env}"
    
    if [ -f "$env_file" ]; then
        print_status "info" "加载环境变量文件: $env_file"
        # 读取 .env 文件，忽略注释和空行
        while IFS='=' read -r key value; do
            # 跳过注释和空行
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z $key ]] && continue
            # 移除引号
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"
            # 设置环境变量
            export "$key"="$value"
        done < <(grep -v '^[[:space:]]*#' "$env_file" | grep -v '^[[:space:]]*$')
    else
        print_status "warning" "环境变量文件不存在: $env_file"
    fi
}

# 显示标题
show_header() {
    local title="${1:-Subscription API TypeScript}"
    echo -e "${PURPLE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${WHITE}    $title    ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════╝${NC}"
    echo ""
}
