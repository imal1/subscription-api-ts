#!/bin/bash

# 配置管理函数

# 确保 yq 工具可用
ensure_yq() {
    # 检查系统是否已安装 yq
    if command_exists yq; then
        return 0
    fi
    
    # 检查本地 bin 目录是否有 yq
    local yq_path="$BIN_DIR/yq"
    if [ -f "$yq_path" ] && [ -x "$yq_path" ]; then
        export PATH="$BIN_DIR:$PATH"
        return 0
    fi
    
    print_status "info" "下载 yq 工具..."
    
    # 构建下载 URL
    local yq_url=""
    case "$OS" in
        "linux")
            case "$ARCH" in
                "x64") yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" ;;
                "arm64") yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm64" ;;
                "armv7") yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm" ;;
                *) print_status "error" "不支持的架构: $ARCH"; return 1 ;;
            esac
            ;;
        "darwin")
            case "$ARCH" in
                "x64") yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_darwin_amd64" ;;
                "arm64") yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_darwin_arm64" ;;
                *) print_status "error" "不支持的架构: $ARCH"; return 1 ;;
            esac
            ;;
        *) print_status "error" "不支持的操作系统: $OS"; return 1 ;;
    esac
    
    # 下载 yq
    if command_exists curl; then
        curl -L -o "$yq_path" "$yq_url" || return 1
    elif command_exists wget; then
        wget -O "$yq_path" "$yq_url" || return 1
    else
        print_status "error" "需要 curl 或 wget 来下载 yq 工具"
        return 1
    fi
    
    # 设置执行权限
    chmod +x "$yq_path"
    
    # 验证工具
    if "$yq_path" --version >/dev/null 2>&1; then
        export PATH="$BIN_DIR:$PATH"
        print_status "success" "yq 工具安装成功"
        return 0
    else
        rm -f "$yq_path"
        print_status "error" "yq 工具安装失败"
        return 1
    fi
}

# 加载配置文件
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_status "warning" "配置文件不存在: $CONFIG_FILE"
        return 1
    fi
    
    # 确保 yq 工具可用
    if ! ensure_yq; then
        print_status "error" "无法获取 yq 工具，无法解析配置文件"
        return 1
    fi
    
    print_status "info" "加载配置文件: $CONFIG_FILE"
    
    # 读取配置
    export APP_NAME=$(yq eval '.app.name' "$CONFIG_FILE" 2>/dev/null | sed 's/null//')
    export APP_VERSION=$(yq eval '.app.version' "$CONFIG_FILE" 2>/dev/null | sed 's/null//')
    export PORT=$(yq eval '.app.port' "$CONFIG_FILE" 2>/dev/null | sed 's/null//')
    export NODE_ENV=$(yq eval '.app.environment' "$CONFIG_FILE" 2>/dev/null | sed 's/null//')
    
    # 验证配置
    if [ -n "$APP_NAME" ] || [ -n "$PORT" ]; then
        print_status "success" "配置文件加载成功"
        return 0
    else
        print_status "error" "配置文件格式错误或为空"
        return 1
    fi
}

# 创建默认配置文件
create_config() {
    print_status "info" "创建配置文件..."
    
    local project_root=$(get_project_root)
    local example_config="$project_root/config.yaml.example"
    
    if [ -f "$example_config" ]; then
        cp "$example_config" "$CONFIG_FILE"
        print_status "success" "配置文件创建成功: $CONFIG_FILE"
    else
        print_status "error" "找不到配置文件模板: $example_config"
        return 1
    fi
}

# 更新配置文件
update_config() {
    local key="$1"
    local value="$2"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        print_status "error" "配置文件不存在: $CONFIG_FILE"
        return 1
    fi
    
    if ! ensure_yq; then
        print_status "error" "无法获取 yq 工具"
        return 1
    fi
    
    yq eval ".$key = \"$value\"" -i "$CONFIG_FILE"
    print_status "success" "配置已更新: $key = $value"
}
