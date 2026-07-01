---
name: project-architecture
description: Current MioBridge architecture decisions
metadata:
  type: project
---

# Project Architecture

- The active service is one Next.js Pages Router app under `frontend/`, using
  Node runtime and standalone output.
- Backend services are framework-independent singletons in
  `frontend/src/server/**`.
- SSR uses direct service calls from `getServerSideProps`.
- mihomo is the local conversion engine; yq v4 handles YAML/config operations.
- Main node owns generated subscription artifacts; child nodes only expose Agent
  source URLs.
