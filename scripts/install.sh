#!/bin/bash

# Subscription API TypeScript 自动安装脚本
# 
# 支持的执行方式:
# 1. 普通用户: bash scripts/install.sh
# 2. sudo执行: sudo bash scripts/install.sh (推荐)
# 3. root用户: bash scripts/install.sh (仅Linux)
#
# 功能:
# - 自动检测操作系统 (Linux/macOS)
# - 安装 Node.js 和项目依赖
# - 创建必要目录和配置文件
# - 安装 systemd 服务 (Linux)
# - 配置 Nginx (可选)

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 引入公共函数库
source "$SCRIPT_DIR/common.sh"

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

# 删除旧的配置文件，确保全新安装环境
echo "🧹 清理旧配置文件..."
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo "  删除旧的 .env 文件"
    rm -f "$PROJECT_ROOT/.env"
fi
if [ -f "$PROJECT_ROOT/config/nginx.conf" ]; then
    echo "  删除旧的 nginx.conf 文件"
    rm -f "$PROJECT_ROOT/config/nginx.conf"
fi

# 设置默认值 - 统一使用 $HOME/.config/.subscription 下的目录
export BASE_DIR="${BASE_DIR:-$HOME/.config/.subscription}"

export DATA_DIR="${DATA_DIR:-${BASE_DIR}/www}"
export LOG_DIR="${LOG_DIR:-${BASE_DIR}/log}"
export NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"

# 设置工作目录为项目根目录
cd "$PROJECT_ROOT"

# 检测操作系统
OS=""
case "$(uname -s)" in
    Linux*)     OS=Linux;;
    Darwin*)    OS=Mac;;
    *)          OS="UNKNOWN";;
esac

echo "🚀 开始安装 Subscription API TypeScript..."
echo "📍 项目目录: $PROJECT_ROOT"
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

# 安装Node.js (如果未安装)
if ! command -v node &> /dev/null; then
    echo "📦 安装 Node.js..."
    if [ "$OS" = "Linux" ]; then
        if [[ $EUID -eq 0 ]]; then
            # root 用户直接安装
            curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
            apt-get install -y nodejs
        else
            # 非 root 用户使用 safe_sudo
            curl -fsSL https://deb.nodesource.com/setup_18.x | safe_sudo -E bash -
            safe_sudo apt-get install -y nodejs
        fi
    elif [ "$OS" = "Mac" ]; then
        if command -v brew &> /dev/null; then
            brew install node
        else
            echo "❌ 未找到 Homebrew，请先安装："
            echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            echo "   或访问 https://nodejs.org/ 手动下载安装"
            exit 1
        fi
    fi
fi

# 安装 Bun (如果未安装)
if ! command -v bun &> /dev/null; then
    echo "📦 安装 Bun..."
    
    # 检测系统架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            BUN_ARCH="x64"
            ;;
        aarch64|arm64)
            BUN_ARCH="aarch64"
            ;;
        *)
            echo "❌ 不支持的系统架构: $ARCH"
            exit 1
            ;;
    esac
    
    # 设置 Bun 安装目录
    if [ "$OS" = "Linux" ]; then
        if [[ $EUID -eq 0 ]]; then
            BUN_INSTALL_DIR="/usr/local/bin"
            BUN_BINARY="$BUN_INSTALL_DIR/bun"
        else
            BUN_INSTALL_DIR="$HOME/.local/bin"
            BUN_BINARY="$BUN_INSTALL_DIR/bun"
            mkdir -p "$BUN_INSTALL_DIR"
        fi
    elif [ "$OS" = "Mac" ]; then
        BUN_INSTALL_DIR="$HOME/.local/bin"
        BUN_BINARY="$BUN_INSTALL_DIR/bun"
        mkdir -p "$BUN_INSTALL_DIR"
    fi
    
    echo "   下载 Bun 到 $BUN_BINARY..."
    
    # 获取最新版本
    BUN_VERSION=$(curl -s https://api.github.com/repos/oven-sh/bun/releases/latest | grep -o '"tag_name": "[^"]*' | grep -o '[^"]*$' | sed 's/^bun-v//')
    if [ -z "$BUN_VERSION" ]; then
        BUN_VERSION="1.0.30"  # 备用版本
    fi
    
    # 根据操作系统构建下载URL
    if [ "$OS" = "Linux" ]; then
        BUN_URL="https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-${BUN_ARCH}.zip"
    elif [ "$OS" = "Mac" ]; then
        BUN_URL="https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-darwin-${BUN_ARCH}.zip"
    fi
    
    # 下载并安装
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    if curl -fsSL "$BUN_URL" -o bun.zip; then
        if command -v unzip &> /dev/null; then
            unzip -q bun.zip
            # 查找解压后的bun可执行文件
            BUN_EXTRACTED=$(find . -name "bun" -type f -executable | head -1)
            if [ -n "$BUN_EXTRACTED" ]; then
                if [[ $EUID -eq 0 ]] || [ "$OS" = "Linux" ] && [ "$BUN_INSTALL_DIR" = "/usr/local/bin" ]; then
                    safe_sudo cp "$BUN_EXTRACTED" "$BUN_BINARY"
                    safe_sudo chmod +x "$BUN_BINARY"
                else
                    cp "$BUN_EXTRACTED" "$BUN_BINARY"
                    chmod +x "$BUN_BINARY"
                fi
                echo "   ✅ Bun 安装成功: $BUN_BINARY"
                
                # 添加到PATH (如果需要)
                if [ "$BUN_INSTALL_DIR" = "$HOME/.local/bin" ]; then
                    if ! echo "$PATH" | grep -q "$BUN_INSTALL_DIR"; then
                        echo "   🔧 添加 $BUN_INSTALL_DIR 到 PATH..."
                        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
                        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
                        [ -f "$HOME/.zshrc" ] && echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
                        export PATH="$HOME/.local/bin:$PATH"
                    fi
                fi
            else
                echo "❌ 无法找到解压后的 bun 可执行文件"
                exit 1
            fi
        else
            echo "❌ 系统缺少 unzip 命令"
            if [ "$OS" = "Linux" ]; then
                echo "   请安装: apt-get install unzip 或 yum install unzip"
            fi
            exit 1
        fi
    else
        echo "❌ 下载 Bun 失败"
        echo "   请检查网络连接或手动安装: curl -fsSL https://bun.sh/install | bash"
        exit 1
    fi
    
    # 清理临时文件
    cd "$PROJECT_ROOT"
    rm -rf "$TEMP_DIR"
    
    # 验证安装
    if "$BUN_BINARY" --version &> /dev/null; then
        echo "   ✅ Bun 验证成功: $("$BUN_BINARY" --version)"
        # 创建符号链接到 bun 命令 (如果不在标准路径)
        if [ "$BUN_INSTALL_DIR" != "/usr/local/bin" ] && [ "$BUN_INSTALL_DIR" != "/usr/bin" ]; then
            alias bun="$BUN_BINARY"
            echo "   💡 使用 $BUN_BINARY 替代 bun 命令"
        fi
    else
        echo "❌ Bun 安装验证失败"
        exit 1
    fi
else
    echo "✅ Bun 已安装: $(bun --version)"
    BUN_BINARY=$(which bun)
fi

# 设置全局 BUN_BINARY 变量供后续使用
export BUN_BINARY

# 下载和安装 mihomo
echo "📦 下载和安装 mihomo..."

# 获取系统信息
ARCH=$(uname -m)
OS_TYPE=""
case "$(uname -s)" in
    Linux*)     OS_TYPE="linux";;
    Darwin*)    OS_TYPE="darwin";;
    *)          
        echo "❌ 不支持的操作系统"
        exit 1
        ;;
esac

# 映射架构名称
case $ARCH in
    x86_64)
        BUN_ARCH="amd64"
        ;;
    aarch64|arm64)
        BUN_ARCH="arm64"
        ;;
    arm*)
        BUN_ARCH="armv7"
        ;;
    *)
        echo "❌ 不支持的系统架构: $ARCH"
        exit 1
        ;;
esac

# 设置 mihomo 安装目录（使用统一的基础目录）
MIHOMO_DIR="$BASE_DIR/mihomo"
MIHOMO_BINARY="$MIHOMO_DIR/mihomo"

mkdir -p "$MIHOMO_DIR"

echo "   mihomo 安装目录: $MIHOMO_DIR"

# 检查是否已经安装了 mihomo
if [ -f "$MIHOMO_BINARY" ] && "$MIHOMO_BINARY" -v &> /dev/null; then
    echo "   ✅ mihomo 已安装: $("$MIHOMO_BINARY" -v | head -1)"
else
    # 获取最新版本
    echo "   获取最新版本信息..."
    MIHOMO_VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep -o '"tag_name": "[^"]*' | grep -o '[^"]*$')
    if [ -z "$MIHOMO_VERSION" ]; then
        MIHOMO_VERSION="v1.18.0"  # 备用版本
        echo "   ⚠️  无法获取最新版本，使用备用版本: $MIHOMO_VERSION"
    else
        echo "   最新版本: $MIHOMO_VERSION"
    fi
    
    # 构建下载 URL
    MIHOMO_FILENAME="mihomo-${OS_TYPE}-${BUN_ARCH}-${MIHOMO_VERSION}.gz"
    MIHOMO_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/${MIHOMO_FILENAME}"
    
    echo "   下载地址: $MIHOMO_URL"
    
    # 下载并安装
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    if curl -fsSL "$MIHOMO_URL" -o mihomo.gz; then
        echo "   解压缩文件..."
        if gunzip mihomo.gz; then
            # 复制到目标位置
            cp mihomo "$MIHOMO_BINARY"
            chmod +x "$MIHOMO_BINARY"
            
            echo "   ✅ mihomo 下载安装成功: $MIHOMO_BINARY"
            
            # 验证安装
            if "$MIHOMO_BINARY" -v &> /dev/null; then
                echo "   ✅ mihomo 验证成功: $("$MIHOMO_BINARY" -v | head -1)"
            else
                echo "   ❌ mihomo 验证失败"
                rm -f "$MIHOMO_BINARY"
                exit 1
            fi
        else
            echo "   ❌ 解压缩失败"
            exit 1
        fi
    else
        echo "   ❌ 下载失败"
        echo "   请检查网络连接或手动下载: $MIHOMO_URL"
        exit 1
    fi
    
    # 清理临时文件
    cd "$PROJECT_ROOT"
    rm -rf "$TEMP_DIR"
fi

# 设置环境变量
echo "   设置 mihomo 路径到环境文件..."
if [ -f .env ]; then
    if grep -q "MIHOMO_PATH=" .env; then
        if [ "$OS" = "Linux" ]; then
            sed -i "s|MIHOMO_PATH=.*|MIHOMO_PATH=${MIHOMO_DIR}|g" .env
        elif [ "$OS" = "Mac" ]; then
            sed -i '' "s|MIHOMO_PATH=.*|MIHOMO_PATH=${MIHOMO_DIR}|g" .env
        fi
    else
        echo "MIHOMO_PATH=${MIHOMO_DIR}" >> .env
    fi
else
    echo "MIHOMO_PATH=${MIHOMO_DIR}" > .env
fi

echo "   ✅ mihomo 环境配置完成"

# 安装项目依赖
echo "📦 安装项目依赖..."

# 定义安装函数
install_dependencies() {
    local user_prefix="$1"
    local install_success=false
    
    # 使用检测到的或安装的 bun 路径
    BUN_CMD="${BUN_BINARY:-bun}"
    
    # 使用 bun 安装依赖
    echo "   使用 $BUN_CMD 安装依赖..."
    if $user_prefix "$BUN_CMD" install --dev 2>/dev/null; then
        echo "   ✅ bun install 安装成功"
        install_success=true
    else
        echo "   ❌ bun install 失败，请检查错误信息"
        return 1
    fi
    
    # 验证关键依赖是否安装成功
    if [ "$install_success" = true ]; then
        if ! $user_prefix test -f "node_modules/@types/node/index.d.ts"; then
            echo "   ⚠️  重新安装 @types/node..."
            $user_prefix "$BUN_CMD" add --dev @types/node
        fi
    fi
    
    return 0
}

if [[ $EUID -eq 0 ]] && [ "$OS" = "Linux" ]; then
    # root 用户执行时，确保 package.json 等文件权限正确
    safe_sudo chown -R $TARGET_USER:$TARGET_GROUP "$PROJECT_ROOT"
    # 使用目标用户身份安装依赖
    if [ "$TARGET_USER" != "root" ]; then
        echo "   使用用户 $TARGET_USER 安装依赖..."
        if ! install_dependencies "safe_sudo_user $TARGET_USER"; then
            echo "❌ 依赖安装失败"
            exit 1
        fi
    else
        if ! install_dependencies ""; then
            echo "❌ 依赖安装失败"
            exit 1
        fi
    fi
else
    if ! install_dependencies ""; then
        echo "❌ 依赖安装失败"
        exit 1
    fi
fi

# 验证依赖安装
echo "🔍 验证依赖安装..."
MISSING_DEPS=""
REQUIRED_DEPS=(
    "node_modules/@types/express"
    "node_modules/@types/cors"
    "node_modules/@types/compression"
    "node_modules/@types/node-cron"
    "node_modules/@types/node"
    "node_modules/@types/fs-extra"
    "node_modules/typescript"
)

for dep in "${REQUIRED_DEPS[@]}"; do
    if [ ! -d "$dep" ]; then
        MISSING_DEPS="$MISSING_DEPS $(basename $dep)"
    fi
done

if [ -n "$MISSING_DEPS" ]; then
    echo "❌ 缺少依赖:$MISSING_DEPS"
    echo "🔧 重新安装缺少的依赖..."
    if [[ $EUID -eq 0 ]] && [ "$TARGET_USER" != "root" ]; then
        if ! install_dependencies "safe_sudo_user $TARGET_USER"; then
            echo "❌ 重新安装依赖失败"
            exit 1
        fi
    else
        if ! install_dependencies ""; then
            echo "❌ 重新安装依赖失败"
            exit 1
        fi
    fi
fi

# 检查并安装TypeScript工具
echo "🔧 检查 TypeScript 工具..."
if [ -f "node_modules/.bin/tsc" ] && [ -f "node_modules/.bin/ts-node" ]; then
    echo "✅ 使用项目本地的 TypeScript 工具"
else
    echo "🔧 安装全局 TypeScript 工具..."
    BUN_CMD="${BUN_BINARY:-bun}"
    if [ "$OS" = "Linux" ]; then
        if [[ $EUID -eq 0 ]]; then
            "$BUN_CMD" add -g typescript ts-node pm2
        else
            safe_sudo "$BUN_CMD" add -g typescript ts-node pm2
        fi
    elif [ "$OS" = "Mac" ]; then
        "$BUN_CMD" add -g typescript ts-node pm2
    fi
fi

# 创建必要目录
echo "📁 创建目录..."
echo "   数据目录: $DATA_DIR"
echo "   日志目录: $LOG_DIR"

# 创建目录并设置权限的函数
setup_directory() {
    local dir_path="$1"
    local dir_name="$2"
    local user="$3"
    local group="$4"
    
    echo "   创建 $dir_name: $dir_path"
    
    # 创建目录
    if [[ "$dir_path" == /* ]]; then
        # 绝对路径
        if [[ $EUID -eq 0 ]]; then
            mkdir -p "$dir_path"
        else
            safe_sudo mkdir -p "$dir_path"
        fi
    else
        # 相对路径
        mkdir -p "$dir_path"
    fi
    
    # 设置所有者
    if [[ $EUID -eq 0 ]]; then
        safe_sudo chown -R "$user:$group" "$dir_path"
    else
        if [[ "$dir_path" == /* ]]; then
            safe_sudo chown -R "$user:$group" "$dir_path"
        else
            safe_sudo chown -R "$user:$group" "$dir_path" 2>/dev/null || true
        fi
    fi
    
    # 设置权限：用户读写执行，组读执行，其他人无权限
    if [[ $EUID -eq 0 ]]; then
        safe_sudo chmod -R 750 "$dir_path"
        # 确保目录有执行权限
        safe_sudo find "$dir_path" -type d -exec chmod 750 {} \;
        # 确保文件有读写权限
        safe_sudo find "$dir_path" -type f -exec chmod 640 {} \; 2>/dev/null || true
    else
        if [[ "$dir_path" == /* ]]; then
            safe_sudo chmod -R 750 "$dir_path"
            safe_sudo find "$dir_path" -type d -exec chmod 750 {} \; 2>/dev/null || true
            safe_sudo find "$dir_path" -type f -exec chmod 640 {} \; 2>/dev/null || true
        else
            safe_sudo chmod -R 750 "$dir_path" 2>/dev/null || true
            safe_sudo find "$dir_path" -type d -exec chmod 750 {} \; 2>/dev/null || true
            safe_sudo find "$dir_path" -type f -exec chmod 640 {} \; 2>/dev/null || true
        fi
    fi
    
    # 验证权限设置
    if [ -d "$dir_path" ]; then
        local actual_owner=$(ls -ld "$dir_path" | awk '{print $3":"$4}')
        local actual_perms=$(ls -ld "$dir_path" | awk '{print $1}')
        echo "   ✅ $dir_name 创建成功 (所有者: $actual_owner, 权限: $actual_perms)"
    else
        echo "   ❌ $dir_name 创建失败"
        return 1
    fi
}

if [ "$OS" = "Linux" ]; then
    # 设置数据目录
    setup_directory "$DATA_DIR" "数据目录" "$TARGET_USER" "$TARGET_GROUP"
    
    # 设置日志目录
    setup_directory "$LOG_DIR" "日志目录" "$TARGET_USER" "$TARGET_GROUP"
    
    # 创建数据目录的子目录
    if [[ $EUID -eq 0 ]]; then
        safe_sudo mkdir -p "$DATA_DIR/backup"
        safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$DATA_DIR/backup"
        safe_sudo chmod -R 750 "$DATA_DIR/backup"
    else
        if [[ "$DATA_DIR" == /* ]]; then
            safe_sudo mkdir -p "$DATA_DIR/backup"
            safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$DATA_DIR/backup"
            safe_sudo chmod -R 750 "$DATA_DIR/backup"
        else
            mkdir -p "$DATA_DIR/backup"
            safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$DATA_DIR/backup" 2>/dev/null || true
            safe_sudo chmod -R 750 "$DATA_DIR/backup" 2>/dev/null || true
        fi
    fi
    
elif [ "$OS" = "Mac" ]; then
    # macOS 上设置目录权限
    mkdir -p "$DATA_DIR"
    mkdir -p "$DATA_DIR/backup"
    mkdir -p "$LOG_DIR"
    mkdir -p dist
    
    # 设置适当的权限
    safe_sudo chmod -R 750 "$DATA_DIR" 2>/dev/null || true
    safe_sudo chmod -R 750 "$LOG_DIR" 2>/dev/null || true
    
    echo "   ✅ macOS 目录创建完成"
    echo "   - 数据目录: $DATA_DIR"
    echo "   - 日志目录: $LOG_DIR"
fi

# 复制环境配置文件
if [ ! -f .env ]; then
    echo "⚙️ 创建环境配置文件..."
    safe_sudo cp .env.example .env
    
    # 根据操作系统调整配置文件中的路径
    if [ "$OS" = "Linux" ]; then
        # 使用已经设置的目录路径
        sed -i "s|BASE_DIR=.*|BASE_DIR=${BASE_DIR}|g" .env
        sed -i "s|DATA_DIR=.*|DATA_DIR=${DATA_DIR}|g" .env
        sed -i "s|LOG_DIR=.*|LOG_DIR=${LOG_DIR}|g" .env
        echo "✅ 已配置 Linux 系统路径"
        echo "   基础目录: ${BASE_DIR}"
        echo "   数据目录: ${DATA_DIR}"
        echo "   日志目录: ${LOG_DIR}"
    elif [ "$OS" = "Mac" ]; then
        sed -i '' "s|BASE_DIR=.*|BASE_DIR=${BASE_DIR}|g" .env
        sed -i '' "s|DATA_DIR=.*|DATA_DIR=${DATA_DIR}|g" .env
        sed -i '' "s|LOG_DIR=.*|LOG_DIR=${LOG_DIR}|g" .env
        echo "✅ 已配置 macOS 项目本地路径"
        echo "   基础目录: ${BASE_DIR}"
        echo "   数据目录: ${DATA_DIR}"
        echo "   日志目录: ${LOG_DIR}"
    fi
    
    echo "请编辑 .env 文件配置您的参数"
    
    # 确保 .env 文件的权限正确
    if [ "$OS" = "Linux" ]; then
        if [[ $EUID -eq 0 ]]; then
            safe_sudo chown "$TARGET_USER:$TARGET_GROUP" .env
            safe_sudo chmod 640 .env
        else
            safe_sudo chown "$TARGET_USER:$TARGET_GROUP" .env 2>/dev/null || true
            safe_sudo chmod 640 .env 2>/dev/null || true
        fi
        echo "✅ .env 文件权限已设置 (所有者: $TARGET_USER:$TARGET_GROUP, 权限: 640)"
    fi
fi

# 构建项目（包含前端）
echo "🏗️ 构建项目..."

# 清理之前的构建文件
echo "   清理旧的构建文件..."
rm -rf dist
rm -rf frontend/dist 2>/dev/null || true

# 验证 TypeScript 配置
echo "   验证 TypeScript 配置..."
if [ ! -f "tsconfig.json" ]; then
    echo "❌ 未找到 tsconfig.json"
    exit 1
fi

# 验证源代码目录
if [ ! -d "src" ]; then
    echo "❌ 未找到 src 目录"
    exit 1
fi

# 执行构建（monorepo方式）
echo "   执行 TypeScript 编译和前端构建..."
BUN_CMD="${BUN_BINARY:-bun}"
if [[ $EUID -eq 0 ]] && [ "$OS" = "Linux" ] && [ "$TARGET_USER" != "root" ]; then
    # root 执行但目标用户非 root 时，使用目标用户身份构建
    if ! safe_sudo_user $TARGET_USER "$BUN_CMD" run build:all; then
        echo "❌ 构建失败，请检查 TypeScript 错误"
        echo "   尝试运行: $BUN_CMD run build:all 查看详细错误信息"
        echo "   或者检查 tsconfig.json 配置"
        exit 1
    fi
else
    if ! "$BUN_CMD" run build:all; then
        echo "❌ 构建失败，请检查 TypeScript 错误"
        echo "   尝试运行: $BUN_CMD run build:all 查看详细错误信息"
        echo "   或者检查 tsconfig.json 配置"
        exit 1
    fi
fi

# 验证构建结果
if [ ! -f "dist/index.js" ]; then
    echo "❌ 后端构建失败：未找到 dist/index.js"
    exit 1
fi

if [ -d "frontend" ] && [ ! -f "frontend/dist/index.html" ]; then
    echo "❌ 前端构建失败：未找到 frontend/dist/index.html"
    exit 1
fi

echo "✅ 构建成功！"

# 设置前端文件权限（Linux）
if [ "$OS" = "Linux" ] && [ -d "frontend/dist" ]; then
    echo "🔧 设置前端文件权限..."
    NGINX_USER="www-data"
    if ! id "$NGINX_USER" >/dev/null 2>&1; then
        for user in nginx http; do
            if id "$user" >/dev/null 2>&1; then
                NGINX_USER="$user"
                break
            fi
        done
    fi
    
    # 设置适当的权限
    if [[ $EUID -eq 0 ]]; then
        safe_sudo chown -R "$NGINX_USER:$NGINX_USER" frontend/dist/
        safe_sudo chmod -R 755 frontend/dist/
        safe_sudo find frontend/dist/ -type f -exec chmod 644 {} \; 2>/dev/null || true
    else
        safe_sudo chown -R "$NGINX_USER:$NGINX_USER" frontend/dist/ 2>/dev/null || true
        safe_sudo chmod -R 755 frontend/dist/ 2>/dev/null || true
        safe_sudo find frontend/dist/ -type f -exec chmod 644 {} \; 2>/dev/null || true
    fi
    echo "   ✅ 前端文件权限设置完成"
fi

# 安装系统服务
if [ "$OS" = "Linux" ]; then
    echo "🔧 安装 systemd 服务..."
    
    # 检查并修复 Node.js 路径问题
    echo "🔍 检查 Node.js 路径..."
    CURRENT_NODE=$(which node)
    echo "   当前 Node.js 路径: $CURRENT_NODE"
    
    # 如果使用了版本管理器，自动修复
    if [[ "$CURRENT_NODE" == *".local"* ]] || [[ "$CURRENT_NODE" == *"/run/user/"* ]]; then
        echo "⚠️  检测到用户环境路径，自动修复..."
        
        # 检查系统路径是否已有 Node.js
        SYSTEM_NODE=""
        for path in "/usr/bin/node" "/usr/local/bin/node"; do
            if [ -f "$path" ] && [ -x "$path" ]; then
                SYSTEM_NODE="$path"
                break
            fi
        done
        
        if [ -z "$SYSTEM_NODE" ]; then
            echo "   复制 Node.js 到系统路径..."
            if [[ $EUID -eq 0 ]]; then
                safe_sudo cp "$CURRENT_NODE" /usr/local/bin/node
                safe_sudo chmod +x /usr/local/bin/node
                echo "   ✅ Node.js 已复制到 /usr/local/bin/node"
            else
                if safe_sudo cp "$CURRENT_NODE" /usr/local/bin/node && safe_sudo chmod +x /usr/local/bin/node; then
                    echo "   ✅ Node.js 已复制到 /usr/local/bin/node"
                else
                    echo "   ❌ 复制失败，请手动执行："
                    if [ "$HAS_SUDO" = true ]; then
                        echo "      sudo cp $CURRENT_NODE /usr/local/bin/node"
                        echo "      sudo chmod +x /usr/local/bin/node"
                    else
                        echo "      cp $CURRENT_NODE /usr/local/bin/node"
                        echo "      chmod +x /usr/local/bin/node"
                        echo "      (需要root权限)"
                    fi
                fi
            fi
        else
            echo "   ✅ 系统已有 Node.js: $SYSTEM_NODE"
        fi
    else
        echo "   ✅ 使用系统 Node.js 路径"
    fi
    
    # 设置环境变量供服务生成脚本使用
    export SERVICE_USER="$TARGET_USER" SERVICE_GROUP="$TARGET_GROUP"
    
    # 获取项目绝对路径并验证
    ABSOLUTE_PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
    echo "📁 项目绝对路径: $ABSOLUTE_PROJECT_ROOT"
    
    # 验证项目目录和关键文件
    if [ ! -d "$ABSOLUTE_PROJECT_ROOT" ]; then
        echo "❌ 项目目录不存在: $ABSOLUTE_PROJECT_ROOT"
        exit 1
    fi
    
    if [ ! -f "$ABSOLUTE_PROJECT_ROOT/dist/index.js" ]; then
        echo "❌ 编译文件不存在: $ABSOLUTE_PROJECT_ROOT/dist/index.js"
        echo "   请确保项目构建成功"
        exit 1
    fi
    
    # 验证环境文件
    if [ ! -f "$ABSOLUTE_PROJECT_ROOT/.env" ]; then
        echo "⚠️  环境文件不存在: $ABSOLUTE_PROJECT_ROOT/.env"
        if [ -f "$ABSOLUTE_PROJECT_ROOT/.env.example" ]; then
            echo "📋 复制示例环境文件..."
            safe_sudo cp "$ABSOLUTE_PROJECT_ROOT/.env.example" "$ABSOLUTE_PROJECT_ROOT/.env"
            echo "✅ 已创建环境文件，请根据需要修改配置"
        else
            echo "   请创建 .env 文件配置环境变量"
        fi
    fi
    
    # 检查目标用户对项目目录的访问权限
    if ! safe_sudo_user "$TARGET_USER" test -r "$ABSOLUTE_PROJECT_ROOT"; then
        echo "⚠️  用户 $TARGET_USER 无法访问项目目录，调整权限..."
        if [[ $EUID -eq 0 ]]; then
            safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$ABSOLUTE_PROJECT_ROOT"
            safe_sudo chmod -R u+rX "$ABSOLUTE_PROJECT_ROOT"
        else
            safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$ABSOLUTE_PROJECT_ROOT"
            safe_sudo chmod -R u+rX "$ABSOLUTE_PROJECT_ROOT"
        fi
    fi
    
    # 生成systemd服务文件
    echo "🔧 生成systemd服务配置..."
    echo "📁 安装目录: $ABSOLUTE_PROJECT_ROOT"
    echo "👤 运行用户: $TARGET_USER"
    echo "👥 运行组: $TARGET_GROUP"
    
    # 检查服务模板文件
    SERVICE_TEMPLATE="$ABSOLUTE_PROJECT_ROOT/config/subscription-api-ts.service.template"
    if [ ! -f "$SERVICE_TEMPLATE" ]; then
        echo "❌ 服务模板文件不存在: $SERVICE_TEMPLATE"
        exit 1
    fi
    
    # 获取Node.js路径
    NODE_PATH=$(which node)
    if [ -z "$NODE_PATH" ]; then
        echo "❌ 未找到 node 可执行文件"
        exit 1
    fi
    echo "🔍 Node.js 路径: $NODE_PATH"
    
    # 生成服务文件
    SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"
    SERVICE_OUTPUT="/tmp/${SERVICE_NAME}.service"
    
    # 检查并安装envsubst (如果需要)
    if ! command -v envsubst >/dev/null 2>&1; then
        echo "🔧 安装 envsubst 工具..."
        if [[ $EUID -eq 0 ]]; then
            safe_sudo apt-get update && safe_sudo apt-get install -y gettext-base
        else
            safe_sudo apt-get update && safe_sudo apt-get install -y gettext-base
        fi
    fi
    
    # 导出环境变量供envsubst使用
    export SERVICE_USER="$TARGET_USER" SERVICE_GROUP="$TARGET_GROUP" INSTALL_DIR="$ABSOLUTE_PROJECT_ROOT" NODE_PATH DATA_DIR LOG_DIR
    
    # 生成服务文件
    envsubst '${SERVICE_USER} ${SERVICE_GROUP} ${INSTALL_DIR} ${NODE_PATH} ${DATA_DIR} ${LOG_DIR}' < "$SERVICE_TEMPLATE" > "$SERVICE_OUTPUT"
    echo "✅ 服务文件已生成: $SERVICE_OUTPUT"
    
    # 安装服务文件
    SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"
    safe_sudo cp "/tmp/${SERVICE_NAME}.service" /etc/systemd/system/
    safe_sudo systemctl daemon-reload
    safe_sudo systemctl enable "$SERVICE_NAME"
    
    echo "✅ 服务文件已安装到 /etc/systemd/system/${SERVICE_NAME}.service"
    echo "📁 工作目录: $PROJECT_ROOT"
    echo "👤 运行用户: $TARGET_USER"
    
    # 验证数据目录权限
    echo "🔍 验证数据目录权限..."
    echo "   数据目录: $DATA_DIR"
    if [ -d "$DATA_DIR" ]; then
        # 测试写入权限
        TEST_FILE="$DATA_DIR/.write_test_$$"
        if safe_sudo_user "$TARGET_USER" touch "$TEST_FILE" 2>/dev/null; then
            safe_sudo_user "$TARGET_USER" rm -f "$TEST_FILE" 2>/dev/null || true
            echo "   ✅ 数据目录写入权限正常"
        else
            echo "   ❌ 数据目录写入权限异常，尝试修复..."
            # 重新设置权限
            if [[ $EUID -eq 0 ]]; then
                safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$DATA_DIR"
                safe_sudo chmod -R 750 "$DATA_DIR"
                safe_sudo find "$DATA_DIR" -type d -exec chmod 750 {} \;
                safe_sudo find "$DATA_DIR" -type f -exec chmod 640 {} \; 2>/dev/null || true
            else
                safe_sudo chown -R "$TARGET_USER:$TARGET_GROUP" "$DATA_DIR"
                safe_sudo chmod -R 750 "$DATA_DIR"
                safe_sudo find "$DATA_DIR" -type d -exec chmod 750 {} \; 2>/dev/null || true
                safe_sudo find "$DATA_DIR" -type f -exec chmod 640 {} \; 2>/dev/null || true
            fi
            
            # 再次测试
            if safe_sudo_user "$TARGET_USER" touch "$TEST_FILE" 2>/dev/null; then
                safe_sudo_user "$TARGET_USER" rm -f "$TEST_FILE" 2>/dev/null || true
                echo "   ✅ 权限修复成功"
            else
                echo "   ❌ 权限修复失败，请检查以下问题："
                echo "      1. 文件系统是否为只读挂载"
                echo "      2. SELinux 是否阻止了写入"
                echo "      3. 磁盘空间是否足够"
                echo "      4. 目录路径是否正确"
                ls -la "$DATA_DIR" 2>/dev/null || echo "      目录不存在或无法访问"
            fi
        fi
        
        # 显示目录详细信息
        echo "   数据目录详情:"
        ls -la "$DATA_DIR" 2>/dev/null || echo "      无法访问目录"
        echo "   挂载信息:"
        df -h "$DATA_DIR" 2>/dev/null || echo "      无法获取挂载信息"
    else
        echo "   ❌ 数据目录不存在: $DATA_DIR"
    fi
    
    # 检查服务状态并重启/启动服务
    echo "🔄 检查和重启服务..."
    
    # 准备日志提示命令
    if [[ $EUID -eq 0 ]]; then
        STATUS_CMD="systemctl status $SERVICE_NAME"
        LOG_CMD="journalctl -u $SERVICE_NAME -f"
    else
        if [ "$HAS_SUDO" = true ]; then
            STATUS_CMD="sudo systemctl status $SERVICE_NAME"
            LOG_CMD="sudo journalctl -u $SERVICE_NAME -f"
        else
            STATUS_CMD="systemctl status $SERVICE_NAME (需要root权限)"
            LOG_CMD="journalctl -u $SERVICE_NAME -f (需要root权限)"
        fi
    fi
    
    # 检查并启动/重启服务
    if safe_sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "   服务正在运行，重启以加载新代码..."
        if safe_sudo systemctl restart "$SERVICE_NAME"; then
            echo "   ✅ 服务重启成功"
        else
            echo "   ❌ 服务重启失败，请检查日志:"
            echo "      $STATUS_CMD"
            echo "      $LOG_CMD"
        fi
    else
        echo "   服务未运行，启动服务..."
        if safe_sudo systemctl start "$SERVICE_NAME"; then
            echo "   ✅ 服务启动成功"
        else
            echo "   ❌ 服务启动失败，请检查日志:"
            echo "      $STATUS_CMD"
            echo "      $LOG_CMD"
        fi
    fi
    
    # 显示服务状态
    echo "📊 服务状态:"
    safe_sudo systemctl status "$SERVICE_NAME" --no-pager -l || true
elif [ "$OS" = "Mac" ]; then
    echo "ℹ️  macOS 用户请手动启动服务或使用 pm2"
fi

# 安装Nginx配置
if command -v nginx &> /dev/null; then
    echo "🌐 配置 Nginx..."
    
    # 生成nginx配置文件
    echo "📄 生成 Nginx 配置文件..."
    API_PORT="${PORT:-3000}"
    NGINX_PORT="${NGINX_PORT:-3080}"
    NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"
    
    # 获取项目绝对路径（用于nginx配置）
    ABSOLUTE_PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
    
    # 检查并安装envsubst (gettext包的一部分)
    if ! command -v envsubst >/dev/null 2>&1; then
        echo "🔧 安装 envsubst 工具..."
        if [ "$OS" = "Linux" ]; then
            if [[ $EUID -eq 0 ]]; then
                apt-get update && apt-get install -y gettext-base
            else
                safe_sudo apt-get update && safe_sudo apt-get install -y gettext-base
            fi
        elif [ "$OS" = "Mac" ]; then
            if command -v brew &> /dev/null; then
                brew install gettext
                # 添加到PATH
                export PATH="/usr/local/opt/gettext/bin:$PATH"
            fi
        fi
    fi
    
    # 使用envsubst生成配置文件
    export API_PORT NGINX_PORT NGINX_PROXY_PORT DATA_DIR LOG_DIR ABSOLUTE_PROJECT_ROOT
    if command -v envsubst >/dev/null 2>&1; then
        # 只替换指定的环境变量，避免nginx变量被误替换
        envsubst '${API_PORT} ${NGINX_PORT} ${NGINX_PROXY_PORT} ${DATA_DIR} ${LOG_DIR} ${ABSOLUTE_PROJECT_ROOT}' < config/nginx.conf.template > config/nginx.conf
        echo "✅ 使用 envsubst 生成配置文件"
    else
        # 如果没有envsubst，使用sed替换
        sed "s/\${API_PORT}/${API_PORT}/g; s/\${NGINX_PORT}/${NGINX_PORT}/g; s/\${NGINX_PROXY_PORT}/${NGINX_PROXY_PORT}/g; s|\${DATA_DIR}|${DATA_DIR}|g; s|\${LOG_DIR}|${LOG_DIR}|g; s|\${ABSOLUTE_PROJECT_ROOT}|${ABSOLUTE_PROJECT_ROOT}|g" config/nginx.conf.template > config/nginx.conf
        echo "✅ 使用 sed 生成配置文件"
    fi
    
    if [ "$OS" = "Linux" ]; then
        # 修复 Nginx 静态文件服务权限
        echo "🔧 配置 Nginx 权限..."
        
        # 检查数据目录权限
        if [ -d "$DATA_DIR" ]; then
            # 检查 Nginx 用户
            NGINX_USER="www-data"
            if ! id "$NGINX_USER" >/dev/null 2>&1; then
                for user in nginx http; do
                    if id "$user" >/dev/null 2>&1; then
                        NGINX_USER="$user"
                        break
                    fi
                done
            fi
            
            # 修复权限
            safe_sudo chown -R "$NGINX_USER:$NGINX_USER" "$DATA_DIR"
            safe_sudo chmod -R 755 "$DATA_DIR"
            safe_sudo find "$DATA_DIR" -type f -exec chmod 644 {} \; 2>/dev/null || true
            
            # 创建测试文件
            cat > /tmp/test.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Nginx 测试页面</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>🎉 Nginx 静态服务正常工作！</h1>
    <p>如果您看到这个页面，说明 Nginx 静态文件服务已经正确配置。</p>
    <p>访问时间: <script>document.write(new Date().toLocaleString());</script></p>
    <hr>
    <p><a href="/subscription.txt">查看订阅文件</a></p>
</body>
</html>
EOF
            
            # 复制测试文件
            safe_sudo cp /tmp/test.html "$DATA_DIR/test.html"
            safe_sudo cp /tmp/test.html "$DATA_DIR/index.html"
            safe_sudo chown "$NGINX_USER:$NGINX_USER" "$DATA_DIR/test.html" "$DATA_DIR/index.html"
            safe_sudo chmod 644 "$DATA_DIR/test.html" "$DATA_DIR/index.html"
            rm /tmp/test.html
            
            # 检查 SELinux (如果适用)
            if command -v getenforce >/dev/null 2>&1; then
                SELINUX_STATUS=$(getenforce 2>/dev/null || echo "未知")
                if [ "$SELINUX_STATUS" = "Enforcing" ]; then
                    safe_sudo setsebool -P httpd_read_user_content 1 2>/dev/null || true
                    safe_sudo restorecon -R "$DATA_DIR" 2>/dev/null || true
                fi
            fi
        fi
        
        # 删除现有符号链接（如果存在）
        if [ -L "/etc/nginx/sites-enabled/${SERVICE_NAME}" ]; then
            safe_sudo rm -f "/etc/nginx/sites-enabled/${SERVICE_NAME}"
        fi
        safe_sudo cp config/nginx.conf /etc/nginx/sites-available/${SERVICE_NAME}
        safe_sudo ln -sf /etc/nginx/sites-available/${SERVICE_NAME} /etc/nginx/sites-enabled/
        
        # 检查nginx配置是否正确
        if safe_sudo nginx -t; then
            # 检查nginx是否已经运行
            if safe_sudo systemctl is-active --quiet nginx; then
                safe_sudo systemctl reload nginx || safe_sudo systemctl restart nginx
            else
                safe_sudo systemctl start nginx
                safe_sudo systemctl enable nginx
            fi
            
            # 测试静态文件访问
            sleep 2
            if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${NGINX_PORT}/" | grep -q "200"; then
                echo "   ✅ Nginx 配置完成"
            else
                echo "   ⚠️  Nginx 启动成功，但静态文件服务可能需要检查"
            fi
        else
            echo "❌ Nginx 配置测试失败，请检查配置文件"
        fi
    elif [ "$OS" = "Mac" ]; then
        echo "ℹ️  配置文件已生成: config/nginx.conf"
        echo "   可使用: brew services start nginx"
    fi
else
    echo "⚠️  未检测到 Nginx，如需使用请先安装"
fi

echo "✅ 安装完成！"
echo ""
echo "� 快速开始："
if [ "$OS" = "Linux" ]; then
    NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"
    echo "1. 生成订阅文件: curl http://localhost:${NGINX_PROXY_PORT}/api/update"
    echo "2. 访问控制面板: http://localhost:${NGINX_PROXY_PORT}/dashboard/"
    
    SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"
    echo ""
    echo "📊 服务管理："
    if [[ $EUID -eq 0 ]]; then
        echo "   查看状态: systemctl status $SERVICE_NAME"
        echo "   查看日志: journalctl -u $SERVICE_NAME -f"
    else
        if [ "$HAS_SUDO" = true ]; then
            echo "   查看状态: sudo systemctl status $SERVICE_NAME"
            echo "   查看日志: sudo journalctl -u $SERVICE_NAME -f"
        fi
    fi
elif [ "$OS" = "Mac" ]; then
    API_PORT="${PORT:-3000}"
    echo "1. 启动服务: bun run dev"
    echo "2. 生成订阅: curl http://localhost:${API_PORT}/api/update"
    echo "3. 访问控制面板: http://localhost:${API_PORT}/dashboard/"
fi

echo ""
echo "🔧 故障排除："
echo "如遇到问题，请检查："
if [ "$OS" = "Linux" ]; then
    echo "1. 日志信息:"
    if [[ $EUID -eq 0 ]]; then
        echo "   journalctl -u $SERVICE_NAME -f"
    else
        if [ "$HAS_SUDO" = true ]; then
            echo "   sudo journalctl -u $SERVICE_NAME -f"
        fi
    fi
    echo "2. Dashboard 无法访问:"
    echo "   ls -la $ABSOLUTE_PROJECT_ROOT/frontend/dist/"
    if [[ $EUID -eq 0 ]]; then
        echo "   systemctl restart nginx"
    else
        if [ "$HAS_SUDO" = true ]; then
            echo "   sudo systemctl restart nginx"
        fi
    fi
    echo "3. 运行修复脚本: bash scripts/fix-dashboard.sh"
else
    echo "1. 检查目录权限: ls -la $DATA_DIR"
    echo "2. 检查磁盘空间: df -h $DATA_DIR"
fi