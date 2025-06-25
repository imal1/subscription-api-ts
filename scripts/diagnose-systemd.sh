#!/bin/bash

# SystemD 服务诊断脚本
echo "=== SystemD 服务诊断 ==="

SERVICE_NAME="subscription-api-ts"

echo "📋 系统信息:"
echo "操作系统: $(uname -a)"
echo "当前用户: $(whoami)"
echo "用户ID: $EUID"
echo ""

echo "🔍 检查 systemctl 可用性:"
if command -v systemctl &> /dev/null; then
    echo "✅ systemctl 已安装"
    echo "SystemD 版本: $(systemctl --version | head -1)"
else
    echo "❌ systemctl 未找到"
    exit 1
fi
echo ""

echo "🔍 检查服务文件:"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
if [ -f "$SERVICE_FILE" ]; then
    echo "✅ 服务文件存在: $SERVICE_FILE"
    echo "文件权限: $(ls -l $SERVICE_FILE)"
    echo ""
    echo "📄 服务文件内容:"
    echo "----------------------------------------"
    cat "$SERVICE_FILE"
    echo "----------------------------------------"
else
    echo "❌ 服务文件不存在: $SERVICE_FILE"
    echo ""
    echo "🔍 查找可能的服务文件:"
    find /etc/systemd/system/ -name "*subscription*" -type f 2>/dev/null || echo "未找到相关服务文件"
fi
echo ""

echo "🔍 检查服务状态:"
echo "运行以下命令的输出:"
echo ""

echo "1️⃣ systemctl status ${SERVICE_NAME}:"
echo "----------------------------------------"
systemctl status ${SERVICE_NAME} 2>&1 || echo "命令执行失败"
echo "----------------------------------------"
echo ""

echo "2️⃣ systemctl is-active ${SERVICE_NAME}:"
systemctl is-active ${SERVICE_NAME} 2>&1 || echo "服务未激活"
echo ""

echo "3️⃣ systemctl is-enabled ${SERVICE_NAME}:"
systemctl is-enabled ${SERVICE_NAME} 2>&1 || echo "服务未启用"
echo ""

echo "4️⃣ systemctl list-units --type=service | grep subscription:"
systemctl list-units --type=service | grep subscription || echo "未找到相关服务"
echo ""

echo "🔍 检查日志:"
echo "5️⃣ journalctl -u ${SERVICE_NAME} --no-pager --lines=10:"
echo "----------------------------------------"
journalctl -u ${SERVICE_NAME} --no-pager --lines=10 2>&1 || echo "无法获取日志"
echo "----------------------------------------"
echo ""

echo "🔍 检查 systemd daemon 状态:"
echo "6️⃣ systemctl status systemd-logind:"
systemctl status systemd-logind --no-pager --lines=3 2>&1 || echo "systemd-logind 状态检查失败"
echo ""

echo "🔍 检查项目文件:"
PROJECT_DIR="/Users/imali/Projects/subscription-api-ts"
if [ -d "$PROJECT_DIR" ]; then
    echo "✅ 项目目录存在: $PROJECT_DIR"
    echo "目录权限: $(ls -ld $PROJECT_DIR)"
    
    if [ -f "$PROJECT_DIR/dist/index.js" ]; then
        echo "✅ 编译文件存在: $PROJECT_DIR/dist/index.js"
    else
        echo "❌ 编译文件不存在: $PROJECT_DIR/dist/index.js"
    fi
    
    if [ -f "$PROJECT_DIR/.env" ]; then
        echo "✅ 环境配置存在: $PROJECT_DIR/.env"
    else
        echo "❌ 环境配置不存在: $PROJECT_DIR/.env"
    fi
else
    echo "❌ 项目目录不存在: $PROJECT_DIR"
fi
echo ""

echo "💡 常见问题解决方案:"
echo "1. 如果服务文件不存在，运行: npm run systemd:service \$(pwd)"
echo "2. 如果权限不足，使用 sudo 执行 systemctl 命令"
echo "3. 如果服务文件有误，重新生成服务文件"
echo "4. 如果项目文件不存在，先运行: npm run build"
echo "5. 重载 systemd: sudo systemctl daemon-reload"
