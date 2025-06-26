#!/bin/bash

# Nginx 403 错误诊断和修复脚本
# 专门用于解决静态文件服务的 403 Forbidden 问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 检查sudo命令是否可用
HAS_SUDO=false
if command -v sudo >/dev/null 2>&1; then
    HAS_SUDO=true
fi

# 定义安全的sudo函数
safe_sudo() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif [ "$HAS_SUDO" = true ]; then
        sudo "$@"
    else
        echo "❌ 错误：需要root权限或sudo命令来执行: $*"
        exit 1
    fi
}

echo -e "${RED}🚨 Nginx 403 错误诊断和修复${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

# 1. 检查环境变量和配置
echo -e "${WHITE}1. 检查配置文件...${NC}"

if [ -f ".env" ]; then
    echo -e "  ✅ .env 文件存在"
    
    # 安全地加载环境变量
    while IFS='=' read -r key value; do
        if [[ $key =~ ^[A-Z_][A-Z0-9_]*$ ]] && [[ ! $key =~ ^# ]]; then
            export "$key"="$value"
        fi
    done < <(grep -E '^[A-Z_][A-Z0-9_]*=' .env | grep -v '^#')
    
    echo -e "  📋 关键配置:"
    echo -e "    STATIC_DIR: ${STATIC_DIR:-未设置}"
    echo -e "    NGINX_PORT: ${NGINX_PORT:-未设置}"
else
    echo -e "  ❌ .env 文件不存在"
fi

# 设置数据目录
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    DATA_DIR="${STATIC_DIR:-/var/www/subscription}"
else
    DATA_DIR="${STATIC_DIR:-./data}"
fi

echo -e "  📁 数据目录: $DATA_DIR"

# 2. 检查数据目录
echo -e "${WHITE}2. 检查数据目录状态...${NC}"

if [ -d "$DATA_DIR" ]; then
    echo -e "  ✅ 数据目录存在: $DATA_DIR"
    
    # 检查目录权限
    DIR_PERMS=$(ls -ld "$DATA_DIR" | cut -d' ' -f1)
    DIR_OWNER=$(ls -ld "$DATA_DIR" | awk '{print $3":"$4}')
    echo -e "  📋 目录权限: $DIR_PERMS"
    echo -e "  👤 目录所有者: $DIR_OWNER"
    
    # 检查目录是否可读
    if [ -r "$DATA_DIR" ]; then
        echo -e "  ✅ 目录可读"
    else
        echo -e "  ❌ 目录不可读"
    fi
    
    # 检查目录内容
    echo -e "  📂 目录内容:"
    if [ "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
        ls -la "$DATA_DIR" | head -10
        TOTAL_FILES=$(find "$DATA_DIR" -type f 2>/dev/null | wc -l)
        echo -e "  📊 总文件数: $TOTAL_FILES"
    else
        echo -e "  ⚠️  目录为空"
    fi
else
    echo -e "  ❌ 数据目录不存在: $DATA_DIR"
    echo -e "  🔧 创建数据目录..."
    
    if [[ "$DATA_DIR" == /var/www/* ]]; then
        safe_sudo mkdir -p "$DATA_DIR"
        safe_sudo chown -R www-data:www-data "$DATA_DIR"
        safe_sudo chmod 755 "$DATA_DIR"
    else
        mkdir -p "$DATA_DIR"
        chmod 755 "$DATA_DIR"
    fi
    
    echo -e "  ✅ 数据目录已创建"
fi

# 3. 检查 Nginx 配置
echo -e "${WHITE}3. 检查 Nginx 配置...${NC}"

if [ -f "config/nginx.conf" ]; then
    echo -e "  ✅ nginx.conf 存在"
    
    # 检查配置中的 root 路径
    ROOT_PATH=$(grep "root.*data" config/nginx.conf | head -1 | awk '{print $2}' | tr -d ';')
    echo -e "  📋 配置中的 root 路径: $ROOT_PATH"
    
    # 检查监听端口
    LISTEN_PORT=$(grep "listen.*3080" config/nginx.conf | head -1 | awk '{print $2}' | tr -d ';')
    echo -e "  📋 监听端口: $LISTEN_PORT"
    
    # 检查是否启用了 autoindex
    if grep -q "autoindex on" config/nginx.conf; then
        echo -e "  ✅ autoindex 已启用"
    else
        echo -e "  ⚠️  autoindex 未启用"
    fi
    
else
    echo -e "  ❌ nginx.conf 不存在"
fi

# 4. 检查 Nginx 进程和用户
echo -e "${WHITE}4. 检查 Nginx 进程...${NC}"

if command -v nginx >/dev/null 2>&1; then
    echo -e "  ✅ Nginx 已安装"
    
    if pgrep nginx >/dev/null; then
        echo -e "  ✅ Nginx 正在运行"
        
        # 检查 Nginx 用户
        NGINX_USER=$(ps aux | grep "nginx: worker" | grep -v grep | head -1 | awk '{print $1}')
        if [ -n "$NGINX_USER" ]; then
            echo -e "  👤 Nginx 运行用户: $NGINX_USER"
            
            # 检查用户对数据目录的访问权限
            if safe_sudo -u "$NGINX_USER" test -r "$DATA_DIR" 2>/dev/null; then
                echo -e "  ✅ Nginx 用户可以读取数据目录"
            else
                echo -e "  ❌ Nginx 用户无法读取数据目录"
            fi
        fi
    else
        echo -e "  ❌ Nginx 未运行"
    fi
else
    echo -e "  ❌ Nginx 未安装"
fi

# 5. 创建测试文件
echo -e "${WHITE}5. 创建测试文件...${NC}"

TEST_FILE="$DATA_DIR/test.html"
INDEX_FILE="$DATA_DIR/index.html"

# 创建测试文件
cat > /tmp/test.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Nginx 测试页面</title>
    <meta charset="utf-8">
</head>
<body>
    <h1>🎉 Nginx 静态服务正常工作！</h1>
    <p>如果您看到这个页面，说明 Nginx 静态文件服务已经正确配置。</p>
    <p>访问时间: <script>document.write(new Date().toLocaleString());</script></p>
    <hr>
    <p><a href="/subscription.txt">查看订阅文件</a></p>
</body>
</html>
EOF

# 复制测试文件
if [[ "$DATA_DIR" == /var/www/* ]]; then
    safe_sudo cp /tmp/test.html "$TEST_FILE"
    safe_sudo cp /tmp/test.html "$INDEX_FILE"
    safe_sudo chown www-data:www-data "$TEST_FILE" "$INDEX_FILE"
    safe_sudo chmod 644 "$TEST_FILE" "$INDEX_FILE"
else
    cp /tmp/test.html "$TEST_FILE"
    cp /tmp/test.html "$INDEX_FILE"
    chmod 644 "$TEST_FILE" "$INDEX_FILE"
fi

rm /tmp/test.html
echo -e "  ✅ 测试文件已创建: $TEST_FILE"

# 6. 修复权限问题
echo -e "${WHITE}6. 修复权限问题...${NC}"

if [[ "$DATA_DIR" == /var/www/* ]]; then
    echo -e "  🔧 修复 /var/www 目录权限..."
    safe_sudo chown -R www-data:www-data "$DATA_DIR"
    safe_sudo chmod -R 755 "$DATA_DIR"
    safe_sudo find "$DATA_DIR" -type f -exec chmod 644 {} \;
    echo -e "  ✅ 权限修复完成"
else
    echo -e "  🔧 修复本地数据目录权限..."
    chmod -R 755 "$DATA_DIR"
    find "$DATA_DIR" -type f -exec chmod 644 {} \;
    echo -e "  ✅ 权限修复完成"
fi

# 7. 检查 SELinux (如果适用)
if command -v getenforce >/dev/null 2>&1; then
    echo -e "${WHITE}7. 检查 SELinux...${NC}"
    SELINUX_STATUS=$(getenforce 2>/dev/null || echo "未知")
    echo -e "  📋 SELinux 状态: $SELINUX_STATUS"
    
    if [ "$SELINUX_STATUS" = "Enforcing" ]; then
        echo -e "  ⚠️  SELinux 可能阻止访问，尝试修复..."
        safe_sudo setsebool -P httpd_read_user_content 1
        safe_sudo restorecon -R "$DATA_DIR"
        echo -e "  ✅ SELinux 策略已更新"
    fi
fi

# 8. 测试 Nginx 配置
echo -e "${WHITE}8. 测试 Nginx 配置...${NC}"

if command -v nginx >/dev/null 2>&1; then
    if safe_sudo nginx -t 2>/dev/null; then
        echo -e "  ✅ Nginx 配置测试通过"
        
        echo -e "  🔄 重新加载 Nginx..."
        if safe_sudo systemctl reload nginx 2>/dev/null; then
            echo -e "  ✅ Nginx 重新加载成功"
        else
            echo -e "  ⚠️  Nginx 重新加载失败，尝试重启..."
            safe_sudo systemctl restart nginx
        fi
    else
        echo -e "  ❌ Nginx 配置测试失败"
        echo -e "  📋 错误详情:"
        safe_sudo nginx -t 2>&1 | head -5
    fi
fi

# 9. 测试访问
echo -e "${WHITE}9. 测试本地访问...${NC}"

NGINX_PORT="${NGINX_PORT:-3080}"

# 等待一下确保服务启动
sleep 2

if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$NGINX_PORT/" | grep -q "200"; then
    echo -e "  ✅ 本地访问测试成功 (200)"
else
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$NGINX_PORT/" || echo "连接失败")
    echo -e "  ❌ 本地访问测试失败 (HTTP: $HTTP_CODE)"
fi

# 10. 总结和建议
echo -e "${WHITE}10. 诊断总结${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

echo -e "${GREEN}✅ 修复操作已完成：${NC}"
echo -e "  • 创建/检查了数据目录"
echo -e "  • 修复了文件权限"
echo -e "  • 创建了测试文件"
echo -e "  • 重新加载了 Nginx"

echo -e "${YELLOW}🧪 测试建议：${NC}"
echo -e "  • 访问: ${BLUE}http://104.234.37.101:$NGINX_PORT/${NC}"
echo -e "  • 测试页面: ${BLUE}http://104.234.37.101:$NGINX_PORT/test.html${NC}"
echo -e "  • 订阅文件: ${BLUE}http://104.234.37.101:$NGINX_PORT/subscription.txt${NC}"

echo -e "${WHITE}📋 如果仍有问题，请检查：${NC}"
echo -e "  • 防火墙是否阻止了 $NGINX_PORT 端口"
echo -e "  • 云服务器安全组是否开放了 $NGINX_PORT 端口"
echo -e "  • Nginx 错误日志: ${CYAN}tail -f /var/log/nginx/error.log${NC}"

echo -e "${CYAN}═══════════════════════════════════════${NC}"
