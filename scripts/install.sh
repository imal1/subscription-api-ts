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
export DATA_DIR="${DATA_DIR:-./data}"
export LOG_DIR="${LOG_DIR:-./logs}"
export NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"

set -e

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
            # 非 root 用户使用 sudo
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt-get install -y nodejs
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
if [[ $EUID -eq 0 ]] && [ "$OS" = "Linux" ]; then
    # root 用户执行时，确保 package.json 等文件权限正确
    chown -R $TARGET_USER:$TARGET_GROUP "$PROJECT_ROOT"
    # 使用目标用户身份安装依赖
    if [ "$TARGET_USER" != "root" ]; then
        echo "   使用用户 $TARGET_USER 安装依赖..."
        sudo -u $TARGET_USER npm ci --include=dev
        # 验证关键依赖是否安装成功
        if ! sudo -u $TARGET_USER test -f "node_modules/@types/node/index.d.ts"; then
            echo "⚠️  重新安装 @types/node..."
            sudo -u $TARGET_USER npm install --save-dev @types/node
        fi
    else
        npm ci --include=dev
        # 验证关键依赖是否安装成功
        if ! test -f "node_modules/@types/node/index.d.ts"; then
            echo "⚠️  重新安装 @types/node..."
            npm install --save-dev @types/node
        fi
    fi
else
    npm ci --include=dev
    # 验证关键依赖是否安装成功
    if ! test -f "node_modules/@types/node/index.d.ts"; then
        echo "⚠️  重新安装 @types/node..."
        npm install --save-dev @types/node
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
        sudo -u $TARGET_USER npm install
    else
        npm install
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
            sudo npm install -g typescript ts-node pm2
        fi
    elif [ "$OS" = "Mac" ]; then
        npm install -g typescript ts-node pm2
    fi
fi

# 创建必要目录
echo "📁 创建目录..."
echo "   数据目录: $DATA_DIR"
echo "   日志目录: $LOG_DIR"

if [ "$OS" = "Linux" ]; then
    if [[ $EUID -eq 0 ]]; then
        # root 用户直接创建目录
        mkdir -p "$DATA_DIR"
        mkdir -p "$LOG_DIR"
        # 设置目录权限给目标用户
        chown -R $TARGET_USER:$TARGET_GROUP "$DATA_DIR"
        chown -R $TARGET_USER:$TARGET_GROUP "$LOG_DIR"
    else
        # 非 root 用户使用 sudo
        if [[ "$DATA_DIR" == /* ]] || [[ "$LOG_DIR" == /* ]]; then
            # 绝对路径需要 sudo
            sudo mkdir -p "$DATA_DIR"
            sudo mkdir -p "$LOG_DIR"
            sudo chown -R $TARGET_USER:$TARGET_GROUP "$DATA_DIR"
            sudo chown -R $TARGET_USER:$TARGET_GROUP "$LOG_DIR"
        else
            # 相对路径直接创建
            mkdir -p "$DATA_DIR"
            mkdir -p "$LOG_DIR"
            chown -R $TARGET_USER:$TARGET_GROUP "$DATA_DIR" 2>/dev/null || true
            chown -R $TARGET_USER:$TARGET_GROUP "$LOG_DIR" 2>/dev/null || true
        fi
    fi
elif [ "$OS" = "Mac" ]; then
    mkdir -p "$DATA_DIR"
    mkdir -p "$DATA_DIR/backup"
    mkdir -p "$LOG_DIR"
    mkdir -p dist
fi

# 复制环境配置文件
if [ ! -f .env ]; then
    echo "⚙️ 创建环境配置文件..."
    cp .env.example .env
    
    # 根据操作系统调整配置文件中的路径
    if [ "$OS" = "Linux" ]; then
        # 使用配置的目录路径
        DEFAULT_DATA_DIR="/var/www/subscription"
        DEFAULT_LOG_DIR="/var/log/subscription"
        
        sed -i "s|DATA_DIR=.*|DATA_DIR=${DATA_DIR:-$DEFAULT_DATA_DIR}|g" .env
        sed -i "s|LOG_DIR=.*|LOG_DIR=${LOG_DIR:-$DEFAULT_LOG_DIR}|g" .env
        echo "✅ 已配置 Linux 系统路径"
        echo "   数据目录: ${DATA_DIR:-$DEFAULT_DATA_DIR}"
        echo "   日志目录: ${LOG_DIR:-$DEFAULT_LOG_DIR}"
    elif [ "$OS" = "Mac" ]; then
        echo "✅ 已配置 macOS 项目本地路径"
        echo "   数据目录: ${DATA_DIR}"
        echo "   日志目录: ${LOG_DIR}"
    fi
    
    echo "请编辑 .env 文件配置您的参数"
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
    if ! sudo -u $TARGET_USER npm run build 2>&1; then
        echo "❌ 构建失败，尝试诊断问题..."
        echo "🔍 运行 TypeScript 诊断..."
        sudo -u $TARGET_USER bash scripts/diagnose-typescript.sh
        echo "� 尝试自动修复..."
        sudo -u $TARGET_USER bash scripts/fix-typescript.sh
    fi
else
    if ! npm run build 2>&1; then
        echo "❌ 构建失败，尝试诊断问题..."
        echo "🔍 运行 TypeScript 诊断..."
        bash scripts/diagnose-typescript.sh
        echo "� 尝试自动修复..."
        bash scripts/fix-typescript.sh
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
    
    # 设置环境变量供服务生成脚本使用
    export SERVICE_USER="$TARGET_USER" SERVICE_GROUP="$TARGET_GROUP"
    
    # 使用生成脚本创建服务文件
    if [[ $EUID -eq 0 ]] && [ "$TARGET_USER" != "root" ]; then
        sudo -u $TARGET_USER bash scripts/generate-systemd-service.sh "$PROJECT_ROOT"
    else
        bash scripts/generate-systemd-service.sh "$PROJECT_ROOT"
    fi
    
    # 安装服务文件
    SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"
    if [[ $EUID -eq 0 ]]; then
        # 备份现有服务文件（如果存在）
        if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
            echo "📁 备份现有 systemd 服务文件..."
            cp "/etc/systemd/system/${SERVICE_NAME}.service" "/etc/systemd/system/${SERVICE_NAME}.service.backup.$(date +%Y%m%d_%H%M%S)"
        fi
        cp "/tmp/${SERVICE_NAME}.service" /etc/systemd/system/
        systemctl daemon-reload
        systemctl enable "$SERVICE_NAME"
    else
        # 备份现有服务文件（如果存在）
        if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
            echo "📁 备份现有 systemd 服务文件..."
            sudo cp "/etc/systemd/system/${SERVICE_NAME}.service" "/etc/systemd/system/${SERVICE_NAME}.service.backup.$(date +%Y%m%d_%H%M%S)"
        fi
        sudo cp "/tmp/${SERVICE_NAME}.service" /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable "$SERVICE_NAME"
    fi
    
    echo "✅ 服务文件已安装到 /etc/systemd/system/${SERVICE_NAME}.service"
    echo "📁 工作目录: $PROJECT_ROOT"
    echo "👤 运行用户: $TARGET_USER"
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
                sudo apt-get update && sudo apt-get install -y gettext-base
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
        if [[ $EUID -eq 0 ]]; then
            # 备份现有配置文件（如果存在）
            if [ -f "/etc/nginx/sites-available/${SERVICE_NAME}" ]; then
                echo "📁 备份现有 Nginx 配置文件..."
                cp "/etc/nginx/sites-available/${SERVICE_NAME}" "/etc/nginx/sites-available/${SERVICE_NAME}.backup.$(date +%Y%m%d_%H%M%S)"
            fi
            # 删除现有符号链接（如果存在）
            if [ -L "/etc/nginx/sites-enabled/${SERVICE_NAME}" ]; then
                rm -f "/etc/nginx/sites-enabled/${SERVICE_NAME}"
            fi
            cp config/nginx.conf /etc/nginx/sites-available/${SERVICE_NAME}
            ln -sf /etc/nginx/sites-available/${SERVICE_NAME} /etc/nginx/sites-enabled/
            # 检查nginx配置是否正确
            if nginx -t; then
                # 检查nginx是否已经运行
                if systemctl is-active --quiet nginx; then
                    echo "🔄 重新加载 Nginx 配置..."
                    if systemctl reload nginx; then
                        echo "✅ Nginx 配置重新加载成功"
                    else
                        echo "⚠️  Nginx 重新加载失败，尝试重启..."
                        systemctl restart nginx
                    fi
                else
                    echo "🚀 启动 Nginx 服务..."
                    systemctl start nginx
                    systemctl enable nginx
                fi
                echo "✅ Nginx 配置完成"
            else
                echo "❌ Nginx 配置测试失败，请检查配置文件"
            fi
        else
            # 备份现有配置文件（如果存在）
            if [ -f "/etc/nginx/sites-available/${SERVICE_NAME}" ]; then
                echo "📁 备份现有 Nginx 配置文件..."
                sudo cp "/etc/nginx/sites-available/${SERVICE_NAME}" "/etc/nginx/sites-available/${SERVICE_NAME}.backup.$(date +%Y%m%d_%H%M%S)"
            fi
            # 删除现有符号链接（如果存在）
            if [ -L "/etc/nginx/sites-enabled/${SERVICE_NAME}" ]; then
                sudo rm -f "/etc/nginx/sites-enabled/${SERVICE_NAME}"
            fi
            sudo cp config/nginx.conf /etc/nginx/sites-available/${SERVICE_NAME}
            sudo ln -sf /etc/nginx/sites-available/${SERVICE_NAME} /etc/nginx/sites-enabled/
            # 检查nginx配置是否正确
            if sudo nginx -t; then
                # 检查nginx是否已经运行
                if sudo systemctl is-active --quiet nginx; then
                    echo "🔄 重新加载 Nginx 配置..."
                    if sudo systemctl reload nginx; then
                        echo "✅ Nginx 配置重新加载成功"
                    else
                        echo "⚠️  Nginx 重新加载失败，尝试重启..."
                        sudo systemctl restart nginx
                    fi
                else
                    echo "🚀 启动 Nginx 服务..."
                    sudo systemctl start nginx
                    sudo systemctl enable nginx
                fi
                echo "✅ Nginx 配置完成"
            else
                echo "❌ Nginx 配置测试失败，请检查配置文件"
            fi
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
echo "下一步："
if [ "$OS" = "Linux" ]; then
    echo "1. 编辑 .env 文件配置参数"
    SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"
    if [[ $EUID -eq 0 ]]; then
        echo "2. 启动服务: systemctl start $SERVICE_NAME"
        echo "3. 查看状态: systemctl status $SERVICE_NAME"
    else
        echo "2. 启动服务: sudo systemctl start $SERVICE_NAME"
        echo "3. 查看状态: sudo systemctl status $SERVICE_NAME"
    fi
    # 从环境变量读取端口号
    API_PORT="${PORT:-3000}"
    NGINX_PORT="${NGINX_PORT:-3080}"
    NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"
    echo "4. 访问服务:"
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