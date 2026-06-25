# MioBridge Deploy

Trigger a deployment to the production server via GitHub Actions and verify it completes successfully.

## Steps

1. Check the current git branch and identify any unpushed commits:
   ```bash
   git branch --show-current
   git log origin/HEAD..HEAD --oneline
   ```

2. If there are unpushed commits, push them:
   ```bash
   git push origin <current-branch>
   ```

3. If the push was to `main`, the deploy workflow triggers automatically. If pushing a different branch, manually trigger:
   ```bash
   gh workflow run deploy.yml --ref <branch>
   ```

4. Get the latest deploy workflow run ID and watch it:
   ```bash
   RUN_ID=$(gh run list -w deploy.yml -L1 --json databaseId -q '.[0].databaseId')
   gh run watch $RUN_ID
   ```

5. After CI completes, verify the deployment with a secondary health check:
   ```bash
   PORT=$(grep 'port:' ~/.config/miobridge/config.yaml 2>/dev/null | awk '{print $2}' | head -1 || echo "3001")
   curl -fsS "http://localhost:${PORT:-3001}/api/health" | python3 -m json.tool
   ```

6. Report the result:
   - Release ID, commit hash, and deployment status
   - Current running version: `readlink ~/.config/miobridge/dist`