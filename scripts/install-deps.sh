#!/bin/bash

# 依赖安装脚本
# 负责安装 Node.js 和项目依赖

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 引入公共函数库
source "$SCRIPT_DIR/common.sh"

# 显示标题
show_header "依赖安装"

# 加载环境变量
load_config

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

print_status "info" "当前用户: $CURRENT_USER"
print_status "info" "目标用户: $TARGET_USER"

# 安装 Node.js（如果未安装）
install_nodejs() {
    print_status "info" "检查 Node.js 安装状态..."
    
    if command_exists node; then
        local node_version=$(node --version)
        print_status "success" "Node.js 已安装: $node_version"
        return 0
    fi
    
    print_status "info" "安装 Node.js..."
    
    if [ "$OS" = "Linux" ]; then
        # 使用 NodeSource 仓库安装 Node.js 18.x
        print_status "info" "添加 NodeSource 仓库..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | safe_sudo bash -
        
        print_status "info" "安装 Node.js 包..."
        safe_sudo apt-get install -y nodejs
        
    elif [ "$OS" = "Mac" ]; then
        if command_exists brew; then
            print_status "info" "使用 Homebrew 安装 Node.js..."
            brew install node
        else
            print_status "error" "未找到 Homebrew，请先安装："
            echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            echo "   或访问 https://nodejs.org/ 手动下载安装"
            exit 1
        fi
    else
        print_status "error" "不支持的操作系统: $OS"
        exit 1
    fi
    
    # 验证安装
    if command_exists node; then
        local node_version=$(node --version)
        print_status "success" "Node.js 安装成功: $node_version"
    else
        print_status "error" "Node.js 安装失败"
        exit 1
    fi
}

# 安装项目依赖
install_project_deps() {
    print_status "info" "安装项目依赖..."
    
    # 检测 bun 命令
    local bun_cmd=$(detect_bun)
    if [ -z "$bun_cmd" ]; then
        # 尝试使用全局或二进制目录中的 bun
        if [ -n "$BUN_BINARY" ] && [ -f "$BUN_BINARY" ]; then
            bun_cmd="$BUN_BINARY"
        elif [ -f "${BASE_DIR}/bin/bun" ]; then
            bun_cmd="${BASE_DIR}/bin/bun"
        else
            print_status "error" "未找到 bun 命令"
            echo "请先运行 scripts/install-binaries.sh 安装 bun"
            exit 1
        fi
    fi
    
    print_status "info" "使用 bun: $($bun_cmd --version)"
    
    # 切换到项目根目录
    cd "$PROJECT_ROOT"
    
    # 安装依赖的函数
    local install_success=false
    
    # 根据用户权限选择安装方式
    if [[ $EUID -eq 0 ]] && [ "$OS" = "Linux" ]; then
        # root 用户执行时，确保文件权限正确
        safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$PROJECT_ROOT"
        
        if [ "$TARGET_USER" != "root" ]; then
            print_status "info" "使用用户 $TARGET_USER 安装依赖..."
            if safe_sudo_user "$TARGET_USER" "$bun_cmd" install --dev; then
                install_success=true
            fi
        else
            if "$bun_cmd" install --dev; then
                install_success=true
            fi
        fi
    else
        if "$bun_cmd" install --dev; then
            install_success=true
        fi
    fi
    
    if [ "$install_success" = false ]; then
        print_status "error" "依赖安装失败"
        exit 1
    fi
    
    print_status "success" "依赖安装成功"
}

# 验证依赖安装
verify_deps() {
    print_status "info" "验证依赖安装..."
    
    local missing_deps=""
    local required_deps=(
        "node_modules/@types/express"
        "node_modules/@types/cors"
        "node_modules/@types/compression"
        "node_modules/@types/node-cron"
        "node_modules/@types/node"
        "node_modules/@types/fs-extra"
        "node_modules/typescript"
    )
    
    for dep in "${required_deps[@]}"; do
        if [ ! -d "$PROJECT_ROOT/$dep" ]; then
            missing_deps="$missing_deps $(basename $dep)"
        fi
    done
    
    if [ -n "$missing_deps" ]; then
        print_status "error" "缺少依赖:$missing_deps"
        print_status "info" "重新安装缺少的依赖..."
        
        # 重新安装
        install_project_deps
        
        # 再次验证
        missing_deps=""
        for dep in "${required_deps[@]}"; do
            if [ ! -d "$PROJECT_ROOT/$dep" ]; then
                missing_deps="$missing_deps $(basename $dep)"
            fi
        done
        
        if [ -n "$missing_deps" ]; then
            print_status "error" "重新安装后仍缺少依赖:$missing_deps"
            exit 1
        fi
    fi
    
    print_status "success" "所有依赖验证通过"
}

# 检查并安装 TypeScript 工具
install_typescript_tools() {
    print_status "info" "检查 TypeScript 工具..."
    
    if [ -f "$PROJECT_ROOT/node_modules/.bin/tsc" ] && [ -f "$PROJECT_ROOT/node_modules/.bin/ts-node" ]; then
        print_status "success" "使用项目本地的 TypeScript 工具"
    else
        print_status "info" "安装全局 TypeScript 工具..."
        
        local bun_cmd=$(detect_bun)
        if [ -z "$bun_cmd" ]; then
            if [ -n "$BUN_BINARY" ] && [ -f "$BUN_BINARY" ]; then
                bun_cmd="$BUN_BINARY"
            elif [ -f "${BASE_DIR}/bin/bun" ]; then
                bun_cmd="${BASE_DIR}/bin/bun"
            else
                print_status "error" "未找到 bun 命令"
                exit 1
            fi
        fi
        
        if [ "$OS" = "Linux" ]; then
            if [[ $EUID -eq 0 ]]; then
                "$bun_cmd" add -g typescript ts-node pm2
            else
                safe_sudo "$bun_cmd" add -g typescript ts-node pm2
            fi
        elif [ "$OS" = "Mac" ]; then
            "$bun_cmd" add -g typescript ts-node pm2
        fi
        
        print_status "success" "TypeScript 工具安装完成"
    fi
}

# 主函数
main() {
    print_status "info" "开始安装依赖..."
    
    # 安装 Node.js
    install_nodejs
    
    # 安装项目依赖
    install_project_deps
    
    # 验证依赖
    verify_deps
    
    # 安装 TypeScript 工具
    install_typescript_tools
    
    print_status "success" "所有依赖安装完成！"
}

# 如果脚本直接执行，则运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
