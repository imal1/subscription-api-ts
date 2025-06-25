#!/bin/bash

# 安装脚本
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

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
   echo "❌ 请不要使用root用户运行此脚本"
   exit 1
fi

# 安装Node.js (如果未安装)
if ! command -v node &> /dev/null; then
    echo "📦 安装 Node.js..."
    if [ "$OS" = "Linux" ]; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
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
npm install

# 检查并安装TypeScript工具
echo "🔧 检查 TypeScript 工具..."
if [ -f "node_modules/.bin/tsc" ] && [ -f "node_modules/.bin/ts-node" ]; then
    echo "✅ 使用项目本地的 TypeScript 工具"
else
    echo "� 安装全局 TypeScript 工具..."
    if [ "$OS" = "Linux" ]; then
        sudo npm install -g typescript ts-node pm2
    elif [ "$OS" = "Mac" ]; then
        npm install -g typescript ts-node pm2
    fi
fi

# 创建必要目录
echo "📁 创建目录..."
if [ "$OS" = "Linux" ]; then
    sudo mkdir -p /var/www/subscription
    sudo mkdir -p /var/log/subscription
    sudo chown -R $USER:$USER /var/www/subscription
    sudo chown -R $USER:$USER /var/log/subscription
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
npm run build

# 安装系统服务
if [ "$OS" = "Linux" ]; then
    echo "🔧 安装 systemd 服务..."
    sudo cp config/subscription-api-ts.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable subscription-api-ts
elif [ "$OS" = "Mac" ]; then
    echo "ℹ️  macOS 用户请手动启动服务或使用 pm2"
fi

# 安装Nginx配置
if command -v nginx &> /dev/null; then
    echo "🌐 配置 Nginx..."
    if [ "$OS" = "Linux" ]; then
        sudo cp config/nginx.conf /etc/nginx/sites-available/subscription-api-ts
        sudo ln -sf /etc/nginx/sites-available/subscription-api-ts /etc/nginx/sites-enabled/
        sudo nginx -t && sudo systemctl reload nginx
    elif [ "$OS" = "Mac" ]; then
        echo "ℹ️  请手动配置 Nginx，配置文件位于 config/nginx.conf"
    fi
fi

echo "✅ 安装完成！"
echo ""
echo "下一步："
if [ "$OS" = "Linux" ]; then
    echo "1. 编辑 .env 文件配置参数"
    echo "2. 启动服务: sudo systemctl start subscription-api-ts"
    echo "3. 查看状态: sudo systemctl status subscription-api-ts"
    echo "4. 访问: http://localhost:3000"
elif [ "$OS" = "Mac" ]; then
    echo "1. 编辑 .env 文件配置参数"
    echo "2. 启动开发服务器: npm run dev"
    echo "3. 或使用 PM2: pm2 start dist/index.js --name subscription-api-ts"
    echo "4. 访问: http://localhost:3000"
fi