#!/bin/bash

# Nginx 静态文件服务诊断脚本

echo "🔍 Nginx 静态文件服务诊断"
echo "================================"

# 读取环境变量
if [ -f ".env" ]; then
    source .env
fi

DATA_DIR="${DATA_DIR:-/var/www/subscription}"
NGINX_PORT="${NGINX_PORT:-3080}"
NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"

echo "📋 配置信息:"
echo "   数据目录: $DATA_DIR"
echo "   静态端口: $NGINX_PORT"
echo "   代理端口: $NGINX_PROXY_PORT"
echo ""

# 1. 检查数据目录
echo "📁 检查数据目录..."
if [ -d "$DATA_DIR" ]; then
    echo "   ✅ 数据目录存在: $DATA_DIR"
    echo "   📊 目录权限:"
    ls -la "$DATA_DIR"
    echo ""
    echo "   📂 目录内容:"
    ls -la "$DATA_DIR"/ 2>/dev/null || echo "   ❌ 无法列出目录内容"
else
    echo "   ❌ 数据目录不存在: $DATA_DIR"
fi
echo ""

# 2. 检查关键文件
echo "📄 检查关键文件..."
files=("subscription.txt" "clash.yaml" "raw_links.txt")
for file in "${files[@]}"; do
    file_path="$DATA_DIR/$file"
    if [ -f "$file_path" ]; then
        echo "   ✅ $file 存在"
        ls -la "$file_path"
    else
        echo "   ❌ $file 不存在"
    fi
done
echo ""

# 3. 检查 Nginx 配置
echo "🌐 检查 Nginx 配置..."
nginx_config="/etc/nginx/sites-enabled/subscription-api-ts"
if [ -f "$nginx_config" ]; then
    echo "   ✅ Nginx 配置文件存在"
    echo "   📋 配置内容 (静态文件部分):"
    grep -A 20 "listen ${NGINX_PORT}" "$nginx_config" 2>/dev/null || echo "   ⚠️  未找到静态端口配置"
else
    echo "   ❌ Nginx 配置文件不存在: $nginx_config"
fi
echo ""

# 4. 检查 Nginx 进程
echo "🔄 检查 Nginx 状态..."
if systemctl is-active --quiet nginx; then
    echo "   ✅ Nginx 服务运行中"
    echo "   📊 Nginx 进程:"
    ps aux | grep nginx | grep -v grep
else
    echo "   ❌ Nginx 服务未运行"
fi
echo ""

# 5. 检查端口监听
echo "🔌 检查端口监听..."
if command -v netstat >/dev/null 2>&1; then
    echo "   端口 $NGINX_PORT 监听状态:"
    netstat -tuln | grep ":$NGINX_PORT " || echo "   ❌ 端口 $NGINX_PORT 未监听"
    echo "   端口 $NGINX_PROXY_PORT 监听状态:"
    netstat -tuln | grep ":$NGINX_PROXY_PORT " || echo "   ❌ 端口 $NGINX_PROXY_PORT 未监听"
elif command -v ss >/dev/null 2>&1; then
    echo "   端口 $NGINX_PORT 监听状态:"
    ss -tuln | grep ":$NGINX_PORT " || echo "   ❌ 端口 $NGINX_PORT 未监听"
    echo "   端口 $NGINX_PROXY_PORT 监听状态:"
    ss -tuln | grep ":$NGINX_PROXY_PORT " || echo "   ❌ 端口 $NGINX_PROXY_PORT 未监听"
else
    echo "   ⚠️  无法检查端口状态 (netstat/ss 不可用)"
fi
echo ""

# 6. 测试本地访问
echo "🌐 测试本地访问..."
echo "   测试静态端口 ($NGINX_PORT):"
if curl -s -I "http://localhost:$NGINX_PORT/" | head -1; then
    echo "   ✅ 静态端口响应正常"
else
    echo "   ❌ 静态端口无响应"
fi

echo "   测试代理端口 ($NGINX_PROXY_PORT):"
if curl -s -I "http://localhost:$NGINX_PROXY_PORT/" | head -1; then
    echo "   ✅ 代理端口响应正常"
else
    echo "   ❌ 代理端口无响应"
fi

if [ -f "$DATA_DIR/subscription.txt" ]; then
    echo "   测试订阅文件访问:"
    echo "     静态端口: http://localhost:$NGINX_PORT/subscription.txt"
    if curl -s -I "http://localhost:$NGINX_PORT/subscription.txt" | head -1; then
        echo "     ✅ 静态端口订阅文件可访问"
    else
        echo "     ❌ 静态端口订阅文件不可访问"
    fi
    
    echo "     代理端口: http://localhost:$NGINX_PROXY_PORT/subscription.txt"
    if curl -s -I "http://localhost:$NGINX_PROXY_PORT/subscription.txt" | head -1; then
        echo "     ✅ 代理端口订阅文件可访问"
    else
        echo "     ❌ 代理端口订阅文件不可访问"
    fi
fi
echo ""

# 7. 检查 Nginx 错误日志
echo "📋 检查 Nginx 错误日志..."
error_log="/var/log/nginx/error.log"
if [ -f "$error_log" ]; then
    echo "   最近的 Nginx 错误 (最后 10 行):"
    tail -10 "$error_log" | grep -E "(error|denied|forbidden)" || echo "   ✅ 最近无相关错误"
else
    echo "   ⚠️  Nginx 错误日志不存在: $error_log"
fi
echo ""

# 8. 权限建议
echo "🔧 权限修复建议:"
echo "   如果遇到 403 错误，请执行以下命令:"
echo ""
echo "   # 修复目录权限"
echo "   sudo chown -R nginx:nginx $DATA_DIR"
echo "   sudo chmod -R 755 $DATA_DIR"
echo "   sudo chmod 644 $DATA_DIR/*.txt $DATA_DIR/*.yaml 2>/dev/null || true"
echo ""
echo "   # 重新生成 Nginx 配置"
echo "   ./manage.sh update  # 或者重新运行安装脚本"
echo ""
echo "   # 测试 Nginx 配置"
echo "   sudo nginx -t"
echo ""
echo "   # 重新加载 Nginx"
echo "   sudo systemctl reload nginx"
echo ""

echo "✅ 诊断完成"
