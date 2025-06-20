#!/bin/bash

# 安装脚本
set -e

echo "🚀 开始安装 Subscription API TypeScript..."

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
   echo "❌ 请不要使用root用户运行此脚本"
   exit 1
fi

# 安装Node.js (如果未安装)
if ! command -v node &> /dev/null; then
    echo "📦 安装 Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# 全局安装TypeScript工具
echo "🔧 安装 TypeScript 工具..."
sudo npm install -g typescript ts-node pm2

# 创建必要目录
echo "📁 创建目录..."
sudo mkdir -p /var/www/subscription
sudo mkdir -p /var/log/subscription
sudo chown -R $USER:$USER /var/www/subscription
sudo chown -R $USER:$USER /var/log/subscription

# 安装项目依赖
echo "📦 安装项目依赖..."
npm install

# 复制环境配置文件
if [ ! -f .env ]; then
    echo "⚙️ 创建环境配置文件..."
    cp .env.example .env
    echo "请编辑 .env 文件配置您的参数"
fi

# 构建项目
echo "🏗️ 构建项目..."
npm run build

# 安装systemd服务
echo "🔧 安装 systemd 服务..."
sudo cp config/subscription-api-ts.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable subscription-api-ts

# 安装Nginx配置
if command -v nginx &> /dev/null; then
    echo "🌐 配置 Nginx..."
    sudo cp config/nginx.conf /etc/nginx/sites-available/subscription-api-ts
    sudo ln -sf /etc/nginx/sites-available/subscription-api-ts /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx
fi

echo "✅ 安装完成！"
echo ""
echo "下一步："
echo "1. 编辑 .env 文件配置参数"
echo "2. 启动服务: sudo systemctl start subscription-api-ts"
echo "3. 查看状态: sudo systemctl status subscription-api-ts"
echo "4. 访问: http://localhost:5000"