#!/bin/bash

# 服务更新脚本
# 用于服务器上的代码更新和服务重启

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 引入公共函数库
source "$SCRIPT_DIR/common.sh"

# 检测操作系统
OS=$(detect_os)
print_status "info" "操作系统: $OS"
print_status "info" "项目目录: $PROJECT_ROOT"

# 服务名称
SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"

# 拉取最新代码
update_code() {
    print_status "info" "拉取最新代码..."
    
    cd "$PROJECT_ROOT"
    
    # 检查是否是git仓库
    if [ -d ".git" ]; then
        # 检查当前分支
        local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
        print_status "info" "当前分支: $current_branch"
        
        # 拉取最新代码
        if git pull origin "$current_branch" 2>/dev/null || 
           git pull origin main 2>/dev/null || 
           git pull origin master 2>/dev/null; then
            print_status "success" "代码更新完成"
            
            # 更新环境变量中的版本信息
            update_env_version ".env" "$PROJECT_ROOT"
        else
            print_status "warning" "Git pull 失败，继续使用本地代码"
        fi
    else
        print_status "info" "不是 Git 仓库，跳过代码拉取"
    fi
}

# 更新依赖
update_dependencies() {
    print_status "info" "更新项目依赖..."
    
    if ! bash "$SCRIPT_DIR/install-deps.sh"; then
        print_status "error" "依赖更新失败"
        exit 1
    fi
    
    print_status "success" "依赖更新完成"
}

# 重新构建项目
rebuild_project() {
    print_status "info" "重新构建项目..."
    
    if ! bash "$SCRIPT_DIR/build-all.sh"; then
        print_status "error" "项目构建失败"
        exit 1
    fi
    
    print_status "success" "项目构建完成"
}

# 更新配置文件
update_configs() {
    print_status "info" "更新配置文件..."
    
    # 更新 Nginx 配置
    if command_exists nginx; then
        if ! bash "$SCRIPT_DIR/setup-nginx.sh"; then
            print_status "warning" "Nginx 配置更新失败"
        else
            print_status "success" "Nginx 配置更新完成"
        fi
    else
        print_status "info" "未安装 Nginx，跳过配置更新"
    fi
}

# 重启服务
restart_services() {
    print_status "info" "重启服务..."
    
    if [ "$OS" = "Linux" ]; then
        # 检查服务是否存在
        if systemctl list-unit-files "$SERVICE_NAME.service" >/dev/null 2>&1; then
            if service_is_active "$SERVICE_NAME"; then
                print_status "info" "服务正在运行，重启服务..."
                service_restart "$SERVICE_NAME"
                
                # 等待服务启动
                sleep 3
                
                # 验证服务状态
                if service_is_active "$SERVICE_NAME"; then
                    print_status "success" "服务重启成功"
                else
                    print_status "error" "服务重启失败"
                    service_status "$SERVICE_NAME" || true
                    exit 1
                fi
            else
                print_status "info" "服务未运行，启动服务..."
                service_start "$SERVICE_NAME"
                
                # 等待服务启动
                sleep 3
                
                # 验证服务状态
                if service_is_active "$SERVICE_NAME"; then
                    print_status "success" "服务启动成功"
                else
                    print_status "error" "服务启动失败"
                    service_status "$SERVICE_NAME" || true
                    exit 1
                fi
            fi
        else
            print_status "warning" "系统服务 $SERVICE_NAME 不存在"
            print_status "info" "请先运行 scripts/setup-systemd.sh 安装服务"
        fi
        
        # 重启 Nginx
        if command_exists nginx; then
            if systemctl is-active --quiet nginx; then
                print_status "info" "重载 Nginx 配置..."
                safe_sudo systemctl reload nginx
                print_status "success" "Nginx 配置重载完成"
            fi
        fi
    elif [ "$OS" = "Mac" ]; then
        print_status "info" "macOS 环境，请手动重启服务"
        echo "建议运行: bun run dev 或使用 pm2 管理服务"
    fi
}

# 验证更新结果
verify_update() {
    print_status "info" "验证更新结果..."
    
    # 加载环境变量
    load_env_file "$PROJECT_ROOT/.env"
    
    local nginx_proxy_port="${NGINX_PROXY_PORT:-3888}"
    local api_port="${PORT:-3000}"
    local external_host="${EXTERNAL_HOST:-localhost}"
    
    # 测试 API 健康检查
    if [ "$OS" = "Linux" ]; then
        local base_url="http://${external_host}:${nginx_proxy_port}"
    else
        local base_url="http://${external_host}:${api_port}"
    fi
    
    print_status "info" "测试 API 连接..."
    
    # 等待服务完全启动
    sleep 5
    
    # 测试健康检查端点
    if curl -s -o /dev/null -w "%{http_code}" "$base_url/api/health" | grep -q "200"; then
        print_status "success" "API 服务正常"
    else
        print_status "warning" "API 服务可能未完全启动"
    fi
    
    # 显示服务状态
    if [ "$OS" = "Linux" ] && systemctl list-unit-files "$SERVICE_NAME.service" >/dev/null 2>&1; then
        print_status "info" "服务状态:"
        service_status "$SERVICE_NAME" || true
    fi
}

# 显示更新完成信息
show_completion_info() {
    load_env_file "$PROJECT_ROOT/.env"
    
    local nginx_proxy_port="${NGINX_PROXY_PORT:-3888}"
    local api_port="${PORT:-3000}"
    local external_host="${EXTERNAL_HOST:-localhost}"
    
    print_status "success" "服务更新完成！"
    
    echo ""
    print_status "info" "🚀 测试命令："
    
    if [ "$OS" = "Linux" ]; then
        echo "  - 健康检查: curl http://${external_host}:${nginx_proxy_port}/api/health"
        echo "  - 更新订阅: curl http://${external_host}:${nginx_proxy_port}/api/update"
        echo "  - Clash配置: curl http://${external_host}:${nginx_proxy_port}/clash.yaml"
        echo "  - 控制面板: http://${external_host}:${nginx_proxy_port}/dashboard/"
    else
        echo "  - 健康检查: curl http://${external_host}:${api_port}/api/health"
        echo "  - 更新订阅: curl http://${external_host}:${api_port}/api/update"
        echo "  - Clash配置: curl http://${external_host}:${api_port}/clash.yaml"
        echo "  - 控制面板: http://${external_host}:${api_port}/dashboard/"
    fi
    
    echo ""
    print_status "info" "📊 查看日志："
    
    if [ "$OS" = "Linux" ]; then
        if [[ $EUID -eq 0 ]]; then
            echo "  - 服务日志: journalctl -u $SERVICE_NAME -f"
        else
            if [ "$HAS_SUDO" = "true" ]; then
                echo "  - 服务日志: sudo journalctl -u $SERVICE_NAME -f"
            else
                echo "  - 服务日志: journalctl -u $SERVICE_NAME -f (需要root权限)"
            fi
        fi
        
        if command_exists nginx; then
            echo "  - Nginx日志: tail -f /var/log/nginx/access.log"
        fi
    else
        echo "  - 查看应用日志文件或控制台输出"
    fi
    
    echo ""
    print_status "info" "🔧 管理命令："
    echo "  - 权限验证: bash scripts/verify-permissions.sh"
    echo "  - 重新构建: bash scripts/build-all.sh"
    echo "  - 服务配置: bash scripts/setup-systemd.sh"
    echo "  - Nginx配置: bash scripts/setup-nginx.sh"
}

# 主函数
main() {
    print_status "info" "开始服务更新流程..."
    
    # 1. 拉取最新代码
    update_code
    
    # 2. 更新依赖
    update_dependencies
    
    # 3. 重新构建项目
    rebuild_project
    
    # 4. 更新配置文件
    update_configs
    
    # 5. 重启服务
    restart_services
    
    # 6. 验证更新结果
    verify_update
    
    # 7. 显示完成信息
    show_completion_info
    
    print_status "success" "🎉 服务更新流程完成！"
}

# 显示帮助信息
show_help() {
    echo "服务更新脚本"
    echo ""
    echo "用法:"
    echo "  bash scripts/update.sh [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo ""
    echo "功能:"
    echo "  1. 拉取最新代码"
    echo "  2. 更新项目依赖"
    echo "  3. 重新构建项目"
    echo "  4. 更新配置文件"
    echo "  5. 重启相关服务"
    echo "  6. 验证更新结果"
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
