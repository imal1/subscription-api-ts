#!/usr/bin/env bash
#
# server-deploy.sh — 在远端服务器上完成原子部署。
#
# 由 GitHub Actions 通过 SSH 调用：上传一个 release.tar.gz（Next standalone
# 整树）和本脚本，然后执行：
#
#   server-deploy.sh apply <tarball-path> <release-id>
#
# 流程：
#   1. 解压到 $BASE_DIR/releases/<release-id>/
#   2. 拷贝 .next/static、public（standalone 不自带）从 tar 内已包含的位置
#   3. 原子切换 $BASE_DIR/dist 软链接 → releases/<release-id>
#   4. 重启 systemd 服务（subscription-api-ts）
#   5. 健康检查（/api/health 轮询，最多 30s）
#   6. 失败则回滚软链接 + 重启 + 退出非零
#   7. 成功则保留最近 5 个 release，其余清理
#
# 设计原则：
#   - 自包含：不依赖仓库 lib/，可单独 scp 到服务器执行。
#   - 幂等：dist 既可能是软链接也可能是真实目录（首次迁移），都能处理。
#   - 安全：所有路径在 $BASE_DIR 之下，删除前校验前缀。

set -euo pipefail

# ---------- 默认参数 ----------
BASE_DIR="${BASE_DIR:-$HOME/.config/subscription}"
RELEASES_DIR="$BASE_DIR/releases"
DIST_LINK="$BASE_DIR/dist"
SERVICE_NAME="${SERVICE_NAME:-subscription-api-ts}"
KEEP_RELEASES="${KEEP_RELEASES:-5}"
HEALTH_PATH="${HEALTH_PATH:-/api/health}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-30}"
HEALTH_HOST="${HEALTH_HOST:-127.0.0.1}"

# ---------- 工具 ----------
log()  { printf '\033[0;34m[deploy]\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m[deploy]\033[0m ✅ %s\n' "$*"; }
warn() { printf '\033[1;33m[deploy]\033[0m ⚠️  %s\n' "$*" >&2; }
err()  { printf '\033[0;31m[deploy]\033[0m ❌ %s\n' "$*" >&2; }

die() { err "$*"; exit 1; }

run_sudo() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo -n "$@"
    else
        die "需要 root 权限或 NOPASSWD sudo 来执行: $*"
    fi
}

# 从 config.yaml 读取端口（用于健康检查）。无 yq / 无 config 时回退默认 3000。
detect_port() {
    local cfg="$BASE_DIR/config.yaml"
    if [[ -f "$cfg" ]] && command -v yq >/dev/null 2>&1; then
        local p
        p="$(yq eval '.app.port // ""' "$cfg" 2>/dev/null || true)"
        if [[ -n "$p" && "$p" != "null" ]]; then
            echo "$p"; return
        fi
    fi
    echo "${PORT:-3000}"
}

# ---------- 主命令：apply ----------
cmd_apply() {
    local tarball="${1:-}"
    local release_id="${2:-}"

    [[ -n "$tarball"   ]] || die "用法: $0 apply <tarball> <release-id>"
    [[ -n "$release_id" ]] || die "缺少 release-id"
    [[ -f "$tarball"   ]] || die "tarball 不存在: $tarball"

    # release-id 安全校验，防注入路径
    if [[ ! "$release_id" =~ ^[A-Za-z0-9._-]+$ ]]; then
        die "非法的 release-id: $release_id"
    fi

    mkdir -p "$RELEASES_DIR"
    local target="$RELEASES_DIR/$release_id"

    if [[ -e "$target" ]]; then
        warn "目标已存在，先清理: $target"
        rm -rf "$target"
    fi
    mkdir -p "$target"

    log "解压 $tarball → $target"
    tar -xzf "$tarball" -C "$target"

    # 校验 standalone 入口
    if [[ ! -f "$target/frontend/server.js" ]]; then
        rm -rf "$target"
        die "release 校验失败：未找到 frontend/server.js（tarball 是否打错了根目录？）"
    fi

    # 记录上一个 release 用于回滚
    local previous=""
    if [[ -L "$DIST_LINK" ]]; then
        previous="$(readlink "$DIST_LINK")"
    elif [[ -e "$DIST_LINK" ]]; then
        # 旧布局：dist 是真实目录，迁移到 releases/legacy
        warn "$DIST_LINK 是真实目录（旧布局），迁移为 releases/legacy"
        local legacy="$RELEASES_DIR/legacy"
        if [[ ! -e "$legacy" ]]; then
            mv "$DIST_LINK" "$legacy"
        else
            rm -rf "$DIST_LINK"
        fi
        previous="$legacy"
    fi

    # 原子切换软链接：先建临时再 mv -T
    local tmp_link="${DIST_LINK}.new"
    rm -f "$tmp_link"
    ln -s "$target" "$tmp_link"
    mv -Tf "$tmp_link" "$DIST_LINK"
    ok "软链接切换：$DIST_LINK → $target"

    # 重启服务
    log "重启 systemd 服务: $SERVICE_NAME"
    if ! run_sudo systemctl restart "$SERVICE_NAME"; then
        warn "重启失败，尝试回滚"
        rollback "$previous" "$target"
        die "服务重启失败"
    fi

    # 健康检查
    if ! wait_healthy; then
        warn "健康检查失败，回滚到上一个 release"
        rollback "$previous" "$target"
        die "部署失败（健康检查未通过）"
    fi

    ok "部署成功: $release_id"

    # 清理旧 release
    prune_releases "$release_id" "$previous"

    # 删除 tarball（CI 上传到 /tmp 后已无价值）
    rm -f "$tarball"
}

wait_healthy() {
    local port deadline url
    port="$(detect_port)"
    url="http://${HEALTH_HOST}:${port}${HEALTH_PATH}"
    deadline=$(( $(date +%s) + HEALTH_TIMEOUT ))

    log "健康检查: $url（最长 ${HEALTH_TIMEOUT}s）"

    while [[ $(date +%s) -lt $deadline ]]; do
        if curl -fsS --max-time 3 "$url" >/dev/null 2>&1; then
            ok "服务已就绪"
            return 0
        fi
        sleep 1
    done
    return 1
}

# 回滚到上一个 release。$1=previous_target $2=failed_target
rollback() {
    local previous="$1"
    local failed="$2"

    if [[ -z "$previous" || ! -d "$previous" ]]; then
        warn "没有可回滚的上个 release，保留失败的 release 以便排查"
        return
    fi

    rm -f "$DIST_LINK"
    ln -s "$previous" "$DIST_LINK"
    log "回滚软链接 → $previous"

    if ! run_sudo systemctl restart "$SERVICE_NAME"; then
        err "回滚后重启仍失败，需要人工介入"
        return
    fi
    ok "已回滚到上一个 release"

    # 失败的 release 改名留痕，方便后续清理
    if [[ -d "$failed" ]]; then
        mv "$failed" "${failed}.failed-$(date +%s)" || true
    fi
}

# 保留最近 N 个目录（按修改时间），清理其余
prune_releases() {
    local current="$1"
    local previous="$2"

    [[ -d "$RELEASES_DIR" ]] || return 0

    # 只列入正常的 release 目录（排除 .failed-* 留痕）
    local -a keep
    keep=()
    [[ -n "$current"  ]] && keep+=("$current")
    if [[ -n "$previous" ]]; then
        # previous 形如 .../releases/xxx，只取末段
        keep+=("$(basename "$previous")")
    fi

    # 收集所有 release 目录，按 mtime 倒序
    local -a all
    while IFS= read -r line; do all+=("$line"); done < <(
        find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d \
            -not -name '*.failed-*' -printf '%T@ %f\n' 2>/dev/null \
            | sort -rn | awk '{print $2}'
    )

    local kept=0
    for name in "${all[@]}"; do
        local skip=0
        for k in "${keep[@]}"; do
            if [[ "$name" == "$k" ]]; then skip=1; break; fi
        done
        if [[ $skip -eq 1 ]]; then
            continue
        fi
        if [[ $kept -lt $KEEP_RELEASES ]]; then
            kept=$((kept+1))
            continue
        fi

        local victim="$RELEASES_DIR/$name"
        # 安全检查：必须在 RELEASES_DIR 之下
        case "$victim" in
            "$RELEASES_DIR"/*)
                log "清理旧 release: $name"
                rm -rf "$victim"
                ;;
        esac
    done
}

# ---------- 入口 ----------
case "${1:-}" in
    apply)
        shift
        cmd_apply "$@"
        ;;
    health)
        wait_healthy && exit 0 || exit 1
        ;;
    *)
        cat <<EOF
用法: $0 <command> [args]

命令:
  apply <tarball> <release-id>   解压 tarball 并执行原子部署
  health                         运行一次健康检查（成功退出 0）

环境变量:
  BASE_DIR        默认 \$HOME/.config/subscription
  SERVICE_NAME    默认 subscription-api-ts
  KEEP_RELEASES   保留的历史 release 数（默认 5）
  HEALTH_TIMEOUT  健康检查超时秒数（默认 30）
  HEALTH_PATH     健康检查路径（默认 /api/health）
  PORT            健康检查端口（默认从 config.yaml 读取，回退 3000）
EOF
        exit 1
        ;;
esac
