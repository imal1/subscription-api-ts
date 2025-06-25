#!/bin/bash

# 快速修复 Node.js systemd 服务路径问题

echo "🔧 快速修复 systemd 服务中的 Node.js 路径问题"
echo ""

# 获取项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "步骤 1: 检查当前 Node.js 路径"
CURRENT_NODE=$(which node)
echo "   当前路径: $CURRENT_NODE"

if [[ "$CURRENT_NODE" == *"fnm"* ]] || [[ "$CURRENT_NODE" == *"nvm"* ]] || [[ "$CURRENT_NODE" == *"/run/user/"* ]]; then
    echo "   ⚠️  检测到版本管理器路径"
    
    echo ""
    echo "步骤 2: 复制 Node.js 到系统路径"
    if [[ $EUID -eq 0 ]]; then
        cp "$CURRENT_NODE" /usr/local/bin/node
        chmod +x /usr/local/bin/node
        echo "   ✅ 已复制到 /usr/local/bin/node"
    else
        sudo cp "$CURRENT_NODE" /usr/local/bin/node
        sudo chmod +x /usr/local/bin/node
        echo "   ✅ 已复制到 /usr/local/bin/node"
    fi
else
    echo "   ✅ Node.js 路径正常"
fi

echo ""
echo "步骤 3: 重新生成并安装服务文件"

# 设置环境变量
export SERVICE_USER="${USER}"
export SERVICE_GROUP="$(id -gn)"

# 重新生成服务文件
bash "$PROJECT_ROOT/scripts/generate-systemd-service.sh" "$PROJECT_ROOT"

SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"

# 安装服务文件
if [[ $EUID -eq 0 ]]; then
    cp "/tmp/${SERVICE_NAME}.service" /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    echo "   ✅ 服务已安装和启用"
else
    sudo cp "/tmp/${SERVICE_NAME}.service" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    echo "   ✅ 服务已安装和启用"
fi

echo ""
echo "步骤 4: 启动服务"
if [[ $EUID -eq 0 ]]; then
    systemctl start "$SERVICE_NAME"
    systemctl status "$SERVICE_NAME"
else
    sudo systemctl start "$SERVICE_NAME"
    sudo systemctl status "$SERVICE_NAME"
fi

echo ""
echo "🎉 修复完成！"
echo ""
echo "常用命令:"
if [[ $EUID -eq 0 ]]; then
    echo "  查看状态: systemctl status $SERVICE_NAME"
    echo "  查看日志: journalctl -u $SERVICE_NAME -f"
    echo "  重启服务: systemctl restart $SERVICE_NAME"
else
    echo "  查看状态: sudo systemctl status $SERVICE_NAME"
    echo "  查看日志: sudo journalctl -u $SERVICE_NAME -f"
    echo "  重启服务: sudo systemctl restart $SERVICE_NAME"
fi
