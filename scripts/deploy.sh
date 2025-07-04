#!/bin/bash

# 部署脚本
# 用于生产环境部署

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 引入公共函数库
source "$SCRIPT_DIR/common.sh"

# 显示标题
show_header "生产环境部署"

# 检测操作系统
OS=$(detect_os)
print_status "info" "操作系统: $OS"

# 服务名称
SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"

# 部署前检查
pre_deploy_check() {
    print_status "info" "部署前检查..."
    
    # 检查是否为 Linux 系统
    if [ "$OS" != "Linux" ]; then
        print_status "error" "生产环境部署仅支持 Linux 系统"
        exit 1
    fi
    
    print_status "success" "部署前检查完成"
}

# 确保依赖服务运行
ensure_dependencies() {
    print_status "info" "确保依赖服务运行..."
    
    # 检查网络连接
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        print_status "warning" "网络连接检查失败，请检查网络状态"
    else
        print_status "success" "网络连接正常"
    fi
    
    print_status "success" "依赖服务检查完成"
}

# 部署项目
deploy_project() {
    print_status "info" "开始部署项目..."
    
    cd "$PROJECT_ROOT"
    
    # 构建项目
    print_status "info" "构建项目..."
    if ! bash "$SCRIPT_DIR/build-all.sh"; then
        print_status "error" "项目构建失败"
        exit 1
    fi
    
    # 重启服务
    print_status "info" "重启服务..."
    if service_is_active "$SERVICE_NAME"; then
        service_restart "$SERVICE_NAME"
    else
        service_start "$SERVICE_NAME"
    fi
    
    # 等待服务启动
    sleep 3
    
    # 检查服务状态
    if service_is_active "$SERVICE_NAME"; then
        print_status "success" "服务部署成功！"
        
        # 显示服务信息
        load_env_file "$PROJECT_ROOT/.env"
        local api_port="${PORT:-3000}"
        local nginx_proxy_port="${NGINX_PROXY_PORT:-3888}"
        local external_host="${EXTERNAL_HOST:-localhost}"
        
        print_status "info" "服务信息:"
        echo "  - 服务状态: $(systemctl is-active "$SERVICE_NAME")"
        echo "  - API 端口: $api_port"
        echo "  - Nginx 代理端口: $nginx_proxy_port"
        echo "  - 访问地址: http://${external_host}:$nginx_proxy_port"
    else
        print_status "error" "服务启动失败"
        service_status "$SERVICE_NAME"
        exit 1
    fi
}

# 主函数
main() {
    print_status "info" "开始生产环境部署..."
    
    # 1. 部署前检查
    pre_deploy_check
    
    # 2. 确保依赖服务运行
    ensure_dependencies
    
    # 3. 部署项目
    deploy_project
    
    print_status "success" "🎉 生产环境部署完成！"
}

# 显示帮助信息
show_help() {
    echo "生产环境部署脚本"
    echo ""
    echo "用法:"
    echo "  bash scripts/deploy.sh [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo ""
    echo "功能:"
    echo "  1. 部署前环境检查"
    echo "  2. 确保依赖服务运行"
    echo "  3. 构建和部署项目"
    echo "  4. 重启相关服务"
    echo ""
    echo "注意:"
    echo "  - 仅支持 Linux 生产环境"
    echo "  - 需要先运行 scripts/install.sh 完成初始化"
}

# 参数解析
case "${1:-}" in
    -h|--help)
        show_help
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