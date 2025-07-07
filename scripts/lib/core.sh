#!/bin/bash

# 核心工具函数库
# 提供基础的工具函数和常量定义

# 颜色定义
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export NC='\033[0m' # No Color

# 打印带颜色的状态消息
print_status() {
    local status="$1"
    local message="$2"
    
    case "$status" in
        "info")    echo -e "${BLUE}ℹ️  $message${NC}" ;;
        "success") echo -e "${GREEN}✅ $message${NC}" ;;
        "warning") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "error")   echo -e "${RED}❌ $message${NC}" ;;
        "debug")   echo -e "${PURPLE}🔍 $message${NC}" ;;
        *)         echo -e "$message" ;;
    esac
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查文件是否存在
check_file() {
    local file="$1"
    local description="${2:-文件}"
    
    if [ ! -f "$file" ]; then
        print_status "error" "$description 不存在: $file"
        return 1
    fi
    return 0
}

# 检查目录是否存在
check_dir() {
    local dir="$1"
    local description="${2:-目录}"
    
    if [ ! -d "$dir" ]; then
        print_status "error" "$description 不存在: $dir"
        return 1
    fi
    return 0
}

# 确保目录存在
ensure_dir() {
    local dir="$1"
    local description="${2:-目录}"
    
    if [ ! -d "$dir" ]; then
        print_status "info" "创建$description: $dir"
        mkdir -p "$dir"
    fi
}

# 获取项目根目录
get_project_root() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "$script_dir" == */scripts* ]]; then
        echo "$(cd "$script_dir/../.." && pwd)"
    else
        echo "$script_dir"
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

# 读取 package.json 版本
get_package_version() {
    local package_json="${1:-package.json}"
    local project_root="${2:-$(get_project_root)}"
    local full_path="$project_root/$package_json"
    
    if [ -f "$full_path" ]; then
        local version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$full_path" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        echo "${version:-1.0.0}"
    else
        echo "1.0.0"
    fi
}

# 显示版本信息
show_version() {
    local project_root="${1:-$(get_project_root)}"
    local version=$(get_package_version "package.json" "$project_root")
    print_status "info" "版本: $version"
}
