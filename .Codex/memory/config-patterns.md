---
name: config-patterns
description: Current configuration conventions
metadata:
  type: project
---

# Config Patterns

- Runtime config is `~/.config/miobridge/config.yaml`.
- Runtime data/log/backup/dist paths are under `~/.config/miobridge/`.
- Binary lookup order is configured path, `~/.config/miobridge/bin/`, repo
  `bin/`, then PATH.
- `PORT` can override the app port for systemd/Next startup.
