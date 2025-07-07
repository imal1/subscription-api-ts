#!/bin/bash

# 权限验证脚本
# 负责验证和修复文件系统权限

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 引入公共函数库
source "$SCRIPT_DIR/common.sh"

# 显示标题
show_header "权限验证"

# 配置变量（不再从环境文件加载）
# 现在所有配置都基于 config.yaml

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

# 设置目录变量（使用公共函数）
setup_default_env

# 额外的目录定义
BIN_DIR="${BASE_DIR}/bin"

# 权限检查结果
PERMISSION_ISSUES=()

# 检查目录权限
check_directory_permissions() {
    local dir="$1"
    local expected_owner="$2"
    local expected_perms="$3"
    local description="$4"
    
    if [ ! -d "$dir" ]; then
        print_status "error" "$description 不存在: $dir"
        PERMISSION_ISSUES+=("目录不存在: $dir")
        return 1
    fi
    
    local actual_owner=$(ls -ld "$dir" | awk '{print $3":"$4}')
    local actual_perms=$(ls -ld "$dir" | awk '{print $1}')
    
    print_status "info" "$description 权限检查:"
    echo "  - 路径: $dir"
    echo "  - 期望所有者: $expected_owner"
    echo "  - 实际所有者: $actual_owner"
    echo "  - 实际权限: $actual_perms"
    
    # 检查所有者
    if [ "$actual_owner" != "$expected_owner" ]; then
        print_status "warning" "$description 所有者不匹配"
        PERMISSION_ISSUES+=("$description 所有者不匹配: $dir (期望: $expected_owner, 实际: $actual_owner)")
    fi
    
    # 检查权限（简化检查，主要检查用户权限）
    if [[ ! "$actual_perms" =~ ^d.....-.* ]]; then
        # 检查用户是否有读写执行权限
        if [[ ! "$actual_perms" =~ ^d[r-][w-][x-] ]]; then
            print_status "warning" "$description 用户权限不足"
            PERMISSION_ISSUES+=("$description 用户权限不足: $dir")
        fi
    fi
    
    # 测试写入权限
    local test_file="$dir/.write_test_$$"
    if ! safe_sudo_user "$TARGET_USER" touch "$test_file" 2>/dev/null; then
        print_status "error" "$description 写入权限测试失败"
        PERMISSION_ISSUES+=("$description 写入权限测试失败: $dir")
        return 1
    else
        safe_sudo_user "$TARGET_USER" rm -f "$test_file" 2>/dev/null || true
        print_status "success" "$description 权限正常"
    fi
    
    return 0
}

# 检查文件权限
check_file_permissions() {
    local file="$1"
    local expected_owner="$2"
    local expected_perms="$3"
    local description="$4"
    
    if [ ! -f "$file" ]; then
        print_status "warning" "$description 不存在: $file"
        return 0
    fi
    
    local actual_owner=$(ls -l "$file" | awk '{print $3":"$4}')
    local actual_perms=$(ls -l "$file" | awk '{print $1}')
    
    print_status "info" "$description 权限检查:"
    echo "  - 路径: $file"
    echo "  - 期望所有者: $expected_owner"
    echo "  - 实际所有者: $actual_owner"
    echo "  - 实际权限: $actual_perms"
    
    # 检查所有者
    if [ "$actual_owner" != "$expected_owner" ]; then
        print_status "warning" "$description 所有者不匹配"
        PERMISSION_ISSUES+=("$description 所有者不匹配: $file (期望: $expected_owner, 实际: $actual_owner)")
    fi
    
    # 测试读取权限
    if ! safe_sudo_user "$TARGET_USER" test -r "$file" 2>/dev/null; then
        print_status "error" "$description 读取权限测试失败"
        PERMISSION_ISSUES+=("$description 读取权限测试失败: $file")
        return 1
    else
        print_status "success" "$description 权限正常"
    fi
    
    return 0
}

# 检查二进制文件权限
check_binary_permissions() {
    local binary="$1"
    local description="$2"
    
    if [ ! -f "$binary" ]; then
        print_status "warning" "$description 不存在: $binary"
        return 0
    fi
    
    local actual_owner=$(ls -l "$binary" | awk '{print $3":"$4}')
    local actual_perms=$(ls -l "$binary" | awk '{print $1}')
    
    print_status "info" "$description 权限检查:"
    echo "  - 路径: $binary"
    echo "  - 实际所有者: $actual_owner"
    echo "  - 实际权限: $actual_perms"
    
    # 测试执行权限
    if ! safe_sudo_user "$TARGET_USER" test -x "$binary" 2>/dev/null; then
        print_status "error" "$description 执行权限测试失败"
        PERMISSION_ISSUES+=("$description 执行权限测试失败: $binary")
        return 1
    else
        print_status "success" "$description 权限正常"
    fi
    
    return 0
}

# 检查所有权限
check_all_permissions() {
    print_status "info" "开始权限检查..."
    
    # 检查基础目录权限
    check_directory_permissions "$BASE_DIR" "$TARGET_USER:$TARGET_GROUP" "755" "基础目录"
    
    # 检查数据目录权限
    check_directory_permissions "$DATA_DIR" "$TARGET_USER:$TARGET_GROUP" "755" "数据目录"
    
    # 检查日志目录权限
    check_directory_permissions "$LOG_DIR" "$TARGET_USER:$TARGET_GROUP" "750" "日志目录"
    
    # 检查构建目录权限
    check_directory_permissions "$DIST_DIR" "$TARGET_USER:$TARGET_GROUP" "755" "构建目录"
    
    # 检查二进制目录权限
    check_directory_permissions "$BIN_DIR" "$TARGET_USER:$TARGET_GROUP" "755" "二进制目录"
    
    # 检查配置文件权限
    check_file_permissions "$PROJECT_ROOT/.env" "$TARGET_USER:$TARGET_GROUP" "600" "环境配置文件"
    
    # 检查二进制文件权限
    check_binary_permissions "$BIN_DIR/bun" "Bun 二进制文件"
    check_binary_permissions "$BIN_DIR/mihomo" "mihomo 二进制文件"
    
    # 检查构建文件权限
    check_file_permissions "$PROJECT_ROOT/dist/index.js" "$TARGET_USER:$TARGET_GROUP" "644" "后端构建文件"
    check_file_permissions "$PROJECT_ROOT/frontend/dist/index.html" "www-data:www-data" "644" "前端构建文件"
    
    # 检查 Nginx 相关目录权限（Linux）
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
        
        # 检查前端文件权限
        if [ -d "$PROJECT_ROOT/frontend/dist" ]; then
            print_status "info" "检查前端文件 Nginx 权限..."
            local frontend_owner=$(ls -ld "$PROJECT_ROOT/frontend/dist" | awk '{print $3":"$4}')
            if [ "$frontend_owner" != "$nginx_user:$nginx_user" ]; then
                print_status "warning" "前端文件所有者不匹配 Nginx 用户"
                PERMISSION_ISSUES+=("前端文件所有者不匹配: $PROJECT_ROOT/frontend/dist (期望: $nginx_user:$nginx_user, 实际: $frontend_owner)")
            fi
        fi
        
        # 检查数据目录 Nginx 权限
        local data_owner=$(ls -ld "$DATA_DIR" | awk '{print $3":"$4}')
        if [ "$data_owner" != "$nginx_user:$nginx_user" ]; then
            print_status "warning" "数据目录所有者不匹配 Nginx 用户"
            PERMISSION_ISSUES+=("数据目录所有者不匹配: $DATA_DIR (期望: $nginx_user:$nginx_user, 实际: $data_owner)")
        fi
    fi
    
    # 检查项目根目录权限
    local project_owner=$(ls -ld "$PROJECT_ROOT" | awk '{print $3":"$4}')
    if [ "$project_owner" != "$TARGET_USER:$TARGET_GROUP" ]; then
        print_status "warning" "项目根目录所有者不匹配"
        PERMISSION_ISSUES+=("项目根目录所有者不匹配: $PROJECT_ROOT (期望: $TARGET_USER:$TARGET_GROUP, 实际: $project_owner)")
    fi
    
    print_status "success" "权限检查完成"
}

# 修复权限问题
fix_permissions() {
    if [ ${#PERMISSION_ISSUES[@]} -eq 0 ]; then
        print_status "success" "没有发现权限问题"
        return 0
    fi
    
    print_status "warning" "发现 ${#PERMISSION_ISSUES[@]} 个权限问题"
    
    echo "问题列表:"
    for issue in "${PERMISSION_ISSUES[@]}"; do
        echo "  - $issue"
    done
    
    echo ""
    read -p "是否自动修复这些权限问题？(y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "info" "跳过权限修复"
        return 0
    fi
    
    print_status "info" "开始修复权限问题..."
    
    # 修复基础目录权限
    if [ -d "$BASE_DIR" ]; then
        print_status "info" "修复基础目录权限..."
        if [[ $EUID -eq 0 ]]; then
            chown -R "$TARGET_USER:$TARGET_GROUP" "$BASE_DIR"
            chmod 755 "$BASE_DIR"
        else
            safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$BASE_DIR"
            safe_sudo chmod 755 "$BASE_DIR"
        fi
    fi
    
    # 修复数据目录权限
    if [ -d "$DATA_DIR" ]; then
        print_status "info" "修复数据目录权限..."
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
            
            if [[ $EUID -eq 0 ]]; then
                chown -R "$nginx_user:$nginx_user" "$DATA_DIR"
                chmod -R 755 "$DATA_DIR"
                find "$DATA_DIR" -type f -exec chmod 644 {} \; 2>/dev/null || true
            else
                safe_sudo chown -R "$nginx_user:$nginx_user" "$DATA_DIR"
                safe_sudo chmod -R 755 "$DATA_DIR"
                safe_sudo find "$DATA_DIR" -type f -exec chmod 644 {} \; 2>/dev/null || true
            fi
        else
            if [[ $EUID -eq 0 ]]; then
                chown -R "$TARGET_USER:$TARGET_GROUP" "$DATA_DIR"
                chmod -R 755 "$DATA_DIR"
            else
                safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$DATA_DIR"
                safe_sudo chmod -R 755 "$DATA_DIR"
            fi
        fi
    fi
    
    # 修复日志目录权限
    if [ -d "$LOG_DIR" ]; then
        print_status "info" "修复日志目录权限..."
        if [[ $EUID -eq 0 ]]; then
            chown -R "$TARGET_USER:$TARGET_GROUP" "$LOG_DIR"
            chmod -R 750 "$LOG_DIR"
        else
            safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$LOG_DIR"
            safe_sudo chmod -R 750 "$LOG_DIR"
        fi
    fi
    
    # 修复构建目录权限
    if [ -d "$DIST_DIR" ]; then
        print_status "info" "修复构建目录权限..."
        if [[ $EUID -eq 0 ]]; then
            chown -R "$TARGET_USER:$TARGET_GROUP" "$DIST_DIR"
            chmod -R 755 "$DIST_DIR"
            find "$DIST_DIR" -type f -exec chmod 644 {} \; 2>/dev/null || true
            # 确保执行文件可执行
            if [ -f "$DIST_DIR/backend/index.js" ]; then
                chmod 755 "$DIST_DIR/backend/index.js"
            fi
        else
            safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$DIST_DIR"
            safe_sudo chmod -R 755 "$DIST_DIR"
            safe_sudo find "$DIST_DIR" -type f -exec chmod 644 {} \; 2>/dev/null || true
        fi
    fi
    
    # 修复二进制目录权限
    if [ -d "$BIN_DIR" ]; then
        print_status "info" "修复二进制目录权限..."
        if [[ $EUID -eq 0 ]]; then
            chown -R "$TARGET_USER:$TARGET_GROUP" "$BIN_DIR"
            chmod 755 "$BIN_DIR"
            find "$BIN_DIR" -type f -exec chmod 755 {} \; 2>/dev/null || true
        else
            safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$BIN_DIR"
            safe_sudo chmod 755 "$BIN_DIR"
            safe_sudo find "$BIN_DIR" -type f -exec chmod 755 {} \; 2>/dev/null || true
        fi
    fi
    
    # 修复环境配置文件权限
    if [ -f "$PROJECT_ROOT/.env" ]; then
        print_status "info" "修复环境配置文件权限..."
        if [[ $EUID -eq 0 ]]; then
            chown "$TARGET_USER:$TARGET_GROUP" "$PROJECT_ROOT/.env"
            chmod 600 "$PROJECT_ROOT/.env"
        else
            safe_sudo chown "$TARGET_USER:$TARGET_GROUP" "$PROJECT_ROOT/.env"
            safe_sudo chmod 600 "$PROJECT_ROOT/.env"
        fi
    fi
    
    # 修复前端构建文件权限（Linux）
    if [ "$OS" = "Linux" ] && [ -d "$PROJECT_ROOT/frontend/dist" ]; then
        print_status "info" "修复前端构建文件权限..."
        local nginx_user="www-data"
        if ! id "$nginx_user" >/dev/null 2>&1; then
            for user in nginx http; do
                if id "$user" >/dev/null 2>&1; then
                    nginx_user="$user"
                    break
                fi
            done
        fi
        
        if [[ $EUID -eq 0 ]]; then
            chown -R "$nginx_user:$nginx_user" "$PROJECT_ROOT/frontend/dist"
            chmod -R 755 "$PROJECT_ROOT/frontend/dist"
            find "$PROJECT_ROOT/frontend/dist" -type f -exec chmod 644 {} \; 2>/dev/null || true
        else
            safe_sudo chown -R "$nginx_user:$nginx_user" "$PROJECT_ROOT/frontend/dist"
            safe_sudo chmod -R 755 "$PROJECT_ROOT/frontend/dist"
            safe_sudo find "$PROJECT_ROOT/frontend/dist" -type f -exec chmod 644 {} \; 2>/dev/null || true
        fi
    fi
    
    # 修复项目根目录权限
    print_status "info" "修复项目根目录权限..."
    if [[ $EUID -eq 0 ]]; then
        chown -R "$TARGET_USER:$TARGET_GROUP" "$PROJECT_ROOT"
        chmod -R u+rX "$PROJECT_ROOT"
    else
        safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$PROJECT_ROOT"
        safe_sudo chmod -R u+rX "$PROJECT_ROOT"
    fi
    
    print_status "success" "权限修复完成"
}

# 生成权限报告
generate_report() {
    print_status "info" "生成权限报告..."
    
    local report_file="$PROJECT_ROOT/permission_report.txt"
    
    cat > "$report_file" << EOF
权限检查报告
生成时间: $(date)
检查用户: $CURRENT_USER
目标用户: $TARGET_USER
操作系统: $OS

目录权限检查:
================
基础目录: $BASE_DIR
$(ls -ld "$BASE_DIR" 2>/dev/null || echo "目录不存在")

数据目录: $DATA_DIR
$(ls -ld "$DATA_DIR" 2>/dev/null || echo "目录不存在")

日志目录: $LOG_DIR
$(ls -ld "$LOG_DIR" 2>/dev/null || echo "目录不存在")

构建目录: $DIST_DIR
$(ls -ld "$DIST_DIR" 2>/dev/null || echo "目录不存在")

二进制目录: $BIN_DIR
$(ls -ld "$BIN_DIR" 2>/dev/null || echo "目录不存在")

文件权限检查:
================
环境配置文件: $PROJECT_ROOT/.env
$(ls -l "$PROJECT_ROOT/.env" 2>/dev/null || echo "文件不存在")

后端构建文件: $PROJECT_ROOT/dist/index.js
$(ls -l "$PROJECT_ROOT/dist/index.js" 2>/dev/null || echo "文件不存在")

前端构建文件: $PROJECT_ROOT/frontend/dist/index.html
$(ls -l "$PROJECT_ROOT/frontend/dist/index.html" 2>/dev/null || echo "文件不存在")

二进制文件检查:
================
Bun: $BIN_DIR/bun
$(ls -l "$BIN_DIR/bun" 2>/dev/null || echo "文件不存在")

mihomo: $BIN_DIR/mihomo
$(ls -l "$BIN_DIR/mihomo" 2>/dev/null || echo "文件不存在")

权限问题:
================
EOF
    
    if [ ${#PERMISSION_ISSUES[@]} -eq 0 ]; then
        echo "没有发现权限问题" >> "$report_file"
    else
        for issue in "${PERMISSION_ISSUES[@]}"; do
            echo "- $issue" >> "$report_file"
        done
    fi
    
    print_status "success" "权限报告已生成: $report_file"
}

# 显示修复建议
show_fix_commands() {
    print_status "info" "权限修复命令:"
    
    local cmd_prefix=""
    if [[ $EUID -ne 0 ]]; then
        if [ "$HAS_SUDO" = "true" ]; then
            cmd_prefix="sudo "
        else
            cmd_prefix="(需要root权限) "
        fi
    fi
    
    echo "手动修复命令:"
    echo "  - 重置基础目录权限: ${cmd_prefix}chown -R $TARGET_USER:$TARGET_GROUP $BASE_DIR && ${cmd_prefix}chmod -R 755 $BASE_DIR"
    echo "  - 重置数据目录权限: ${cmd_prefix}chown -R $TARGET_USER:$TARGET_GROUP $DATA_DIR && ${cmd_prefix}chmod -R 755 $DATA_DIR"
    echo "  - 重置日志目录权限: ${cmd_prefix}chown -R $TARGET_USER:$TARGET_GROUP $LOG_DIR && ${cmd_prefix}chmod -R 750 $LOG_DIR"
    echo "  - 重置配置文件权限: ${cmd_prefix}chown $TARGET_USER:$TARGET_GROUP $PROJECT_ROOT/.env && ${cmd_prefix}chmod 600 $PROJECT_ROOT/.env"
    echo "  - 重置二进制权限: ${cmd_prefix}chmod 755 $BIN_DIR/bun $BIN_DIR/mihomo"
    
    if [ "$OS" = "Linux" ]; then
        echo "  - 重置前端文件权限: ${cmd_prefix}chown -R www-data:www-data $PROJECT_ROOT/frontend/dist && ${cmd_prefix}chmod -R 755 $PROJECT_ROOT/frontend/dist"
    fi
    
    echo ""
    echo "批量修复命令:"
    echo "  bash $SCRIPT_DIR/verify-permissions.sh"
}

# 主函数
main() {
    print_status "info" "开始权限验证..."
    
    # 检查所有权限
    check_all_permissions
    
    # 生成报告
    generate_report
    
    # 显示结果
    if [ ${#PERMISSION_ISSUES[@]} -eq 0 ]; then
        print_status "success" "所有权限检查通过！"
    else
        print_status "warning" "发现 ${#PERMISSION_ISSUES[@]} 个权限问题"
        
        # 尝试修复权限
        fix_permissions
        
        # 显示修复建议
        show_fix_commands
    fi
    
    print_status "success" "权限验证完成！"
}

# 如果脚本直接执行，则运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
