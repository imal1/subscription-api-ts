#!/bin/bash

# systemd 服务工作目录诊断脚本
# 用于诊断和修复 "Changing to the requested working directory failed" 错误

set -e

echo "🔍 SystemD 工作目录诊断"
echo "══════════════════════════════════════"

# 获取项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 读取环境变量
if [ -f "$PROJECT_ROOT/.env" ]; then
    while IFS='=' read -r key value; do
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z $key ]] && continue
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        export "$key"="$value"
    done < <(grep -v '^[[:space:]]*#' "$PROJECT_ROOT/.env" | grep -v '^[[:space:]]*$')
fi

SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

echo "📋 基本信息:"
echo "   项目目录: $PROJECT_ROOT"
echo "   服务名称: $SERVICE_NAME"
echo "   服务文件: $SERVICE_FILE"
echo ""

# 检查服务文件是否存在
if [ ! -f "$SERVICE_FILE" ]; then
    echo "❌ 服务文件不存在: $SERVICE_FILE"
    echo "   请先运行安装脚本生成服务文件"
    exit 1
fi

echo "✅ 服务文件存在"

# 解析服务文件中的工作目录
WORKING_DIR=$(grep "^WorkingDirectory=" "$SERVICE_FILE" | cut -d'=' -f2- | tr -d ' ')
SERVICE_USER=$(grep "^User=" "$SERVICE_FILE" | cut -d'=' -f2- | tr -d ' ')
EXEC_START=$(grep "^ExecStart=" "$SERVICE_FILE" | cut -d'=' -f2-)

echo ""
echo "📝 服务配置:"
echo "   工作目录: $WORKING_DIR"
echo "   运行用户: $SERVICE_USER"
echo "   启动命令: $EXEC_START"
echo ""

# 检查工作目录
echo "🔍 工作目录检查:"
if [ -d "$WORKING_DIR" ]; then
    echo "✅ 工作目录存在: $WORKING_DIR"
    
    # 检查权限
    if [ -r "$WORKING_DIR" ]; then
        echo "✅ 工作目录可读"
    else
        echo "❌ 工作目录不可读"
    fi
    
    if [ -x "$WORKING_DIR" ]; then
        echo "✅ 工作目录可执行（可进入）"
    else
        echo "❌ 工作目录不可执行（无法进入）"
    fi
    
    # 显示目录详细信息
    echo "   详细信息: $(ls -ld "$WORKING_DIR")"
    
else
    echo "❌ 工作目录不存在: $WORKING_DIR"
    echo ""
    echo "🔧 可能的解决方案:"
    echo "1. 检查项目是否已正确安装到指定目录"
    echo "2. 重新运行安装脚本"
    echo "3. 手动创建目录或修正服务文件中的路径"
    exit 1
fi

# 检查关键文件
echo ""
echo "📂 关键文件检查:"
KEY_FILES=(
    "$WORKING_DIR/dist/index.js"
    "$WORKING_DIR/package.json"
    "$WORKING_DIR/.env"
)

for file in "${KEY_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file (缺失)"
    fi
done

# 检查服务用户权限
echo ""
echo "👤 用户权限检查:"
if id "$SERVICE_USER" >/dev/null 2>&1; then
    echo "✅ 服务用户存在: $SERVICE_USER"
    
    # 检查用户对工作目录的访问权限
    if sudo -u "$SERVICE_USER" test -r "$WORKING_DIR" 2>/dev/null; then
        echo "✅ 服务用户可读取工作目录"
    else
        echo "❌ 服务用户无法读取工作目录"
        echo "   建议执行: sudo chown -R $SERVICE_USER:$SERVICE_USER $WORKING_DIR"
    fi
    
    if sudo -u "$SERVICE_USER" test -x "$WORKING_DIR" 2>/dev/null; then
        echo "✅ 服务用户可进入工作目录"
    else
        echo "❌ 服务用户无法进入工作目录"
        echo "   建议执行: sudo chmod u+x $WORKING_DIR"
    fi
    
else
    echo "❌ 服务用户不存在: $SERVICE_USER"
    echo "   建议创建用户或修改服务文件中的用户名"
fi

# 检查 Node.js 路径
echo ""
echo "🟢 Node.js 检查:"
NODE_PATH=$(grep "^ExecStart=" "$SERVICE_FILE" | grep -o '^[^[:space:]]*node\|/[^[:space:]]*node' | head -1)
if [ -n "$NODE_PATH" ]; then
    echo "   服务中的 Node.js 路径: $NODE_PATH"
    if [ -f "$NODE_PATH" ] && [ -x "$NODE_PATH" ]; then
        echo "✅ Node.js 可执行文件存在"
        # 检查服务用户是否可以执行
        if sudo -u "$SERVICE_USER" test -x "$NODE_PATH" 2>/dev/null; then
            echo "✅ 服务用户可以执行 Node.js"
        else
            echo "❌ 服务用户无法执行 Node.js"
        fi
    else
        echo "❌ Node.js 可执行文件不存在或无执行权限"
    fi
else
    echo "⚠️  无法从服务文件中提取 Node.js 路径"
fi

# 测试服务启动
echo ""
echo "🧪 服务启动测试:"
echo "   尝试启动服务..."
if sudo systemctl start "$SERVICE_NAME" 2>/dev/null; then
    echo "✅ 服务启动成功"
    sleep 2
    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "✅ 服务运行正常"
    else
        echo "⚠️  服务启动后异常退出"
    fi
    
    # 显示最新日志
    echo ""
    echo "📝 最近日志:"
    sudo journalctl -u "$SERVICE_NAME" --no-pager --lines=5 --since="1 minute ago"
    
else
    echo "❌ 服务启动失败"
    echo ""
    echo "📝 错误日志:"
    sudo journalctl -u "$SERVICE_NAME" --no-pager --lines=10 --since="1 minute ago"
fi

echo ""
echo "🔧 故障排除建议:"
echo "1. 确保工作目录存在且权限正确:"
echo "   sudo mkdir -p $WORKING_DIR"
echo "   sudo chown -R $SERVICE_USER:$SERVICE_USER $WORKING_DIR"
echo "   sudo chmod -R u+rX $WORKING_DIR"
echo ""
echo "2. 重新生成服务文件:"
echo "   cd $PROJECT_ROOT"
echo "   ./scripts/generate-systemd-service.sh $WORKING_DIR"
echo "   sudo cp /tmp/${SERVICE_NAME}.service /etc/systemd/system/"
echo "   sudo systemctl daemon-reload"
echo ""
echo "3. 检查完整服务状态:"
echo "   sudo systemctl status $SERVICE_NAME"
echo "   sudo journalctl -u $SERVICE_NAME -f"
