#!/bin/bash

# Dashboard 集成部署脚本

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎨 Dashboard 集成部署${NC}"
echo "================================"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
FRONTEND_DIR="$PROJECT_ROOT/frontend"

# 读取环境变量
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# 设置默认值
NGINX_PROXY_PORT="${NGINX_PROXY_PORT:-3888}"
API_PORT="${PORT:-3000}"
DATA_DIR="${STATIC_DIR:-./data}"

echo -e "${YELLOW}📋 配置信息:${NC}"
echo "   项目根目录: $PROJECT_ROOT"
echo "   前端目录: $FRONTEND_DIR"
echo "   API 端口: $API_PORT"
echo "   Nginx 代理端口: $NGINX_PROXY_PORT"
echo "   数据目录: $DATA_DIR"
echo ""

# 1. 构建前端
echo -e "${YELLOW}🏗️  步骤 1: 构建前端 Dashboard${NC}"

if [ ! -d "$FRONTEND_DIR" ]; then
    echo -e "${RED}❌ 错误: 前端目录不存在: $FRONTEND_DIR${NC}"
    exit 1
fi

cd "$FRONTEND_DIR"

# 检查 package.json
if [ ! -f "package.json" ]; then
    echo -e "${RED}❌ 错误: package.json 不存在${NC}"
    exit 1
fi

# 安装依赖
echo -e "${YELLOW}📦 安装前端依赖...${NC}"
if command -v npm >/dev/null 2>&1; then
    npm install
elif command -v yarn >/dev/null 2>&1; then
    yarn install
else
    echo -e "${RED}❌ 错误: 未找到 npm 或 yarn${NC}"
    exit 1
fi

# 构建
echo -e "${YELLOW}🔨 构建前端...${NC}"
npm run build

if [ ! -d "dist" ]; then
    echo -e "${RED}❌ 错误: 前端构建失败，dist 目录不存在${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 前端构建完成${NC}"

# 2. 编译后端
echo -e "${YELLOW}🏗️  步骤 2: 编译后端 TypeScript${NC}"

cd "$PROJECT_ROOT"

if [ -f "package.json" ] && [ -f "tsconfig.json" ]; then
    echo -e "${YELLOW}📦 安装后端依赖...${NC}"
    npm install
    
    echo -e "${YELLOW}🔨 编译 TypeScript...${NC}"
    npm run build
    
    if [ ! -d "dist" ]; then
        echo -e "${RED}❌ 错误: 后端编译失败，dist 目录不存在${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 后端编译完成${NC}"
else
    echo -e "${YELLOW}⚠️  跳过后端编译 (package.json 或 tsconfig.json 不存在)${NC}"
fi

# 3. 更新 Nginx 配置
echo -e "${YELLOW}🌐 步骤 3: 更新 Nginx 配置${NC}"

NGINX_CONF_TEMPLATE="$PROJECT_ROOT/config/nginx.conf.template"
NGINX_CONF="$PROJECT_ROOT/config/nginx.conf"

if [ -f "$NGINX_CONF_TEMPLATE" ]; then
    echo -e "${YELLOW}📝 生成 Nginx 配置...${NC}"
    
    # 替换模板中的变量
    sed -e "s|\${NGINX_PROXY_PORT}|$NGINX_PROXY_PORT|g" \
        -e "s|\${API_PORT}|$API_PORT|g" \
        -e "s|\${DATA_DIR}|$DATA_DIR|g" \
        -e "s|\${PROJECT_ROOT}|$PROJECT_ROOT|g" \
        "$NGINX_CONF_TEMPLATE" > "$NGINX_CONF"
    
    echo -e "${GREEN}✅ Nginx 配置已生成: $NGINX_CONF${NC}"
else
    echo -e "${YELLOW}⚠️  Nginx 配置模板不存在，跳过配置生成${NC}"
fi

# 4. 创建系统服务文件 (如果在 Linux 上)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo -e "${YELLOW}⚙️  步骤 4: 准备系统服务${NC}"
    
    SERVICE_TEMPLATE="$PROJECT_ROOT/config/subscription-api-ts.service.template"
    SERVICE_FILE="$PROJECT_ROOT/config/subscription-api-ts.service"
    
    if [ -f "$SERVICE_TEMPLATE" ]; then
        sed -e "s|\${PROJECT_ROOT}|$PROJECT_ROOT|g" \
            -e "s|\${USER}|$(whoami)|g" \
            "$SERVICE_TEMPLATE" > "$SERVICE_FILE"
        
        echo -e "${GREEN}✅ 系统服务文件已生成: $SERVICE_FILE${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  非 Linux 系统，跳过系统服务配置${NC}"
fi

# 5. 显示部署说明
echo ""
echo -e "${GREEN}🎉 Dashboard 集成构建完成！${NC}"
echo "================================"
echo ""
echo -e "${YELLOW}📋 后续部署步骤:${NC}"
echo ""

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo -e "${BLUE}1. 部署 Nginx 配置:${NC}"
    echo "   sudo cp $NGINX_CONF /etc/nginx/sites-available/subscription-api-ts"
    echo "   sudo ln -sf /etc/nginx/sites-available/subscription-api-ts /etc/nginx/sites-enabled/"
    echo "   sudo nginx -t"
    echo "   sudo systemctl reload nginx"
    echo ""
    
    echo -e "${BLUE}2. 安装系统服务:${NC}"
    echo "   sudo cp $SERVICE_FILE /etc/systemd/system/"
    echo "   sudo systemctl daemon-reload"
    echo "   sudo systemctl enable subscription-api-ts"
    echo "   sudo systemctl start subscription-api-ts"
    echo ""
    
    echo -e "${BLUE}3. 访问 Dashboard:${NC}"
    echo "   http://localhost:$NGINX_PROXY_PORT/dashboard/"
    echo ""
else
    echo -e "${BLUE}1. 启动 API 服务:${NC}"
    echo "   cd $PROJECT_ROOT"
    echo "   npm start"
    echo ""
    
    echo -e "${BLUE}2. 配置 Web 服务器:${NC}"
    echo "   - 将 $FRONTEND_DIR/dist/ 内容部署到 Web 服务器"
    echo "   - 配置反向代理到 API 服务端口 $API_PORT"
    echo "   - 参考 $NGINX_CONF 配置"
    echo ""
    
    echo -e "${BLUE}3. 本地开发访问:${NC}"
    echo "   - API: http://localhost:$API_PORT"
    echo "   - Dashboard: 需要配置 Web 服务器"
    echo ""
fi

echo -e "${YELLOW}🔧 验证部署:${NC}"
echo "   curl http://localhost:$NGINX_PROXY_PORT/health"
echo "   curl http://localhost:$NGINX_PROXY_PORT/api/status"
echo ""

echo -e "${GREEN}✨ 完成！${NC}"
