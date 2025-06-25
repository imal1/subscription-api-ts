#!/bin/bash

# 修复 systemd 服务工作目录问题
# 解决 "Changing to the requested working directory failed" 错误

set -e

echo "🔧 修复 SystemD 工作目录问题"
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

# 检查权限
if [[ $EUID -ne 0 ]]; then
    echo "❌ 此脚本需要 root 权限运行"
    echo "   请使用: sudo $0"
    exit 1
fi

# 检查服务文件
if [ ! -f "$SERVICE_FILE" ]; then
    echo "❌ 服务文件不存在: $SERVICE_FILE"
    echo "🔄 重新生成服务文件..."
    
    # 确定目标用户
    if [ -n "$SUDO_USER" ]; then
        TARGET_USER="$SUDO_USER"
        TARGET_GROUP="$(id -gn $SUDO_USER)"
    else
        TARGET_USER="$(stat -c %U "$PROJECT_ROOT" 2>/dev/null || echo "root")"
        TARGET_GROUP="$(stat -c %G "$PROJECT_ROOT" 2>/dev/null || echo "root")"
    fi
    
    echo "   目标用户: $TARGET_USER"
    echo "   项目目录: $PROJECT_ROOT"
    
    # 设置环境变量
    export SERVICE_USER="$TARGET_USER" SERVICE_GROUP="$TARGET_GROUP"
    
    # 生成服务文件
    sudo -u "$TARGET_USER" bash "$SCRIPT_DIR/generate-systemd-service.sh" "$PROJECT_ROOT"
    
    # 安装服务文件
    cp "/tmp/${SERVICE_NAME}.service" "$SERVICE_FILE"
    systemctl daemon-reload
    
    echo "✅ 服务文件已重新生成"
fi

# 解析服务配置
WORKING_DIR=$(grep "^WorkingDirectory=" "$SERVICE_FILE" | cut -d'=' -f2- | tr -d ' ')
SERVICE_USER=$(grep "^User=" "$SERVICE_FILE" | cut -d'=' -f2- | tr -d ' ')

echo "📋 当前配置:"
echo "   工作目录: $WORKING_DIR"
echo "   服务用户: $SERVICE_USER"

# 检查并创建工作目录
if [ ! -d "$WORKING_DIR" ]; then
    echo "❌ 工作目录不存在，尝试创建..."
    
    # 如果工作目录就是项目根目录，说明项目目录有问题
    if [ "$WORKING_DIR" = "$PROJECT_ROOT" ]; then
        echo "⚠️  工作目录就是项目目录，但项目目录不存在"
        echo "   这可能是路径配置问题"
        echo "   当前项目实际路径: $PROJECT_ROOT"
        
        # 使用当前项目路径重新生成服务
        echo "🔄 使用实际项目路径重新生成服务..."
        export SERVICE_USER SERVICE_GROUP
        bash "$SCRIPT_DIR/generate-systemd-service.sh" "$PROJECT_ROOT"
        cp "/tmp/${SERVICE_NAME}.service" "$SERVICE_FILE"
        systemctl daemon-reload
        
        # 重新读取配置
        WORKING_DIR=$(grep "^WorkingDirectory=" "$SERVICE_FILE" | cut -d'=' -f2- | tr -d ' ')
        echo "   新的工作目录: $WORKING_DIR"
    else
        echo "   尝试创建目录: $WORKING_DIR"
        mkdir -p "$WORKING_DIR"
    fi
fi

# 检查用户是否存在
if ! id "$SERVICE_USER" >/dev/null 2>&1; then
    echo "❌ 服务用户不存在: $SERVICE_USER"
    echo "🔄 创建服务用户..."
    useradd -r -s /bin/false -d "$WORKING_DIR" "$SERVICE_USER"
    echo "✅ 已创建服务用户: $SERVICE_USER"
fi

# 修复目录权限
echo "🔧 修复目录权限..."
echo "   设置目录所有者: $SERVICE_USER:$SERVICE_USER"
chown -R "$SERVICE_USER:$SERVICE_USER" "$WORKING_DIR"

echo "   设置目录权限..."
chmod -R u+rwX "$WORKING_DIR"
chmod -R g+rX "$WORKING_DIR"

# 检查关键文件
echo "📂 检查关键文件..."
MISSING_FILES=()

if [ ! -f "$WORKING_DIR/dist/index.js" ]; then
    MISSING_FILES+=("dist/index.js")
fi

if [ ! -f "$WORKING_DIR/package.json" ]; then
    MISSING_FILES+=("package.json")
fi

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo "❌ 缺少关键文件: ${MISSING_FILES[*]}"
    
    # 如果工作目录不是项目目录，尝试复制文件
    if [ "$WORKING_DIR" != "$PROJECT_ROOT" ]; then
        echo "🔄 从项目目录复制文件..."
        
        for file in "${MISSING_FILES[@]}"; do
            if [ -f "$PROJECT_ROOT/$file" ]; then
                echo "   复制: $file"
                cp -r "$PROJECT_ROOT/$file" "$WORKING_DIR/"
                chown -R "$SERVICE_USER:$SERVICE_USER" "$WORKING_DIR/$file"
            fi
        done
        
        # 复制其他必要文件
        for item in node_modules .env; do
            if [ -e "$PROJECT_ROOT/$item" ] && [ ! -e "$WORKING_DIR/$item" ]; then
                echo "   复制: $item"
                cp -r "$PROJECT_ROOT/$item" "$WORKING_DIR/"
                chown -R "$SERVICE_USER:$SERVICE_USER" "$WORKING_DIR/$item"
            fi
        done
    else
        echo "   请确保项目已正确编译: npm run build"
    fi
fi

# 测试修复结果
echo ""
echo "🧪 测试修复结果..."

# 停止服务（如果正在运行）
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "   停止当前服务..."
    systemctl stop "$SERVICE_NAME"
fi

# 重新加载配置
systemctl daemon-reload

# 尝试启动服务
echo "   尝试启动服务..."
if systemctl start "$SERVICE_NAME"; then
    echo "✅ 服务启动成功！"
    
    # 检查服务状态
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "✅ 服务运行正常"
        echo ""
        echo "📊 服务状态:"
        systemctl status "$SERVICE_NAME" --no-pager --lines=5
    else
        echo "⚠️  服务启动后异常退出"
        echo ""
        echo "📝 最新日志:"
        journalctl -u "$SERVICE_NAME" --no-pager --lines=10 --since="1 minute ago"
    fi
else
    echo "❌ 服务启动失败"
    echo ""
    echo "📝 错误日志:"
    journalctl -u "$SERVICE_NAME" --no-pager --lines=10 --since="1 minute ago"
    
    echo ""
    echo "🔍 建议运行详细诊断:"
    echo "   ./scripts/diagnose-workdir.sh"
fi

echo ""
echo "✅ 修复完成！"
echo ""
echo "💡 后续操作:"
echo "   启动服务: sudo systemctl start $SERVICE_NAME"
echo "   查看状态: sudo systemctl status $SERVICE_NAME"
echo "   查看日志: sudo journalctl -u $SERVICE_NAME -f"
