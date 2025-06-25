#!/bin/bash

# 快速修复 subscription-api-ts 服务启动失败问题
set -e

echo "🔧 快速修复 subscription-api-ts 服务启动问题..."
echo "================================================"

SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"

# 获取当前脚本目录和项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "📁 项目根目录: $PROJECT_ROOT"

# 1. 检查并修复基本环境
echo ""
echo "🔍 步骤 1: 检查基本环境"
echo "--------------------------------"

# 检查 Node.js
if ! command -v node >/dev/null 2>&1; then
    echo "❌ Node.js 未安装或不在 PATH 中"
    exit 1
fi

NODE_VERSION=$(node --version)
echo "✅ Node.js 版本: $NODE_VERSION"

# 检查 npm
if ! command -v npm >/dev/null 2>&1; then
    echo "❌ npm 未安装"
    exit 1
fi

echo "✅ npm 版本: $(npm --version)"

# 2. 进入项目目录并检查文件
echo ""
echo "🔍 步骤 2: 检查项目文件"
echo "--------------------------------"

cd "$PROJECT_ROOT"

if [ ! -f "package.json" ]; then
    echo "❌ package.json 不存在"
    exit 1
fi
echo "✅ package.json 存在"

if [ ! -f "tsconfig.json" ]; then
    echo "❌ tsconfig.json 不存在"
    exit 1
fi
echo "✅ tsconfig.json 存在"

# 3. 安装依赖
echo ""
echo "🔍 步骤 3: 安装/更新依赖"
echo "--------------------------------"

if [ ! -d "node_modules" ]; then
    echo "📦 安装依赖..."
    npm install
else
    echo "📦 更新依赖..."
    npm install
fi

echo "✅ 依赖安装完成"

# 4. 清理并重新构建
echo ""
echo "🔍 步骤 4: 清理并重新构建"
echo "--------------------------------"

echo "🧹 清理之前的构建..."
rm -rf dist/

echo "🏗️ 重新构建项目..."
npm run build

if [ ! -f "dist/index.js" ]; then
    echo "❌ 构建失败，dist/index.js 不存在"
    exit 1
fi

echo "✅ 构建成功"

# 5. 检查环境配置
echo ""
echo "🔍 步骤 5: 检查环境配置"
echo "--------------------------------"

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        echo "📝 从 .env.example 创建 .env 文件..."
        cp .env.example .env
        echo "⚠️  请编辑 .env 文件配置正确的参数"
    else
        echo "⚠️  .env 文件不存在，创建基本配置..."
        cat > .env << EOF
# 基本配置
PORT=3000
NODE_ENV=production

# 日志配置
LOG_LEVEL=info
LOG_FILE=/var/log/subscription-api-ts.log

# Subconverter 配置
SUBCONVERTER_URL=http://localhost:25500

# 自动更新配置（可选）
# AUTO_UPDATE_CRON=0 */6 * * *
EOF
    fi
else
    echo "✅ .env 文件存在"
fi

# 6. 测试应用启动
echo ""
echo "🔍 步骤 6: 测试应用启动"
echo "--------------------------------"

echo "🧪 测试应用是否能正常启动..."

# 设置测试环境变量
export NODE_ENV=production
export PORT=3001  # 使用不同端口避免冲突

# 在后台启动应用，5秒后终止
echo "启动测试 (5秒)..."
timeout 5s node dist/index.js &

TEST_PID=$!
sleep 2

# 检查进程是否还在运行
if kill -0 $TEST_PID 2>/dev/null; then
    echo "✅ 应用启动测试成功"
    kill $TEST_PID 2>/dev/null || true
else
    echo "❌ 应用启动测试失败"
    # 显示可能的错误
    echo "尝试启动以查看错误:"
    timeout 3s node dist/index.js || true
fi

# 7. 生成/更新 systemd 服务配置
echo ""
echo "🔍 步骤 7: 更新 systemd 服务配置"
echo "--------------------------------"

if [ -f "scripts/generate-systemd-service.sh" ]; then
    echo "🔧 重新生成 systemd 服务配置..."
    
    # 确定安装目录
    INSTALL_DIR="$PROJECT_ROOT"
    
    # 运行生成脚本
    bash scripts/generate-systemd-service.sh "$INSTALL_DIR"
    
    echo "📋 生成的服务文件位于: /tmp/subscription-api-ts.service"
    echo "请运行以下命令安装服务配置:"
    echo "   sudo cp /tmp/subscription-api-ts.service /etc/systemd/system/"
    echo "   sudo systemctl daemon-reload"
    
else
    echo "⚠️  服务配置生成脚本不存在"
fi

# 8. 提供最终指令
echo ""
echo "🔍 步骤 8: 服务重启指令"
echo "--------------------------------"

echo "🚀 执行以下命令重新启动服务:"
echo ""
echo "1. 更新服务配置 (如果需要):"
echo "   sudo cp /tmp/subscription-api-ts.service /etc/systemd/system/"
echo "   sudo systemctl daemon-reload"
echo ""
echo "2. 重启服务:"
echo "   sudo systemctl stop $SERVICE_NAME"
echo "   sudo systemctl start $SERVICE_NAME"
echo ""
echo "3. 检查状态:"
echo "   systemctl status $SERVICE_NAME"
echo "   journalctl -u $SERVICE_NAME --lines=10"
echo ""
echo "4. 如果还有问题，运行详细诊断:"
echo "   bash scripts/diagnose-service-failure.sh"

echo ""
echo "================================================"
echo "✅ 快速修复完成！"
