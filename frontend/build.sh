#!/bin/bash

# 前端 Dashboard 构建脚本

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 开始构建前端 Dashboard...${NC}"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$SCRIPT_DIR"
PROJECT_ROOT="$(dirname "$FRONTEND_DIR")"

echo -e "${YELLOW}📂 工作目录: $FRONTEND_DIR${NC}"

# 检查 Node.js 和 npm
if ! command -v node >/dev/null 2>&1; then
    echo -e "${RED}❌ 错误: 未找到 Node.js${NC}"
    echo "请先安装 Node.js: https://nodejs.org/"
    exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
    echo -e "${RED}❌ 错误: 未找到 npm${NC}"
    echo "请先安装 npm (通常随 Node.js 一起安装)"
    exit 1
fi

echo -e "${GREEN}✅ Node.js 版本: $(node --version)${NC}"
echo -e "${GREEN}✅ npm 版本: $(npm --version)${NC}"

# 切换到前端目录
cd "$FRONTEND_DIR"

# 安装依赖
echo -e "${YELLOW}📦 安装依赖...${NC}"
if [ -f "package-lock.json" ]; then
    npm ci
else
    npm install
fi

echo -e "${GREEN}✅ 依赖安装完成${NC}"

# 构建项目
echo -e "${YELLOW}🏗️  构建项目...${NC}"
npm run build

echo -e "${GREEN}✅ 构建完成${NC}"

# 检查构建输出
if [ -d "dist" ]; then
    echo -e "${GREEN}✅ 构建文件已生成在 dist/ 目录${NC}"
    
    # 显示构建文件大小
    echo -e "${YELLOW}📊 构建文件大小:${NC}"
    du -sh dist/
    
    # 列出主要文件
    echo -e "${YELLOW}📁 主要文件:${NC}"
    find dist -name "*.html" -o -name "*.css" -o -name "*.js" | head -10
    
else
    echo -e "${RED}❌ 错误: 构建文件未生成${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 前端 Dashboard 构建完成！${NC}"
echo ""
echo -e "${YELLOW}📋 下一步:${NC}"
echo "1. 配置 Nginx 以服务静态文件"
echo "2. 将 dist/ 目录内容部署到 Web 服务器"
echo "3. 确保 API 服务正在运行以提供后端接口"
echo ""
echo -e "${YELLOW}💡 本地预览:${NC}"
echo "cd $FRONTEND_DIR && npm run start"
