# Deployment

Production runs the Next.js standalone server with systemd behind Nginx.

## Runtime

- App root: `~/.config/miobridge/dist`
- Entrypoint: `~/.config/miobridge/dist/frontend/server.js`
- Env: `PORT=<config port>`, `HOSTNAME=0.0.0.0`, `NODE_ENV=production`
- Data/config/logs: `~/.config/miobridge/`

## Normal Flow

```bash
bun run build
scripts/manage.sh install
sudo systemctl restart miobridge
curl -fsS http://127.0.0.1:3001/api/health
```

GitHub Actions performs the same flow remotely with an atomic release symlink
and rollback on failed health check.

## Server Checks

```bash
sudo systemctl status miobridge
sudo journalctl -u miobridge -n 100 --no-pager
ss -tlnp | grep 3001
readlink ~/.config/miobridge/dist
```

## Required Binaries

Place `mihomo` and `yq` in `~/.config/miobridge/bin/` or make them available on
PATH. `sing-box` is optional for dashboard rendering but needed for local source
extraction.
