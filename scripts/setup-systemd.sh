#!/bin/bash

# systemd 服务配置脚本
# 负责生成和安装 systemd 服务文件（仅适用于 Linux）

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 引入公共函数库
source "$SCRIPT_DIR/common.sh"

# 显示标题
show_header "systemd 服务配置"

# 配置变量（不再从环境文件加载）
# 现在所有配置都基于 config.yaml

# 检测操作系统
OS=$(detect_os)
if [ "$OS" != "Linux" ]; then
    print_status "error" "systemd 服务配置仅适用于 Linux 系统"
    exit 1
fi

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

print_status "info" "当前用户: $CURRENT_USER"
print_status "info" "目标用户: $TARGET_USER"

# 设置目录变量（使用公共函数）
setup_default_env

# 服务名称
SERVICE_NAME="subscription-api-ts"

# 检查必需文件和目录
check_service_requirements() {
    print_status "info" "检查服务配置要求..."
    
    # 检查项目目录
    check_required_dir "$PROJECT_ROOT" "项目根目录"
    
    # 检查构建文件
    check_required_file "$PROJECT_ROOT/dist/index.js" "后端构建文件"
    
    # 检查配置文件
    check_required_file "$PROJECT_ROOT/config.yaml" "配置文件"
    
    # 检查服务模板文件
    check_required_file "$PROJECT_ROOT/config/subscription-api-ts.service.template" "服务模板文件"
    
    # 检查 Node.js
    if ! command_exists node; then
        print_status "error" "未找到 Node.js"
        exit 1
    fi
    
    local node_path=$(which node)
    print_status "info" "Node.js 路径: $node_path"
    
    # 检查并修复 Node.js 路径问题
    if [[ "$node_path" == *".local"* ]] || [[ "$node_path" == *"/run/user/"* ]]; then
        print_status "warning" "检测到用户环境路径，检查系统路径..."
        
        # 检查系统路径是否已有 Node.js
        local system_node=""
        for path in "/usr/bin/node" "/usr/local/bin/node"; do
            if [ -f "$path" ] && [ -x "$path" ]; then
                system_node="$path"
                break
            fi
        done
        
        if [ -z "$system_node" ]; then
            print_status "info" "复制 Node.js 到系统路径..."
            if [[ $EUID -eq 0 ]]; then
                safe_sudo cp "$node_path" /usr/local/bin/node
                safe_sudo chmod +x /usr/local/bin/node
                print_status "success" "Node.js 已复制到 /usr/local/bin/node"
            else
                if safe_sudo cp "$node_path" /usr/local/bin/node && safe_sudo chmod +x /usr/local/bin/node; then
                    print_status "success" "Node.js 已复制到 /usr/local/bin/node"
                else
                    print_status "error" "复制失败，请手动执行："
                    echo "  sudo cp $node_path /usr/local/bin/node"
                    echo "  sudo chmod +x /usr/local/bin/node"
                    exit 1
                fi
            fi
            export NODE_PATH="/usr/local/bin/node"
        else
            print_status "success" "使用系统 Node.js: $system_node"
            export NODE_PATH="$system_node"
        fi
    else
        export NODE_PATH="$node_path"
        print_status "success" "使用系统 Node.js 路径"
    fi
}

# 检查用户权限
check_user_permissions() {
    print_status "info" "检查用户权限..."
    
    # 获取项目绝对路径
    local absolute_project_root="$(cd "$PROJECT_ROOT" && pwd)"
    
    # 验证目标用户对项目目录的访问权限
    if ! safe_sudo_user "$TARGET_USER" test -r "$absolute_project_root"; then
        print_status "warning" "用户 $TARGET_USER 无法访问项目目录，调整权限..."
        if [[ $EUID -eq 0 ]]; then
            safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$absolute_project_root"
            safe_sudo chmod -R u+rX "$absolute_project_root"
        else
            safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$absolute_project_root"
            safe_sudo chmod -R u+rX "$absolute_project_root"
        fi
        print_status "success" "项目目录权限已调整"
    fi
    
    # 验证数据目录权限
    if [ -d "$DATA_DIR" ]; then
        local test_file="$DATA_DIR/.write_test_$$"
        if ! safe_sudo_user "$TARGET_USER" touch "$test_file" 2>/dev/null; then
            print_status "warning" "数据目录写入权限异常，尝试修复..."
            if [[ $EUID -eq 0 ]]; then
                safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$DATA_DIR"
                safe_sudo chmod -R 750 "$DATA_DIR"
                safe_sudo find "$DATA_DIR" -type d -exec chmod 750 {} \;
                safe_sudo find "$DATA_DIR" -type f -exec chmod 640 {} \; 2>/dev/null || true
            else
                safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$DATA_DIR"
                safe_sudo chmod -R 750 "$DATA_DIR"
                safe_sudo find "$DATA_DIR" -type d -exec chmod 750 {} \; 2>/dev/null || true
                safe_sudo find "$DATA_DIR" -type f -exec chmod 640 {} \; 2>/dev/null || true
            fi
            
            # 再次测试
            if safe_sudo_user "$TARGET_USER" touch "$test_file" 2>/dev/null; then
                safe_sudo_user "$TARGET_USER" rm -f "$test_file" 2>/dev/null || true
                print_status "success" "数据目录权限修复成功"
            else
                print_status "error" "数据目录权限修复失败"
                exit 1
            fi
        else
            safe_sudo_user "$TARGET_USER" rm -f "$test_file" 2>/dev/null || true
            print_status "success" "数据目录权限正常"
        fi
    fi
}

# 生成服务文件
generate_service_file() {
    print_status "info" "生成 systemd 服务文件..."
    
    # 检查并安装 envsubst
    if ! command_exists envsubst; then
        print_status "info" "安装 envsubst 工具..."
        if [[ $EUID -eq 0 ]]; then
            safe_sudo apt-get update && safe_sudo apt-get install -y gettext-base
        else
            safe_sudo apt-get update && safe_sudo apt-get install -y gettext-base
        fi
    fi
    
    # 设置环境变量供 envsubst 使用
    export SERVICE_USER="$TARGET_USER"
    export SERVICE_GROUP="$TARGET_GROUP"
    export INSTALL_DIR="$(cd "$PROJECT_ROOT" && pwd)"
    export NODE_PATH
    export DATA_DIR
    export LOG_DIR
    export DIST_DIR
    export BASE_DIR
    export BUN_PATH
    
    # 生成服务文件
    local service_template="$PROJECT_ROOT/config/subscription-api-ts.service.template"
    local service_output="/tmp/${SERVICE_NAME}.service"
    
    print_status "info" "服务配置:"
    echo "  - 服务名称: $SERVICE_NAME"
    echo "  - 项目目录: $INSTALL_DIR"
    echo "  - 运行用户: $SERVICE_USER"
    echo "  - 运行组: $SERVICE_GROUP"
    echo "  - Node.js 路径: $NODE_PATH"
    echo "  - 数据目录: $DATA_DIR"
    echo "  - 日志目录: $LOG_DIR"
    
    # 使用 envsubst 生成服务文件
    envsubst '${SERVICE_USER} ${SERVICE_GROUP} ${INSTALL_DIR} ${NODE_PATH} ${DATA_DIR} ${LOG_DIR} ${DIST_DIR} ${BASE_DIR} ${BUN_PATH}' < "$service_template" > "$service_output"
    
    if [ -f "$service_output" ]; then
        print_status "success" "服务文件已生成: $service_output"
    else
        print_status "error" "服务文件生成失败"
        exit 1
    fi
    
    export SERVICE_OUTPUT="$service_output"
}

# 安装服务文件
install_service_file() {
    print_status "info" "安装服务文件..."
    
    # 复制服务文件到系统目录
    safe_sudo cp "$SERVICE_OUTPUT" "/etc/systemd/system/"
    
    # 重新加载 systemd 配置
    systemd_reload
    
    # 启用服务
    service_enable "$SERVICE_NAME"
    
    print_status "success" "服务文件已安装: /etc/systemd/system/${SERVICE_NAME}.service"
}

# 管理服务状态
manage_service() {
    print_status "info" "管理服务状态..."
    
    # 检查服务是否已在运行
    if service_is_active "$SERVICE_NAME"; then
        print_status "info" "服务正在运行，重启以加载新配置..."
        service_restart "$SERVICE_NAME"
        print_status "success" "服务重启成功"
    else
        print_status "info" "服务未运行，启动服务..."
        service_start "$SERVICE_NAME"
        print_status "success" "服务启动成功"
    fi
}

# 验证服务状态
verify_service() {
    print_status "info" "验证服务状态..."
    
    # 等待服务启动
    sleep 3
    
    # 检查服务状态
    if service_is_active "$SERVICE_NAME"; then
        print_status "success" "服务运行正常"
        
        # 显示服务状态
        print_status "info" "服务状态:"
        service_status "$SERVICE_NAME" || true
    else
        print_status "error" "服务启动失败"
        print_status "info" "检查服务日志:"
        safe_sudo journalctl -u "$SERVICE_NAME" -n 20 --no-pager || true
        exit 1
    fi
}

# 显示管理命令
show_management_commands() {
    print_status "info" "服务管理命令:"
    
    local cmd_prefix=""
    if [[ $EUID -ne 0 ]]; then
        if [ "$HAS_SUDO" = "true" ]; then
            cmd_prefix="sudo "
        else
            cmd_prefix="(需要root权限) "
        fi
    fi
    
    echo "  - 查看状态: ${cmd_prefix}systemctl status $SERVICE_NAME"
    echo "  - 查看日志: ${cmd_prefix}journalctl -u $SERVICE_NAME -f"
    echo "  - 启动服务: ${cmd_prefix}systemctl start $SERVICE_NAME"
    echo "  - 停止服务: ${cmd_prefix}systemctl stop $SERVICE_NAME"
    echo "  - 重启服务: ${cmd_prefix}systemctl restart $SERVICE_NAME"
    echo "  - 重新加载配置: ${cmd_prefix}systemctl reload $SERVICE_NAME"
}

# 主函数
main() {
    print_status "info" "开始配置 systemd 服务..."
    
    # 检查服务配置要求
    check_service_requirements
    
    # 检查用户权限
    check_user_permissions
    
    # 生成服务文件
    generate_service_file
    
    # 安装服务文件
    install_service_file
    
    # 管理服务状态
    manage_service
    
    # 验证服务状态
    verify_service
    
    # 显示管理命令
    show_management_commands
    
    print_status "success" "systemd 服务配置完成！"
}

# 如果脚本直接执行，则运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
