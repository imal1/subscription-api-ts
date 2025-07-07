#!/bin/bash

# 环境检测和基础设置脚本
# 
# 功能:
# - 检测操作系统和用户权限
# - 设置环境变量和目录结构
# - 创建基础目录并设置权限
# 
# 参数:
# --skip-confirm  跳过用户确认（用于脚本间调用）

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 引入公共函数库
source "$SCRIPT_DIR/common.sh"

# 显示帮助信息
show_help() {
    echo "环境检测和基础设置脚本"
    echo ""
    echo "用法:"
    echo "  bash scripts/setup-env.sh [选项]"
    echo ""
    echo "选项:"
    echo "  --skip-confirm   跳过用户确认（用于脚本间调用）"
    echo "  --help, -h       显示此帮助信息"
    echo ""
}

# 处理参数
SKIP_CONFIRM=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-confirm)
            SKIP_CONFIRM=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

setup_environment() {
    echo "🔍 环境检测和设置..."
    
    # 使用公共函数检查用户权限
    if [ "$SKIP_CONFIRM" = true ]; then
        if ! check_user_permissions --skip-confirm; then
            echo "❌ 用户权限检查失败"
            exit 1
        fi
    else
        if ! check_user_permissions; then
            echo "❌ 用户权限检查失败"
            exit 1
        fi
    fi
    
    echo "🖥️  操作系统: $OS"
    echo "👤 当前用户: $CURRENT_USER"
    echo "🎯 目标用户: $TARGET_USER"
}

setup_directories() {
    echo "📁 设置目录结构..."
    
    # 加载配置文件
    load_config

    # 设置默认环境变量（使用公共函数）
    setup_default_env

    # 创建基础目录结构并设置权限
    echo "📁 创建基础目录结构..."
    mkdir -p "${BASE_DIR}/bin"
    mkdir -p "${BASE_DIR}/dist"
    mkdir -p "${BASE_DIR}/www"
    mkdir -p "${BASE_DIR}/log"

    # 设置基础目录权限
    if [ "$OS" != "UNKNOWN" ]; then
        # 确保用户对基础目录有完全控制权
        chmod 755 "${BASE_DIR}"
        chmod 755 "${BASE_DIR}/bin"
        chmod 755 "${BASE_DIR}/dist" 
        chmod 755 "${BASE_DIR}/www"
        chmod 755 "${BASE_DIR}/log"
        
        echo "   ✅ 基础目录权限设置完成"
    fi
    
    echo "   基础目录: ${BASE_DIR}"
    echo "   数据目录: ${DATA_DIR}"
    echo "   日志目录: ${LOG_DIR}"
    echo "   构建目录: ${DIST_DIR}"
    echo "   二进制目录: ${BASE_DIR}/bin"
}

clean_old_configs() {
    echo "🧹 清理旧配置文件..."
    
    if [ -f "$PROJECT_ROOT/.env" ]; then
        echo "  删除旧的 .env 文件"
        rm -f "$PROJECT_ROOT/.env"
    fi
    if [ -f "$PROJECT_ROOT/config/nginx.conf" ]; then
        echo "  删除旧的 nginx.conf 文件"
        rm -f "$PROJECT_ROOT/config/nginx.conf"
    fi
    if [ -f "$PROJECT_ROOT/config/subscription-api-ts.service" ]; then
        echo "  删除旧的 subscription-api-ts.service 文件"
        rm -f "$PROJECT_ROOT/config/subscription-api-ts.service"
    fi
}

# 主函数
main() {
    echo "🚀 开始环境设置..."
    echo "📍 项目目录: $PROJECT_ROOT"
    
    clean_old_configs
    setup_environment
    setup_directories
    
    echo "✅ 环境设置完成！"
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
