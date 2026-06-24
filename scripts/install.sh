#!/bin/bash

# 快速安装脚本
# 这是一个简化的安装入口，调用统一管理脚本

set -e

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检查管理脚本是否存在
MANAGE_SCRIPT="$SCRIPT_DIR/manage.sh"
if [ ! -f "$MANAGE_SCRIPT" ]; then
    echo "❌ 错误：管理脚本不存在: $MANAGE_SCRIPT"
    exit 1
fi

# 显示欢迎信息
echo "🚀 MioBridge 快速安装"
echo "版本: $(cd "$SCRIPT_DIR/.." && grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' package.json | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || echo "未知")"
echo ""

# 执行完整安装
echo "正在执行完整安装..."
bash "$MANAGE_SCRIPT" setup

echo ""
echo "✅ 安装完成！"
echo ""
echo "使用 'bash scripts/manage.sh help' 查看所有可用命令"

# 检查是否有旧脚本需要清理
if [ -f "$SCRIPT_DIR/common.sh" ] && [ $(wc -l < "$SCRIPT_DIR/common.sh") -gt 100 ]; then
    echo ""
    echo "⚠️  检测到旧版本脚本文件"
    echo "运行 'bash scripts/migrate.sh' 进行清理和迁移"
fi

# 清理旧配置
cleanup_old_config() {
    print_status "info" "清理旧配置文件..."

    # 检查 config.yaml 文件是否存在，如果存在则询问用户
    if [ -f "$BASE_DIR/config.yaml" ]; then
        print_status "warning" "发现现有的 config.yaml 配置文件"
        echo ""
        echo "删除现有配置文件将重置所有自定义设置为默认值。"
        echo "如果你有重要的自定义配置，请先手动备份。"
        echo ""
        
        read -p "是否删除现有的 config.yaml 文件并创建新配置？(y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f "$BASE_DIR/config.yaml"
            print_status "success" "config.yaml 文件已删除，将创建新的配置文件"
        else
            print_status "info" "保留现有的 config.yaml 文件"
            print_status "warning" "注意: 现有配置可能与新版本不兼容，如遇问题请手动更新配置"
        fi
    fi
    
    # 删除其他旧的配置文件（不需要用户确认）
    local other_files_to_remove=(
        "$PROJECT_ROOT/config/nginx.conf"
        "$PROJECT_ROOT/config/miobridge.service"
    )
    
    for file in "${other_files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            print_status "info" "删除旧配置: $(basename "$file")"
            rm -f "$file"
        fi
    done
    
    print_status "success" "旧配置清理完成"
}

# 创建 YAML 配置文件
create_yaml_config() {
    print_status "info" "创建 YAML 配置文件..."
    
    local config_path="$BASE_DIR/config.yaml"
    
    # 确保 BASE_DIR 存在
    mkdir -p "$BASE_DIR"
    
    if [ ! -f "$config_path" ]; then
        # 创建新的配置文件
        if [ -f "$PROJECT_ROOT/config.yaml.example" ]; then
            cp "$PROJECT_ROOT/config.yaml.example" "$config_path"
            print_status "success" "已从示例文件创建配置文件: $config_path"
        else
            print_status "error" "找不到 config.yaml.example 文件"
            return 1
        fi
    else
        print_status "info" "配置文件已存在: $config_path"
    fi
}

# 更新 YAML 配置文件（在二进制文件安装后）
update_yaml_config() {
    print_status "info" "更新 YAML 配置文件..."
    
    local config_path="$BASE_DIR/config.yaml"
    
    if [ ! -f "$config_path" ]; then
        print_status "warning" "配置文件不存在，跳过更新"
        return 0
    fi
    
    # 尝试使用 yq 工具更新配置文件
    local yq_available=false
    if command -v yq >/dev/null 2>&1; then
        yq_available=true
        print_status "info" "使用系统 yq 工具更新配置文件..."
    elif [ -f "$BASE_DIR/bin/yq" ]; then
        export PATH="$BASE_DIR/bin:$PATH"
        yq_available=true
        print_status "info" "使用本地 yq 工具更新配置文件..."
    else
        print_status "warning" "未找到 yq 工具，跳过配置更新"
        return 0
    fi
    
    if [ "$yq_available" = "true" ]; then
        # 更新目录配置
        if [ -n "$BASE_DIR" ]; then
            yq eval '.directories.base_dir = "'$BASE_DIR'"' -i "$config_path" 2>/dev/null || true
        fi
        if [ -n "$DATA_DIR" ]; then
            yq eval '.directories.data_dir = "'$DATA_DIR'"' -i "$config_path" 2>/dev/null || true
        fi
        if [ -n "$LOG_DIR" ]; then
            yq eval '.directories.log_dir = "'$LOG_DIR'"' -i "$config_path" 2>/dev/null || true
        fi
        if [ -n "$DIST_DIR" ]; then
            yq eval '.directories.dist_dir = "'$DIST_DIR'"' -i "$config_path" 2>/dev/null || true
        fi
        
        # 更新二进制文件路径
        if [ -n "$BASE_DIR" ]; then
            yq eval '.binaries.mihomo_path = "'$BASE_DIR'/bin/mihomo"' -i "$config_path" 2>/dev/null || true
            yq eval '.binaries.bun_path = "'$BASE_DIR'/bin/bun"' -i "$config_path" 2>/dev/null || true
        fi
        
        print_status "success" "配置文件已更新"
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
    # 加载配置
    load_config
    
    # 设置主机地址
    local external_host="${EXTERNAL_HOST:-localhost}"
    local api_port="${PORT:-3000}"
    local nginx_proxy_port="${NGINX_PROXY_PORT:-3888}"
    
    print_status "success" "安装完成！"
    
    echo ""
    print_status "info" "🚀 快速开始："
    
    if [ "$OS" = "Linux" ]; then
        echo "1. 生成订阅文件: curl http://${external_host}:${nginx_proxy_port}/api/update"
        echo "2. 访问控制面板(SSR): http://${external_host}:${nginx_proxy_port}/"
        
        local service_name="${SERVICE_NAME:-miobridge}"
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
        echo "1. 本地开发: cd frontend && bun run dev  (next dev :3001)"
        echo "2. 生成订阅: curl http://${external_host}:${api_port}/api/update"
        echo "3. 访问控制面板(SSR): http://${external_host}:${api_port}/"
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
    echo "   YAML 配置: $BASE_DIR/config.yaml"
    echo "   数据目录: $DATA_DIR"
    echo "   日志目录: $LOG_DIR"
    echo "   构建目录: $DIST_DIR"
    
    echo ""
    print_status "info" "🆘 故障排除："
    echo "   如遇到问题，请检查："
    echo "   1. 权限问题: bash scripts/verify-permissions.sh"
    echo "   2. 服务日志: journalctl -u miobridge -f"
    echo "   3. 配置文件: cat $BASE_DIR/config.yaml"
    echo "   4. 端口占用: netstat -tlnp | grep :$nginx_proxy_port"
}

# 主安装流程
main() {
    print_status "info" "开始模块化安装流程..."
    
    # 清理旧配置
    cleanup_old_config
    
    # 步骤1: 环境设置
    print_status "info" "第 1 步: 环境设置和目录创建"
    local script_path="$SCRIPT_DIR/setup-env.sh"
    if [ ! -f "$script_path" ]; then
        print_status "error" "脚本不存在: $script_path"
        exit 1
    fi
    
    if ! bash "$script_path" --skip-confirm; then
        print_status "error" "环境设置和目录创建 失败"
        exit 1
    fi
    
    print_status "success" "环境设置和目录创建 完成"
    
    # 创建初始 YAML 配置文件
    create_yaml_config
    
    # 步骤2: 安装二进制文件
    run_install_step "2" "install-binaries.sh" "二进制文件安装"
    
    # 更新 YAML 配置文件（在二进制文件安装后）
    update_yaml_config
    
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
    
    print_status "success" "🎉 MioBridge 安装完成！"
}

# 显示帮助信息
show_help() {
    echo "MioBridge 安装脚本"
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
