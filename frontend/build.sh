#!/bin/bash

# 前端 Dashboard 构建脚本

set -e

# 获取脚本所在目录和项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$SCRIPT_DIR"
PROJECT_ROOT="$(dirname "$FRONTEND_DIR")"

# 引入公共函数库
source "$PROJECT_ROOT/scripts/common.sh"

print_status "info" "开始构建前端 Dashboard..."
print_status "info" "工作目录: $FRONTEND_DIR"

# 检查 Node.js 和包管理器
if ! command_exists node; then
    print_status "error" "未找到 Node.js"
    echo "请先安装 Node.js: https://nodejs.org/"
    exit 1
fi

# 检查 Bun
BUN_CMD=$(detect_bun)
if [ -z "$BUN_CMD" ]; then
    print_status "error" "未找到 bun"
    echo "请先运行安装脚本来自动安装 bun: bash scripts/install.sh"
    echo "或手动安装 bun: https://bun.sh/"
    exit 1
fi

print_status "success" "使用 bun: $($BUN_CMD --version)"

# 切换到前端目录
cd "$FRONTEND_DIR"

# 安装依赖
print_status "info" "安装依赖..."
"$BUN_CMD" install

print_status "success" "依赖安装完成"

# 构建项目
print_status "info" "构建项目..."
"$BUN_CMD" run build

print_status "success" "构建完成"

# 检查构建输出
if [ -d "dist" ]; then
    print_status "success" "构建文件已生成在 dist/ 目录"
    
    # 显示构建文件大小
    echo -e "${YELLOW}📊 构建文件大小:${NC}"
    du -sh dist/
    
    # 列出主要文件
    echo -e "${YELLOW}📁 主要文件:${NC}"
    find dist -name "*.html" -o -name "*.css" -o -name "*.js" | head -10
    
else
    print_status "error" "构建文件未生成"
    exit 1
fi

print_status "success" "前端 Dashboard 构建完成！"
echo ""
echo -e "${YELLOW}📋 下一步:${NC}"
echo "1. 配置 Nginx 以服务静态文件"
echo "2. 将 dist/ 目录内容部署到 Web 服务器"
echo "3. 确保 API 服务正在运行以提供后端接口"
echo ""
echo -e "${YELLOW}💡 本地预览:${NC}"
echo "cd $FRONTEND_DIR && $BUN_CMD run start"
