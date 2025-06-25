#!/bin/bash

# Linux SystemD 问题修复脚本
echo "=== Linux SystemD 问题修复 ==="

if [ "$(uname -s)" != "Linux" ]; then
    echo "❌ 此脚本仅适用于 Linux 系统"
    exit 1
fi

if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    echo "❌ 需要 sudo 权限来修复 systemd 问题"
    echo "请运行: sudo bash $0"
    exit 1
fi

# 获取项目目录并读取环境变量
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$PROJECT_DIR/.env" ]; then
    # 读取 .env 文件，忽略注释和空行
    while IFS='=' read -r key value; do
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z $key ]] && continue
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        export "$key"="$value"
    done < <(grep -v '^[[:space:]]*#' "$PROJECT_DIR/.env" | grep -v '^[[:space:]]*$')
fi

# 服务名称，可通过环境变量覆盖
SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

echo "🔧 开始修复 SystemD 服务问题..."
echo "📁 项目目录: $PROJECT_DIR"
echo ""

# 1. 检查并修复systemd daemon
echo "1️⃣ 检查 systemd daemon..."
if sudo systemctl status systemd > /dev/null 2>&1; then
    echo "✅ systemd daemon 正常运行"
else
    echo "❌ systemd daemon 可能有问题，尝试重启..."
    sudo systemctl daemon-reexec
fi

# 2. 清理旧的服务配置
echo ""
echo "2️⃣ 清理旧的服务配置..."
if [ -f "$SERVICE_FILE" ]; then
    echo "🗑️  停止并禁用旧服务..."
    sudo systemctl stop ${SERVICE_NAME} 2>/dev/null || true
    sudo systemctl disable ${SERVICE_NAME} 2>/dev/null || true
    sudo rm -f "$SERVICE_FILE"
    echo "✅ 旧服务配置已清理"
fi

# 3. 重新生成服务文件
echo ""
echo "3️⃣ 重新生成服务文件..."
cd "$PROJECT_DIR"

# 确保项目已构建
if [ ! -f "dist/index.js" ]; then
    echo "📦 构建项目..."
    npm run build
fi

# 生成新的服务文件
echo "🔧 生成新的服务文件..."
bash scripts/generate-systemd-service.sh "$PROJECT_DIR"

if [ -f "/tmp/${SERVICE_NAME}.service" ]; then
    echo "✅ 服务文件生成成功"
    
    # 安装服务文件
    sudo cp "/tmp/${SERVICE_NAME}.service" "$SERVICE_FILE"
    sudo chmod 644 "$SERVICE_FILE"
    echo "✅ 服务文件已安装"
else
    echo "❌ 服务文件生成失败"
    exit 1
fi

# 4. 重新加载systemd配置
echo ""
echo "4️⃣ 重新加载 systemd 配置..."
sudo systemctl daemon-reload
echo "✅ systemd 配置已重新加载"

# 5. 启用并启动服务
echo ""
echo "5️⃣ 启用并启动服务..."
sudo systemctl enable ${SERVICE_NAME}
echo "✅ 服务已启用"

echo ""
echo "🚀 尝试启动服务..."
if sudo systemctl start ${SERVICE_NAME}; then
    echo "✅ 服务启动成功！"
else
    echo "❌ 服务启动失败，查看详细信息..."
    echo ""
    echo "📋 服务状态:"
    sudo systemctl status ${SERVICE_NAME} --no-pager
    echo ""
    echo "📋 服务日志:"
    sudo journalctl -u ${SERVICE_NAME} --no-pager --lines=20
    echo ""
    echo "🔍 可能的问题:"
    echo "1. Node.js 路径不正确"
    echo "2. 项目文件权限问题"
    echo "3. 环境变量配置错误"
    echo "4. 端口被占用"
    exit 1
fi

# 6. 验证服务状态
echo ""
echo "6️⃣ 验证服务状态..."
sleep 2

if sudo systemctl is-active ${SERVICE_NAME} --quiet; then
    echo "✅ 服务运行正常"
    
    # 检查端口
    PORT=$(grep '^PORT=' "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"' 2>/dev/null || echo "3000")
    echo "🔌 检查端口 $PORT..."
    
    if curl -s http://localhost:$PORT/health > /dev/null; then
        echo "✅ 服务响应正常"
        echo ""
        echo "🎉 修复完成！服务已正常运行"
        echo "📊 服务状态: sudo systemctl status ${SERVICE_NAME}"
        echo "📋 查看日志: sudo journalctl -u ${SERVICE_NAME} -f"
        echo "🌐 测试地址: http://localhost:$PORT/health"
    else
        echo "⚠️  服务运行但无响应，可能需要等待启动完成"
        echo "请稍后再次检查: curl http://localhost:$PORT/health"
    fi
else
    echo "❌ 服务未能正常运行"
    sudo systemctl status ${SERVICE_NAME} --no-pager
fi
