---
name: deployment-flow
description: Current deployment flow notes
metadata:
  type: project
---

# Deployment Flow

- Production runs on Vercel at `https://miobridge.vercel.app/`.
- Vercel Git Integration builds and publishes production when `main` is pushed.
- GitHub Actions is a CI gate only; it does not deploy and does not install or
  run Vercel CLI.
- The old server main-node flow, systemd restart, SSH upload, symlink switch,
  and scheduled SSH health check are no longer used for production.
