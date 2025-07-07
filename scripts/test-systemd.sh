#!/bin/bash

# 简化的 systemd 测试脚本
# 只生成服务文件，不安装，用于快速测试

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/common.sh"

echo "=== systemd 配置测试 ==="
echo ""

# 检查操作系统
OS=$(detect_os)
if [ "$OS" != "Linux" ]; then
    echo "错误: 此脚本仅适用于 Linux 系统"
    exit 1
fi

# 设置环境变量
setup_default_env

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

echo "用户信息:"
echo "  当前用户: $CURRENT_USER"
echo "  目标用户: $TARGET_USER"
echo "  目标组: $TARGET_GROUP"
echo ""

# 检查必需文件
echo "检查必需文件:"
echo "  项目目录: $PROJECT_ROOT"
echo "  配置文件: $BASE_DIR/config.yaml"
echo "  构建文件: $DIST_DIR/backend/index.js"
echo "  服务模板: $PROJECT_ROOT/config/subscription-api-ts.service.template"
echo ""

# 检查 Node.js
if command -v node >/dev/null 2>&1; then
    NODE_PATH="$(which node)"
    echo "Node.js: $NODE_PATH ($(node --version))"
else
    echo "❌ Node.js 不可用"
    exit 1
fi

# 检查 Bun
if [ -f "$BASE_DIR/bin/bun" ]; then
    BUN_PATH="$BASE_DIR/bin/bun"
    echo "Bun: $BUN_PATH"
else
    echo "❌ Bun 不可用: $BASE_DIR/bin/bun"
    exit 1
fi

# 检查 envsubst
if ! command -v envsubst >/dev/null 2>&1; then
    echo "❌ envsubst 不可用，正在安装..."
    sudo apt-get update && sudo apt-get install -y gettext-base
fi

echo ""
echo "=== 生成服务文件 ==="

# 设置环境变量
export SERVICE_USER="$TARGET_USER"
export SERVICE_GROUP="$TARGET_GROUP"
export INSTALL_DIR="$PROJECT_ROOT"
export NODE_PATH
export DATA_DIR
export LOG_DIR
export DIST_DIR
export BASE_DIR
export BUN_PATH

# 生成服务文件
service_output="/tmp/subscription-api-ts-test.service"
if envsubst '${SERVICE_USER} ${SERVICE_GROUP} ${INSTALL_DIR} ${NODE_PATH} ${DATA_DIR} ${LOG_DIR} ${DIST_DIR} ${BASE_DIR} ${BUN_PATH}' < "$PROJECT_ROOT/config/subscription-api-ts.service.template" > "$service_output"; then
    echo "✅ 服务文件生成成功: $service_output"
    echo ""
    echo "生成的服务文件内容:"
    echo "========================"
    cat "$service_output"
    echo "========================"
    echo ""
    
    # 验证服务文件
    if systemd-analyze verify "$service_output" 2>/dev/null; then
        echo "✅ 服务文件验证通过"
    else
        echo "❌ 服务文件验证失败:"
        systemd-analyze verify "$service_output" 2>&1 || true
    fi
else
    echo "❌ 服务文件生成失败"
    exit 1
fi

echo ""
echo "=== 测试完成 ==="
echo "如果测试通过，可以运行完整安装:"
echo "  ./manage.sh install"
echo "或者单独配置 systemd:"
echo "  sudo bash scripts/setup-systemd.sh"
