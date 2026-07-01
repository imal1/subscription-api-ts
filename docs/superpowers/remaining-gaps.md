# MioBridge Remaining Gaps

This file keeps only the parts from the old superpowers plans that are not
implemented yet. Completed design and implementation-plan documents were
removed to avoid confusing them with current project documentation.

## Agent lifecycle operations

The following API routes currently acknowledge requests but do not execute
remote SSH/systemd operations:

- `POST /api/cluster/agent/update`
- `POST /api/cluster/agent/restart`
- `POST /api/cluster/agent/stop`
- `POST /api/cluster/agent/start`
- `POST /api/cluster/agent/uninstall`
- `POST /api/cluster/kernel/uninstall`

`POST /api/cluster/kernel/install` returns the install command, but does not
run it on the remote node outside the full deploy flow.

## SSH and deployment hardening

- SSH and Agent ports can be represented in `nodes.yaml`, but the dashboard
  add-node form still does not expose custom port inputs.
- Normal remote Agent status/update checks require direct public access to the
  Agent port. SSH remains available for deployment and diagnostics only, so the
  add-node/deploy flow should surface provider firewall/security-group guidance
  before the first public Agent health check.

## Agent update distribution

`UpdateChecker` exists, but release-based Agent update discovery is not wired
into the dashboard lifecycle. The expected release asset name and multi-arch
selection also need to match the actual build outputs.
