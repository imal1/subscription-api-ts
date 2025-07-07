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

# 检测并安装 yq 工具
ensure_yq_available() {
    local project_root="${1:-$(get_project_root)}"
    local base_dir="${BASE_DIR:-$HOME/.config/subscription}"
    local bin_dir="$base_dir/bin"
    local yq_path="$bin_dir/yq"
    
    # 检查系统是否已安装 yq
    if command -v yq >/dev/null 2>&1; then
        print_status "debug" "系统已安装 yq 工具"
        return 0
    fi
    
    # 检查 BASE_DIR/bin 目录是否有 yq
    if [ -f "$yq_path" ] && [ -x "$yq_path" ]; then
        print_status "debug" "BASE_DIR/bin 目录已有 yq 工具"
        export PATH="$bin_dir:$PATH"
        return 0
    fi
    
    # 检查项目 bin 目录是否有 yq（向后兼容）
    local project_yq_path="$project_root/bin/yq"
    if [ -f "$project_yq_path" ] && [ -x "$project_yq_path" ]; then
        print_status "debug" "项目 bin 目录已有 yq 工具，正在迁移到 BASE_DIR"
        mkdir -p "$bin_dir"
        cp "$project_yq_path" "$yq_path"
        chmod +x "$yq_path"
        export PATH="$bin_dir:$PATH"
        return 0
    fi
    
    print_status "info" "yq 工具不存在，正在下载到 BASE_DIR/bin..."
    
    # 创建 bin 目录
    mkdir -p "$bin_dir"
    
    # 检测系统架构
    local os=$(detect_os)
    local arch=$(uname -m)
    local yq_url=""
    
    case "$os" in
        "Linux")
            case "$arch" in
                "x86_64"|"amd64")
                    yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
                    ;;
                "aarch64"|"arm64")
                    yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm64"
                    ;;
                "armv7l")
                    yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm"
                    ;;
                *)
                    print_status "error" "不支持的 Linux 架构: $arch"
                    return 1
                    ;;
            esac
            ;;
        "Mac")
            case "$arch" in
                "x86_64"|"amd64")
                    yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_darwin_amd64"
                    ;;
                "arm64")
                    yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_darwin_arm64"
                    ;;
                *)
                    print_status "error" "不支持的 macOS 架构: $arch"
                    return 1
                    ;;
            esac
            ;;
        *)
            print_status "error" "不支持的操作系统: $os"
            return 1
            ;;
    esac
    
    print_status "info" "下载 yq 工具: $yq_url"
    
    # 下载 yq
    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$yq_path" "$yq_url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$yq_path" "$yq_url"
    else
        print_status "error" "需要 curl 或 wget 来下载 yq 工具"
        return 1
    fi
    
    # 检查下载是否成功
    if [ ! -f "$yq_path" ]; then
        print_status "error" "yq 工具下载失败"
        return 1
    fi
    
    # 设置执行权限
    chmod +x "$yq_path"
    
    # 验证 yq 工具是否可用
    if "$yq_path" --version >/dev/null 2>&1; then
        print_status "success" "yq 工具安装成功"
        export PATH="$bin_dir:$PATH"
        return 0
    else
        print_status "error" "yq 工具安装后无法执行"
        rm -f "$yq_path"
        return 1
    fi
}

# YAML 配置解析说明：
# 该脚本使用 yq 工具解析 YAML 配置文件
# yq 工具会自动下载到 bin/yq（如果系统未安装）
# 支持 Linux/macOS 多架构自动检测下载

# 加载 YAML 配置文件（更高效的版本）
load_yaml_config() {
    local config_file="${1:-config.yaml}"
    
    if [ ! -f "$config_file" ]; then
        print_status "warning" "YAML 配置文件不存在: $config_file"
        return 1
    fi
    
    print_status "info" "加载 YAML 配置文件: $config_file"
    
    # 确保 yq 工具可用
    local project_root=$(get_project_root)
    local base_dir="${BASE_DIR:-$HOME/.config/subscription}"
    
    if ! command -v yq >/dev/null 2>&1; then
        if ! ensure_yq_available "$project_root"; then
            print_status "error" "无法获取 yq 工具，无法解析 YAML 配置"
            return 1
        fi
    fi
    
    # 如果 yq 在 BASE_DIR/bin 目录，确保 PATH 包含该目录
    if [ -f "$base_dir/bin/yq" ] && [ -x "$base_dir/bin/yq" ]; then
        export PATH="$base_dir/bin:$PATH"
    # 向后兼容：如果 yq 在项目 bin 目录，确保 PATH 包含该目录
    elif [ -f "$project_root/bin/yq" ] && [ -x "$project_root/bin/yq" ]; then
        export PATH="$project_root/bin:$PATH"
    fi
    
    # 使用 yq 逐个读取配置（更加可靠的方式）
    print_status "debug" "使用 yq 工具解析 YAML"
    
    export APP_NAME=$(yq eval '.app.name' "$config_file" 2>/dev/null | sed 's/null//')
    export APP_VERSION=$(yq eval '.app.version' "$config_file" 2>/dev/null | sed 's/null//')
    export PORT=$(yq eval '.app.port' "$config_file" 2>/dev/null | sed 's/null//')
    export NODE_ENV=$(yq eval '.app.environment' "$config_file" 2>/dev/null | sed 's/null//')
    
    export SING_BOX_CONFIGS=$(yq eval '.protocols.sing_box_configs | join(",")' "$config_file" 2>/dev/null | sed 's/null//')
    export MIHOMO_PATH=$(yq eval '.binaries.mihomo_path' "$config_file" 2>/dev/null | sed 's/null//')
    export BUN_PATH=$(yq eval '.binaries.bun_path' "$config_file" 2>/dev/null | sed 's/null//')
    
    export BASE_DIR=$(yq eval '.directories.base_dir' "$config_file" 2>/dev/null | sed 's/null//')
    export DATA_DIR=$(yq eval '.directories.data_dir' "$config_file" 2>/dev/null | sed 's/null//')
    export LOG_DIR=$(yq eval '.directories.log_dir' "$config_file" 2>/dev/null | sed 's/null//')
    export BACKUP_DIR=$(yq eval '.directories.backup_dir' "$config_file" 2>/dev/null | sed 's/null//')
    export DIST_DIR=$(yq eval '.directories.dist_dir' "$config_file" 2>/dev/null | sed 's/null//')
    
    export AUTO_UPDATE_CRON=$(yq eval '.automation.auto_update_cron' "$config_file" 2>/dev/null | sed 's/null//')
    export NGINX_PORT=$(yq eval '.network.nginx_port' "$config_file" 2>/dev/null | sed 's/null//')
    export NGINX_PROXY_PORT=$(yq eval '.network.nginx_proxy_port' "$config_file" 2>/dev/null | sed 's/null//')
    export MAX_RETRIES=$(yq eval '.network.max_retries' "$config_file" 2>/dev/null | sed 's/null//')
    export REQUEST_TIMEOUT=$(yq eval '.network.request_timeout' "$config_file" 2>/dev/null | sed 's/null//')
    
    export EXTERNAL_HOST=$(yq eval '.external.host' "$config_file" 2>/dev/null | sed 's/null//')
    export CORS_ORIGIN=$(yq eval '.cors.origin' "$config_file" 2>/dev/null | sed 's/null//')
    export LOG_LEVEL=$(yq eval '.logging.level' "$config_file" 2>/dev/null | sed 's/null//')
    
    # 验证是否成功读取了一些关键配置
    if [ -n "$APP_NAME" ] || [ -n "$PORT" ]; then
        print_status "success" "YAML 配置加载成功"
        return 0
    else
        print_status "error" "YAML 配置解析失败，请检查配置文件格式"
        return 1
    fi
}

# 加载 YAML 配置文件
load_config() {
    local config_loaded=false
    local project_root="${PROJECT_ROOT:-$(get_project_root)}"
    local base_dir="${BASE_DIR:-$HOME/.config/subscription}"
    local config_file="$base_dir/config.yaml"
    
    # 尝试加载 BASE_DIR 的 YAML 配置
    if [ -f "$config_file" ]; then
        if load_yaml_config "$config_file"; then
            config_loaded=true
        fi
    # 向后兼容：如果 BASE_DIR 没有配置文件，尝试项目根目录
    elif [ -f "$project_root/config.yaml" ]; then
        print_status "warning" "在项目根目录找到 config.yaml，建议迁移到 $base_dir/config.yaml"
        if load_yaml_config "$project_root/config.yaml"; then
            config_loaded=true
        fi
    fi
    
    if [ "$config_loaded" = false ]; then
        print_status "error" "未找到配置文件: $config_file"
        print_status "info" "请确保配置文件存在于: $config_file"
        return 1
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

# 用户身份确认函数
# 统一处理用户权限检查和确认逻辑，避免重复代码
# 参数：--skip-confirm 跳过用户确认（用于脚本间调用）
check_user_permissions() {
    local skip_confirm=false
    
    # 处理参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-confirm)
                skip_confirm=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # 检测操作系统
    local os=$(detect_os)
    if [ "$os" = "Unknown" ]; then
        print_status "error" "不支持的操作系统"
        return 1
    fi
    
    # 获取用户信息
    local current_user=$(whoami)
    local target_user target_group
    
    if [[ $EUID -eq 0 ]]; then
        print_status "warning" "检测到 root 用户执行"
        if [ "$os" = "Linux" ]; then
            print_status "success" "Linux 环境下允许 root 用户执行"
            if [ -z "$SUDO_USER" ]; then
                if [ "$skip_confirm" = false ]; then
                    print_status "warning" "建议使用 sudo 执行此脚本以保留原用户信息"
                    echo "   例如: sudo bash scripts/install.sh"
                    read -p "是否继续以 root 用户安装? (y/N): " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                        print_status "info" "操作已取消"
                        return 1
                    fi
                fi
                target_user="root"
                target_group="root"
            else
                target_user="$SUDO_USER"
                target_group="$(id -gn $SUDO_USER)"
                print_status "info" "目标用户: $target_user"
            fi
        else
            print_status "error" "macOS 环境下请不要使用 root 用户运行此脚本"
            return 1
        fi
    else
        target_user="$current_user"
        target_group="$(id -gn $current_user)"
    fi
    
    print_status "info" "当前用户: $current_user"
    print_status "info" "目标用户: $target_user"
    
    # 导出用户信息供子脚本使用
    export TARGET_USER="$target_user"
    export TARGET_GROUP="$target_group"
    export CURRENT_USER="$current_user"
    export OS="$os"
    
    return 0
}

# 版本管理函数
# 从 package.json 读取版本信息
read_package_version() {
    local package_json_path="${1:-package.json}"
    local project_root="${2:-$(get_project_root)}"
    local full_path="$project_root/$package_json_path"
    
    if [ -f "$full_path" ]; then
        # 使用 grep 和 sed 提取版本信息，避免依赖 jq
        local version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$full_path" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        echo "${version:-1.0.0}"
    else
        print_status "warning" "package.json 文件不存在: $full_path"
        echo "1.0.0"
    fi
}

# 从 package.json 读取应用名称
read_package_name() {
    local package_json_path="${1:-package.json}"
    local project_root="${2:-$(get_project_root)}"
    local full_path="$project_root/$package_json_path"
    
    if [ -f "$full_path" ]; then
        # 使用 grep 和 sed 提取名称信息
        local name=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$full_path" | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        echo "${name:-subscription-api}"
    else
        print_status "warning" "package.json 文件不存在: $full_path"
        echo "subscription-api"
    fi
}

# 更新 YAML 配置文件中的版本信息
update_yaml_version() {
    local config_file="${1:-config.yaml}"
    local project_root="${2:-$(get_project_root)}"
    local config_path="$project_root/$config_file"
    
    # 读取 package.json 中的版本和名称
    local version=$(read_package_version "package.json" "$project_root")
    local name=$(read_package_name "package.json" "$project_root")
    
    print_status "info" "更新 YAML 配置文件中的版本信息..."
    print_status "info" "应用名称: $name"
    print_status "info" "应用版本: $version"
    
    if [ -f "$config_path" ] && [ -f "$yq_path" ]; then
        # 使用 yq 工具更新 YAML 文件
        print_status "info" "使用 yq 工具更新配置文件版本..."
        
        # 更新版本
        "$yq_path" eval '.app.version = "'$version'"' -i "$config_path"
        
        # 更新名称
        "$yq_path" eval '.app.name = "'$name'"' -i "$config_path"
        
        print_status "success" "已更新 YAML 配置文件: version=$version, name=$name"
    else
        print_status "warning" "无法更新 YAML 配置文件（文件不存在或缺少 yq 工具）"
    fi
}

# 更新配置文件中的版本信息
update_config_version() {
    local project_root="${1:-$(get_project_root)}"
    
    if [ -f "$project_root/config.yaml" ]; then
        update_yaml_version "config.yaml" "$project_root"
    fi
}

# 显示版本信息
show_version_info() {
    local project_root="${1:-$(get_project_root)}"
    local version=$(read_package_version "package.json" "$project_root")
    local name=$(read_package_name "package.json" "$project_root")
    
    print_status "info" "项目信息:"
    print_status "info" "  应用名称: $name"
    print_status "info" "  应用版本: $version"
}

# 设置默认环境变量（公共函数）
# 为所有脚本提供统一的环境变量设置
setup_default_env() {
    print_status "info" "设置默认环境变量..."
    
    # 确定正确的用户主目录
    local user_home="$HOME"
    if [[ $EUID -eq 0 ]] && [ -n "$SUDO_USER" ]; then
        # 如果是通过 sudo 运行，使用原始用户的主目录
        user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [ -z "$user_home" ]; then
            user_home="/home/$SUDO_USER"
        fi
        print_status "info" "检测到 sudo 执行，使用用户 $SUDO_USER 的主目录: $user_home"
    fi
    
    # 设置基础目录
    BASE_DIR="${BASE_DIR:-$user_home/.config/subscription}"
    DATA_DIR="${DATA_DIR:-${BASE_DIR}/www}"
    LOG_DIR="${LOG_DIR:-${BASE_DIR}/log}"
    DIST_DIR="${DIST_DIR:-${BASE_DIR}/dist}"
    NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"
    MIHOMO_PATH="${MIHOMO_PATH:-${BASE_DIR}/bin}"
    BUN_PATH="${BUN_PATH:-${BASE_DIR}/bin}"
    
    # 导出环境变量
    export BASE_DIR DATA_DIR LOG_DIR DIST_DIR NGINX_PROXY_PORT MIHOMO_PATH BUN_PATH
    
    print_status "success" "环境变量设置完成"
    print_status "info" "配置信息:"
    echo "  - 用户主目录: $user_home"
    echo "  - 基础目录: $BASE_DIR"
    echo "  - 数据目录: $DATA_DIR"
    echo "  - 日志目录: $LOG_DIR"
    echo "  - 构建目录: $DIST_DIR"
    echo "  - 二进制目录: ${BASE_DIR}/bin"
    echo "  - 代理端口: $NGINX_PROXY_PORT"
}
