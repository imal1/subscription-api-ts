#!/bin/bash

# 构建相关函数

# 检查 bun 可用性
check_bun() {
    local bun_cmd=""
    
    # 检查系统 bun
    if command_exists bun; then
        bun_cmd="bun"
    # 检查本地 bun
    elif [ -f "$BIN_DIR/bun" ]; then
        bun_cmd="$BIN_DIR/bun"
    else
        print_status "error" "未找到 bun 命令"
        print_status "info" "请先运行安装脚本或手动安装 bun"
        return 1
    fi
    
    export BUN_CMD="$bun_cmd"
    print_status "info" "使用 bun: $($bun_cmd --version)"
    return 0
}

# 清理构建文件
clean_build() {
    print_status "info" "清理构建文件..."
    
    local project_root=$(get_project_root)
    
    # 清理主项目构建文件
    rm -rf "$project_root/dist"
    
    # 清理前端构建文件
    if [ -d "$project_root/frontend" ]; then
        rm -rf "$project_root/frontend/dist"
        rm -rf "$project_root/frontend/.next"
        rm -rf "$project_root/frontend/out"
    fi
    
    # 清理统一构建目录
    rm -rf "$DIST_DIR"
    
    print_status "success" "构建文件清理完成"
}

# 构建后端
build_backend() {
    print_status "info" "构建后端项目..."
    
    local project_root=$(get_project_root)
    
    # 检查必要文件
    check_file "$project_root/package.json" "package.json"
    check_file "$project_root/tsconfig.json" "tsconfig.json"
    check_dir "$project_root/src" "源代码目录"
    
    # 检查 bun
    if ! check_bun; then
        return 1
    fi
    
    # 切换到项目目录
    cd "$project_root"
    
    # 安装依赖
    if [ ! -d "node_modules" ]; then
        print_status "info" "安装后端依赖..."
        if ! "$BUN_CMD" install; then
            print_status "error" "后端依赖安装失败"
            return 1
        fi
    fi
    
    # 执行构建
    if ! "$BUN_CMD" run build; then
        print_status "error" "后端构建失败"
        return 1
    fi
    
    # 验证构建结果
    if [ ! -f "$project_root/dist/index.js" ]; then
        print_status "error" "后端构建失败：未找到 dist/index.js"
        return 1
    fi
    
    print_status "success" "后端构建完成"
    return 0
}

# 构建前端
build_frontend() {
    local project_root=$(get_project_root)
    
    if [ ! -d "$project_root/frontend" ]; then
        print_status "info" "跳过前端构建：未找到前端项目"
        return 0
    fi
    
    print_status "info" "构建前端项目..."
    
    # 检查必要文件
    check_file "$project_root/frontend/package.json" "前端 package.json"
    
    # 检查 bun
    if ! check_bun; then
        return 1
    fi
    
    # 切换到前端目录
    cd "$project_root/frontend"
    
    # 安装依赖
    if [ ! -d "node_modules" ]; then
        print_status "info" "安装前端依赖..."
        if ! "$BUN_CMD" install; then
            print_status "error" "前端依赖安装失败"
            return 1
        fi
    fi
    
    # 执行构建
    if ! "$BUN_CMD" run build; then
        print_status "error" "前端构建失败"
        return 1
    fi
    
    # 验证构建结果
    if [ ! -f "$project_root/frontend/dist/index.html" ]; then
        print_status "error" "前端构建失败：未找到 frontend/dist/index.html"
        return 1
    fi
    
    print_status "success" "前端构建完成"
    return 0
}

# 复制构建文件
copy_build_files() {
    print_status "info" "复制构建文件..."
    
    local project_root=$(get_project_root)
    
    # 创建目标目录
    ensure_dir "$DIST_DIR/backend" "后端构建目录"
    ensure_dir "$DIST_DIR/frontend" "前端构建目录"
    
    # 复制后端文件
    if [ -d "$project_root/dist" ]; then
        cp -r "$project_root/dist"/* "$DIST_DIR/backend/"
        print_status "success" "后端文件复制完成"
    fi
    
    # 复制前端文件
    if [ -d "$project_root/frontend/dist" ]; then
        cp -r "$project_root/frontend/dist"/* "$DIST_DIR/frontend/"
        print_status "success" "前端文件复制完成"
    fi
    
    # 设置权限
    if [ "$OS" = "linux" ]; then
        safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$DIST_DIR" 2>/dev/null || true
        safe_sudo chmod -R 755 "$DIST_DIR" 2>/dev/null || true
    fi
    
    print_status "success" "构建文件复制完成"
}

# 完整构建流程
build_all() {
    print_status "info" "开始完整构建..."
    
    # 清理构建文件
    clean_build
    
    # 构建后端
    if ! build_backend; then
        print_status "error" "后端构建失败"
        return 1
    fi
    
    # 构建前端
    if ! build_frontend; then
        print_status "error" "前端构建失败"
        return 1
    fi
    
    # 复制构建文件
    copy_build_files
    
    print_status "success" "完整构建完成"
    return 0
}
