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

# 设置默认值
if [ "$OS" = "Linux" ]; then
    export DATA_DIR="${DATA_DIR:-/var/www/subscription}"
    export LOG_DIR="${LOG_DIR:-/var/log/subscription}"
else
    export DATA_DIR="${DATA_DIR:-./data}"
    export LOG_DIR="${LOG_DIR:-./logs}"
fi
export NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"

# 检查sudo命令是否可用
HAS_SUDO=false
if command -v sudo >/dev/null 2>&1; then
    HAS_SUDO=true
fi

# 定义安全的sudo函数
safe_sudo() {
    if [[ $EUID -eq 0 ]]; then
        # 如果是root用户，直接执行命令
        "$@"
    elif [ "$HAS_SUDO" = true ]; then
        # 如果有sudo且不是root，使用sudo
        sudo "$@"
    else
        echo "❌ 错误：需要root权限或sudo命令来执行: $*"
        echo "   请以root用户运行此脚本，或安装sudo命令"
        exit 1
    fi
}

# 定义用户切换函数
safe_sudo_user() {
    local target_user="$1"
    shift
    
    if [[ $EUID -eq 0 ]]; then
        if [ "$target_user" = "root" ]; then
            # root用户直接执行
            "$@"
        else
            # root用户切换到目标用户
            if command -v su >/dev/null 2>&1; then
                su -c "$(printf '%q ' "$@")" "$target_user"
            else
                echo "❌ 错误：无法切换用户，缺少su命令"
                exit 1
            fi
        fi
    elif [ "$HAS_SUDO" = true ]; then
        # 非root用户使用sudo切换
        sudo -u "$target_user" "$@"
    else
        echo "❌ 错误：需要sudo命令来切换用户执行: $*"
        echo "   请安装sudo命令或以root用户运行此脚本"
        exit 1
    fi
}

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

# 安装项目依赖
echo "📦 安装项目依赖..."

# 定义安装函数
install_dependencies() {
    local user_prefix="$1"
    local install_success=false
    
    # 首先尝试 npm ci
    echo "   尝试使用 npm ci 安装依赖..."
    if $user_prefix npm ci --include=dev 2>/dev/null; then
        echo "   ✅ npm ci 安装成功"
        install_success=true
    else
        echo "   ⚠️  npm ci 失败，可能是 package-lock.json 与 package.json 不同步"
        echo "   📦 回退到 npm install..."
        
        # 如果 npm ci 失败，使用 npm install
        if $user_prefix npm install --include=dev; then
            echo "   ✅ npm install 安装成功"
            install_success=true
        else
            echo "   ❌ npm install 也失败了"
            return 1
        fi
    fi
    
    # 验证关键依赖是否安装成功
    if [ "$install_success" = true ]; then
        if ! $user_prefix test -f "node_modules/@types/node/index.d.ts"; then
            echo "   ⚠️  重新安装 @types/node..."
            $user_prefix npm install --save-dev @types/node
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
    if [ "$OS" = "Linux" ]; then
        if [[ $EUID -eq 0 ]]; then
            npm install -g typescript ts-node pm2
        else
            safe_sudo npm install -g typescript ts-node pm2
        fi
    elif [ "$OS" = "Mac" ]; then
        npm install -g typescript ts-node pm2
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
        sed -i "s|DATA_DIR=.*|DATA_DIR=${DATA_DIR}|g" .env
        sed -i "s|LOG_DIR=.*|LOG_DIR=${LOG_DIR}|g" .env
        echo "✅ 已配置 Linux 系统路径"
        echo "   数据目录: ${DATA_DIR}"
        echo "   日志目录: ${LOG_DIR}"
    elif [ "$OS" = "Mac" ]; then
        sed -i '' "s|DATA_DIR=.*|DATA_DIR=${DATA_DIR}|g" .env
        sed -i '' "s|LOG_DIR=.*|LOG_DIR=${LOG_DIR}|g" .env
        echo "✅ 已配置 macOS 项目本地路径"
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

# 构建项目
echo "🏗️ 构建项目..."

# 清理之前的构建文件
echo "   清理旧的构建文件..."
rm -rf dist

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

# 执行构建
echo "   执行 TypeScript 编译..."
if [[ $EUID -eq 0 ]] && [ "$OS" = "Linux" ] && [ "$TARGET_USER" != "root" ]; then
    # root 执行但目标用户非 root 时，使用目标用户身份构建
    if ! safe_sudo_user $TARGET_USER npm run build 2>&1; then
        echo "❌ 构建失败，请检查 TypeScript 错误"
        echo "   尝试运行: npm run build 查看详细错误信息"
        echo "   或者检查 tsconfig.json 配置"
        exit 1
    fi
else
    if ! npm run build 2>&1; then
        echo "❌ 构建失败，请检查 TypeScript 错误"
        echo "   尝试运行: npm run build 查看详细错误信息"
        echo "   或者检查 tsconfig.json 配置"
        exit 1
    fi
fi

# 验证构建结果
if [ ! -f "dist/index.js" ]; then
    echo "❌ 构建失败：未找到 dist/index.js"
    exit 1
fi

echo "✅ 构建成功！"

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
    export SERVICE_USER="$TARGET_USER" SERVICE_GROUP="$TARGET_GROUP" INSTALL_DIR="$ABSOLUTE_PROJECT_ROOT" NODE_PATH
    
    # 生成服务文件
    envsubst '${SERVICE_USER} ${SERVICE_GROUP} ${INSTALL_DIR} ${NODE_PATH}' < "$SERVICE_TEMPLATE" > "$SERVICE_OUTPUT"
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
    export API_PORT NGINX_PORT NGINX_PROXY_PORT DATA_DIR
    if command -v envsubst >/dev/null 2>&1; then
        # 只替换指定的环境变量，避免nginx变量被误替换
        envsubst '${API_PORT} ${NGINX_PORT} ${NGINX_PROXY_PORT} ${DATA_DIR}' < config/nginx.conf.template > config/nginx.conf
        echo "✅ 使用 envsubst 生成配置文件"
    else
        # 如果没有envsubst，使用sed替换
        sed "s/\${API_PORT}/${API_PORT}/g; s/\${NGINX_PORT}/${NGINX_PORT}/g; s/\${NGINX_PROXY_PORT}/${NGINX_PROXY_PORT}/g; s|\${DATA_DIR}|${DATA_DIR}|g" config/nginx.conf.template > config/nginx.conf
        echo "✅ 使用 sed 生成配置文件"
    fi
    
    if [ "$OS" = "Linux" ]; then
        # 修复 Nginx 静态文件服务权限问题
        echo "🔧 修复 Nginx 静态文件权限..."
        
        # 检查数据目录权限
        if [ -d "$DATA_DIR" ]; then
            echo "   检查数据目录: $DATA_DIR"
            DIR_PERMS=$(ls -ld "$DATA_DIR" | cut -d' ' -f1)
            DIR_OWNER=$(ls -ld "$DATA_DIR" | awk '{print $3":"$4}')
            echo "   当前权限: $DIR_PERMS (所有者: $DIR_OWNER)"
            
            # 检查 Nginx 用户
            NGINX_USER="www-data"
            if ! id "$NGINX_USER" >/dev/null 2>&1; then
                # 尝试其他常见的 Nginx 用户名
                for user in nginx http; do
                    if id "$user" >/dev/null 2>&1; then
                        NGINX_USER="$user"
                        break
                    fi
                done
            fi
            echo "   Nginx 用户: $NGINX_USER"
            
            # 修复权限
            echo "   修复目录权限..."
            safe_sudo chown -R "$NGINX_USER:$NGINX_USER" "$DATA_DIR"
            safe_sudo chmod -R 755 "$DATA_DIR"
            safe_sudo find "$DATA_DIR" -type f -exec chmod 644 {} \; 2>/dev/null || true
            
            # 创建测试文件
            echo "   创建测试文件..."
            TEST_FILE="$DATA_DIR/test.html"
            INDEX_FILE="$DATA_DIR/index.html"
            
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
            safe_sudo cp /tmp/test.html "$TEST_FILE"
            safe_sudo cp /tmp/test.html "$INDEX_FILE"
            safe_sudo chown "$NGINX_USER:$NGINX_USER" "$TEST_FILE" "$INDEX_FILE"
            safe_sudo chmod 644 "$TEST_FILE" "$INDEX_FILE"
            rm /tmp/test.html
            
            echo "   ✅ 测试文件已创建"
            
            # 检查 SELinux (如果适用)
            if command -v getenforce >/dev/null 2>&1; then
                SELINUX_STATUS=$(getenforce 2>/dev/null || echo "未知")
                echo "   SELinux 状态: $SELINUX_STATUS"
                
                if [ "$SELINUX_STATUS" = "Enforcing" ]; then
                    echo "   修复 SELinux 权限..."
                    safe_sudo setsebool -P httpd_read_user_content 1 2>/dev/null || true
                    safe_sudo restorecon -R "$DATA_DIR" 2>/dev/null || true
                    echo "   ✅ SELinux 策略已更新"
                fi
            fi
            
            echo "   ✅ Nginx 静态文件权限修复完成"
        else
            echo "   ❌ 数据目录不存在: $DATA_DIR"
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
                echo "🔄 重新加载 Nginx 配置..."
                if safe_sudo systemctl reload nginx; then
                    echo "✅ Nginx 配置重新加载成功"
                else
                    echo "⚠️  Nginx 重新加载失败，尝试重启..."
                    safe_sudo systemctl restart nginx
                fi
            else
                echo "🚀 启动 Nginx 服务..."
                safe_sudo systemctl start nginx
                safe_sudo systemctl enable nginx
            fi
            
            # 测试静态文件访问
            echo "🧪 测试静态文件访问..."
            sleep 2  # 等待服务启动
            
            if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${NGINX_PORT}/" | grep -q "200"; then
                echo "   ✅ 静态文件服务测试成功 (HTTP 200)"
            else
                HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${NGINX_PORT}/" 2>/dev/null || echo "连接失败")
                echo "   ⚠️  静态文件服务测试失败 (HTTP: $HTTP_CODE)"
                echo "   💡 请检查防火墙或端口配置"
            fi
            
            echo "✅ Nginx 配置完成"
        else
            echo "❌ Nginx 配置测试失败，请检查配置文件"
        fi
    elif [ "$OS" = "Mac" ]; then
        echo "ℹ️  请手动配置 Nginx，配置文件位于 config/nginx.conf"
        echo "   macOS 用户可以使用以下命令:"
        echo "   brew services start nginx"
        echo "   或直接运行: nginx"
        echo "   Nginx 将监听端口: ${NGINX_PROXY_PORT:-3888} (API代理) 和 ${NGINX_PORT:-3080} (静态文件)"
    fi
else
    echo "⚠️  未检测到 Nginx，跳过 Nginx 配置"
    echo "   如需使用 Nginx，请先安装:"
    if [ "$OS" = "Linux" ]; then
        echo "   sudo apt-get install nginx  # Ubuntu/Debian"
        echo "   sudo yum install nginx      # CentOS/RHEL"
    elif [ "$OS" = "Mac" ]; then
        echo "   brew install nginx"
    fi
fi

echo "✅ 安装完成！"
echo ""
echo "📋 重要提示："
echo "   首次使用前需要生成订阅文件（包括 clash.yaml）"
echo "   请在启动服务后执行以下命令："
echo ""
if [ "$OS" = "Linux" ]; then
    API_PORT="${PORT:-3000}"
    NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"
    echo "   curl http://localhost:${NGINX_PROXY_PORT}/api/update"
    echo "   # 或者直接访问 API："
    echo "   curl http://localhost:${API_PORT}/api/update"
elif [ "$OS" = "Mac" ]; then
    API_PORT="${PORT:-3000}"  
    echo "   curl http://localhost:${API_PORT}/api/update"
fi
echo ""
echo "下一步："
if [ "$OS" = "Linux" ]; then
    echo "1. 编辑 .env 文件配置参数 (如需要)"
    SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"
    echo "2. 服务已自动启动，管理命令:"
    if [[ $EUID -eq 0 ]]; then
        echo "   - 查看状态: systemctl status $SERVICE_NAME"
        echo "   - 重启服务: systemctl restart $SERVICE_NAME"
        echo "   - 停止服务: systemctl stop $SERVICE_NAME"
        echo "   - 查看日志: journalctl -u $SERVICE_NAME -f"
    else
        if [ "$HAS_SUDO" = true ]; then
            echo "   - 查看状态: sudo systemctl status $SERVICE_NAME"
            echo "   - 重启服务: sudo systemctl restart $SERVICE_NAME"
            echo "   - 停止服务: sudo systemctl stop $SERVICE_NAME"  
            echo "   - 查看日志: sudo journalctl -u $SERVICE_NAME -f"
        else
            echo "   - 查看状态: systemctl status $SERVICE_NAME (需要root权限)"
            echo "   - 重启服务: systemctl restart $SERVICE_NAME (需要root权限)"
            echo "   - 停止服务: systemctl stop $SERVICE_NAME (需要root权限)"
            echo "   - 查看日志: journalctl -u $SERVICE_NAME -f (需要root权限)"
        fi
    fi
    # 从环境变量读取端口号
    API_PORT="${PORT:-3000}"
    NGINX_PORT="${NGINX_PORT:-3080}"
    NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"
    echo "3. 访问服务:"
    echo "   - API 服务: http://localhost:${NGINX_PROXY_PORT} (通过 Nginx)"
    echo "   - 直接访问: http://localhost:${API_PORT}"
    echo "   - 静态文件: http://localhost:${NGINX_PORT}"
elif [ "$OS" = "Mac" ]; then
    echo "1. 编辑 .env 文件配置参数"
    echo "2. 启动开发服务器: npm run dev"
    SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"
    echo "3. 或使用 PM2: pm2 start dist/index.js --name $SERVICE_NAME"
    # 从环境变量读取端口号
    API_PORT="${PORT:-3000}"
    NGINX_PORT="${NGINX_PORT:-3080}"
    NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"
    echo "4. 访问服务:"
    echo "   - API 服务: http://localhost:${API_PORT}"
    echo "   - 通过 Nginx: http://localhost:${NGINX_PROXY_PORT} (如果配置了 Nginx)"
    echo "   - 静态文件: http://localhost:${NGINX_PORT} (如果配置了 Nginx)"
fi

echo ""
echo "🔧 故障排除："
echo "如果遇到权限错误 (EROFS: read-only file system)，请检查："
if [ "$OS" = "Linux" ]; then
    echo "1. 数据目录权限:"
    echo "   ls -la $DATA_DIR"
    echo "2. 文件系统挂载状态:"
    echo "   mount | grep $(dirname $DATA_DIR)"
    echo "3. 磁盘空间:"
    echo "   df -h $DATA_DIR"
    echo "4. 手动修复权限:"
    if [[ $EUID -eq 0 ]]; then
        echo "   chown -R $TARGET_USER:$TARGET_GROUP $DATA_DIR"
        echo "   chmod -R 750 $DATA_DIR"
    else
        if [ "$HAS_SUDO" = true ]; then
            echo "   sudo chown -R $TARGET_USER:$TARGET_GROUP $DATA_DIR"
            echo "   sudo chmod -R 750 $DATA_DIR"
        else
            echo "   需要root权限执行权限修复命令"
        fi
    fi
    echo "5. SELinux状态 (如果启用):"
    echo "   sestatus"
    echo "   ls -Z $DATA_DIR"
else
    echo "1. 检查目录权限: ls -la $DATA_DIR"
    echo "2. 检查磁盘空间: df -h $DATA_DIR"
fi