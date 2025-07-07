#!/bin/bash

# 二进制文件下载和安装函数

# 下载文件
download_file() {
    local url="$1"
    local output="$2"
    local description="${3:-文件}"
    
    print_status "info" "下载 $description: $url"
    
    if command_exists curl; then
        curl -L --fail --connect-timeout 30 --max-time 300 -o "$output" "$url"
    elif command_exists wget; then
        wget --timeout=30 --tries=3 -O "$output" "$url"
    else
        print_status "error" "需要 curl 或 wget 来下载文件"
        return 1
    fi
}

# 获取最新版本号
get_latest_version() {
    local repo="$1"
    local api_url="https://api.github.com/repos/$repo/releases/latest"
    
    if command_exists curl; then
        curl -s "$api_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -n 1
    elif command_exists wget; then
        wget -qO- "$api_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -n 1
    else
        echo ""
    fi
}

# 安装 bun
install_bun() {
    local bun_binary="$BIN_DIR/bun"
    
    # 检查是否已安装
    if [ -f "$bun_binary" ] && "$bun_binary" --version >/dev/null 2>&1; then
        print_status "success" "bun 已安装: $($bun_binary --version)"
        return 0
    fi
    
    print_status "info" "安装 bun..."
    
    # 构建下载 URL
    local bun_arch="$ARCH"
    case "$ARCH" in
        "x64") bun_arch="x64" ;;
        "arm64") bun_arch="aarch64" ;;
        *) print_status "error" "不支持的架构: $ARCH"; return 1 ;;
    esac
    
    local bun_os="$OS"
    case "$OS" in
        "linux") bun_os="linux" ;;
        "darwin") bun_os="darwin" ;;
        *) print_status "error" "不支持的操作系统: $OS"; return 1 ;;
    esac
    
    local bun_url="https://github.com/oven-sh/bun/releases/latest/download/bun-${bun_os}-${bun_arch}.zip"
    local temp_file="/tmp/bun.zip"
    
    # 下载
    if ! download_file "$bun_url" "$temp_file" "bun"; then
        print_status "error" "bun 下载失败"
        return 1
    fi
    
    # 解压
    local temp_dir="/tmp/bun_extract"
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"
    
    if ! unzip -q "$temp_file" -d "$temp_dir"; then
        print_status "error" "bun 解压失败"
        rm -f "$temp_file"
        return 1
    fi
    
    # 查找解压后的 bun 文件
    local extracted_bun=$(find "$temp_dir" -name "bun" -type f -executable | head -n 1)
    if [ -z "$extracted_bun" ]; then
        print_status "error" "未找到 bun 可执行文件"
        rm -rf "$temp_dir" "$temp_file"
        return 1
    fi
    
    # 移动到目标位置
    mv "$extracted_bun" "$bun_binary"
    chmod +x "$bun_binary"
    
    # 清理临时文件
    rm -rf "$temp_dir" "$temp_file"
    
    # 验证安装
    if "$bun_binary" --version >/dev/null 2>&1; then
        print_status "success" "bun 安装成功: $($bun_binary --version)"
        return 0
    else
        print_status "error" "bun 安装失败"
        rm -f "$bun_binary"
        return 1
    fi
}

# 安装 mihomo
install_mihomo() {
    local mihomo_binary="$BIN_DIR/mihomo"
    
    # 检查是否已安装
    if [ -f "$mihomo_binary" ] && "$mihomo_binary" -v >/dev/null 2>&1; then
        print_status "success" "mihomo 已安装"
        return 0
    fi
    
    print_status "info" "安装 mihomo..."
    
    # 获取最新版本
    local version=$(get_latest_version "MetaCubeX/mihomo")
    if [ -z "$version" ]; then
        version="v1.18.0"  # 默认版本
        print_status "warning" "无法获取最新版本，使用默认版本: $version"
    fi
    
    # 构建下载 URL
    local mihomo_arch="$ARCH"
    case "$ARCH" in
        "x64") mihomo_arch="amd64" ;;
        "arm64") mihomo_arch="arm64" ;;
        "armv7") mihomo_arch="armv7" ;;
        *) print_status "error" "不支持的架构: $ARCH"; return 1 ;;
    esac
    
    local mihomo_os="$OS"
    case "$OS" in
        "linux") mihomo_os="linux" ;;
        "darwin") mihomo_os="darwin" ;;
        *) print_status "error" "不支持的操作系统: $OS"; return 1 ;;
    esac
    
    local mihomo_url="https://github.com/MetaCubeX/mihomo/releases/download/${version}/mihomo-${mihomo_os}-${mihomo_arch}-${version}.gz"
    local temp_file="/tmp/mihomo.gz"
    
    # 下载
    if ! download_file "$mihomo_url" "$temp_file" "mihomo"; then
        print_status "error" "mihomo 下载失败"
        return 1
    fi
    
    # 解压
    if ! gunzip -c "$temp_file" > "$mihomo_binary"; then
        print_status "error" "mihomo 解压失败"
        rm -f "$temp_file"
        return 1
    fi
    
    # 设置权限
    chmod +x "$mihomo_binary"
    
    # 清理临时文件
    rm -f "$temp_file"
    
    # 验证安装
    if "$mihomo_binary" -v >/dev/null 2>&1; then
        print_status "success" "mihomo 安装成功"
        return 0
    else
        print_status "error" "mihomo 安装失败"
        rm -f "$mihomo_binary"
        return 1
    fi
}

# 安装所有二进制文件
install_binaries() {
    print_status "info" "开始安装二进制文件..."
    
    # 安装 bun
    if ! install_bun; then
        print_status "error" "bun 安装失败"
        return 1
    fi
    
    # 安装 mihomo
    if ! install_mihomo; then
        print_status "error" "mihomo 安装失败"
        return 1
    fi
    
    print_status "success" "所有二进制文件安装完成"
    
    # 设置二进制文件权限
    if [ "$OS" = "linux" ]; then
        safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$BIN_DIR" 2>/dev/null || true
    fi
    
    return 0
}
