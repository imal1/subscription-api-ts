import type { DeployStatus } from '../types';

/** In-memory deploy progress store — single current status per node, 5-min TTL */
const deployProgress = new Map<string, DeployStatus>();
const TTL_MS = 5 * 60 * 1000; // 5 minutes

function cleanup(): void {
  const now = Date.now();
  // Convert to array first to avoid iteration issues
  const entries = Array.from(deployProgress.entries());
  for (const [nodeId, status] of entries) {
    if (now - status.startedAt > TTL_MS) {
      deployProgress.delete(nodeId);
    }
  }
}

export function getDeployStatus(nodeId: string): DeployStatus | null {
  cleanup();
  return deployProgress.get(nodeId) || null;
}

export function getAllDeployStatuses(): DeployStatus[] {
  cleanup();
  return Array.from(deployProgress.values());
}

export function setDeployStatus(nodeId: string, status: DeployStatus): void {
  deployProgress.set(nodeId, status);
}

export function clearDeployStatus(nodeId: string): void {
  deployProgress.delete(nodeId);
}
