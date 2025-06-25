#!/bin/bash

# subscription-api-ts 服务状态检测与诊断脚本
# 
# 功能说明:
# - 全面检测 systemd 状态、日志、端口、关键文件、Node.js 路径、进程、配置等
# - 支持 Linux (systemd) 和 macOS (进程管理) 环境
# - 提供详细的服务状态信息和故障排除建议
# - 自动检测配置文件、端口占用、服务响应等关键状态
#
# 使用方式:
#   ./scripts/check-service-status.sh
#
# 检查项目:
#   ✅ 环境配置和关键文件
#   ✅ Node.js 环境和依赖
#   ✅ 服务进程状态（systemd/进程）
#   ✅ 端口占用情况
#   ✅ 服务连接测试
#   ✅ Nginx 配置验证
#   ✅ 服务日志分析
#   ✅ 故障排除建议
#
echo "=== Subscription API TypeScript 服务状态检测 ==="

# 检测操作系统
OS=""
case "$(uname -s)" in
    Linux*)     OS=Linux;;
    Darwin*)    OS=Mac;;
    *)          OS="UNKNOWN";;
esac

echo "🖥️  操作系统: $OS"
echo "👤 当前用户: $(whoami)"
echo "⏰ 检测时间: $(date)"
echo ""

# 项目配置检查
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "📁 项目目录: $PROJECT_DIR"

# 读取环境配置
ENV_FILE="$PROJECT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    echo "✅ 环境配置文件存在"
    # 安全读取环境变量
    while IFS='=' read -r key value; do
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z $key ]] && continue
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        export "$key"="$value"
    done < <(grep -v '^[[:space:]]*#' "$ENV_FILE" | grep -v '^[[:space:]]*$')
    
    # 显示关键配置
    echo "🔌 应用端口: ${PORT:-3000}"
    echo "🌐 Nginx 端口: ${NGINX_PORT:-3080}"
    echo "� 代理端口: ${NGINX_PROXY_PORT:-3888}"
    echo "🏷️  服务名称: ${SERVICE_NAME:-subscription-api-ts}"
    echo "🌍 运行环境: ${NODE_ENV:-development}"
else
    echo "❌ 环境配置文件不存在: $ENV_FILE"
    echo "   建议运行: cp .env.example .env"
    # 设置默认值
    PORT=3000
    NGINX_PORT=3080
    NGINX_PROXY_PORT=3888
    SERVICE_NAME="subscription-api-ts"
    NODE_ENV="development"
fi

# 设置默认值
PORT="${PORT:-3000}"
NGINX_PORT="${NGINX_PORT:-3080}"
NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"
SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"
echo ""

# 检查关键文件
echo "📋 关键文件检查:"
check_file() {
    local file="$1"
    local desc="$2"
    if [ -f "$file" ]; then
        echo "✅ $desc: $file"
        return 0
    else
        echo "❌ $desc: $file (不存在)"
        return 1
    fi
}

check_file "$PROJECT_DIR/package.json" "包配置文件"
check_file "$PROJECT_DIR/tsconfig.json" "TypeScript 配置"
check_file "$PROJECT_DIR/dist/index.js" "编译输出文件"
check_file "$PROJECT_DIR/src/index.ts" "源代码入口"

if [ ! -f "$PROJECT_DIR/dist/index.js" ]; then
    echo "   💡 运行编译: npm run build"
fi
echo ""

# Node.js 环境检查
echo "🟢 Node.js 环境检查:"
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version)
    NODE_PATH_CMD=$(which node)
    echo "✅ Node.js 版本: $NODE_VERSION"
    echo "✅ Node.js 路径: $NODE_PATH_CMD"
    
    # 检查 npm
    if command -v npm >/dev/null 2>&1; then
        NPM_VERSION=$(npm --version)
        echo "✅ npm 版本: $NPM_VERSION"
    else
        echo "❌ npm 未安装或不在 PATH 中"
    fi
    
    # 检查依赖安装
    if [ -d "$PROJECT_DIR/node_modules" ]; then
        echo "✅ 依赖已安装"
    else
        echo "❌ 依赖未安装，请运行: npm install"
    fi
else
    echo "❌ Node.js 未安装或不在 PATH 中"
    echo "   请安装 Node.js 或确保其在 PATH 中"
fi
echo ""

if [ "$OS" = "Linux" ]; then
    echo "🐧 Linux 环境 - SystemD 服务检查:"
    
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    # 检查 systemctl 可用性
    if ! command -v systemctl &> /dev/null; then
        echo "❌ systemctl 不可用，可能不是 systemd 系统"
        echo "   请检查是否使用了 SysV init 或其他初始化系统"
        exit 1
    fi
    
    # 检查服务文件
    echo "📄 服务文件检查:"
    if [ -f "$SERVICE_FILE" ]; then
        echo "✅ 服务文件存在: $SERVICE_FILE"
        
        # 检查服务文件内容
        echo "   � 服务文件关键配置:"
        if grep -q "ExecStart=" "$SERVICE_FILE"; then
            EXEC_START=$(grep "ExecStart=" "$SERVICE_FILE" | cut -d'=' -f2-)
            echo "   🚀 启动命令: $EXEC_START"
        fi
        if grep -q "WorkingDirectory=" "$SERVICE_FILE"; then
            WORKING_DIR=$(grep "WorkingDirectory=" "$SERVICE_FILE" | cut -d'=' -f2-)
            echo "   📁 工作目录: $WORKING_DIR"
        fi
        if grep -q "User=" "$SERVICE_FILE"; then
            SERVICE_USER=$(grep "User=" "$SERVICE_FILE" | cut -d'=' -f2-)
            echo "   👤 运行用户: $SERVICE_USER"
        fi
        
        # 检查文件权限
        echo "   🔐 文件权限: $(ls -l "$SERVICE_FILE" | awk '{print $1 " " $3 ":" $4}')"
    else
        echo "❌ 服务文件不存在: $SERVICE_FILE"
        echo "   💡 生成服务文件:"
        echo "      cd $PROJECT_DIR"
        echo "      scripts/generate-systemd-service.sh"
        echo "      sudo systemctl daemon-reload"
        echo "      sudo systemctl enable ${SERVICE_NAME}"
    fi
    echo ""
    
    # 检查服务状态
    echo "📊 SystemD 服务状态:"
    echo "----------------------------------------"
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        echo "✅ 服务状态: 活跃 (运行中)"
    else
        echo "❌ 服务状态: 非活跃"
    fi
    
    if systemctl is-enabled --quiet ${SERVICE_NAME}; then
        echo "✅ 开机自启: 已启用"
    else
        echo "⚠️  开机自启: 未启用"
    fi
    
    # 详细状态信息
    echo ""
    echo "📈 详细状态信息:"
    systemctl status ${SERVICE_NAME} --no-pager --lines=5 2>&1 || true
    echo "----------------------------------------"
    
    # 最近日志
    echo ""
    echo "📝 最近服务日志 (最新 10 条):"
    echo "----------------------------------------"
    journalctl -u ${SERVICE_NAME} --no-pager --lines=10 --since="1 hour ago" 2>&1 || true
    echo "----------------------------------------"
    
    # 检查服务依赖
    echo ""
    echo "🔗 服务依赖检查:"
    if systemctl list-dependencies ${SERVICE_NAME} --no-pager 2>/dev/null | grep -q "subconverter.service"; then
        if systemctl is-active --quiet subconverter; then
            echo "✅ subconverter 服务: 运行中"
        else
            echo "⚠️  subconverter 服务: 未运行"
        fi
    fi
    
    echo ""
    echo "🔧 SystemD 服务控制命令:"
    echo "   查看状态: sudo systemctl status ${SERVICE_NAME}"
    echo "   启动服务: sudo systemctl start ${SERVICE_NAME}"
    echo "   停止服务: sudo systemctl stop ${SERVICE_NAME}"
    echo "   重启服务: sudo systemctl restart ${SERVICE_NAME}"
    echo "   启用自启: sudo systemctl enable ${SERVICE_NAME}"
    echo "   禁用自启: sudo systemctl disable ${SERVICE_NAME}"
    echo "   重载配置: sudo systemctl daemon-reload"
    echo "   查看日志: sudo journalctl -u ${SERVICE_NAME} -f"
    echo "   查看错误: sudo journalctl -u ${SERVICE_NAME} --since today --priority=err"
    
elif [ "$OS" = "Mac" ]; then
    echo "🍎 macOS 环境 - 进程与端口检查:"
    
    # 检查应用进程
    echo "🔍 进程检查:"
    APP_PROCESSES=$(pgrep -f "node.*dist/index.js" 2>/dev/null || true)
    if [ -n "$APP_PROCESSES" ]; then
        echo "✅ 应用进程运行中:"
        echo "$APP_PROCESSES" | while read -r pid; do
            if [ -n "$pid" ]; then
                echo "   PID: $pid"
                ps -p "$pid" -o pid,ppid,user,command --no-headers 2>/dev/null || true
            fi
        done
    else
        echo "❌ 应用进程未运行"
    fi
    
    # 检查 PM2 进程
    if command -v pm2 >/dev/null 2>&1; then
        echo ""
        echo "🔄 PM2 进程管理:"
        PM2_LIST=$(pm2 list 2>/dev/null | grep -i "${SERVICE_NAME}" || true)
        if [ -n "$PM2_LIST" ]; then
            echo "✅ PM2 中发现相关进程:"
            pm2 list | grep -E "(│|App name|${SERVICE_NAME})" || true
        else
            echo "⚠️  PM2 中未发现相关进程"
        fi
        
        echo ""
        echo "🔧 PM2 管理命令:"
        echo "   启动服务: pm2 start dist/index.js --name ${SERVICE_NAME}"
        echo "   停止服务: pm2 stop ${SERVICE_NAME}"
        echo "   重启服务: pm2 restart ${SERVICE_NAME}"
        echo "   查看状态: pm2 status"
        echo "   查看日志: pm2 logs ${SERVICE_NAME}"
        echo "   删除进程: pm2 delete ${SERVICE_NAME}"
    else
        echo ""
        echo "⚠️  PM2 未安装，建议安装: npm install -g pm2"
    fi
    
    echo ""
    echo "🔧 macOS 服务控制命令:"
    echo "   开发模式: npm run dev"
    echo "   生产模式: npm start"
    echo "   后台运行: nohup npm start > logs/app.log 2>&1 &"
    
else
    echo "❌ 不支持的操作系统: $OS"
    echo "   目前仅支持 Linux (systemd) 和 macOS"
fi

echo ""
echo "🌐 端口占用检查:"

# 检查应用端口
check_port() {
    local port="$1"
    local desc="$2"
    local protocol="$3"
    protocol="${protocol:-tcp}"
    
    if [ "$OS" = "Linux" ]; then
        if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
            echo "✅ $desc (端口 $port): 被占用"
            netstat -tuln | grep ":${port} " | head -1
        else
            echo "❌ $desc (端口 $port): 未被占用"
        fi
    elif [ "$OS" = "Mac" ]; then
        if lsof -i $protocol:$port >/dev/null 2>&1; then
            echo "✅ $desc (端口 $port): 被占用"
            lsof -i $protocol:$port | head -2
        else
            echo "❌ $desc (端口 $port): 未被占用"
        fi
    fi
}

check_port "$PORT" "应用服务端口"
check_port "$NGINX_PORT" "Nginx 服务端口"
check_port "$NGINX_PROXY_PORT" "Nginx 代理端口"

# 检查 subconverter 端口
SUBCONVERTER_PORT="25500"
check_port "$SUBCONVERTER_PORT" "Subconverter 端口"

echo ""
echo "🌍 服务连接测试:"

# 测试应用服务
test_service() {
    local url="$1"
    local desc="$2"
    local timeout="5"
    
    echo -n "🔗 测试 $desc ($url): "
    if curl -s --max-time $timeout "$url" >/dev/null 2>&1; then
        echo "✅ 连接成功"
        # 尝试获取响应内容
        RESPONSE=$(curl -s --max-time $timeout "$url" 2>/dev/null)
        if [ -n "$RESPONSE" ]; then
            # 如果是 JSON，尝试格式化
            if echo "$RESPONSE" | jq . >/dev/null 2>&1; then
                echo "   📄 响应: $(echo "$RESPONSE" | jq -c .)"
            else
                echo "   📄 响应: ${RESPONSE:0:100}..."
            fi
        fi
    else
        echo "❌ 连接失败"
    fi
}

test_service "http://localhost:$PORT/health" "健康检查接口"
test_service "http://localhost:$PORT/" "应用根路径"
test_service "http://localhost:$NGINX_PORT/" "Nginx 服务"
test_service "http://localhost:$SUBCONVERTER_PORT/" "Subconverter 服务"

echo ""
echo "📊 Nginx 配置检查:"

# 检查 Nginx 配置文件
NGINX_CONFIGS=(
    "/etc/nginx/sites-available/subscription-api-ts"
    "/etc/nginx/sites-enabled/subscription-api-ts" 
    "$PROJECT_DIR/config/nginx.conf"
)

for config in "${NGINX_CONFIGS[@]}"; do
    if [ -f "$config" ]; then
        echo "✅ Nginx 配置: $config"
        # 检查配置中的端口设置
        if grep -q "listen.*$NGINX_PROXY_PORT" "$config" 2>/dev/null; then
            echo "   ✅ 监听端口配置正确: $NGINX_PROXY_PORT"
        elif grep -q "listen.*$NGINX_PORT" "$config" 2>/dev/null; then
            echo "   ✅ 监听端口配置正确: $NGINX_PORT"
        else
            ACTUAL_PORT=$(grep -o "listen [0-9]*" "$config" 2>/dev/null | head -1 | awk '{print $2}')
            if [ -n "$ACTUAL_PORT" ]; then
                echo "   ⚠️  实际监听端口: $ACTUAL_PORT"
            else
                echo "   ⚠️  无法检测监听端口"
            fi
        fi
        
        # 检查代理配置
        if grep -q "proxy_pass.*:$PORT" "$config" 2>/dev/null; then
            echo "   ✅ 代理目标端口配置正确: $PORT"
        else
            ACTUAL_PROXY=$(grep -o "proxy_pass.*:[0-9]*" "$config" 2>/dev/null | head -1 | grep -o "[0-9]*$")
            if [ -n "$ACTUAL_PROXY" ]; then
                echo "   ⚠️  实际代理端口: $ACTUAL_PROXY"
            fi
        fi
    else
        echo "❌ Nginx 配置: $config (不存在)"
    fi
done

# 检查 Nginx 进程
if [ "$OS" = "Linux" ]; then
    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo "✅ Nginx 服务状态: 运行中"
    else
        echo "❌ Nginx 服务状态: 未运行"
    fi
elif [ "$OS" = "Mac" ]; then
    if pgrep nginx >/dev/null 2>&1; then
        echo "✅ Nginx 进程: 运行中"
    else
        echo "❌ Nginx 进程: 未运行"
    fi
fi

echo ""
echo "🔧 故障排除建议:"

# 根据检查结果给出建议
if [ ! -f "$PROJECT_DIR/dist/index.js" ]; then
    echo "📝 编译项目: npm run build"
fi

if [ "$OS" = "Linux" ] && [ ! -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
    echo "📝 生成并安装服务文件:"
    echo "   cd $PROJECT_DIR"
    echo "   ./scripts/generate-systemd-service.sh"
    echo "   sudo systemctl daemon-reload"
    echo "   sudo systemctl enable ${SERVICE_NAME}"
    echo "   sudo systemctl start ${SERVICE_NAME}"
fi

echo "📝 常用诊断命令:"
echo "   完整诊断: ./scripts/diagnose-systemd.sh"
echo "   TypeScript 诊断: ./scripts/diagnose-typescript.sh"
echo "   修复 Node.js 路径: ./scripts/fix-node-path.sh"
echo "   快速修复服务: ./scripts/quick-fix-systemd.sh"

echo ""
echo "✨ 检测完成！"
echo "   如需详细帮助，请查看 README.md 或运行相应的诊断脚本"
