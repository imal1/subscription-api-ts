#!/bin/bash

# 通用工具函数库
# 包含 Node.js 路径检测、sudo 处理等常用功能

# 检测是否是版本管理器路径（fnm, nvm 等）
is_version_manager_path() {
    local node_path="$1"
    if [[ "$node_path" == *"fnm"* ]] || \
       [[ "$node_path" == *"nvm"* ]] || \
       [[ "$node_path" == *".local/share/fnm"* ]] || \
       [[ "$node_path" == *".fnm"* ]] || \
       [[ "$node_path" == *"node-versions"* ]] || \
       [[ "$node_path" == *".local"* ]] || \
       [[ "$node_path" == *"/run/user/"* ]]; then
        return 0  # 是版本管理器路径
    else
        return 1  # 不是版本管理器路径
    fi
}

# 安全执行 systemctl 命令（自动处理 sudo）
safe_systemctl() {
    local action="$1"
    local service="$2"
    
    if [[ $EUID -eq 0 ]]; then
        systemctl "$action" "$service"
    else
        sudo systemctl "$action" "$service"
    fi
}

# 安全复制文件（自动处理 sudo）
safe_copy() {
    local source="$1"
    local target="$2"
    
    if [[ $EUID -eq 0 ]]; then
        cp "$source" "$target"
    else
        sudo cp "$source" "$target"
    fi
}

# 安全设置文件权限（自动处理 sudo）
safe_chmod() {
    local permissions="$1"
    local file="$2"
    
    if [[ $EUID -eq 0 ]]; then
        chmod "$permissions" "$file"
    else
        sudo chmod "$permissions" "$file"
    fi
}

# 查找系统路径中的 Node.js
find_system_node() {
    local system_paths=(
        "/usr/bin/node"
        "/usr/local/bin/node"
        "/opt/node/bin/node"
    )
    
    for path in "${system_paths[@]}"; do
        if [ -f "$path" ] && [ -x "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# 将 Node.js 复制到系统路径
copy_node_to_system() {
    local source_node="$1"
    local target_path="${2:-/usr/local/bin/node}"
    
    if [ ! -f "$source_node" ] || [ ! -x "$source_node" ]; then
        echo "错误：源 Node.js 文件无效: $source_node" >&2
        return 1
    fi
    
    # 复制文件
    if safe_copy "$source_node" "$target_path" && safe_chmod "+x" "$target_path"; then
        # 验证复制结果
        if [ -f "$target_path" ] && [ -x "$target_path" ]; then
            local version=$("$target_path" --version 2>/dev/null || echo "unknown")
            echo "✅ Node.js 已复制到: $target_path (版本: $version)"
            return 0
        else
            echo "错误：复制后的 Node.js 文件无效" >&2
            return 1
        fi
    else
        echo "错误：复制 Node.js 失败" >&2
        return 1
    fi
}

# 智能获取适合 systemd 的 Node.js 路径
get_systemd_node_path() {
    local current_node
    local system_node
    
    # 首先尝试系统路径
    if system_node=$(find_system_node); then
        echo "$system_node"
        return 0
    fi
    
    # 获取当前环境的 Node.js
    current_node=$(which node 2>/dev/null)
    if [ -z "$current_node" ]; then
        echo "错误：未找到 Node.js" >&2
        return 1
    fi
    
    # 检查是否是版本管理器路径
    if is_version_manager_path "$current_node"; then
        echo "检测到版本管理器路径: $current_node" >&2
        echo "正在复制到系统路径..." >&2
        
        if copy_node_to_system "$current_node"; then
            echo "/usr/local/bin/node"
            return 0
        else
            echo "警告：复制失败，使用原路径（可能导致 systemd 启动失败）" >&2
            echo "$current_node"
            return 1
        fi
    else
        echo "$current_node"
        return 0
    fi
}

# 检测 fnm 是否已安装
is_fnm_installed() {
    if command -v fnm >/dev/null 2>&1; then
        return 0
    elif [ -d "$HOME/.local/share/fnm" ] || [ -d "$HOME/.fnm" ]; then
        return 0
    else
        return 1
    fi
}

# 获取 fnm 版本信息
get_fnm_info() {
    if command -v fnm >/dev/null 2>&1; then
        local version=$(fnm --version 2>/dev/null || echo "unknown")
        echo "fnm 版本: $version"
        
        if command -v node >/dev/null 2>&1; then
            local node_version=$(node --version)
            local node_path=$(which node)
            echo "当前 Node.js: $node_version ($node_path)"
        fi
    else
        echo "fnm 未在 PATH 中"
    fi
}

# 显示 Node.js 环境诊断信息
diagnose_node_environment() {
    echo "Node.js 环境诊断:"
    echo "=================="
    
    if command -v node >/dev/null 2>&1; then
        local node_path=$(which node)
        local node_version=$(node --version)
        echo "✅ Node.js: $node_version"
        echo "   路径: $node_path"
        
        if is_version_manager_path "$node_path"; then
            echo "   ⚠️  版本管理器路径（systemd 不可用）"
        else
            echo "   ✅ 系统路径（systemd 可用）"
        fi
    else
        echo "❌ Node.js 未安装或不在 PATH 中"
    fi
    
    echo ""
    echo "系统路径检查:"
    local system_paths=(
        "/usr/bin/node"
        "/usr/local/bin/node"
        "/opt/node/bin/node"
    )
    
    local found_system=false
    for path in "${system_paths[@]}"; do
        if [ -f "$path" ] && [ -x "$path" ]; then
            local version=$("$path" --version 2>/dev/null || echo "unknown")
            echo "✅ $path (版本: $version)"
            found_system=true
        else
            echo "❌ $path (不存在)"
        fi
    done
    
    if [ "$found_system" = false ]; then
        echo ""
        echo "建议: 复制 Node.js 到系统路径"
        echo "命令: sudo cp \$(which node) /usr/local/bin/node"
    fi
    
    echo ""
    if is_fnm_installed; then
        echo "版本管理器信息:"
        get_fnm_info
    fi
}

# 导出函数供其他脚本使用
export -f is_version_manager_path
export -f safe_systemctl
export -f safe_copy
export -f safe_chmod
export -f find_system_node
export -f copy_node_to_system
export -f get_systemd_node_path
export -f is_fnm_installed
export -f get_fnm_info
export -f diagnose_node_environment
