#!/bin/bash

# 跨平台服务状态检查脚本
echo "=== 服务状态检查 ==="

# 检测操作系统
OS=""
case "$(uname -s)" in
    Linux*)     OS=Linux;;
    Darwin*)    OS=Mac;;
    *)          OS="UNKNOWN";;
esac

echo "🖥️  操作系统: $OS"
echo "👤 当前用户: $(whoami)"
echo ""

# 项目配置检查
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "📁 项目目录: $PROJECT_DIR"

if [ -f "$PROJECT_DIR/.env" ]; then
    echo "✅ 环境配置文件存在"
    # 读取端口配置
    PORT=$(grep '^PORT=' "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"' || echo "3000")
    echo "🔌 配置端口: $PORT"
else
    echo "❌ 环境配置文件不存在"
    PORT="3000"
fi

if [ -f "$PROJECT_DIR/dist/index.js" ]; then
    echo "✅ 编译文件存在"
else
    echo "❌ 编译文件不存在，请运行: npm run build"
fi
echo ""

if [ "$OS" = "Linux" ]; then
    echo "🐧 Linux 环境 - 检查 SystemD 服务:"
    
    SERVICE_NAME="subscription-api-ts"
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    # 检查systemctl是否可用
    if ! command -v systemctl &> /dev/null; then
        echo "❌ systemctl 不可用，可能不是 systemd 系统"
        echo "   请检查是否使用了 SysV init 或其他初始化系统"
        exit 1
    fi
    
    # 检查服务文件
    if [ -f "$SERVICE_FILE" ]; then
        echo "✅ 服务文件存在: $SERVICE_FILE"
        
        echo ""
        echo "📊 服务状态:"
        echo "----------------------------------------"
        if sudo systemctl status ${SERVICE_NAME} --no-pager 2>&1; then
            echo "✅ 服务状态获取成功"
        else
            echo "❌ 服务状态获取失败"
            echo ""
            echo "🔍 详细错误信息:"
            sudo journalctl -u ${SERVICE_NAME} --no-pager --lines=20 2>&1
        fi
        echo "----------------------------------------"
        
        echo ""
        echo "🔧 服务控制命令:"
        echo "启动服务: sudo systemctl start ${SERVICE_NAME}"
        echo "停止服务: sudo systemctl stop ${SERVICE_NAME}"
        echo "重启服务: sudo systemctl restart ${SERVICE_NAME}"
        echo "查看日志: sudo journalctl -u ${SERVICE_NAME} -f"
        
    else
        echo "❌ 服务文件不存在: $SERVICE_FILE"
        echo ""
        echo "🔧 生成服务文件:"
        echo "cd $PROJECT_DIR"
        echo "npm run systemd:service \$(pwd)"
        echo "sudo cp /tmp/subscription-api-ts.service /etc/systemd/system/"
        echo "sudo systemctl daemon-reload"
        echo "sudo systemctl enable subscription-api-ts"
    fi
    
elif [ "$OS" = "Mac" ]; then
    echo "🍎 macOS 环境 - 检查进程状态:"
    
    # 检查进程是否运行
    if pgrep -f "node.*dist/index.js" > /dev/null; then
        echo "✅ 服务进程正在运行"
        echo "进程信息:"
        ps aux | grep -E "node.*dist/index.js" | grep -v grep
    else
        echo "❌ 服务进程未运行"
    fi
    
    # 检查端口占用
    if lsof -i :$PORT > /dev/null 2>&1; then
        echo "✅ 端口 $PORT 被占用"
        echo "端口占用情况:"
        lsof -i :$PORT
    else
        echo "❌ 端口 $PORT 未被占用"
    fi
    
    echo ""
    echo "🔧 macOS 服务控制命令:"
    echo "启动开发服务: npm run dev"
    echo "启动生产服务: npm start"
    echo "使用 PM2 管理: pm2 start dist/index.js --name subscription-api-ts"
    echo "查看 PM2 状态: pm2 status"
    echo "查看 PM2 日志: pm2 logs subscription-api-ts"
    
else
    echo "❌ 不支持的操作系统: $OS"
fi

echo ""
echo "🌐 测试服务连接:"
if curl -s http://localhost:$PORT/health > /dev/null; then
    echo "✅ 服务响应正常"
    curl -s http://localhost:$PORT/health | jq . 2>/dev/null || curl -s http://localhost:$PORT/health
else
    echo "❌ 服务无响应或未启动"
    echo "   请检查服务是否正在运行，端口是否正确"
fi
