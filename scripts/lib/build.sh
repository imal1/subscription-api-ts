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
# 注：自迁移到 Next.js 全栈后，后端 API 已并入 Next（frontend/src/server + src/pages/api），
# 不再单独编译。此函数保留为兼容占位，实际由 build_frontend 统一产出。
build_backend() {
    print_status "info" "后端已并入 Next.js 全栈，跳过独立后端构建"
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
    
    # 执行构建（Next.js standalone 产物）
    if ! "$BUN_CMD" run build; then
        print_status "error" "前端构建失败"
        return 1
    fi

    # 验证 standalone 入口
    if [ ! -f "$project_root/frontend/.next/standalone/frontend/server.js" ]; then
        print_status "error" "前端构建失败：未找到 .next/standalone/frontend/server.js"
        return 1
    fi

    # standalone 不会自动包含静态资源与 public，需手动拷入运行目录
    cp -r "$project_root/frontend/.next/static" \
          "$project_root/frontend/.next/standalone/frontend/.next/static"
    if [ -d "$project_root/frontend/public" ]; then
        cp -r "$project_root/frontend/public" \
              "$project_root/frontend/.next/standalone/frontend/public"
    fi

    print_status "success" "前端构建完成 (Next.js standalone)"
    return 0
}

# 复制构建文件
copy_build_files() {
    print_status "info" "复制构建文件..."

    local project_root=$(get_project_root)
    local standalone="$project_root/frontend/.next/standalone"

    # 清空旧产物并复制 Next standalone 整棵树
    # 结果：$DIST_DIR/frontend/server.js（入口）+ $DIST_DIR/node_modules（依赖）
    rm -rf "$DIST_DIR/frontend" "$DIST_DIR/node_modules" "$DIST_DIR/backend"
    if [ -d "$standalone" ]; then
        cp -r "$standalone"/. "$DIST_DIR/"
        print_status "success" "Next standalone 产物复制完成"
    else
        print_status "error" "未找到 standalone 产物: $standalone"
        return 1
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
