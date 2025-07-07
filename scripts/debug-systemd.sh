#!/bin/bash

# systemd 调试脚本
# 用于诊断 systemd 配置问题

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 引入公共函数库
source "$SCRIPT_DIR/common.sh"

echo "=== systemd 配置调试脚本 ==="
echo "调试时间: $(date)"
echo ""

# 检查操作系统
OS=$(detect_os)
echo "操作系统: $OS"

if [ "$OS" != "Linux" ]; then
    echo "错误: 此脚本仅适用于 Linux 系统"
    exit 1
fi

# 设置环境变量
setup_default_env

echo "=== 环境变量设置 ==="
echo "PROJECT_ROOT: $PROJECT_ROOT"
echo "BASE_DIR: $BASE_DIR"
echo "DIST_DIR: $DIST_DIR"
echo "DATA_DIR: $DATA_DIR"
echo "LOG_DIR: $LOG_DIR"
echo ""

# 获取用户信息
CURRENT_USER=$(whoami)
if [[ $EUID -eq 0 ]]; then
    if [ -n "$SUDO_USER" ]; then
        TARGET_USER="$SUDO_USER"
        TARGET_GROUP="$(id -gn $SUDO_USER)"
    else
        TARGET_USER="root"
        TARGET_GROUP="root"
    fi
else
    TARGET_USER="$CURRENT_USER"
    TARGET_GROUP="$(id -gn $CURRENT_USER)"
fi

echo "=== 用户信息 ==="
echo "当前用户: $CURRENT_USER"
echo "目标用户: $TARGET_USER"
echo "目标组: $TARGET_GROUP"
echo "用户ID: $(id)"
echo ""

# 检查必需的目录和文件
echo "=== 检查必需文件和目录 ==="

echo "项目目录: $PROJECT_ROOT"
[ -d "$PROJECT_ROOT" ] && echo "✅ 项目目录存在" || echo "❌ 项目目录不存在"

echo "BASE_DIR: $BASE_DIR"
[ -d "$BASE_DIR" ] && echo "✅ BASE_DIR 存在" || echo "❌ BASE_DIR 不存在"

echo "DIST_DIR: $DIST_DIR"
[ -d "$DIST_DIR" ] && echo "✅ DIST_DIR 存在" || echo "❌ DIST_DIR 不存在"

echo "后端构建文件: $DIST_DIR/backend/index.js"
[ -f "$DIST_DIR/backend/index.js" ] && echo "✅ 后端构建文件存在" || echo "❌ 后端构建文件不存在"

echo "配置文件: $BASE_DIR/config.yaml"
[ -f "$BASE_DIR/config.yaml" ] && echo "✅ 配置文件存在" || echo "❌ 配置文件不存在"

echo "服务模板: $PROJECT_ROOT/config/subscription-api-ts.service.template"
[ -f "$PROJECT_ROOT/config/subscription-api-ts.service.template" ] && echo "✅ 服务模板存在" || echo "❌ 服务模板不存在"

echo ""

# 检查系统工具
echo "=== 检查系统工具 ==="

if command -v systemctl >/dev/null 2>&1; then
    echo "✅ systemctl 可用"
    echo "systemd 版本: $(systemctl --version | head -1)"
else
    echo "❌ systemctl 不可用"
fi

if command -v journalctl >/dev/null 2>&1; then
    echo "✅ journalctl 可用"
else
    echo "❌ journalctl 不可用"
fi

if command -v envsubst >/dev/null 2>&1; then
    echo "✅ envsubst 可用"
else
    echo "❌ envsubst 不可用"
    echo "安装命令: sudo apt-get install gettext-base"
fi

if command -v node >/dev/null 2>&1; then
    echo "✅ Node.js 可用"
    NODE_PATH="$(which node)"
    echo "Node.js 路径: $NODE_PATH"
    echo "Node.js 版本: $(node --version)"
else
    echo "❌ Node.js 不可用"
    NODE_PATH=""
fi

echo ""

# 检查权限
echo "=== 检查权限 ==="

echo "当前用户权限:"
id

echo ""
echo "systemd 目录权限:"
ls -ld /etc/systemd/system/ 2>/dev/null || echo "无法访问 /etc/systemd/system/"

echo ""
echo "项目目录权限:"
ls -ld "$PROJECT_ROOT"

echo ""
echo "BASE_DIR 权限:"
ls -ld "$BASE_DIR" 2>/dev/null || echo "BASE_DIR 不存在"

echo ""

# 检查现有服务
echo "=== 检查现有服务 ==="
SERVICE_NAME="subscription-api-ts"

if systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
    echo "✅ 服务已注册"
    echo "服务状态:"
    systemctl status "$SERVICE_NAME" --no-pager || true
else
    echo "❌ 服务未注册"
fi

echo ""

# 尝试生成服务文件
echo "=== 尝试生成服务文件 ==="

if [ -f "$PROJECT_ROOT/config/subscription-api-ts.service.template" ]; then
    export SERVICE_USER="$TARGET_USER"
    export SERVICE_GROUP="$TARGET_GROUP"
    export INSTALL_DIR="$PROJECT_ROOT"
    export NODE_PATH="$(which node 2>/dev/null || echo 'NOT_FOUND')"
    export DATA_DIR
    export LOG_DIR
    export DIST_DIR
    export BASE_DIR
    export BUN_PATH="${BUN_PATH:-$BASE_DIR/bin/bun}"
    
    echo "服务配置变量:"
    echo "  SERVICE_USER: $SERVICE_USER"
    echo "  SERVICE_GROUP: $SERVICE_GROUP"
    echo "  INSTALL_DIR: $INSTALL_DIR"
    echo "  NODE_PATH: $NODE_PATH"
    echo "  DATA_DIR: $DATA_DIR"
    echo "  LOG_DIR: $LOG_DIR"
    echo "  DIST_DIR: $DIST_DIR"
    echo "  BASE_DIR: $BASE_DIR"
    echo "  BUN_PATH: $BUN_PATH"
    echo ""
    
    # 检查关键路径
    echo "=== 检查关键路径 ==="
    echo "检查 Node.js 路径:"
    if [ "$NODE_PATH" != "NOT_FOUND" ] && [ -f "$NODE_PATH" ]; then
        echo "  ✅ Node.js 可执行文件存在: $NODE_PATH"
        echo "  版本: $($NODE_PATH --version)"
    else
        echo "  ❌ Node.js 不可用"
    fi
    
    echo "检查 Bun 路径:"
    if [ -f "$BUN_PATH" ]; then
        echo "  ✅ Bun 可执行文件存在: $BUN_PATH"
        echo "  版本: $($BUN_PATH --version 2>/dev/null || echo '无法获取版本')"
    else
        echo "  ❌ Bun 不存在: $BUN_PATH"
    fi
    
    echo "检查构建文件:"
    if [ -f "$DIST_DIR/backend/index.js" ]; then
        echo "  ✅ 后端构建文件存在: $DIST_DIR/backend/index.js"
    else
        echo "  ❌ 后端构建文件不存在: $DIST_DIR/backend/index.js"
    fi
    echo ""
    
    local service_output="/tmp/${SERVICE_NAME}-debug.service"
    
    echo "=== 生成服务文件 ==="
    if command -v envsubst >/dev/null 2>&1; then
        echo "正在生成服务文件..."
        if envsubst '${SERVICE_USER} ${SERVICE_GROUP} ${INSTALL_DIR} ${NODE_PATH} ${DATA_DIR} ${LOG_DIR} ${DIST_DIR} ${BASE_DIR} ${BUN_PATH}' < "$PROJECT_ROOT/config/subscription-api-ts.service.template" > "$service_output" 2>/dev/null; then
            echo "✅ 服务文件生成成功: $service_output"
            echo ""
            echo "生成的服务文件内容:"
            echo "========================"
            cat "$service_output"
            echo "========================"
            echo ""
            
            # 验证服务文件语法
            echo "=== 验证服务文件语法 ==="
            if systemd-analyze verify "$service_output" 2>/dev/null; then
                echo "✅ 服务文件语法验证通过"
            else
                echo "❌ 服务文件语法验证失败:"
                systemd-analyze verify "$service_output" 2>&1 || true
            fi
        else
            echo "❌ 服务文件生成失败"
            echo "错误信息:"
            envsubst '${SERVICE_USER} ${SERVICE_GROUP} ${INSTALL_DIR} ${NODE_PATH} ${DATA_DIR} ${LOG_DIR} ${DIST_DIR} ${BASE_DIR} ${BUN_PATH}' < "$PROJECT_ROOT/config/subscription-api-ts.service.template" 2>&1 || true
        fi
    else
        echo "❌ envsubst 不可用，无法生成服务文件"
    fi
else
    echo "❌ 服务模板文件不存在"
fi

echo ""
echo "=== 调试完成 ==="
echo ""

# 提供修复建议
echo "=== 修复建议 ==="
echo ""

# 检查缺失的依赖
missing_deps=()
if ! command -v systemctl >/dev/null 2>&1; then
    missing_deps+=("systemctl")
fi
if ! command -v journalctl >/dev/null 2>&1; then
    missing_deps+=("journalctl")
fi
if ! command -v envsubst >/dev/null 2>&1; then
    missing_deps+=("envsubst (gettext-base)")
fi
if ! command -v node >/dev/null 2>&1; then
    missing_deps+=("node")
fi

if [ ${#missing_deps[@]} -gt 0 ]; then
    echo "❌ 缺失的依赖: ${missing_deps[*]}"
    echo "修复命令:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install -y systemd gettext-base nodejs"
    echo ""
fi

# 检查文件问题
if [ ! -f "$BASE_DIR/config.yaml" ]; then
    echo "❌ 配置文件不存在"
    echo "修复命令:"
    echo "  bash scripts/install.sh"
    echo ""
fi

if [ ! -f "$DIST_DIR/backend/index.js" ]; then
    echo "❌ 后端构建文件不存在"
    echo "修复命令:"
    echo "  bash scripts/build-all.sh"
    echo ""
fi

# 检查权限问题
if [ ! -w "/etc/systemd/system" ]; then
    echo "❌ 没有 systemd 目录写权限"
    echo "请确保以 root 用户运行或使用 sudo"
    echo ""
fi

echo "如果发现问题，请根据上述建议修复后重新运行:"
echo "  ./manage.sh install"
echo "或者单独运行 systemd 配置:"
echo "  sudo bash scripts/setup-systemd.sh"
echo ""

echo "=== 手动调试命令 ==="
echo "查看服务状态:"
echo "  sudo systemctl status subscription-api-ts"
echo "查看服务日志:"
echo "  sudo journalctl -u subscription-api-ts -f"
echo "验证生成的服务文件:"
echo "  systemd-analyze verify /tmp/subscription-api-ts-debug.service"
