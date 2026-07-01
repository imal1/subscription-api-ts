---
name: deployment-flow
description: Current deployment flow notes
metadata:
  type: project
---

# Deployment Flow

- Production runs `~/.config/miobridge/dist/frontend/server.js` with Node.
- Deployments build Next standalone output, copy required static assets, publish
  a release directory, switch the `dist` symlink, restart systemd, and health
  check.
- Keep `mihomo` and `yq` available in `~/.config/miobridge/bin/` or PATH.
