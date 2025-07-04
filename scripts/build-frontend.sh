#!/bin/bash

# 前端 Dashboard 构建脚本
# 独立的前端构建脚本，可单独运行或被主流程调用

set -e

# 获取脚本所在目录和项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRONTEND_DIR="$PROJECT_ROOT/frontend"

# 引入公共函数库
source "$SCRIPT_DIR/common.sh"

# 显示标题
show_header "前端构建"

# 加载环境变量
load_env_file "$PROJECT_ROOT/.env"

# 检测操作系统
OS=$(detect_os)

print_status "info" "开始构建前端 Dashboard..."
print_status "info" "工作目录: $FRONTEND_DIR"
print_status "info" "操作系统: $OS"

# 检查构建环境
check_build_env() {
    print_status "info" "检查构建环境..."
    
    # 检查 Node.js
    if ! command_exists node; then
        print_status "error" "未找到 Node.js"
        echo "请先安装 Node.js: https://nodejs.org/"
        exit 1
    fi
    
    local node_version=$(node --version)
    print_status "info" "Node.js 版本: $node_version"
    
    # 检查包配置文件
    if [ ! -f "$FRONTEND_DIR/package.json" ]; then
        print_status "error" "未找到 package.json"
        exit 1
    fi
    
    print_status "success" "构建环境检查通过"
}

# 检测并获取 Bun 命令
get_bun_command() {
    # 检查 Bun
    local bun_cmd=$(detect_bun)
    if [ -z "$bun_cmd" ]; then
        # 尝试使用二进制目录中的 bun
        local base_dir="${BASE_DIR:-$HOME/.config/subscription}"
        if [ -f "${base_dir}/bin/bun" ]; then
            bun_cmd="${base_dir}/bin/bun"
        elif [ -n "$BUN_BINARY" ] && [ -f "$BUN_BINARY" ]; then
            bun_cmd="$BUN_BINARY"
        else
            print_status "error" "未找到 bun"
            echo "请先运行安装脚本来自动安装 bun: bash scripts/install.sh"
            echo "或手动安装 bun: https://bun.sh/"
            exit 1
        fi
    fi
    
    echo "$bun_cmd"
}

# 清理构建文件
clean_build() {
    print_status "info" "清理旧的构建文件..."
    
    # 清理各种可能的构建目录
    rm -rf "$FRONTEND_DIR/dist"
    rm -rf "$FRONTEND_DIR/.next"
    rm -rf "$FRONTEND_DIR/out"
    rm -rf "$FRONTEND_DIR/build"
    
    print_status "success" "构建文件清理完成"
}

# 安装依赖
install_dependencies() {
    local bun_cmd="$1"
    
    print_status "info" "检查依赖..."
    
    # 检查是否需要安装依赖
    if [ ! -d "$FRONTEND_DIR/node_modules" ] || [ "$FRONTEND_DIR/package.json" -nt "$FRONTEND_DIR/node_modules" ]; then
        print_status "info" "安装前端依赖..."
        cd "$FRONTEND_DIR"
        
        if ! "$bun_cmd" install; then
            print_status "error" "依赖安装失败"
            exit 1
        fi
        
        print_status "success" "依赖安装完成"
    else
        print_status "info" "依赖已是最新，跳过安装"
    fi
}

# 执行构建
build_project() {
    local bun_cmd="$1"
    
    print_status "info" "开始构建项目..."
    
    # 切换到前端目录
    cd "$FRONTEND_DIR"
    
    # 检查构建脚本
    if ! grep -q '"build"' package.json; then
        print_status "error" "package.json 中未找到 build 脚本"
        exit 1
    fi
    
    # 执行构建
    if ! "$bun_cmd" run build; then
        print_status "error" "项目构建失败"
        echo "请检查构建错误或运行: $bun_cmd run build"
        exit 1
    fi
    
    print_status "success" "项目构建完成"
}

# 验证构建结果
verify_build() {
    print_status "info" "验证构建结果..."
    
    # 检查构建输出目录
    local build_dir=""
    if [ -d "$FRONTEND_DIR/dist" ]; then
        build_dir="$FRONTEND_DIR/dist"
    elif [ -d "$FRONTEND_DIR/.next" ]; then
        build_dir="$FRONTEND_DIR/.next"
    elif [ -d "$FRONTEND_DIR/out" ]; then
        build_dir="$FRONTEND_DIR/out"
    elif [ -d "$FRONTEND_DIR/build" ]; then
        build_dir="$FRONTEND_DIR/build"
    else
        print_status "error" "未找到构建输出目录"
        exit 1
    fi
    
    # 检查关键文件
    if [ ! -f "$build_dir/index.html" ]; then
        print_status "error" "构建失败：未找到 index.html"
        exit 1
    fi
    
    print_status "success" "构建结果验证通过"
    
    # 显示构建信息
    print_status "info" "构建信息:"
    echo "  - 构建目录: $build_dir"
    
    # 显示构建文件大小
    if command_exists du; then
        local build_size=$(du -sh "$build_dir" 2>/dev/null | cut -f1)
        echo "  - 构建大小: $build_size"
    fi
    
    # 列出主要文件
    echo "  - 主要文件:"
    find "$build_dir" -maxdepth 2 -name "*.html" -o -name "*.css" -o -name "*.js" | head -10 | while read -r file; do
        echo "    $(basename "$file")"
    done
    
    export BUILD_DIR="$build_dir"
}

# 设置构建文件权限
setup_permissions() {
    local build_dir="$1"
    
    if [ "$OS" = "Linux" ]; then
        print_status "info" "设置构建文件权限..."
        
        # 获取当前用户
        local current_user=$(whoami)
        local current_group=$(id -gn)
        
        # 如果是 root 用户执行，需要特殊处理
        if [[ $EUID -eq 0 ]]; then
            if [ -n "$SUDO_USER" ]; then
                current_user="$SUDO_USER"
                current_group="$(id -gn $SUDO_USER)"
            fi
        fi
        
        # 设置文件权限
        chown -R "$current_user:$current_group" "$build_dir" 2>/dev/null || true
        chmod -R 755 "$build_dir" 2>/dev/null || true
        find "$build_dir" -type f -exec chmod 644 {} \; 2>/dev/null || true
        
        print_status "success" "文件权限设置完成"
    fi
}

# 主函数
main() {
    # 检查构建环境
    check_build_env
    
    # 获取 Bun 命令
    local bun_cmd=$(get_bun_command)
    print_status "success" "使用 bun: $($bun_cmd --version)"
    
    # 清理构建文件
    clean_build
    
    # 安装依赖
    install_dependencies "$bun_cmd"
    
    # 执行构建
    build_project "$bun_cmd"
    
    # 验证构建结果
    verify_build
    
    # 设置文件权限
    setup_permissions "$BUILD_DIR"
    
    print_status "success" "前端 Dashboard 构建完成！"
    
    # 显示后续步骤
    echo ""
    print_status "info" "后续步骤:"
    echo "  1. 配置 Nginx 以服务静态文件"
    echo "  2. 将构建文件部署到 Web 服务器"
    echo "  3. 确保 API 服务正在运行以提供后端接口"
    echo ""
    print_status "info" "本地预览:"
    echo "  cd $FRONTEND_DIR && $bun_cmd run start"
}

# 如果脚本直接执行，则运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
