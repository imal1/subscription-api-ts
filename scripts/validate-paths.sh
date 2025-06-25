#!/bin/bash

# 路径验证脚本
echo "=== 路径配置验证 ==="

# 获取项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# 读取环境变量
if [ -f ".env" ]; then
    echo "✅ 找到 .env 文件"
    # 读取 .env 文件，忽略注释和空行
    while IFS='=' read -r key value; do
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z $key ]] && continue
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        export "$key"="$value"
    done < <(grep -v '^[[:space:]]*#' .env | grep -v '^[[:space:]]*$')
else
    echo "❌ 未找到 .env 文件，使用默认配置"
fi

# 设置默认值
DATA_DIR="${DATA_DIR:-./data}"
LOG_DIR="${LOG_DIR:-./logs}"
BACKUP_DIR="${BACKUP_DIR:-./data/backup}"

echo ""
echo "📁 当前路径配置:"
echo "   项目根目录: $PROJECT_ROOT"
echo "   数据目录: $DATA_DIR"
echo "   日志目录: $LOG_DIR"
echo "   备份目录: $BACKUP_DIR"
echo ""

# 检查目录是否存在
echo "🔍 检查目录状态:"

check_directory() {
    local dir="$1"
    local name="$2"
    
    if [ -d "$dir" ]; then
        echo "   ✅ $name: $dir (存在)"
        echo "      权限: $(ls -ld "$dir" | awk '{print $1, $3, $4}')"
    else
        echo "   ❌ $name: $dir (不存在)"
        echo "      建议: mkdir -p \"$dir\""
    fi
}

check_directory "$DATA_DIR" "数据目录"
check_directory "$LOG_DIR" "日志目录"
check_directory "$BACKUP_DIR" "备份目录"

echo ""
echo "🔧 TypeScript 编译配置检查:"

if [ -f "tsconfig.json" ]; then
    echo "   ✅ tsconfig.json 存在"
    
    # 检查输出目录
    OUT_DIR=$(node -e "const ts = require('./tsconfig.json'); console.log(ts.compilerOptions.outDir || './dist')")
    if [ -d "$OUT_DIR" ]; then
        echo "   ✅ 输出目录存在: $OUT_DIR"
    else
        echo "   ⚠️  输出目录不存在: $OUT_DIR (运行 npm run build 创建)"
    fi
    
    # 检查源目录
    ROOT_DIR=$(node -e "const ts = require('./tsconfig.json'); console.log(ts.compilerOptions.rootDir || './src')")
    if [ -d "$ROOT_DIR" ]; then
        echo "   ✅ 源代码目录存在: $ROOT_DIR"
    else
        echo "   ❌ 源代码目录不存在: $ROOT_DIR"
    fi
else
    echo "   ❌ tsconfig.json 不存在"
fi

echo ""
echo "📦 依赖检查:"

if [ -d "node_modules" ]; then
    echo "   ✅ node_modules 存在"
else
    echo "   ❌ node_modules 不存在，运行: npm install"
fi

if [ -f "package-lock.json" ] || [ -f "yarn.lock" ] || [ -f "bun.lock" ]; then
    echo "   ✅ 锁文件存在"
else
    echo "   ⚠️  未找到锁文件"
fi

echo ""
echo "🎯 建议的修复命令:"
echo "   # 创建缺失目录"
echo "   mkdir -p \"$DATA_DIR\" \"$LOG_DIR\" \"$BACKUP_DIR\""
echo "   # 安装依赖"
echo "   npm install"
echo "   # 编译项目"
echo "   npm run build"
echo "   # 验证环境变量"
echo "   npm run config:validate"
