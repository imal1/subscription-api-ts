#!/bin/bash

# Subscription API TypeScript 主安装脚本
# 重构后的模块化安装脚本，负责调度各个功能模块
# 
# 支持的执行方式:
# 1. 普通用户: bash scripts/install.sh
# 2. sudo执行: sudo bash scripts/install.sh (推荐)
# 3. root用户: bash scripts/install.sh (仅Linux)

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 引入公共函数库
source "$SCRIPT_DIR/common.sh"

# 显示标题
show_header "Subscription API TypeScript 安装"

# 版本信息
VERSION="2.0.0"
print_status "info" "安装脚本版本: $VERSION (模块化重构版)"

# 检测操作系统
OS=$(detect_os)
print_status "info" "操作系统: $OS"
print_status "info" "项目目录: $PROJECT_ROOT"

if [ "$OS" = "Unknown" ]; then
    print_status "error" "不支持的操作系统"
    exit 1
fi

# 获取用户信息
CURRENT_USER=$(whoami)
if [[ $EUID -eq 0 ]]; then
    print_status "warning" "检测到 root 用户执行"
    if [ "$OS" = "Linux" ]; then
        print_status "success" "Linux 环境下允许 root 用户执行"
        if [ -z "$SUDO_USER" ]; then
            print_status "warning" "建议使用 sudo 执行此脚本以保留原用户信息"
            echo "   例如: sudo bash scripts/install.sh"
            read -p "是否继续以 root 用户安装? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_status "info" "安装已取消"
                exit 0
            fi
            TARGET_USER="root"
            TARGET_GROUP="root"
        else
            TARGET_USER="$SUDO_USER"
            TARGET_GROUP="$(id -gn $SUDO_USER)"
            print_status "info" "目标用户: $TARGET_USER"
        fi
    else
        print_status "error" "macOS 环境下请不要使用 root 用户运行此脚本"
        exit 1
    fi
else
    TARGET_USER="$CURRENT_USER"
    TARGET_GROUP="$(id -gn $CURRENT_USER)"
fi

print_status "info" "当前用户: $CURRENT_USER"
print_status "info" "目标用户: $TARGET_USER"

# 导出用户信息供子脚本使用
export TARGET_USER TARGET_GROUP

# 设置默认环境变量
setup_default_env() {
    print_status "info" "设置默认环境变量..."
    
    # 设置基础目录
    export BASE_DIR="${BASE_DIR:-$HOME/.config/subscription}"
    export DATA_DIR="${DATA_DIR:-${BASE_DIR}/www}"
    export LOG_DIR="${LOG_DIR:-${BASE_DIR}/log}"
    export DIST_DIR="${DIST_DIR:-${BASE_DIR}/dist}"
    export NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"
    export MIHOMO_PATH="${MIHOMO_PATH:-${BASE_DIR}/bin}"
    export BUN_PATH="${BUN_PATH:-${BASE_DIR}/bin}"
    
    print_status "success" "环境变量设置完成"
    print_status "info" "配置信息:"
    echo "  - 基础目录: $BASE_DIR"
    echo "  - 数据目录: $DATA_DIR"
    echo "  - 日志目录: $LOG_DIR"
    echo "  - 构建目录: $DIST_DIR"
    echo "  - 二进制目录: ${BASE_DIR}/bin"
    echo "  - 代理端口: $NGINX_PROXY_PORT"
}

# 清理旧配置
cleanup_old_config() {
    print_status "info" "清理旧配置文件..."
    
    # 检查 .env 文件是否存在，如果存在则询问用户
    if [ -f "$PROJECT_ROOT/.env" ]; then
        print_status "warning" "发现现有的 .env 配置文件"
        echo ""
        echo "删除现有配置文件将重置所有自定义设置为默认值。"
        echo "如果你有重要的自定义配置，请先手动备份。"
        echo ""
        
        read -p "是否删除现有的 .env 文件并创建新配置？(y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f "$PROJECT_ROOT/.env"
            print_status "success" ".env 文件已删除，将创建新的配置文件"
        else
            print_status "info" "保留现有的 .env 文件"
            print_status "warning" "注意: 现有配置可能与新版本不兼容，如遇问题请手动更新配置"
        fi
    fi
    
    # 删除其他旧的配置文件（不需要用户确认）
    local other_files_to_remove=(
        "$PROJECT_ROOT/config/nginx.conf"
        "$PROJECT_ROOT/config/subscription-api-ts.service"
    )
    
    for file in "${other_files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            print_status "info" "删除旧配置: $(basename "$file")"
            rm -f "$file"
        fi
    done
    
    print_status "success" "旧配置清理完成"
}

# 创建环境配置文件
create_env_config() {
    print_status "info" "创建环境配置文件..."
    
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        if [ -f "$PROJECT_ROOT/.env.example" ]; then
            cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
            
            # 根据操作系统调整配置文件中的路径
            if [ "$OS" = "Linux" ]; then
                sed -i "s|BASE_DIR=.*|BASE_DIR=${BASE_DIR}|g" "$PROJECT_ROOT/.env"
                sed -i "s|DATA_DIR=.*|DATA_DIR=${DATA_DIR}|g" "$PROJECT_ROOT/.env"
                sed -i "s|LOG_DIR=.*|LOG_DIR=${LOG_DIR}|g" "$PROJECT_ROOT/.env"
                sed -i "s|DIST_DIR=.*|DIST_DIR=${DIST_DIR}|g" "$PROJECT_ROOT/.env"
                sed -i "s|MIHOMO_PATH=.*|MIHOMO_PATH=${MIHOMO_PATH}|g" "$PROJECT_ROOT/.env"
                sed -i "s|BUN_PATH=.*|BUN_PATH=${BUN_PATH}|g" "$PROJECT_ROOT/.env"
            elif [ "$OS" = "Mac" ]; then
                sed -i '' "s|BASE_DIR=.*|BASE_DIR=${BASE_DIR}|g" "$PROJECT_ROOT/.env"
                sed -i '' "s|DATA_DIR=.*|DATA_DIR=${DATA_DIR}|g" "$PROJECT_ROOT/.env"
                sed -i '' "s|LOG_DIR=.*|LOG_DIR=${LOG_DIR}|g" "$PROJECT_ROOT/.env"
                sed -i '' "s|DIST_DIR=.*|DIST_DIR=${DIST_DIR}|g" "$PROJECT_ROOT/.env"
                sed -i '' "s|MIHOMO_PATH=.*|MIHOMO_PATH=${MIHOMO_PATH}|g" "$PROJECT_ROOT/.env"
                sed -i '' "s|BUN_PATH=.*|BUN_PATH=${BUN_PATH}|g" "$PROJECT_ROOT/.env"
            fi
            
            print_status "success" "环境配置文件创建完成"
        else
            print_status "warning" "未找到 .env.example 文件"
        fi
    else
        print_status "info" "使用现有的 .env 配置文件"
        
        # 验证现有配置文件是否包含必要的变量
        local required_vars=("BASE_DIR" "DATA_DIR" "LOG_DIR" "DIST_DIR")
        local missing_vars=()
        
        for var in "${required_vars[@]}"; do
            if ! grep -q "^${var}=" "$PROJECT_ROOT/.env"; then
                missing_vars+=("$var")
            fi
        done
        
        if [ ${#missing_vars[@]} -gt 0 ]; then
            print_status "warning" "检测到缺少的环境变量: ${missing_vars[*]}"
            print_status "info" "建议手动检查并更新 .env 文件，或重新运行安装脚本并选择删除现有配置"
        else
            print_status "success" "现有配置文件验证通过"
        fi
    fi
}

# 执行安装步骤
run_install_step() {
    local step_name="$1"
    local script_name="$2"
    local description="$3"
    
    print_status "info" "第 $step_name 步: $description"
    
    local script_path="$SCRIPT_DIR/$script_name"
    if [ ! -f "$script_path" ]; then
        print_status "error" "脚本不存在: $script_path"
        exit 1
    fi
    
    if ! bash "$script_path"; then
        print_status "error" "$description 失败"
        exit 1
    fi
    
    print_status "success" "$description 完成"
}

# 可选安装步骤
run_optional_step() {
    local step_name="$1"
    local script_name="$2"
    local description="$3"
    local condition="$4"
    
    if [ "$condition" = "true" ]; then
        run_install_step "$step_name" "$script_name" "$description"
    else
        print_status "info" "跳过第 $step_name 步: $description"
    fi
}

# 显示安装完成信息
show_completion_info() {
    # 加载环境变量
    load_env_file "$PROJECT_ROOT/.env"
    
    # 设置主机地址
    local external_host="${EXTERNAL_HOST:-localhost}"
    
    print_status "success" "安装完成！"
    
    echo ""
    print_status "info" "🚀 快速开始："
    
    if [ "$OS" = "Linux" ]; then
        echo "1. 生成订阅文件: curl http://${external_host}:${NGINX_PROXY_PORT}/api/update"
        echo "2. 访问控制面板: http://${external_host}:${NGINX_PROXY_PORT}/dashboard/"
        
        local service_name="${SERVICE_NAME:-subscription-api-ts}"
        echo ""
        print_status "info" "📊 服务管理："
        if [[ $EUID -eq 0 ]]; then
            echo "   查看状态: systemctl status $service_name"
            echo "   查看日志: journalctl -u $service_name -f"
            echo "   重启服务: systemctl restart $service_name"
        else
            if [ "$HAS_SUDO" = "true" ]; then
                echo "   查看状态: sudo systemctl status $service_name"
                echo "   查看日志: sudo journalctl -u $service_name -f"
                echo "   重启服务: sudo systemctl restart $service_name"
            fi
        fi
    elif [ "$OS" = "Mac" ]; then
        local api_port="${PORT:-3000}"
        echo "1. 启动服务: bun run dev"
        echo "2. 生成订阅: curl http://${external_host}:${api_port}/api/update"
        echo "3. 访问控制面板: http://${external_host}:${api_port}/dashboard/"
    fi
    
    echo ""
    print_status "info" "🔧 管理脚本："
    echo "   权限验证: bash scripts/verify-permissions.sh"
    echo "   重新构建: bash scripts/build-all.sh"
    echo "   前端构建: bash scripts/build-frontend.sh"
    
    if [ "$OS" = "Linux" ]; then
        echo "   systemd 配置: bash scripts/setup-systemd.sh"
        echo "   Nginx 配置: bash scripts/setup-nginx.sh"
    fi
    
    echo ""
    print_status "info" "📋 配置文件："
    echo "   环境配置: $PROJECT_ROOT/.env"
    echo "   数据目录: $DATA_DIR"
    echo "   日志目录: $LOG_DIR"
    echo "   构建目录: $DIST_DIR"
    
    echo ""
    print_status "info" "🆘 故障排除："
    echo "   如遇到问题，请检查："
    echo "   1. 权限问题: bash scripts/verify-permissions.sh"
    echo "   2. 服务日志: journalctl -u subscription-api-ts -f"
    echo "   3. 环境配置: cat $PROJECT_ROOT/.env"
    echo "   4. 端口占用: netstat -tlnp | grep :$NGINX_PROXY_PORT"
}

# 主安装流程
main() {
    print_status "info" "开始模块化安装流程..."
    
    # 设置默认环境变量
    setup_default_env
    
    # 清理旧配置
    cleanup_old_config
    
    # 步骤1: 环境设置
    run_install_step "1" "setup-env.sh" "环境设置和目录创建"
    
    # 创建环境配置文件
    create_env_config
    
    # 步骤2: 安装二进制文件
    run_install_step "2" "install-binaries.sh" "二进制文件安装"
    
    # 步骤3: 安装依赖
    run_install_step "3" "install-deps.sh" "依赖安装"
    
    # 步骤4: 构建项目
    run_install_step "4" "build-all.sh" "项目构建"
    
    # 步骤5: systemd 服务配置（仅Linux）
    run_optional_step "5" "setup-systemd.sh" "systemd 服务配置" "$([ "$OS" = "Linux" ] && echo "true" || echo "false")"
    
    # 步骤6: Nginx 配置（可选）
    if command_exists nginx; then
        run_optional_step "6" "setup-nginx.sh" "Nginx 配置" "true"
    else
        print_status "info" "跳过第 6 步: Nginx 配置 (未安装 Nginx)"
    fi
    
    # 步骤7: 权限验证
    run_install_step "7" "verify-permissions.sh" "权限验证"
    
    # 显示完成信息
    show_completion_info
    
    print_status "success" "🎉 Subscription API TypeScript 安装完成！"
}

# 显示帮助信息
show_help() {
    echo "Subscription API TypeScript 安装脚本"
    echo "版本: $VERSION"
    echo ""
    echo "用法:"
    echo "  bash scripts/install.sh [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -v, --version  显示版本信息"
    echo ""
    echo "执行方式:"
    echo "  普通用户: bash scripts/install.sh"
    echo "  sudo执行: sudo bash scripts/install.sh (推荐)"
    echo "  root用户: bash scripts/install.sh (仅Linux)"
    echo ""
    echo "模块化脚本:"
    echo "  scripts/setup-env.sh        - 环境设置"
    echo "  scripts/install-binaries.sh - 二进制文件安装"
    echo "  scripts/install-deps.sh     - 依赖安装"
    echo "  scripts/build-all.sh        - 项目构建"
    echo "  scripts/setup-systemd.sh    - systemd 服务配置"
    echo "  scripts/setup-nginx.sh      - Nginx 配置"
    echo "  scripts/verify-permissions.sh - 权限验证"
    echo "  scripts/build-frontend.sh      - 前端构建"
}

# 参数解析
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--version)
        echo "版本: $VERSION"
        exit 0
        ;;
    "")
        # 默认执行主流程
        main
        ;;
    *)
        print_status "error" "未知参数: $1"
        echo "使用 --help 查看帮助信息"
        exit 1
        ;;
esac
