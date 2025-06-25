#!/bin/bash

# TypeScript 问题修复脚本
echo "=== TypeScript 问题修复 ==="

# 获取项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "📁 项目目录: $PROJECT_ROOT"
echo ""

# 备份当前配置
echo "📋 备份当前配置..."
if [ -f "package-lock.json" ]; then
    cp package-lock.json package-lock.json.backup
    echo "✅ 已备份 package-lock.json"
fi

# 1. 清理环境
echo "🧹 清理环境..."
rm -rf node_modules
rm -rf dist
rm -f package-lock.json
echo "✅ 已清理 node_modules, dist, package-lock.json"

# 2. 重新安装依赖
echo "📦 重新安装依赖..."
npm cache clean --force
npm install

# 3. 验证关键依赖
echo "🔍 验证关键依赖..."
CRITICAL_DEPS=(
    "@types/node"
    "@types/express" 
    "@types/cors"
    "@types/compression"
    "@types/node-cron"
    "@types/fs-extra"
    "typescript"
    "ts-node"
)

MISSING_DEPS=""
for dep in "${CRITICAL_DEPS[@]}"; do
    if ! npm ls "$dep" >/dev/null 2>&1; then
        MISSING_DEPS="$MISSING_DEPS $dep"
    fi
done

if [ -n "$MISSING_DEPS" ]; then
    echo "🔧 安装缺失的依赖:$MISSING_DEPS"
    npm install $MISSING_DEPS
fi

# 4. 强制重新安装类型定义
echo "🔧 强制重新安装类型定义..."
npm install --save-dev @types/node@latest @types/express@latest @types/cors@latest @types/compression@latest @types/node-cron@latest @types/fs-extra@latest

# 5. 验证 TypeScript 配置
echo "🔍 验证 TypeScript 配置..."
if ! node -e "
const fs = require('fs');
const config = fs.readFileSync('tsconfig.json', 'utf8');
const cleanConfig = config.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
JSON.parse(cleanConfig);
console.log('✅ tsconfig.json 语法正确');
" 2>/dev/null; then
    echo "❌ tsconfig.json 语法错误，尝试修复..."
    
    # 备份并创建简化版本
    cp tsconfig.json tsconfig.json.backup
    cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "types": ["node"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true,
    "moduleResolution": "node",
    "allowSyntheticDefaultImports": true,
    "baseUrl": "./src",
    "paths": {
      "@/*": ["*"],
      "@/types/*": ["types/*"],
      "@/services/*": ["services/*"],
      "@/controllers/*": ["controllers/*"],
      "@/utils/*": ["utils/*"],
      "@/config/*": ["config/*"],
      "@/routes/*": ["routes/*"]
    }
  },
  "include": [
    "src/**/*"
  ],
  "exclude": [
    "node_modules",
    "dist",
    "**/*.test.ts"
  ],
  "ts-node": {
    "require": ["tsconfig-paths/register"]
  }
}
EOF
    echo "✅ 已创建修复版本的 tsconfig.json"
fi

# 6. 测试编译
echo "🔧 测试 TypeScript 编译..."
if npx tsc --noEmit; then
    echo "✅ TypeScript 类型检查通过"
    
    # 尝试完整构建
    echo "🏗️ 执行完整构建..."
    if npm run build; then
        echo "✅ 构建成功！"
        
        # 验证输出
        if [ -f "dist/index.js" ]; then
            echo "✅ 输出文件正确生成"
        else
            echo "⚠️ 构建完成但未找到输出文件"
        fi
    else
        echo "❌ 构建失败"
        exit 1
    fi
else
    echo "❌ TypeScript 类型检查失败"
    echo ""
    echo "📋 常见解决方案:"
    echo "1. 检查是否有语法错误"
    echo "2. 确保所有导入路径正确"
    echo "3. 验证环境变量配置"
    echo ""
    echo "请检查上面的错误信息并手动修复。"
    exit 1
fi

echo ""
echo "🎉 TypeScript 问题修复完成！"
echo ""
echo "📋 修复总结:"
echo "✅ 清理了旧的依赖和构建文件"
echo "✅ 重新安装了所有依赖"
echo "✅ 验证了类型定义"
echo "✅ 修复了 TypeScript 配置"
echo "✅ 成功完成构建"
