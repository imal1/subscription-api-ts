#!/bin/bash

# 诊断 subscription-api-ts 服务启动失败的脚本
echo "🔍 诊断 subscription-api-ts 服务启动失败问题..."
echo "=================================================="

SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"

# 1. 检查 systemd 服务状态
echo "1️⃣ 检查服务状态:"
echo "----------------------------------------"
systemctl status "$SERVICE_NAME" --no-pager || true
echo ""

# 2. 查看详细错误日志
echo "2️⃣ 查看服务日志 (最近 20 条):"
echo "----------------------------------------"
journalctl -u "$SERVICE_NAME" --no-pager --lines=20 || true
echo ""

# 3. 查看最新的错误日志
echo "3️⃣ 查看最新错误日志:"
echo "----------------------------------------"
journalctl -u "$SERVICE_NAME" --no-pager --since="5 minutes ago" || true
echo ""

# 4. 检查服务配置文件
echo "4️⃣ 检查服务配置文件:"
echo "----------------------------------------"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
if [ -f "$SERVICE_FILE" ]; then
    echo "服务文件存在: $SERVICE_FILE"
    echo "内容:"
    cat "$SERVICE_FILE"
else
    echo "❌ 服务文件不存在: $SERVICE_FILE"
fi
echo ""

# 5. 检查工作目录和文件
echo "5️⃣ 检查工作目录和关键文件:"
echo "----------------------------------------"

# 从服务文件中提取工作目录
WORKING_DIR=$(grep "^WorkingDirectory=" "$SERVICE_FILE" 2>/dev/null | cut -d'=' -f2)
if [ -z "$WORKING_DIR" ]; then
    WORKING_DIR="/opt/subscription-api-ts"
fi

echo "工作目录: $WORKING_DIR"

if [ -d "$WORKING_DIR" ]; then
    echo "✅ 工作目录存在"
    echo "目录权限: $(ls -ld "$WORKING_DIR")"
    
    # 检查关键文件
    echo ""
    echo "关键文件检查:"
    [ -f "$WORKING_DIR/dist/index.js" ] && echo "✅ dist/index.js 存在" || echo "❌ dist/index.js 不存在"
    [ -f "$WORKING_DIR/dist/app.js" ] && echo "✅ dist/app.js 存在" || echo "❌ dist/app.js 不存在"
    [ -f "$WORKING_DIR/package.json" ] && echo "✅ package.json 存在" || echo "❌ package.json 不存在"
    [ -f "$WORKING_DIR/.env" ] && echo "✅ .env 存在" || echo "❌ .env 不存在"
    
    # 检查 node_modules
    if [ -d "$WORKING_DIR/node_modules" ]; then
        echo "✅ node_modules 存在"
        echo "   依赖数量: $(ls "$WORKING_DIR/node_modules" | wc -l)"
    else
        echo "❌ node_modules 不存在"
    fi
    
    # 检查 dist 目录结构
    if [ -d "$WORKING_DIR/dist" ]; then
        echo "✅ dist 目录存在"
        echo "   内容:"
        ls -la "$WORKING_DIR/dist"
    else
        echo "❌ dist 目录不存在"
    fi
    
else
    echo "❌ 工作目录不存在: $WORKING_DIR"
fi
echo ""

# 6. 检查 Node.js 可执行文件
echo "6️⃣ 检查 Node.js:"
echo "----------------------------------------"
NODE_PATH=$(grep "^ExecStart=" "$SERVICE_FILE" 2>/dev/null | cut -d'=' -f2 | cut -d' ' -f1)
if [ -z "$NODE_PATH" ]; then
    NODE_PATH="/usr/bin/node"
fi

echo "配置的 Node.js 路径: $NODE_PATH"

if [ -f "$NODE_PATH" ] && [ -x "$NODE_PATH" ]; then
    echo "✅ Node.js 可执行文件存在且可执行"
    echo "   版本: $($NODE_PATH --version)"
else
    echo "❌ Node.js 可执行文件问题"
    echo "   文件存在: $([ -f "$NODE_PATH" ] && echo "是" || echo "否")"
    echo "   可执行: $([ -x "$NODE_PATH" ] && echo "是" || echo "否")"
    
    # 查找其他可能的 Node.js 路径
    echo "   查找其他 Node.js 路径:"
    which node 2>/dev/null || echo "   系统 PATH 中未找到 node"
    [ -f "/usr/local/bin/node" ] && echo "   /usr/local/bin/node 存在"
    [ -f "/opt/node/bin/node" ] && echo "   /opt/node/bin/node 存在"
fi
echo ""

# 7. 测试手动运行
echo "7️⃣ 测试手动运行:"
echo "----------------------------------------"
if [ -f "$WORKING_DIR/dist/index.js" ] && [ -x "$NODE_PATH" ]; then
    echo "尝试手动运行应用..."
    cd "$WORKING_DIR" 2>/dev/null || true
    
    # 设置环境变量
    export NODE_ENV=production
    
    echo "命令: cd $WORKING_DIR && $NODE_PATH dist/index.js"
    echo "输出:"
    
    # 运行 5 秒后终止
    timeout 5s "$NODE_PATH" dist/index.js 2>&1 || echo "手动运行测试完成 (5秒超时或出错)"
else
    echo "❌ 无法进行手动运行测试"
fi
echo ""

# 8. 检查用户权限
echo "8️⃣ 检查用户权限:"
echo "----------------------------------------"
SERVICE_USER=$(grep "^User=" "$SERVICE_FILE" 2>/dev/null | cut -d'=' -f2)
if [ -n "$SERVICE_USER" ]; then
    echo "配置的运行用户: $SERVICE_USER"
    
    # 检查用户是否存在
    if id "$SERVICE_USER" >/dev/null 2>&1; then
        echo "✅ 用户存在"
        echo "   用户信息: $(id "$SERVICE_USER")"
        
        # 检查对工作目录的权限
        if [ -d "$WORKING_DIR" ]; then
            echo "   对工作目录的权限:"
            -u "$SERVICE_USER" test -r "$WORKING_DIR" && echo "   ✅ 读权限" || echo "   ❌ 读权限"
            -u "$SERVICE_USER" test -x "$WORKING_DIR" && echo "   ✅ 执行权限" || echo "   ❌ 执行权限"
        fi
    else
        echo "❌ 用户不存在: $SERVICE_USER"
    fi
else
    echo "未指定运行用户，将使用 root"
fi
echo ""

# 9. 提供修复建议
echo "9️⃣ 修复建议:"
echo "----------------------------------------"
echo "基于以上检查，可能的解决方案:"
echo ""

if [ ! -f "$WORKING_DIR/dist/index.js" ]; then
    echo "🔧 构建问题:"
    echo "   cd $WORKING_DIR"
    echo "   npm install"
    echo "   npm run build"
    echo ""
fi

if [ ! -f "$NODE_PATH" ] || [ ! -x "$NODE_PATH" ]; then
    echo "🔧 Node.js 路径问题:"
    echo "   ln -sf \$(which node) $NODE_PATH"
    echo "   或重新生成服务配置"
    echo ""
fi

if [ ! -f "$WORKING_DIR/.env" ]; then
    echo "🔧 环境配置问题:"
    echo "   cp $WORKING_DIR/.env.example $WORKING_DIR/.env"
    echo "   # 然后编辑 .env 文件配置正确的参数"
    echo ""
fi

echo "🔧 重新启动服务:"
echo "   systemctl daemon-reload"
echo "   systemctl restart $SERVICE_NAME"
echo "   systemctl enable $SERVICE_NAME"
echo ""

echo "🔍 继续监控:"
echo "   journalctl -u $SERVICE_NAME -f"
echo ""

echo "=================================================="
echo "诊断完成！请根据上述信息进行相应的修复。"
