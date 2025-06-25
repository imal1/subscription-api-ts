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

set -e

# 设置工作目录为项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
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
        sudo -u $TARGET_USER npm install
    else
        npm install
    fi
else
    npm install
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
if [ "$OS" = "Linux" ]; then
    if [[ $EUID -eq 0 ]]; then
        # root 用户直接创建目录
        mkdir -p /var/www/subscription
        mkdir -p /var/log/subscription
        # 设置目录权限给目标用户
        chown -R $TARGET_USER:$TARGET_GROUP /var/www/subscription
        chown -R $TARGET_USER:$TARGET_GROUP /var/log/subscription
    else
        # 非 root 用户使用 sudo
        sudo mkdir -p /var/www/subscription
        sudo mkdir -p /var/log/subscription
        sudo chown -R $TARGET_USER:$TARGET_GROUP /var/www/subscription
        sudo chown -R $TARGET_USER:$TARGET_GROUP /var/log/subscription
    fi
elif [ "$OS" = "Mac" ]; then
    mkdir -p data
    mkdir -p data/backup
    mkdir -p logs
    mkdir -p dist
fi

# 复制环境配置文件
if [ ! -f .env ]; then
    echo "⚙️ 创建环境配置文件..."
    cp .env.example .env
    
    # 根据操作系统调整配置文件中的路径
    if [ "$OS" = "Linux" ]; then
        sed -i 's|STATIC_DIR=./data|STATIC_DIR=/var/www/subscription|g' .env
        sed -i 's|LOG_DIR=./logs|LOG_DIR=/var/log/subscription|g' .env
        sed -i 's|BACKUP_DIR=./data/backup|BACKUP_DIR=/var/www/subscription/backup|g' .env
        echo "✅ 已配置 Linux 系统路径"
    elif [ "$OS" = "Mac" ]; then
        echo "✅ 已配置 macOS 项目本地路径"
    fi
    
    echo "请编辑 .env 文件配置您的参数"
fi

# 构建项目
echo "🏗️ 构建项目..."
if [[ $EUID -eq 0 ]] && [ "$OS" = "Linux" ] && [ "$TARGET_USER" != "root" ]; then
    # root 执行但目标用户非 root 时，使用目标用户身份构建
    sudo -u $TARGET_USER npm run build
else
    npm run build
fi

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
    if [[ $EUID -eq 0 ]]; then
        cp /tmp/subscription-api-ts.service /etc/systemd/system/
        systemctl daemon-reload
        systemctl enable subscription-api-ts
    else
        sudo cp /tmp/subscription-api-ts.service /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable subscription-api-ts
    fi
    
    echo "✅ 服务文件已安装到 /etc/systemd/system/subscription-api-ts.service"
    echo "📁 工作目录: $PROJECT_ROOT"
    echo "👤 运行用户: $TARGET_USER"
elif [ "$OS" = "Mac" ]; then
    echo "ℹ️  macOS 用户请手动启动服务或使用 pm2"
fi

# 安装Nginx配置
if command -v nginx &> /dev/null; then
    echo "🌐 配置 Nginx..."
    if [ "$OS" = "Linux" ]; then
        if [[ $EUID -eq 0 ]]; then
            cp config/nginx.conf /etc/nginx/sites-available/subscription-api-ts
            ln -sf /etc/nginx/sites-available/subscription-api-ts /etc/nginx/sites-enabled/
            nginx -t && systemctl reload nginx
        else
            sudo cp config/nginx.conf /etc/nginx/sites-available/subscription-api-ts
            sudo ln -sf /etc/nginx/sites-available/subscription-api-ts /etc/nginx/sites-enabled/
            sudo nginx -t && sudo systemctl reload nginx
        fi
    elif [ "$OS" = "Mac" ]; then
        echo "ℹ️  请手动配置 Nginx，配置文件位于 config/nginx.conf"
    fi
fi

echo "✅ 安装完成！"
echo ""
echo "下一步："
if [ "$OS" = "Linux" ]; then
    echo "1. 编辑 .env 文件配置参数"
    if [[ $EUID -eq 0 ]]; then
        echo "2. 启动服务: systemctl start subscription-api-ts"
        echo "3. 查看状态: systemctl status subscription-api-ts"
    else
        echo "2. 启动服务: sudo systemctl start subscription-api-ts"
        echo "3. 查看状态: sudo systemctl status subscription-api-ts"
    fi
    echo "4. 访问: http://localhost:3000"
elif [ "$OS" = "Mac" ]; then
    echo "1. 编辑 .env 文件配置参数"
    echo "2. 启动开发服务器: npm run dev"
    echo "3. 或使用 PM2: pm2 start dist/index.js --name subscription-api-ts"
    echo "4. 访问: http://localhost:3000"
fi