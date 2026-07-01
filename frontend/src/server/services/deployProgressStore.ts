import type { DeployStatus } from '../types';

/** In-memory deploy progress store — single current status per node. */
const globalState = globalThis as typeof globalThis & {
  __MIOBRIDGE_DEPLOY_PROGRESS__?: Map<string, DeployStatus>;
};
const deployProgress = globalState.__MIOBRIDGE_DEPLOY_PROGRESS__ ?? new Map<string, DeployStatus>();
globalState.__MIOBRIDGE_DEPLOY_PROGRESS__ = deployProgress;
const TTL_MS = 5 * 60 * 1000; // 5 minutes

function cleanup(): void {
  const now = Date.now();
  const entries = Array.from(deployProgress.entries());
  for (const [nodeId, status] of entries) {
    const isTerminal = status.status === 'success' || status.status === 'error';
    if (isTerminal && now - status.startedAt > TTL_MS) {
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
