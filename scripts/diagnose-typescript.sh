#!/bin/bash

# TypeScript 类型检查和诊断脚本
echo "=== TypeScript 诊断工具 ==="

# 获取项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "📁 项目目录: $PROJECT_ROOT"
echo ""

# 检查 Node.js 和 npm 版本
echo "🔍 环境检查:"
echo "Node.js: $(node --version)"
echo "npm: $(npm --version)"
echo ""

# 检查关键依赖
echo "🔍 检查关键依赖:"
DEPS_TO_CHECK=(
    "typescript"
    "@types/node"
    "@types/express"
    "@types/cors"
    "@types/compression"
    "@types/node-cron"
    "@types/fs-extra"
)

ALL_DEPS_OK=true
for dep in "${DEPS_TO_CHECK[@]}"; do
    if [ -d "node_modules/$dep" ]; then
        VERSION=$(cat "node_modules/$dep/package.json" | grep '"version"' | cut -d'"' -f4)
        echo "✅ $dep: $VERSION"
    else
        echo "❌ $dep: 缺失"
        ALL_DEPS_OK=false
    fi
done

echo ""

if [ "$ALL_DEPS_OK" = false ]; then
    echo "🔧 重新安装缺失的依赖..."
    npm install
    echo ""
fi

# 检查 TypeScript 配置
echo "🔍 TypeScript 配置检查:"
if [ -f "tsconfig.json" ]; then
    echo "✅ tsconfig.json 存在"
    
    # 验证 TypeScript 编译器
    if [ -f "node_modules/.bin/tsc" ]; then
        echo "✅ 本地 TypeScript 编译器可用"
        echo "   版本: $(./node_modules/.bin/tsc --version)"
    else
        echo "❌ 本地 TypeScript 编译器不可用"
    fi
    
    # 检查配置文件语法
    echo "🔍 验证 tsconfig.json 语法..."
    if node -e "JSON.parse(require('fs').readFileSync('tsconfig.json', 'utf8').replace(/\/\*.*?\*\//g, '').replace(/\/\/.*$/gm, ''))" 2>/dev/null; then
        echo "✅ tsconfig.json 语法正确"
    else
        echo "❌ tsconfig.json 语法错误"
    fi
else
    echo "❌ tsconfig.json 不存在"
fi

echo ""

# 检查源代码结构
echo "🔍 源代码结构检查:"
if [ -d "src" ]; then
    echo "✅ src 目录存在"
    echo "   文件数量: $(find src -name "*.ts" | wc -l)"
    
    # 检查关键文件
    KEY_FILES=("src/index.ts" "src/app.ts" "src/config/index.ts")
    for file in "${KEY_FILES[@]}"; do
        if [ -f "$file" ]; then
            echo "✅ $file"
        else
            echo "❌ $file"
        fi
    done
else
    echo "❌ src 目录不存在"
fi

echo ""

# 尝试类型检查
echo "🔍 TypeScript 类型检查:"
if [ -f "node_modules/.bin/tsc" ]; then
    echo "执行类型检查 (不输出文件)..."
    if ./node_modules/.bin/tsc --noEmit --project . 2>&1; then
        echo "✅ 类型检查通过"
    else
        echo "❌ 类型检查失败"
        echo ""
        echo "🔧 尝试解决方案:"
        echo "1. 清理 node_modules 并重新安装:"
        echo "   rm -rf node_modules package-lock.json"
        echo "   npm install"
        echo ""
        echo "2. 强制重新安装类型定义:"
        echo "   npm install --save-dev @types/node @types/express @types/cors"
        echo ""
        echo "3. 清理构建缓存:"
        echo "   rm -rf dist"
        echo "   npm run build"
    fi
else
    echo "❌ TypeScript 编译器不可用"
fi

echo ""
echo "💡 如果问题持续存在，请运行:"
echo "   bash scripts/fix-typescript.sh"
