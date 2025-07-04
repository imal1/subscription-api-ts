#!/bin/bash

# 环境检测和基础设置脚本
# 
# 功能:
# - 检测操作系统和用户权限
# - 设置环境变量和目录结构
# - 创建基础目录并设置权限

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 引入公共函数库
source "$SCRIPT_DIR/common.sh"

setup_environment() {
    echo "🔍 环境检测和设置..."
    
    # 检测操作系统
    OS=""
    case "$(uname -s)" in
        Linux*)     OS=Linux;;
        Darwin*)    OS=Mac;;
        *)          OS="UNKNOWN";;
    esac

    echo "🖥️  操作系统: $OS"

    if [ "$OS" = "UNKNOWN" ]; then
        echo "❌ 不支持的操作系统"
        exit 1
    fi

    # 检查用户权限
    CURRENT_USER=$(whoami)
    if [[ $EUID -eq 0 ]]; then
        echo "⚠️  检测到 root 用户执行"
        if [ "$OS" = "Linux" ]; then
            echo "✅ Linux 环境下允许 root 用户执行"
            # 在 Linux 下以 root 执行时，检查是否指定了目标用户
            if [ -z "$SUDO_USER" ]; then
                echo "⚠️  建议使用 sudo 执行此脚本以保留原用户信息"
                echo "   例如: sudo bash scripts/install.sh"
                read -p "是否继续以 root 用户安装? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo "❌ 安装已取消"
                    exit 1
                fi
                TARGET_USER="root"
                TARGET_GROUP="root"
            else
                # 使用 sudo 执行时，使用原用户
                TARGET_USER="$SUDO_USER"
                TARGET_GROUP="$(id -gn $SUDO_USER)"
                echo "🎯 目标用户: $TARGET_USER"
            fi
        else
            echo "❌ macOS 环境下请不要使用 root 用户运行此脚本"
            exit 1
        fi
    else
        TARGET_USER="$CURRENT_USER"
        TARGET_GROUP="$(id -gn $CURRENT_USER)"
    fi

    echo "👤 当前用户: $CURRENT_USER"
    echo "🎯 目标用户: $TARGET_USER"
    
    # 导出变量供其他脚本使用
    export OS TARGET_USER TARGET_GROUP CURRENT_USER
}

setup_directories() {
    echo "📁 设置目录结构..."
    
    # 读取环境变量文件
    if [ -f "$PROJECT_ROOT/.env" ]; then
        echo "📋 加载环境变量..."
        # 读取 .env 文件，忽略注释和空行
        while IFS='=' read -r key value; do
            # 跳过注释和空行
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z $key ]] && continue
            # 移除引号
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"
            # 设置环境变量
            export "$key"="$value"
        done < <(grep -v '^[[:space:]]*#' "$PROJECT_ROOT/.env" | grep -v '^[[:space:]]*$')
    fi

    # 设置默认值 - 统一使用 $HOME/.config/subscription 下的目录
    export BASE_DIR="${BASE_DIR:-$HOME/.config/subscription}"
    export DATA_DIR="${DATA_DIR:-${BASE_DIR}/www}"
    export LOG_DIR="${LOG_DIR:-${BASE_DIR}/log}"
    export DIST_DIR="${DIST_DIR:-${BASE_DIR}/dist}"
    export MIHOMO_PATH="${MIHOMO_PATH:-${BASE_DIR}/bin}"
    export BUN_PATH="${BUN_PATH:-${BASE_DIR}/bin}"
    export NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"

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
