#!/bin/bash

# Subscription API TypeScript 统一管理脚本
# 这是一个集成了所有功能的管理脚本，替代原有的多个脚本文件

set -e

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 导入函数库
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/system.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/service.sh"
source "$SCRIPT_DIR/lib/install.sh"
source "$SCRIPT_DIR/lib/build.sh"

# 显示帮助信息
show_help() {
    show_header "Subscription API TypeScript 管理工具"
    show_version
    
    echo "用法: $0 <命令> [选项]"
    echo ""
    echo "环境管理:"
    echo "  init           初始化项目环境"
    echo "  setup          完整安装配置"
    echo "  env            显示环境信息"
    echo "  config         显示配置信息"
    echo ""
    echo "构建相关:"
    echo "  build          构建项目 (后端+前端)"
    echo "  build-backend  仅构建后端"
    echo "  build-frontend 仅构建前端"
    echo "  clean          清理构建文件"
    echo ""
    echo "服务管理: (仅 Linux)"
    echo "  start          启动服务"
    echo "  stop           停止服务"
    echo "  restart        重启服务"
    echo "  status         查看服务状态"
    echo "  logs           查看服务日志"
    echo "  logs-f         实时跟踪日志"
    echo ""
    echo "维护工具:"
    echo "  update         更新项目"
    echo "  backup         备份配置"
    echo "  check          系统检查"
    echo "  verify         验证权限"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -v, --version  显示版本信息"
    echo "  -q, --quiet    静默模式"
    echo "  -y, --yes      自动确认"
    echo ""
    echo "示例:"
    echo "  $0 setup              # 完整安装"
    echo "  $0 build              # 构建项目"
    echo "  sudo $0 restart       # 重启服务"
    echo "  $0 logs -f            # 实时日志"
}

# 初始化环境
cmd_init() {
    print_status "info" "初始化项目环境..."
    
    # 检查系统
    check_system
    check_dependencies
    
    # 设置环境
    setup_env
    
    # 创建配置文件
    if [ ! -f "$CONFIG_FILE" ]; then
        create_config
    fi
    
    print_status "success" "环境初始化完成"
}

# 完整安装
cmd_setup() {
    print_status "info" "开始完整安装..."
    
    # 初始化环境
    cmd_init
    
    # 安装二进制文件
    install_binaries
    
    # 构建项目
    build_all
    
    # Linux 系统配置服务
    if [ "$OS" = "linux" ]; then
        setup_systemd_service
    fi
    
    print_status "success" "完整安装完成"
    show_completion_info
}

# 设置 systemd 服务
setup_systemd_service() {
    if [ "$OS" != "linux" ]; then
        return 0
    fi
    
    print_status "info" "配置 systemd 服务..."
    
    local service_name="subscription-api-ts"
    local service_file="/etc/systemd/system/${service_name}.service"
    
    # 创建服务文件
    safe_sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=Subscription API TypeScript Service
After=network.target

[Service]
Type=simple
User=$TARGET_USER
Group=$TARGET_GROUP
WorkingDirectory=$PROJECT_ROOT
ExecStart=$BIN_DIR/bun run start
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=CONFIG_FILE=$CONFIG_FILE

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载配置
    systemd_reload
    
    # 启用服务
    service_enable "$service_name"
    
    print_status "success" "systemd 服务配置完成"
}

# 显示环境信息
cmd_env() {
    print_status "info" "系统环境信息:"
    echo "  操作系统: $OS"
    echo "  系统架构: $ARCH"
    echo "  当前用户: $CURRENT_USER"
    echo "  目标用户: $TARGET_USER"
    echo ""
    echo "  项目目录: $PROJECT_ROOT"
    echo "  基础目录: $BASE_DIR"
    echo "  配置文件: $CONFIG_FILE"
    echo "  二进制目录: $BIN_DIR"
    echo "  构建目录: $DIST_DIR"
    echo "  数据目录: $DATA_DIR"
    echo "  日志目录: $LOG_DIR"
}

# 显示配置信息
cmd_config() {
    if [ -f "$CONFIG_FILE" ]; then
        print_status "info" "配置文件: $CONFIG_FILE"
        if load_config; then
            echo "  应用名称: ${APP_NAME:-未设置}"
            echo "  应用版本: ${APP_VERSION:-未设置}"
            echo "  监听端口: ${PORT:-未设置}"
            echo "  运行环境: ${NODE_ENV:-未设置}"
        fi
    else
        print_status "warning" "配置文件不存在"
    fi
}

# 系统检查
cmd_check() {
    print_status "info" "系统检查..."
    
    # 检查系统环境
    check_system
    check_dependencies
    
    # 检查二进制文件
    if [ -f "$BIN_DIR/bun" ]; then
        print_status "success" "bun: $($BIN_DIR/bun --version)"
    else
        print_status "warning" "bun 未安装"
    fi
    
    if [ -f "$BIN_DIR/mihomo" ]; then
        print_status "success" "mihomo: 已安装"
    else
        print_status "warning" "mihomo 未安装"
    fi
    
    # 检查构建文件
    if [ -f "$PROJECT_ROOT/dist/index.js" ]; then
        print_status "success" "后端构建文件存在"
    else
        print_status "warning" "后端构建文件不存在"
    fi
    
    if [ -f "$PROJECT_ROOT/frontend/dist/index.html" ]; then
        print_status "success" "前端构建文件存在"
    else
        print_status "warning" "前端构建文件不存在"
    fi
    
    # 检查服务状态 (Linux)
    if [ "$OS" = "linux" ]; then
        local service_name="subscription-api-ts"
        if service_is_running "$service_name"; then
            print_status "success" "服务正在运行"
        else
            print_status "warning" "服务未运行"
        fi
    fi
}

# 权限验证
cmd_verify() {
    print_status "info" "验证文件权限..."
    
    local issues=0
    
    # 检查关键目录权限
    local dirs=("$BASE_DIR" "$BIN_DIR" "$DIST_DIR" "$DATA_DIR" "$LOG_DIR")
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            if [ -r "$dir" ] && [ -w "$dir" ]; then
                print_status "success" "目录权限正常: $dir"
            else
                print_status "error" "目录权限异常: $dir"
                ((issues++))
            fi
        fi
    done
    
    # 检查二进制文件权限
    local binaries=("$BIN_DIR/bun" "$BIN_DIR/mihomo")
    for binary in "${binaries[@]}"; do
        if [ -f "$binary" ]; then
            if [ -x "$binary" ]; then
                print_status "success" "二进制文件权限正常: $binary"
            else
                print_status "error" "二进制文件权限异常: $binary"
                ((issues++))
            fi
        fi
    done
    
    if [ $issues -eq 0 ]; then
        print_status "success" "所有权限验证通过"
        return 0
    else
        print_status "error" "发现 $issues 个权限问题"
        return 1
    fi
}

# 显示完成信息
show_completion_info() {
    echo ""
    print_status "success" "🎉 安装完成！"
    echo ""
    
    # 加载配置获取端口信息
    load_config 2>/dev/null || true
    
    local api_port="${PORT:-3000}"
    local host="localhost"
    
    echo "🚀 快速开始:"
    if [ "$OS" = "linux" ]; then
        echo "  启动服务: sudo systemctl start subscription-api-ts"
        echo "  查看状态: sudo systemctl status subscription-api-ts"
        echo "  查看日志: sudo journalctl -u subscription-api-ts -f"
    else
        echo "  启动服务: cd $PROJECT_ROOT && bun run start"
    fi
    
    echo "  访问 API: http://$host:$api_port"
    echo "  生成订阅: http://$host:$api_port/api/update"
    echo ""
    
    echo "🔧 管理命令:"
    echo "  $0 build         # 重新构建"
    echo "  $0 restart       # 重启服务"
    echo "  $0 logs          # 查看日志"
    echo "  $0 check         # 系统检查"
    echo ""
}

# 主函数
main() {
    # 初始化系统检查
    check_system
    setup_env
    
    # 解析命令
    local command="${1:-help}"
    shift 2>/dev/null || true
    
    case "$command" in
        init)
            cmd_init "$@"
            ;;
        setup)
            cmd_setup "$@"
            ;;
        env)
            cmd_env "$@"
            ;;
        config)
            cmd_config "$@"
            ;;
        build)
            build_all "$@"
            ;;
        build-backend)
            build_backend "$@"
            ;;
        build-frontend)
            build_frontend "$@"
            ;;
        clean)
            clean_build "$@"
            ;;
        start)
            service_start "subscription-api-ts"
            ;;
        stop)
            service_stop "subscription-api-ts"
            ;;
        restart)
            service_restart "subscription-api-ts"
            ;;
        status)
            service_status "subscription-api-ts"
            ;;
        logs)
            if [ "$1" = "-f" ]; then
                service_logs_follow "subscription-api-ts"
            else
                service_logs "subscription-api-ts" "${1:-50}"
            fi
            ;;
        logs-f)
            service_logs_follow "subscription-api-ts"
            ;;
        check)
            cmd_check "$@"
            ;;
        verify)
            cmd_verify "$@"
            ;;
        update)
            print_status "info" "更新功能开发中..."
            ;;
        backup)
            print_status "info" "备份功能开发中..."
            ;;
        help|--help|-h)
            show_help
            ;;
        version|--version|-v)
            show_version
            ;;
        *)
            print_status "error" "未知命令: $command"
            echo "使用 '$0 help' 查看帮助信息"
            exit 1
            ;;
    esac
}

# 如果脚本被直接执行，则运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
