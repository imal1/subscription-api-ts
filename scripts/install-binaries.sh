#!/bin/bash

# 二进制文件安装脚本
# 负责下载和安装 bun、mihomo 等二进制文件

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 引入公共函数库
source "$SCRIPT_DIR/common.sh"

# 显示标题
show_header "二进制文件安装"

# 加载环境变量
load_config

# 检测操作系统和架构
OS=$(detect_os)
ARCH=$(uname -m)

print_status "info" "操作系统: $OS"
print_status "info" "系统架构: $ARCH"

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

# 设置目录变量（使用公共函数）
setup_default_env

# 二进制文件目录
BIN_DIR="${BASE_DIR}/bin"

# 确保二进制目录存在
ensure_dir_exists "$BIN_DIR" "二进制文件目录"

# 映射系统架构
map_arch_for_bun() {
    case $ARCH in
        x86_64)
            echo "x64"
            ;;
        aarch64|arm64)
            echo "aarch64"
            ;;
        *)
            print_status "error" "不支持的系统架构: $ARCH"
            exit 1
            ;;
    esac
}

map_arch_for_mihomo() {
    case $ARCH in
        x86_64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        arm*)
            echo "armv7"
            ;;
        *)
            print_status "error" "不支持的系统架构: $ARCH"
            exit 1
            ;;
    esac
}

# 下载和安装 Bun
install_bun() {
    print_status "info" "开始安装 Bun..."
    
    local bun_binary="$BIN_DIR/bun"
    local bun_arch=$(map_arch_for_bun)
    
    # 检查是否已经安装
    if [ -f "$bun_binary" ] && "$bun_binary" --version &> /dev/null; then
        local current_version=$("$bun_binary" --version)
        print_status "success" "Bun 已安装: $current_version"
        export BUN_BINARY="$bun_binary"
        return 0
    fi
    
    # 获取最新版本
    print_status "info" "获取最新版本信息..."
    local bun_version=$(curl -s https://api.github.com/repos/oven-sh/bun/releases/latest | grep -o '"tag_name": "[^"]*' | grep -o '[^"]*$' | sed 's/^bun-v//')
    
    if [ -z "$bun_version" ]; then
        bun_version="1.0.30"  # 备用版本
        print_status "warning" "无法获取最新版本，使用备用版本: $bun_version"
    else
        print_status "info" "最新版本: $bun_version"
    fi
    
    # 构建下载URL
    local bun_url
    if [ "$OS" = "Linux" ]; then
        bun_url="https://github.com/oven-sh/bun/releases/download/bun-v${bun_version}/bun-linux-${bun_arch}.zip"
    elif [ "$OS" = "Mac" ]; then
        bun_url="https://github.com/oven-sh/bun/releases/download/bun-v${bun_version}/bun-darwin-${bun_arch}.zip"
    else
        print_status "error" "不支持的操作系统: $OS"
        exit 1
    fi
    
    print_status "info" "下载地址: $bun_url"
    
    # 下载并安装
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    print_status "info" "正在下载 Bun..."
    if curl -fsSL "$bun_url" -o bun.zip; then
        if command_exists unzip; then
            print_status "info" "解压文件..."
            unzip -q bun.zip
            
            # 查找解压后的bun可执行文件
            local bun_extracted=$(find . -name "bun" -type f -executable | head -1)
            if [ -n "$bun_extracted" ]; then
                cp "$bun_extracted" "$bun_binary"
                chmod +x "$bun_binary"
                
                # 设置文件权限
                if [ "$OS" = "Linux" ] && [[ $EUID -eq 0 ]]; then
                    chown "$TARGET_USER:$TARGET_GROUP" "$bun_binary"
                fi
                
                print_status "success" "Bun 安装成功: $bun_binary"
                
                # 验证安装
                if "$bun_binary" --version &> /dev/null; then
                    local installed_version=$("$bun_binary" --version)
                    print_status "success" "Bun 验证成功: $installed_version"
                    export BUN_BINARY="$bun_binary"
                else
                    print_status "error" "Bun 验证失败"
                    rm -f "$bun_binary"
                    exit 1
                fi
            else
                print_status "error" "无法找到解压后的 bun 可执行文件"
                exit 1
            fi
        else
            print_status "error" "系统缺少 unzip 命令"
            if [ "$OS" = "Linux" ]; then
                echo "请安装: apt-get install unzip 或 yum install unzip"
            fi
            exit 1
        fi
    else
        print_status "error" "下载失败"
        echo "请检查网络连接或手动下载: $bun_url"
        exit 1
    fi
    
    # 清理临时文件
    cd "$PROJECT_ROOT"
    rm -rf "$temp_dir"
}

# 下载和安装 mihomo
install_mihomo() {
    print_status "info" "开始安装 mihomo..."
    
    local mihomo_binary="$BIN_DIR/mihomo"
    local mihomo_arch=$(map_arch_for_mihomo)
    
    # 检查是否已经安装
    if [ -f "$mihomo_binary" ] && "$mihomo_binary" -v &> /dev/null; then
        local current_version=$("$mihomo_binary" -v | head -1)
        print_status "success" "mihomo 已安装: $current_version"
        return 0
    fi
    
    # 获取最新版本
    print_status "info" "获取最新版本信息..."
    local mihomo_version=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep -o '"tag_name": "[^"]*' | grep -o '[^"]*$')
    
    if [ -z "$mihomo_version" ]; then
        mihomo_version="v1.18.0"  # 备用版本
        print_status "warning" "无法获取最新版本，使用备用版本: $mihomo_version"
    else
        print_status "info" "最新版本: $mihomo_version"
    fi
    
    # 构建下载URL
    local os_type
    if [ "$OS" = "Linux" ]; then
        os_type="linux"
    elif [ "$OS" = "Mac" ]; then
        os_type="darwin"
    else
        print_status "error" "不支持的操作系统: $OS"
        exit 1
    fi
    
    local mihomo_filename="mihomo-${os_type}-${mihomo_arch}-${mihomo_version}.gz"
    local mihomo_url="https://github.com/MetaCubeX/mihomo/releases/download/${mihomo_version}/${mihomo_filename}"
    
    print_status "info" "下载地址: $mihomo_url"
    
    # 下载并安装
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    print_status "info" "正在下载 mihomo..."
    if curl -fsSL "$mihomo_url" -o mihomo.gz; then
        print_status "info" "解压文件..."
        if gunzip mihomo.gz; then
            # 复制到目标位置
            cp mihomo "$mihomo_binary"
            chmod +x "$mihomo_binary"
            
            # 设置文件权限
            if [ "$OS" = "Linux" ] && [[ $EUID -eq 0 ]]; then
                chown "$TARGET_USER:$TARGET_GROUP" "$mihomo_binary"
            fi
            
            print_status "success" "mihomo 安装成功: $mihomo_binary"
            
            # 验证安装
            if "$mihomo_binary" -v &> /dev/null; then
                local installed_version=$("$mihomo_binary" -v | head -1)
                print_status "success" "mihomo 验证成功: $installed_version"
            else
                print_status "error" "mihomo 验证失败"
                rm -f "$mihomo_binary"
                exit 1
            fi
        else
            print_status "error" "解压失败"
            exit 1
        fi
    else
        print_status "error" "下载失败"
        echo "请检查网络连接或手动下载: $mihomo_url"
        exit 1
    fi
    
    # 清理临时文件
    cd "$PROJECT_ROOT"
    rm -rf "$temp_dir"
}

# 设置二进制文件路径到 config.yaml
setup_binary_paths() {
    print_status "info" "设置二进制文件路径..."
    
    # 使用 setup_default_env 中的 setup_yaml_config 来更新配置
    local config_file="$BASE_DIR/config.yaml"
    
    if [ -f "$config_file" ]; then
        # 确保 yq 可用
        if ! command -v yq >/dev/null 2>&1; then
            print_status "warning" "yq 不可用，跳过配置文件更新"
            return 0
        fi
        
        # 更新 mihomo 路径
        if yq eval '.mihomo.path' "$config_file" >/dev/null 2>&1; then
            yq eval -i ".mihomo.path = \"${BIN_DIR}/mihomo\"" "$config_file"
        else
            print_status "warning" "配置文件中未找到 mihomo.path 字段"
        fi
        
        # 更新 bun 路径
        if yq eval '.bun.path' "$config_file" >/dev/null 2>&1; then
            yq eval -i ".bun.path = \"${BIN_DIR}/bun\"" "$config_file"
        else
            print_status "warning" "配置文件中未找到 bun.path 字段"
        fi
        
        print_status "success" "二进制文件路径设置完成"
    else
        print_status "warning" "配置文件不存在，跳过路径更新: $config_file"
    fi
}

# 设置二进制文件权限
setup_binary_permissions() {
    print_status "info" "设置二进制文件权限..."
    
    if [ "$OS" = "Linux" ]; then
        if [[ $EUID -eq 0 ]]; then
            chown -R "$TARGET_USER:$TARGET_GROUP" "$BIN_DIR"
            chmod 755 "$BIN_DIR"
            find "$BIN_DIR" -type f -exec chmod 755 {} \; 2>/dev/null || true
        else
            safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$BIN_DIR" 2>/dev/null || true
            safe_sudo chmod 755 "$BIN_DIR" 2>/dev/null || true
            safe_sudo find "$BIN_DIR" -type f -exec chmod 755 {} \; 2>/dev/null || true
        fi
    elif [ "$OS" = "Mac" ]; then
        chmod 755 "$BIN_DIR"
        find "$BIN_DIR" -type f -exec chmod 755 {} \; 2>/dev/null || true
    fi
    
    print_status "success" "二进制文件权限设置完成"
}

# 主函数
main() {
    print_status "info" "开始安装二进制文件..."
    
    # 创建二进制目录
    print_status "info" "二进制文件目录: $BIN_DIR"
    
    # 安装 Bun
    install_bun
    
    # 安装 mihomo
    install_mihomo
    
    # 设置二进制文件路径到 config.yaml
    setup_binary_paths
    
    # 设置文件权限
    setup_binary_permissions
    
    print_status "success" "所有二进制文件安装完成！"
    
    # 显示安装信息
    echo ""
    print_status "info" "安装总结:"
    echo "  - Bun: $BIN_DIR/bun"
    echo "  - mihomo: $BIN_DIR/mihomo"
    echo "  - 二进制目录: $BIN_DIR"
}

# 如果脚本直接执行，则运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
