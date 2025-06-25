#!/bin/bash

# Linux 服务器专用：修复 subscription-api-ts 工作目录问题
# 解决：subscription-api-ts.service: Changing to the requested working directory failed

echo "🔧 修复 subscription-api-ts 工作目录问题"
echo "════════════════════════════════════════"

# 检查是否为 root 权限
if [[ $EUID -ne 0 ]]; then
    echo "❌ 需要 root 权限，请使用 sudo 运行"
    exit 1
fi

SERVICE_NAME="subscription-api-ts"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# 检查服务文件是否存在
if [ ! -f "$SERVICE_FILE" ]; then
    echo "❌ 服务文件不存在: $SERVICE_FILE"
    echo "请先运行项目的 install.sh 脚本"
    exit 1
fi

# 获取当前配置
echo "📋 当前服务配置："
WORKING_DIR=$(grep "^WorkingDirectory=" "$SERVICE_FILE" | cut -d'=' -f2-)
SERVICE_USER=$(grep "^User=" "$SERVICE_FILE" | cut -d'=' -f2-)
EXEC_START=$(grep "^ExecStart=" "$SERVICE_FILE" | cut -d'=' -f2-)

echo "   工作目录: $WORKING_DIR"
echo "   运行用户: $SERVICE_USER"
echo "   启动命令: $EXEC_START"

# 检查目录是否存在
if [ ! -d "$WORKING_DIR" ]; then
    echo ""
    echo "❌ 工作目录不存在: $WORKING_DIR"
    echo ""
    echo "🔧 请选择修复方案："
    echo "1) 创建目录并复制项目文件"
    echo "2) 手动指定正确的项目路径"
    echo "3) 退出，手动处理"
    read -p "请选择 (1-3): " choice
    
    case $choice in
        1)
            echo "📁 创建工作目录: $WORKING_DIR"
            mkdir -p "$WORKING_DIR"
            
            echo "👤 请输入项目的当前实际路径："
            read -p "项目路径: " ACTUAL_PROJECT_PATH
            
            if [ ! -d "$ACTUAL_PROJECT_PATH" ]; then
                echo "❌ 输入的路径不存在: $ACTUAL_PROJECT_PATH"
                exit 1
            fi
            
            echo "📂 复制项目文件..."
            cp -r "$ACTUAL_PROJECT_PATH"/* "$WORKING_DIR/"
            
            echo "🔐 设置权限..."
            if id "$SERVICE_USER" >/dev/null 2>&1; then
                chown -R "$SERVICE_USER:$SERVICE_USER" "$WORKING_DIR"
            else
                echo "⚠️  用户 $SERVICE_USER 不存在，创建用户..."
                useradd -r -s /bin/false -d "$WORKING_DIR" "$SERVICE_USER"
                chown -R "$SERVICE_USER:$SERVICE_USER" "$WORKING_DIR"
            fi
            chmod -R u+rX "$WORKING_DIR"
            ;;
            
        2)
            echo "👤 请输入正确的项目路径："
            read -p "项目路径: " CORRECT_PATH
            
            if [ ! -d "$CORRECT_PATH" ]; then
                echo "❌ 输入的路径不存在: $CORRECT_PATH"
                exit 1
            fi
            
            if [ ! -f "$CORRECT_PATH/dist/index.js" ]; then
                echo "❌ 项目路径中缺少编译文件: $CORRECT_PATH/dist/index.js"
                echo "请确保项目已正确编译"
                exit 1
            fi
            
            echo "✏️  更新服务文件..."
            sed -i "s|WorkingDirectory=.*|WorkingDirectory=$CORRECT_PATH|g" "$SERVICE_FILE"
            
            echo "🔐 检查权限..."
            if id "$SERVICE_USER" >/dev/null 2>&1; then
                chown -R "$SERVICE_USER:$SERVICE_USER" "$CORRECT_PATH" 2>/dev/null || echo "⚠️  无法更改所有权，请手动检查权限"
            else
                echo "⚠️  用户 $SERVICE_USER 不存在，创建用户..."
                useradd -r -s /bin/false -d "$CORRECT_PATH" "$SERVICE_USER"
                chown -R "$SERVICE_USER:$SERVICE_USER" "$CORRECT_PATH"
            fi
            ;;
            
        3)
            echo "👋 退出修复，请手动处理"
            exit 0
            ;;
            
        *)
            echo "❌ 无效选择"
            exit 1
            ;;
    esac
else
    echo "✅ 工作目录存在"
    
    # 检查权限
    if [ ! -r "$WORKING_DIR" ]; then
        echo "❌ 工作目录无法读取，修复权限..."
        chmod -R u+rX "$WORKING_DIR"
    fi
    
    # 检查用户权限
    if id "$SERVICE_USER" >/dev/null 2>&1; then
        if ! sudo -u "$SERVICE_USER" test -r "$WORKING_DIR" 2>/dev/null; then
            echo "❌ 服务用户无法访问目录，修复权限..."
            chown -R "$SERVICE_USER:$SERVICE_USER" "$WORKING_DIR"
        fi
    else
        echo "❌ 服务用户不存在，创建用户..."
        useradd -r -s /bin/false -d "$WORKING_DIR" "$SERVICE_USER"
        chown -R "$SERVICE_USER:$SERVICE_USER" "$WORKING_DIR"
    fi
fi

# 检查关键文件
echo ""
echo "📂 检查关键文件..."
if [ ! -f "$WORKING_DIR/dist/index.js" ]; then
    echo "❌ 缺少编译文件: $WORKING_DIR/dist/index.js"
    echo "请确保项目已正确编译 (npm run build)"
fi

if [ ! -f "$WORKING_DIR/package.json" ]; then
    echo "❌ 缺少 package.json: $WORKING_DIR/package.json"
fi

# 重新加载并测试服务
echo ""
echo "🔄 重新加载 systemd 配置..."
systemctl daemon-reload

echo "🧪 测试服务启动..."
systemctl stop "$SERVICE_NAME" 2>/dev/null || true

if systemctl start "$SERVICE_NAME"; then
    echo "✅ 服务启动成功！"
    sleep 2
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "✅ 服务运行正常"
        systemctl status "$SERVICE_NAME" --no-pager --lines=5
    else
        echo "⚠️  服务启动后退出，查看日志："
        journalctl -u "$SERVICE_NAME" --no-pager --lines=10 --since="1 minute ago"
    fi
else
    echo "❌ 服务启动失败，查看错误日志："
    journalctl -u "$SERVICE_NAME" --no-pager --lines=10 --since="1 minute ago"
fi

echo ""
echo "✅ 修复完成！"
echo ""
echo "💡 常用命令："
echo "   查看状态: sudo systemctl status $SERVICE_NAME"
echo "   查看日志: sudo journalctl -u $SERVICE_NAME -f"
echo "   重启服务: sudo systemctl restart $SERVICE_NAME"
