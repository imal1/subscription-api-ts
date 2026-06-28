import type { DeployStep } from './deployManager';

/** In-memory deploy progress store shared across API routes */
const deployProgress = new Map<string, DeployStep[]>();

export function getDeployProgress(nodeId: string): DeployStep[] {
  return deployProgress.get(nodeId) || [];
}

export function setDeployProgress(nodeId: string, steps: DeployStep[]): void {
  deployProgress.set(nodeId, steps);
}

export function clearDeployProgress(nodeId: string): void {
  deployProgress.delete(nodeId);
}
