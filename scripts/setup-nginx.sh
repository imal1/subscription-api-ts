#!/bin/bash

# Nginx 安装和配置脚本
# 支持自动安装、配置和启动 Nginx

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 读取环境变量
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# 设置默认值
SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"
NGINX_PORT="${NGINX_PORT:-3080}"

# 检测操作系统
OS=""
case "$(uname -s)" in
    Linux*)     OS=Linux;;
    Darwin*)    OS=Mac;;
    *)          OS="UNKNOWN";;
esac

echo "🌐 Nginx 安装和配置脚本"
echo "📍 项目目录: $PROJECT_ROOT"
echo "🖥️  操作系统: $OS"

# 检查是否已安装 Nginx
if ! command -v nginx &> /dev/null; then
    echo "❌ 未检测到 Nginx，正在安装..."
    
    if [ "$OS" = "Linux" ]; then
        # 检测 Linux 发行版
        if [ -f /etc/debian_version ]; then
            # Debian/Ubuntu
            if [[ $EUID -eq 0 ]]; then
                apt-get update
                apt-get install -y nginx
            else
                sudo apt-get update
                sudo apt-get install -y nginx
            fi
        elif [ -f /etc/redhat-release ]; then
            # CentOS/RHEL/Fedora
            if [[ $EUID -eq 0 ]]; then
                yum install -y nginx || dnf install -y nginx
            else
                sudo yum install -y nginx || sudo dnf install -y nginx
            fi
        else
            echo "❌ 不支持的 Linux 发行版，请手动安装 Nginx"
            exit 1
        fi
    elif [ "$OS" = "Mac" ]; then
        if command -v brew &> /dev/null; then
            brew install nginx
        else
            echo "❌ 未找到 Homebrew，请先安装 Homebrew 或手动安装 Nginx"
            echo "   安装 Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            exit 1
        fi
    fi
    
    echo "✅ Nginx 安装完成"
else
    echo "✅ 检测到 Nginx 已安装"
fi

# 检查配置文件是否存在
if [ ! -f "$PROJECT_ROOT/config/nginx.conf" ]; then
    echo "❌ 未找到 nginx.conf 配置文件"
    echo "   请先运行: bash scripts/generate-nginx-config.sh"
    exit 1
fi

echo "🔧 配置 Nginx..."

if [ "$OS" = "Linux" ]; then
    # Linux 配置
    if [[ $EUID -eq 0 ]]; then
        # Root 用户
        echo "📝 复制配置文件..."
        cp "$PROJECT_ROOT/config/nginx.conf" "/etc/nginx/sites-available/${SERVICE_NAME}"
        
        # 创建软链接
        ln -sf "/etc/nginx/sites-available/${SERVICE_NAME}" "/etc/nginx/sites-enabled/"
        
        # 移除默认站点 (如果存在)
        if [ -f "/etc/nginx/sites-enabled/default" ]; then
            echo "🗑️  移除默认站点配置..."
            rm -f "/etc/nginx/sites-enabled/default"
        fi
        
        # 测试配置
        echo "🧪 测试 Nginx 配置..."
        if nginx -t; then
            echo "✅ Nginx 配置测试通过"
            
            # 检查 Nginx 服务状态并启动
            echo "🔍 检查 Nginx 服务状态..."
            if systemctl is-active --quiet nginx; then
                echo "🔄 重新加载 Nginx 配置..."
                systemctl reload nginx
            else
                echo "🚀 启动 Nginx 服务..."
                systemctl start nginx
                systemctl enable nginx
            fi
            
            echo "✅ Nginx 配置和启动完成"
        else
            echo "❌ Nginx 配置测试失败，请检查配置文件"
            exit 1
        fi
    else
        # 非 Root 用户
        echo "📝 复制配置文件..."
        sudo cp "$PROJECT_ROOT/config/nginx.conf" "/etc/nginx/sites-available/${SERVICE_NAME}"
        
        # 创建软链接
        sudo ln -sf "/etc/nginx/sites-available/${SERVICE_NAME}" "/etc/nginx/sites-enabled/"
        
        # 移除默认站点 (如果存在)
        if [ -f "/etc/nginx/sites-enabled/default" ]; then
            echo "🗑️  移除默认站点配置..."
            sudo rm -f "/etc/nginx/sites-enabled/default"
        fi
        
        # 测试配置
        echo "🧪 测试 Nginx 配置..."
        if sudo nginx -t; then
            echo "✅ Nginx 配置测试通过"
            
            # 检查 Nginx 服务状态并启动
            echo "🔍 检查 Nginx 服务状态..."
            if sudo systemctl is-active --quiet nginx; then
                echo "🔄 重新加载 Nginx 配置..."
                sudo systemctl reload nginx
            else
                echo "🚀 启动 Nginx 服务..."
                sudo systemctl start nginx
                sudo systemctl enable nginx
            fi
            
            echo "✅ Nginx 配置和启动完成"
        else
            echo "❌ Nginx 配置测试失败，请检查配置文件"
            exit 1
        fi
    fi
    
elif [ "$OS" = "Mac" ]; then
    # macOS 配置
    echo "ℹ️  macOS 环境下需要手动配置 Nginx"
    echo "   配置文件位于: $PROJECT_ROOT/config/nginx.conf"
    echo "   请参考以下步骤:"
    echo "   1. 复制配置到 Nginx 配置目录"
    echo "   2. 编辑 /usr/local/etc/nginx/nginx.conf 包含您的配置"
    echo "   3. 启动 Nginx: brew services start nginx"
    echo "   4. 或直接运行: nginx"
fi

echo ""
echo "🎉 Nginx 设置完成！"
echo ""
echo "📊 服务信息:"
echo "   - 主要 API: http://localhost:3888"
echo "   - 静态文件: http://localhost:${NGINX_PORT}"
echo "   - 配置文件: /etc/nginx/sites-available/${SERVICE_NAME}"
echo ""
echo "🔧 常用命令:"
if [ "$OS" = "Linux" ]; then
    if [[ $EUID -eq 0 ]]; then
        echo "   - 查看状态: systemctl status nginx"
        echo "   - 重启服务: systemctl restart nginx"
        echo "   - 查看日志: journalctl -u nginx -f"
    else
        echo "   - 查看状态: sudo systemctl status nginx"
        echo "   - 重启服务: sudo systemctl restart nginx"
        echo "   - 查看日志: sudo journalctl -u nginx -f"
    fi
elif [ "$OS" = "Mac" ]; then
    echo "   - 查看状态: brew services list | grep nginx"
    echo "   - 重启服务: brew services restart nginx"
    echo "   - 查看配置: nginx -t"
fi
