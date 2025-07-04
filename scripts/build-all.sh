#!/bin/bash

# 项目构建脚本
# 负责构建后端和前端项目

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 引入公共函数库
source "$SCRIPT_DIR/common.sh"

# 显示标题
show_header "项目构建"

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

# 设置构建目录
BASE_DIR="${BASE_DIR:-$HOME/.config/subscription}"
DIST_DIR="${DIST_DIR:-${BASE_DIR}/dist}"

# 检查构建环境
check_build_env() {
    print_status "info" "检查构建环境..."
    
    # 检查 TypeScript 配置
    check_required_file "$PROJECT_ROOT/tsconfig.json" "TypeScript 配置文件"
    
    # 检查源代码目录
    check_required_dir "$PROJECT_ROOT/src" "源代码目录"
    
    # 检查前端目录
    if [ -d "$PROJECT_ROOT/frontend" ]; then
        check_required_file "$PROJECT_ROOT/frontend/package.json" "前端包配置文件"
        print_status "info" "检测到前端项目"
    else
        print_status "warning" "未检测到前端项目"
    fi
    
    # 检查 bun 命令
    local bun_cmd=$(detect_bun)
    if [ -z "$bun_cmd" ]; then
        # 尝试使用二进制目录中的 bun
        if [ -f "${BASE_DIR}/bin/bun" ]; then
            bun_cmd="${BASE_DIR}/bin/bun"
        elif [ -n "$BUN_BINARY" ] && [ -f "$BUN_BINARY" ]; then
            bun_cmd="$BUN_BINARY"
        else
            print_status "error" "未找到 bun 命令"
            echo "请先运行 scripts/install-binaries.sh 安装 bun"
            exit 1
        fi
    fi
    
    export BUN_CMD="$bun_cmd"
    print_status "info" "使用 bun: $($bun_cmd --version)"
}

# 清理构建文件
clean_build() {
    print_status "info" "清理旧的构建文件..."
    
    # 清理项目根目录的构建文件
    rm -rf "$PROJECT_ROOT/dist"
    
    # 清理前端构建文件
    if [ -d "$PROJECT_ROOT/frontend" ]; then
        rm -rf "$PROJECT_ROOT/frontend/dist"
        rm -rf "$PROJECT_ROOT/frontend/.next"
        rm -rf "$PROJECT_ROOT/frontend/out"
    fi
    
    # 清理统一构建目录
    if [ -d "$DIST_DIR" ]; then
        rm -rf "$DIST_DIR"
    fi
    
    print_status "success" "构建文件清理完成"
}

# 构建后端项目
build_backend() {
    print_status "info" "构建后端项目..."
    
    # 切换到项目根目录
    cd "$PROJECT_ROOT"
    
    # 执行构建
    if [[ $EUID -eq 0 ]] && [ "$OS" = "Linux" ] && [ "$TARGET_USER" != "root" ]; then
        # root 执行但目标用户非 root 时，使用目标用户身份构建
        if ! safe_sudo_user "$TARGET_USER" "$BUN_CMD" run build; then
            print_status "error" "后端构建失败"
            echo "请检查 TypeScript 错误或运行: $BUN_CMD run build"
            exit 1
        fi
    else
        if ! "$BUN_CMD" run build; then
            print_status "error" "后端构建失败"
            echo "请检查 TypeScript 错误或运行: $BUN_CMD run build"
            exit 1
        fi
    fi
    
    # 验证构建结果
    if [ ! -f "$PROJECT_ROOT/dist/index.js" ]; then
        print_status "error" "后端构建失败：未找到 dist/index.js"
        exit 1
    fi
    
    print_status "success" "后端构建成功"
}

# 构建前端项目
build_frontend() {
    if [ ! -d "$PROJECT_ROOT/frontend" ]; then
        print_status "info" "跳过前端构建：未找到前端项目"
        return 0
    fi
    
    print_status "info" "构建前端项目..."
    
    # 检查前端构建脚本
    if [ -f "$SCRIPT_DIR/build-frontend.sh" ]; then
        print_status "info" "使用前端构建脚本..."
        
        # 执行前端构建脚本
        if [[ $EUID -eq 0 ]] && [ "$OS" = "Linux" ] && [ "$TARGET_USER" != "root" ]; then
            if ! safe_sudo_user "$TARGET_USER" bash "$SCRIPT_DIR/build-frontend.sh"; then
                print_status "error" "前端构建失败"
                exit 1
            fi
        else
            if ! bash "$SCRIPT_DIR/build-frontend.sh"; then
                print_status "error" "前端构建失败"
                exit 1
            fi
        fi
    else
        print_status "info" "使用默认前端构建方式..."
        
        # 切换到前端目录
        cd "$PROJECT_ROOT/frontend"
        
        # 检查是否有依赖
        if [ ! -d "node_modules" ]; then
            print_status "info" "安装前端依赖..."
            if [[ $EUID -eq 0 ]] && [ "$OS" = "Linux" ] && [ "$TARGET_USER" != "root" ]; then
                safe_sudo_user "$TARGET_USER" "$BUN_CMD" install
            else
                "$BUN_CMD" install
            fi
        fi
        
        # 执行构建
        if [[ $EUID -eq 0 ]] && [ "$OS" = "Linux" ] && [ "$TARGET_USER" != "root" ]; then
            if ! safe_sudo_user "$TARGET_USER" "$BUN_CMD" run build; then
                print_status "error" "前端构建失败"
                exit 1
            fi
        else
            if ! "$BUN_CMD" run build; then
                print_status "error" "前端构建失败"
                exit 1
            fi
        fi
    fi
    
    # 验证构建结果
    if [ ! -f "$PROJECT_ROOT/frontend/dist/index.html" ]; then
        print_status "error" "前端构建失败：未找到 frontend/dist/index.html"
        exit 1
    fi
    
    print_status "success" "前端构建成功"
}

# 复制构建文件到统一目录
copy_build_files() {
    print_status "info" "复制构建文件到统一目录..."
    
    # 创建统一构建目录
    ensure_dir_exists "$DIST_DIR" "统一构建目录"
    ensure_dir_exists "$DIST_DIR/backend" "后端构建目录"
    ensure_dir_exists "$DIST_DIR/frontend" "前端构建目录"
    
    # 复制后端构建文件
    if [ -d "$PROJECT_ROOT/dist" ]; then
        cp -r "$PROJECT_ROOT/dist"/* "$DIST_DIR/backend/"
        print_status "success" "后端文件复制完成: $DIST_DIR/backend/"
    fi
    
    # 复制前端构建文件
    if [ -d "$PROJECT_ROOT/frontend/dist" ]; then
        cp -r "$PROJECT_ROOT/frontend/dist"/* "$DIST_DIR/frontend/"
        print_status "success" "前端文件复制完成: $DIST_DIR/frontend/"
    fi
    
    print_status "success" "构建文件复制完成"
}

# 设置构建文件权限
setup_build_permissions() {
    print_status "info" "设置构建文件权限..."
    
    # 设置后端构建文件权限
    if [ -d "$PROJECT_ROOT/dist" ]; then
        if [ "$OS" = "Linux" ]; then
            if [[ $EUID -eq 0 ]]; then
                chown -R "$TARGET_USER:$TARGET_GROUP" "$PROJECT_ROOT/dist/"
                chmod -R 755 "$PROJECT_ROOT/dist/"
                find "$PROJECT_ROOT/dist/" -type f -exec chmod 644 {} \; 2>/dev/null || true
                # 确保主执行文件可执行
                if [ -f "$PROJECT_ROOT/dist/index.js" ]; then
                    chmod 755 "$PROJECT_ROOT/dist/index.js"
                fi
            else
                safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$PROJECT_ROOT/dist/" 2>/dev/null || true
                safe_sudo chmod -R 755 "$PROJECT_ROOT/dist/" 2>/dev/null || true
                safe_sudo find "$PROJECT_ROOT/dist/" -type f -exec chmod 644 {} \; 2>/dev/null || true
            fi
        elif [ "$OS" = "Mac" ]; then
            chmod -R 755 "$PROJECT_ROOT/dist/"
            find "$PROJECT_ROOT/dist/" -type f -exec chmod 644 {} \; 2>/dev/null || true
        fi
    fi
    
    # 设置前端构建文件权限（Linux）
    if [ "$OS" = "Linux" ] && [ -d "$PROJECT_ROOT/frontend/dist" ]; then
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
        
        # 设置适当的权限
        if [[ $EUID -eq 0 ]]; then
            safe_sudo chown -R "$nginx_user:$nginx_user" "$PROJECT_ROOT/frontend/dist/"
            safe_sudo chmod -R 755 "$PROJECT_ROOT/frontend/dist/"
            safe_sudo find "$PROJECT_ROOT/frontend/dist/" -type f -exec chmod 644 {} \; 2>/dev/null || true
        else
            safe_sudo chown -R "$nginx_user:$nginx_user" "$PROJECT_ROOT/frontend/dist/" 2>/dev/null || true
            safe_sudo chmod -R 755 "$PROJECT_ROOT/frontend/dist/" 2>/dev/null || true
            safe_sudo find "$PROJECT_ROOT/frontend/dist/" -type f -exec chmod 644 {} \; 2>/dev/null || true
        fi
    fi
    
    # 设置统一构建目录权限
    if [ -d "$DIST_DIR" ]; then
        if [ "$OS" = "Linux" ]; then
            if [[ $EUID -eq 0 ]]; then
                chown -R "$TARGET_USER:$TARGET_GROUP" "$DIST_DIR"
                chmod -R 755 "$DIST_DIR"
                find "$DIST_DIR" -type f -exec chmod 644 {} \; 2>/dev/null || true
                # 确保后端执行文件可执行
                if [ -f "$DIST_DIR/backend/index.js" ]; then
                    chmod 755 "$DIST_DIR/backend/index.js"
                fi
            else
                safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$DIST_DIR" 2>/dev/null || true
                safe_sudo chmod -R 755 "$DIST_DIR" 2>/dev/null || true
                safe_sudo find "$DIST_DIR" -type f -exec chmod 644 {} \; 2>/dev/null || true
            fi
        elif [ "$OS" = "Mac" ]; then
            chmod -R 755 "$DIST_DIR"
            find "$DIST_DIR" -type f -exec chmod 644 {} \; 2>/dev/null || true
        fi
    fi
    
    print_status "success" "构建文件权限设置完成"
}

# 显示构建信息
show_build_info() {
    print_status "info" "构建信息:"
    
    if [ -d "$PROJECT_ROOT/dist" ]; then
        echo "  - 后端构建目录: $PROJECT_ROOT/dist"
        if [ -f "$PROJECT_ROOT/dist/index.js" ]; then
            local backend_size=$(du -sh "$PROJECT_ROOT/dist" | cut -f1)
            echo "    主文件: index.js"
            echo "    大小: $backend_size"
        fi
    fi
    
    if [ -d "$PROJECT_ROOT/frontend/dist" ]; then
        echo "  - 前端构建目录: $PROJECT_ROOT/frontend/dist"
        if [ -f "$PROJECT_ROOT/frontend/dist/index.html" ]; then
            local frontend_size=$(du -sh "$PROJECT_ROOT/frontend/dist" | cut -f1)
            echo "    主文件: index.html"
            echo "    大小: $frontend_size"
        fi
    fi
    
    if [ -d "$DIST_DIR" ]; then
        echo "  - 统一构建目录: $DIST_DIR"
        local total_size=$(du -sh "$DIST_DIR" | cut -f1)
        echo "    总大小: $total_size"
    fi
}

# 主函数
main() {
    print_status "info" "开始构建项目..."
    
    # 检查构建环境
    check_build_env
    
    # 清理构建文件
    clean_build
    
    # 构建后端项目
    build_backend
    
    # 构建前端项目
    build_frontend
    
    # 复制构建文件
    copy_build_files
    
    # 设置文件权限
    setup_build_permissions
    
    # 显示构建信息
    show_build_info
    
    print_status "success" "项目构建完成！"
}

# 如果脚本直接执行，则运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
