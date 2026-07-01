---
name: bug-fixes
description: Bug fixes and operational lessons for MioBridge
metadata:
  type: project
---

# Bug Fixes

## 2026-07-01 — Deploy progress polling should preserve active and failed state

**Symptom**: Long-running deployments could disappear from the polling API after 5 minutes, failed deployments lost the last useful step/progress, and the dashboard could leave polling intervals running after repeated deploy attempts or dialog close.

**Cause**: The deploy progress store applied TTL cleanup to all statuses using the deployment start time. The deploy API overwrote all failures with `connect/0`, and the dashboard kept the polling interval in a local variable that could not be cleared outside the starting callback.

**Fix**: TTL cleanup now only removes stale terminal statuses. The deploy API preserves the last known step/progress on failure and stamps terminal statuses with completion time. The dashboard stores the deploy poller in a ref, clears it before starting a new deployment, on terminal status, on dialog close, and on component unmount.

## 2026-07-01 — Main node owns unified subscription artifacts

**Symptom**: Subscription update returned 500 when the local machine had no sing-box configs, even though a deployed child node had a reachable proxy source. The cluster UI also made it look like child nodes should each own subscription and Clash outputs.

**Cause**: `MioBridgeService.updateSubscription()` treated local sing-box extraction as mandatory and did not aggregate proxy URLs from remote Agents. `NodeManager.triggerUpdate()` could call remote update endpoints, which blurred ownership between source nodes and the main node.

**Fix**: Subscription update now requires only local mihomo on the main node, gathers local URLs when available, then aggregates remote node URLs through signed Agent `/api/urls` calls. `raw.txt`, `subscription.txt`, and `clash.yaml` are generated only on the main node, while child nodes report source availability and proxy URL count.

## 2026-07-01 — 233boy kernel config discovery

**Symptom**: A remote test node reported the Agent online but the kernel/source was inaccessible, because the deployed sing-box config lived under 233boy's layout instead of the Agent default path.

**Cause**: The Agent only checked one configured kernel config path. 233boy/sing-box commonly runs `/etc/sing-box/config.json` plus per-proxy JSON files under `/etc/sing-box/conf`, and the related 233boy/xray and 233boy/v2ray scripts use their own `/etc/<kernel>/...` layouts.

**Fix**: Agent source discovery now scans `/etc/sing-box/config.json`, `/etc/sing-box/conf/*.json`, matching `/usr/local/etc` paths, and equivalent xray/v2ray config and conf directories. It extracts VLESS Reality/Trojan/VMess-compatible URLs where possible and exposes them through `/api/urls`.

## 2026-07-01 — Normal Agent polling must not hide firewall issues behind SSH

**Symptom**: After a remote public Agent was unreachable, the dashboard could still appear healthy by curling `127.0.0.1:3001` over SSH, masking the fact that the cloud security group had not allowed the Agent port.

**Cause**: Remote status and health checks reused an SSH fallback path intended for deployment diagnostics.

**Fix**: Normal remote status, health, and URL collection now use the public Agent endpoint with HMAC only. SSH is reserved for deployment and diagnostics, and setup guidance should prompt the operator to open the Agent port before expecting the dashboard to show the node online.

## 2026-07-01 — Remote Agent status over NAT

**Symptom**: Web deployment completed and the remote Agent passed SSH-local health checks, but the dashboard still showed the child node offline because `http://<public-ip>:3001` timed out through the provider NAT layer.

**Cause**: The cluster status path only polled the Agent over public HTTP(S). The tested VPS exposes a private address behind NAT, so the Agent can listen on `0.0.0.0:3001` locally while public HTTP traffic still cannot reach it.

**Fix**: Node/Agent port fields are parsed and persisted so deployment and public Agent status checks use the same port. A later hardening pass removed normal SSH fallback so provider firewall/security-group issues remain visible instead of being masked by deployment credentials.

## 2026-07-01 — Deployment must restart existing Agent with the node secret

**Symptom**: Re-deploying an already running Agent reported success, but the running process kept the old config and HMAC secret.

**Cause**: `systemctl start miobridge-agent || systemctl restart miobridge-agent` is a no-op for an already active service, and `DeployManager` generated a fresh random Agent secret instead of using the node secret stored in `nodes.yaml`.

**Fix**: Deployment now writes `agent.yaml` and the systemd unit with the node's existing secret, then always runs `systemctl restart miobridge-agent` after enabling the service.

## 2026-07-01 — SSH deployment host key and private key handling

**Symptom**: Web-based remote Agent deployment accepted first-use SSH host keys without persisting them, and the add-node form allowed either a private key path or pasted key content while the backend always treated the value as raw key content.

**Cause**: `DeployManager.connectSsh()` recorded no reusable host key state, and passed `ssh.keyPath` directly to `ssh2.privateKey`.

**Fix**: `DeployManager` now records the first-use SHA-256 host key on the deploy target and resolves SSH private keys from either pasted content or a local path. `NodeManager.updateNodeSshHostKey()` writes recorded host keys back to `~/.config/miobridge/nodes.yaml`, and the deploy API persists the key after the background deployment finishes or errors.

## 2026-07-01 — Non-root remote deployment needs sudo

**Symptom**: Web-based Agent deployment could SSH into a node as a non-root user, but failed at kernel installation with the 233boy script reporting that the current user was not root.

**Cause**: `DeployManager` ran kernel installation, `/usr/local/bin` upload, `/etc/miobridge-agent` writes, and `systemctl` commands directly as the SSH user.

**Fix**: Privileged remote commands now run through `sudo -S` when the SSH user is not root and a password is available. Agent upload now stages the binary in `/tmp` via SFTP, then installs it into `/usr/local/bin` with elevated permissions.
