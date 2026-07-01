---
name: coding-conventions
description: Current coding conventions
metadata:
  type: project
---

# Coding Conventions

- Prefer existing service and UI patterns.
- Keep API routes thin; put business logic in `frontend/src/server/**`.
- Keep Markdown short. Move only durable, current facts into memory files.
- Run `bun run lint`, `bun run typecheck`, and relevant tests before handoff
  when code changes warrant it.
