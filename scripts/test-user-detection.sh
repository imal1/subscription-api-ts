#!/bin/bash

# 测试用户权限检测逻辑
echo "=== 用户权限检测测试 ==="

# 模拟检测逻辑
CURRENT_USER=$(whoami)
echo "当前用户: $CURRENT_USER"
echo "EUID: $EUID"
echo "SUDO_USER: ${SUDO_USER:-"未设置"}"

if [[ $EUID -eq 0 ]]; then
    echo "✅ 检测到 root 用户"
    if [ -z "$SUDO_USER" ]; then
        echo "⚠️  直接以 root 登录"
        TARGET_USER="root"
        TARGET_GROUP="root"
    else
        echo "✅ 通过 sudo 执行"
        TARGET_USER="$SUDO_USER"
        TARGET_GROUP="$(id -gn $SUDO_USER 2>/dev/null || echo "users")"
    fi
else
    echo "✅ 普通用户执行"
    TARGET_USER="$CURRENT_USER"
    TARGET_GROUP="$(id -gn $CURRENT_USER)"
fi

echo "目标用户: $TARGET_USER"
echo "目标组: $TARGET_GROUP"

# 测试 Node.js 检测
if command -v node &> /dev/null; then
    echo "✅ Node.js 已安装: $(node --version)"
else
    echo "❌ Node.js 未安装"
fi

# 测试目录权限
echo "当前目录权限: $(ls -ld . | awk '{print $1, $3, $4}')"
