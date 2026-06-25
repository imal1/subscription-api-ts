# MioBridge Diagnostic

Run a comprehensive diagnostic of the MioBridge service, including health status, recent deployments, and logs.

## Steps

1. Check service health:
   ```bash
   PORT=$(grep 'port:' ~/.config/miobridge/config.yaml 2>/dev/null | awk '{print $2}' | head -1 || echo "3001")
   echo "=== Service Health ==="
   curl -fsS "http://localhost:${PORT:-3001}/api/health" 2>&1 || echo "❌ Health check failed"
   ```

2. Get detailed service status:
   ```bash
   echo "=== Service Status ==="
   curl -fsS "http://localhost:${PORT:-3001}/api/status" 2>&1 | python3 -m json.tool || echo "❌ Status check failed"
   ```

3. Check recent GitHub Actions deployments:
   ```bash
   echo "=== Recent Deployments ==="
   gh run list -w deploy.yml -L5
   ```

4. Check recent health check runs:
   ```bash
   echo "=== Recent Health Checks ==="
   gh run list -w health-check.yml -L3
   ```

5. Check service logs:
   ```bash
   echo "=== Recent Service Logs ==="
   sudo journalctl -u miobridge --since "10 min ago" --no-pager
   ```

6. Check current running version:
   ```bash
   echo "=== Current Version ==="
   readlink ~/.config/miobridge/dist
   ```

7. Summarize findings in a structured report with ✅/❌ indicators for each check.