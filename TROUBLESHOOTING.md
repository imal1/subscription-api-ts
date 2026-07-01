# Troubleshooting

Start with the service and app logs:

```bash
sudo systemctl status miobridge
sudo journalctl -u miobridge -n 100 --no-pager
tail -n 100 ~/.config/miobridge/log/combined.log
curl -fsS http://127.0.0.1:3001/api/health
```

## Common Checks

- `clash.yaml` missing: verify `mihomo` and `yq` are executable and run
  `/api/update`.
- Status resets to empty: check `/api/status` response shape and browser console.
- Service will not start: check port conflicts, binary paths, and ownership of
  `~/.config/miobridge`.
- Remote Agent offline: verify public Agent port is reachable; normal checks do
  not use SSH fallback.
- Deploy failed: inspect the latest GitHub Actions log and
  `journalctl -u miobridge -n 200`.

## Rollback

```bash
cd ~/.config/miobridge
ls -lt releases/
ln -sfn releases/<old-release> dist
sudo systemctl restart miobridge
```
