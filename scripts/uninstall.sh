#!/usr/bin/env bash
#
# uninstall.sh — 完整卸载 MioBridge（旧名 subscription-api-ts）的部署产物
#
# 清理内容:
#   1. 停止并禁用 systemd 服务
#   2. 删除 nginx 配置
#   3. 删除 ~/.config/subscription/ (旧目录)
#   4. 删除 ~/.config/miobridge/ (新目录，如果存在)
#   5. 删除 /tmp/miobridge-deploy-* 临时文件
#   6. 清理 sudoers 中的 deploy 配置
#
# 用法: sudo bash scripts/uninstall.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log()  { printf "${GREEN}[uninstall]${NC} %s\n" "$*"; }
warn() { printf "${RED}[uninstall]${NC} %s\n" "$*" >&2; }

SERVICE_NAMES=("subscription-api-ts" "miobridge")
NGINX_CONF="/etc/nginx/sites-enabled/default"
OLD_DIR="$HOME/.config/subscription"
NEW_DIR="$HOME/.config/miobridge"
SUDOERS_FILE="/etc/sudoers.d/subscription-deploy"

# ── 1. Stop & disable systemd services ──
for svc in "${SERVICE_NAMES[@]}"; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        log "停止服务: $svc"
        systemctl stop "$svc"
    fi
    if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
        log "禁用服务: $svc"
        systemctl disable "$svc"
    fi
    if [ -f "/etc/systemd/system/${svc}.service" ]; then
        log "删除 systemd 单元: /etc/systemd/system/${svc}.service"
        rm -f "/etc/systemd/system/${svc}.service"
    fi
done
systemctl daemon-reload

# ── 2. Nginx ──
if [ -f "$NGINX_CONF" ]; then
    if grep -q "subscription\|miobridge\|3001" "$NGINX_CONF" 2>/dev/null; then
        log "备份并删除 nginx 配置: $NGINX_CONF"
        cp "$NGINX_CONF" "${NGINX_CONF}.bak.$(date +%s)"
        rm -f "$NGINX_CONF"
        systemctl reload nginx 2>/dev/null || true
    fi
fi

# ── 3. Data directories ──
for dir in "$OLD_DIR" "$NEW_DIR"; do
    if [ -d "$dir" ]; then
        log "删除数据目录: $dir"
        rm -rf "$dir"
    fi
done

# ── 4. Temp files ──
log "清理临时文件..."
rm -rf /tmp/miobridge-deploy-* 2>/dev/null || true
rm -rf /tmp/subscription-deploy-* 2>/dev/null || true

# ── 5. Sudoers ──
if [ -f "$SUDOERS_FILE" ]; then
    log "删除 sudoers 配置: $SUDOERS_FILE"
    rm -f "$SUDOERS_FILE"
fi

log "卸载完成。"
echo ""
log "如需重新部署 MioBridge，请运行:"
echo "  git clone https://github.com/imal1/miobridge.git"
echo "  cd miobridge && bash scripts/manage.sh setup"
