# MioBridge Release

Create a new versioned release: tag the commit, push the tag, and monitor the deployment.

## Steps

1. Read the current version from CHANGELOG.md:
   ```bash
   head -20 CHANGELOG.md | grep -E '^## \[?[0-9]' | head -1
   ```

2. Ask the user to confirm the version number (e.g., `v1.2.0`). If CHANGELOG.md has unreleased changes, suggest the next version based on semver.

3. Create and push the tag:
   ```bash
   git tag -a <version> -m "Release <version>"
   git push origin <version>
   ```

4. The tag push triggers deploy.yml. Watch the deployment:
   ```bash
   RUN_ID=$(gh run list -w deploy.yml -L1 --json databaseId -q '.[0].databaseId')
   gh run watch $RUN_ID
   ```

5. After deployment succeeds, verify:
   ```bash
   PORT=$(grep 'port:' ~/.config/miobridge/config.yaml 2>/dev/null | awk '{print $2}' | head -1 || echo "3001")
   curl -fsS "http://localhost:${PORT:-3001}/api/health"
   readlink ~/.config/miobridge/dist
   ```

6. Report the release result with version, commit, and deployment status.