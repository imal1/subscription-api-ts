#!/bin/bash

# 系统检测和环境管理函数

# 检测操作系统
detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "darwin" ;;
        *)       echo "unknown" ;;
    esac
}

# 检测系统架构
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "x64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l) echo "armv7" ;;
        *) echo "unknown" ;;
    esac
}

# 检测 sudo 可用性
has_sudo() {
    command -v sudo >/dev/null 2>&1
}

# 安全执行需要权限的命令
safe_sudo() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif has_sudo; then
        sudo "$@"
    else
        print_status "error" "需要 root 权限或 sudo 命令来执行: $*"
        exit 1
    fi
}

# 获取用户信息
get_user_info() {
    local current_user=$(whoami)
    local target_user target_group
    
    if [[ $EUID -eq 0 ]]; then
        if [ -n "$SUDO_USER" ]; then
            target_user="$SUDO_USER"
            target_group="$(id -gn $SUDO_USER)"
        else
            target_user="root"
            target_group="root"
        fi
    else
        target_user="$current_user"
        target_group="$(id -gn $current_user)"
    fi
    
    export CURRENT_USER="$current_user"
    export TARGET_USER="$target_user"
    export TARGET_GROUP="$target_group"
}

# 设置环境变量
setup_env() {
    local user_home="$HOME"
    
    # 如果是 sudo 执行，获取原用户主目录
    if [[ $EUID -eq 0 ]] && [ -n "$SUDO_USER" ]; then
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6 2>/dev/null || echo "/home/$SUDO_USER")
    fi
    
    # 设置基础目录
    export BASE_DIR="${BASE_DIR:-$user_home/.config/subscription}"
    export DATA_DIR="${DATA_DIR:-${BASE_DIR}/www}"
    export LOG_DIR="${LOG_DIR:-${BASE_DIR}/log}"
    export DIST_DIR="${DIST_DIR:-${BASE_DIR}/dist}"
    export BIN_DIR="${BIN_DIR:-${BASE_DIR}/bin}"
    export CONFIG_FILE="${CONFIG_FILE:-${BASE_DIR}/config.yaml}"
    
    # 创建必要目录
    ensure_dir "$BASE_DIR" "基础目录"
    ensure_dir "$DATA_DIR" "数据目录"
    ensure_dir "$LOG_DIR" "日志目录"
    ensure_dir "$DIST_DIR" "构建目录"
    ensure_dir "$BIN_DIR" "二进制目录"
    
    print_status "success" "环境变量设置完成"
}

# 检查系统环境
check_system() {
    local os=$(detect_os)
    local arch=$(detect_arch)
    
    print_status "info" "操作系统: $os"
    print_status "info" "系统架构: $arch"
    
    if [ "$os" = "unknown" ]; then
        print_status "error" "不支持的操作系统"
        exit 1
    fi
    
    if [ "$arch" = "unknown" ]; then
        print_status "error" "不支持的系统架构"
        exit 1
    fi
    
    export OS="$os"
    export ARCH="$arch"
    
    # 获取用户信息
    get_user_info
}

# 检查网络连接
check_network() {
    if ! command_exists curl && ! command_exists wget; then
        print_status "error" "需要 curl 或 wget 来下载文件"
        exit 1
    fi
    
    # 测试网络连接
    if command_exists curl; then
        if ! curl -s --connect-timeout 5 --max-time 10 https://github.com >/dev/null 2>&1; then
            print_status "warning" "网络连接异常，可能影响文件下载"
        fi
    fi
}

# 检查必要的系统依赖
check_dependencies() {
    print_status "info" "检查系统依赖..."
    
    local missing_deps=()
    
    # 检查基础工具
    local required_tools=("git" "tar" "unzip")
    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_deps+=("$tool")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_status "error" "缺少必要的系统工具: ${missing_deps[*]}"
        print_status "info" "请安装缺少的工具后重试"
        exit 1
    fi
    
    # 检查网络工具
    check_network
    
    print_status "success" "系统依赖检查完成"
}
