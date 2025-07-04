#!/bin/bash

# Nginx 配置脚本
# 负责生成和配置 Nginx 服务

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 引入公共函数库
source "$SCRIPT_DIR/common.sh"

# 显示标题
show_header "Nginx 配置"

# 加载环境变量
load_env_file "$PROJECT_ROOT/.env"

# 检测操作系统
OS=$(detect_os)
print_status "info" "操作系统: $OS"

# 获取用户信息
CURRENT_USER=$(whoami)
if [[ $EUID -eq 0 ]]; then
    if [ -n "$SUDO_USER" ]; then
        TARGET_USER="$SUDO_USER"
        TARGET_GROUP="$(id -gn $SUDO_USER)"
    else
        TARGET_USER="root"
        TARGET_GROUP="root"
    fi
else
    TARGET_USER="$CURRENT_USER"
    TARGET_GROUP="$(id -gn $CURRENT_USER)"
fi

# 设置端口和目录变量
API_PORT="${PORT:-3000}"
NGINX_PORT="${NGINX_PORT:-3080}"
NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"
BASE_DIR="${BASE_DIR:-$HOME/.config/subscription}"
DATA_DIR="${DATA_DIR:-${BASE_DIR}/www}"
LOG_DIR="${LOG_DIR:-${BASE_DIR}/log}"
DIST_DIR="${DIST_DIR:-${BASE_DIR}/dist}"
SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"

# 检查 Nginx 安装
check_nginx_installation() {
    print_status "info" "检查 Nginx 安装状态..."
    
    if ! command_exists nginx; then
        print_status "error" "未检测到 Nginx"
        echo "请先安装 Nginx："
        if [ "$OS" = "Linux" ]; then
            echo "  sudo apt-get install nginx"
            echo "  或"
            echo "  sudo yum install nginx"
        elif [ "$OS" = "Mac" ]; then
            echo "  brew install nginx"
        fi
        exit 1
    fi
    
    local nginx_version=$(nginx -v 2>&1 | grep -o 'nginx/[0-9.]*' || echo "unknown")
    print_status "success" "Nginx 已安装: $nginx_version"
}

# 检查必需文件
check_requirements() {
    print_status "info" "检查配置要求..."
    
    # 检查 Nginx 配置模板
    check_required_file "$PROJECT_ROOT/config/nginx.conf.template" "Nginx 配置模板"
    
    # 检查前端构建文件（如果存在）
    if [ -d "$PROJECT_ROOT/frontend/dist" ]; then
        check_required_file "$PROJECT_ROOT/frontend/dist/index.html" "前端构建文件"
        print_status "info" "检测到前端构建文件"
    else
        print_status "warning" "未检测到前端构建文件"
    fi
    
    # 检查数据目录
    if [ ! -d "$DATA_DIR" ]; then
        print_status "info" "创建数据目录: $DATA_DIR"
        ensure_dir_exists "$DATA_DIR" "数据目录"
    fi
}

# 安装 envsubst 工具
install_envsubst() {
    if ! command_exists envsubst; then
        print_status "info" "安装 envsubst 工具..."
        
        if [ "$OS" = "Linux" ]; then
            if [[ $EUID -eq 0 ]]; then
                apt-get update && apt-get install -y gettext-base
            else
                safe_sudo apt-get update && safe_sudo apt-get install -y gettext-base
            fi
        elif [ "$OS" = "Mac" ]; then
            if command_exists brew; then
                brew install gettext
                # 添加到PATH
                export PATH="/usr/local/opt/gettext/bin:$PATH"
            else
                print_status "error" "请先安装 Homebrew"
                exit 1
            fi
        fi
        
        print_status "success" "envsubst 工具安装完成"
    fi
}

# 生成 Nginx 配置文件
generate_nginx_config() {
    print_status "info" "生成 Nginx 配置文件..."
    
    # 获取项目绝对路径
    local absolute_project_root="$(cd "$PROJECT_ROOT" && pwd)"
    
    # 设置环境变量供 envsubst 使用
    export API_PORT
    export NGINX_PORT
    export NGINX_PROXY_PORT
    export DATA_DIR
    export LOG_DIR
    export ABSOLUTE_PROJECT_ROOT="$absolute_project_root"
    export DIST_DIR
    
    print_status "info" "配置参数:"
    echo "  - API 端口: $API_PORT"
    echo "  - Nginx 端口: $NGINX_PORT"
    echo "  - 代理端口: $NGINX_PROXY_PORT"
    echo "  - 数据目录: $DATA_DIR"
    echo "  - 日志目录: $LOG_DIR"
    echo "  - 项目目录: $ABSOLUTE_PROJECT_ROOT"
    echo "  - 构建目录: $DIST_DIR"
    
    # 生成配置文件
    local config_template="$PROJECT_ROOT/config/nginx.conf.template"
    local config_output="$PROJECT_ROOT/config/nginx.conf"
    
    if command_exists envsubst; then
        # 使用 envsubst 生成配置文件
        envsubst '${API_PORT} ${NGINX_PORT} ${NGINX_PROXY_PORT} ${DATA_DIR} ${LOG_DIR} ${ABSOLUTE_PROJECT_ROOT} ${DIST_DIR}' < "$config_template" > "$config_output"
        print_status "success" "使用 envsubst 生成配置文件"
    else
        # 使用 sed 替换
        sed "s/\${API_PORT}/${API_PORT}/g; s/\${NGINX_PORT}/${NGINX_PORT}/g; s/\${NGINX_PROXY_PORT}/${NGINX_PROXY_PORT}/g; s|\${DATA_DIR}|${DATA_DIR}|g; s|\${LOG_DIR}|${LOG_DIR}|g; s|\${ABSOLUTE_PROJECT_ROOT}|${ABSOLUTE_PROJECT_ROOT}|g; s|\${DIST_DIR}|${DIST_DIR}|g" "$config_template" > "$config_output"
        print_status "success" "使用 sed 生成配置文件"
    fi
    
    print_status "success" "配置文件已生成: $config_output"
}

# 配置静态文件权限
setup_static_permissions() {
    print_status "info" "配置静态文件权限..."
    
    if [ "$OS" = "Linux" ]; then
        # 检查 Nginx 用户
        local nginx_user="www-data"
        if ! id "$nginx_user" >/dev/null 2>&1; then
            for user in nginx http; do
                if id "$user" >/dev/null 2>&1; then
                    nginx_user="$user"
                    break
                fi
            done
        fi
        
        print_status "info" "Nginx 用户: $nginx_user"
        
        # 配置数据目录权限
        if [ -d "$DATA_DIR" ]; then
            safe_sudo chown -R "$nginx_user:$nginx_user" "$DATA_DIR"
            safe_sudo chmod -R 755 "$DATA_DIR"
            safe_sudo find "$DATA_DIR" -type f -exec chmod 644 {} \; 2>/dev/null || true
            print_status "success" "数据目录权限设置完成"
        fi
        
        # 配置前端构建文件权限
        if [ -d "$PROJECT_ROOT/frontend/dist" ]; then
            safe_sudo chown -R "$nginx_user:$nginx_user" "$PROJECT_ROOT/frontend/dist"
            safe_sudo chmod -R 755 "$PROJECT_ROOT/frontend/dist"
            safe_sudo find "$PROJECT_ROOT/frontend/dist" -type f -exec chmod 644 {} \; 2>/dev/null || true
            print_status "success" "前端文件权限设置完成"
        fi
        
        # 配置统一构建目录权限
        if [ -d "$DIST_DIR/frontend" ]; then
            safe_sudo chown -R "$nginx_user:$nginx_user" "$DIST_DIR/frontend"
            safe_sudo chmod -R 755 "$DIST_DIR/frontend"
            safe_sudo find "$DIST_DIR/frontend" -type f -exec chmod 644 {} \; 2>/dev/null || true
            print_status "success" "统一构建目录权限设置完成"
        fi
        
        # 检查 SELinux（如果适用）
        if command_exists getenforce; then
            local selinux_status=$(getenforce 2>/dev/null || echo "未知")
            if [ "$selinux_status" = "Enforcing" ]; then
                print_status "info" "检测到 SELinux，配置相关权限..."
                safe_sudo setsebool -P httpd_read_user_content 1 2>/dev/null || true
                safe_sudo restorecon -R "$DATA_DIR" 2>/dev/null || true
                print_status "success" "SELinux 权限配置完成"
            fi
        fi
    elif [ "$OS" = "Mac" ]; then
        # macOS 权限设置
        if [ -d "$DATA_DIR" ]; then
            chmod -R 755 "$DATA_DIR"
            find "$DATA_DIR" -type f -exec chmod 644 {} \; 2>/dev/null || true
            print_status "success" "macOS 权限设置完成"
        fi
    fi
}

# 创建测试文件
create_test_files() {
    print_status "info" "创建测试文件..."
    
    # 创建测试 HTML 文件
    cat > "/tmp/test.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Nginx 测试页面</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #333; }
        .success { color: #28a745; }
        .info { color: #007bff; }
        .timestamp { color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <h1 class="success">🎉 Nginx 静态服务正常工作！</h1>
    <p class="info">如果您看到这个页面，说明 Nginx 静态文件服务已经正确配置。</p>
    <p class="timestamp">页面生成时间: <script>document.write(new Date().toLocaleString());</script></p>
    <hr>
    <h2>测试链接</h2>
    <ul>
        <li><a href="/subscription.txt">查看订阅文件</a></li>
        <li><a href="/dashboard/">访问控制面板</a></li>
        <li><a href="/api/health">API 健康检查</a></li>
    </ul>
</body>
</html>
EOF
    
    # 复制测试文件
    safe_sudo cp "/tmp/test.html" "$DATA_DIR/test.html"
    safe_sudo cp "/tmp/test.html" "$DATA_DIR/index.html"
    
    # 设置测试文件权限
    if [ "$OS" = "Linux" ]; then
        local nginx_user="www-data"
        if ! id "$nginx_user" >/dev/null 2>&1; then
            for user in nginx http; do
                if id "$user" >/dev/null 2>&1; then
                    nginx_user="$user"
                    break
                fi
            done
        fi
        
        safe_sudo chown "$nginx_user:$nginx_user" "$DATA_DIR/test.html" "$DATA_DIR/index.html"
        safe_sudo chmod 644 "$DATA_DIR/test.html" "$DATA_DIR/index.html"
    fi
    
    rm -f "/tmp/test.html"
    print_status "success" "测试文件创建完成"
}

# 安装 Nginx 配置
install_nginx_config() {
    print_status "info" "安装 Nginx 配置..."
    
    local config_file="$PROJECT_ROOT/config/nginx.conf"
    
    if [ "$OS" = "Linux" ]; then
        # 删除现有符号链接（如果存在）
        if [ -L "/etc/nginx/sites-enabled/${SERVICE_NAME}" ]; then
            safe_sudo rm -f "/etc/nginx/sites-enabled/${SERVICE_NAME}"
        fi
        
        # 复制配置文件
        safe_sudo cp "$config_file" "/etc/nginx/sites-available/${SERVICE_NAME}"
        safe_sudo ln -sf "/etc/nginx/sites-available/${SERVICE_NAME}" "/etc/nginx/sites-enabled/"
        
        print_status "success" "配置文件已安装到 /etc/nginx/sites-available/${SERVICE_NAME}"
    elif [ "$OS" = "Mac" ]; then
        # macOS 通常使用不同的配置目录
        local nginx_conf_dir="/usr/local/etc/nginx"
        if [ -d "$nginx_conf_dir" ]; then
            safe_sudo cp "$config_file" "$nginx_conf_dir/servers/${SERVICE_NAME}.conf"
            print_status "success" "配置文件已安装到 $nginx_conf_dir/servers/${SERVICE_NAME}.conf"
        else
            print_status "warning" "未找到 Nginx 配置目录，请手动配置"
            echo "配置文件位置: $config_file"
        fi
    fi
}

# 测试和重载 Nginx 配置
reload_nginx() {
    print_status "info" "测试 Nginx 配置..."
    
    # 测试配置文件
    if safe_sudo nginx -t; then
        print_status "success" "配置文件测试通过"
        
        # 重载或启动 Nginx
        if [ "$OS" = "Linux" ]; then
            if safe_sudo systemctl is-active --quiet nginx; then
                print_status "info" "重载 Nginx 配置..."
                safe_sudo systemctl reload nginx
                print_status "success" "Nginx 配置重载完成"
            else
                print_status "info" "启动 Nginx 服务..."
                safe_sudo systemctl start nginx
                safe_sudo systemctl enable nginx
                print_status "success" "Nginx 服务启动完成"
            fi
        elif [ "$OS" = "Mac" ]; then
            if brew services list | grep -q "nginx.*started"; then
                print_status "info" "重载 Nginx 配置..."
                brew services reload nginx
                print_status "success" "Nginx 配置重载完成"
            else
                print_status "info" "启动 Nginx 服务..."
                brew services start nginx
                print_status "success" "Nginx 服务启动完成"
            fi
        fi
    else
        print_status "error" "Nginx 配置测试失败"
        print_status "info" "请检查配置文件: $PROJECT_ROOT/config/nginx.conf"
        exit 1
    fi
}

# 测试服务
test_nginx_service() {
    print_status "info" "测试 Nginx 服务..."
    
    # 等待服务启动
    sleep 3
    
    # 获取主机地址
    local external_host="${EXTERNAL_HOST:-localhost}"
    
    # 测试静态文件访问
    if curl -s -o /dev/null -w "%{http_code}" "http://${external_host}:${NGINX_PORT}/" | grep -q "200"; then
        print_status "success" "静态文件服务测试通过"
    else
        print_status "warning" "静态文件服务测试失败，请检查配置"
    fi
    
    # 测试代理服务（如果 API 服务正在运行）
    if curl -s -o /dev/null -w "%{http_code}" "http://${external_host}:${NGINX_PROXY_PORT}/api/health" | grep -q "200"; then
        print_status "success" "API 代理服务测试通过"
    else
        print_status "warning" "API 代理服务测试失败，请确保 API 服务正在运行"
    fi
}

# 显示访问信息
show_access_info() {
    local external_host="${EXTERNAL_HOST:-localhost}"
    
    print_status "info" "访问信息:"
    echo "  - 静态文件服务: http://${external_host}:${NGINX_PORT}/"
    echo "  - API 代理服务: http://${external_host}:${NGINX_PROXY_PORT}/"
    echo "  - 控制面板: http://${external_host}:${NGINX_PROXY_PORT}/dashboard/"
    echo "  - 测试页面: http://${external_host}:${NGINX_PORT}/test.html"
    echo "  - 数据目录: $DATA_DIR"
    echo "  - 日志目录: $LOG_DIR"
}

# 显示管理命令
show_management_commands() {
    print_status "info" "Nginx 管理命令:"
    
    local cmd_prefix=""
    if [[ $EUID -ne 0 ]]; then
        if [ "$HAS_SUDO" = "true" ]; then
            cmd_prefix="sudo "
        else
            cmd_prefix="(需要root权限) "
        fi
    fi
    
    if [ "$OS" = "Linux" ]; then
        echo "  - 查看状态: ${cmd_prefix}systemctl status nginx"
        echo "  - 启动服务: ${cmd_prefix}systemctl start nginx"
        echo "  - 停止服务: ${cmd_prefix}systemctl stop nginx"
        echo "  - 重启服务: ${cmd_prefix}systemctl restart nginx"
        echo "  - 重载配置: ${cmd_prefix}systemctl reload nginx"
        echo "  - 测试配置: ${cmd_prefix}nginx -t"
    elif [ "$OS" = "Mac" ]; then
        echo "  - 查看状态: brew services list | grep nginx"
        echo "  - 启动服务: brew services start nginx"
        echo "  - 停止服务: brew services stop nginx"
        echo "  - 重启服务: brew services restart nginx"
        echo "  - 重载配置: brew services reload nginx"
        echo "  - 测试配置: nginx -t"
    fi
}

# 主函数
main() {
    print_status "info" "开始配置 Nginx..."
    
    # 检查 Nginx 安装
    check_nginx_installation
    
    # 检查必需文件
    check_requirements
    
    # 安装 envsubst 工具
    install_envsubst
    
    # 生成配置文件
    generate_nginx_config
    
    # 配置静态文件权限
    setup_static_permissions
    
    # 创建测试文件
    create_test_files
    
    # 安装配置文件
    install_nginx_config
    
    # 重载 Nginx 配置
    reload_nginx
    
    # 测试服务
    test_nginx_service
    
    # 显示访问信息
    show_access_info
    
    # 显示管理命令
    show_management_commands
    
    print_status "success" "Nginx 配置完成！"
}

# 如果脚本直接执行，则运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
