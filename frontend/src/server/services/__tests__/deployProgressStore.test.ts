import { describe, expect, it } from 'vitest';
import {
  clearDeployStatus,
  getDeployStatus,
  setDeployStatus,
} from '../deployProgressStore';
import type { DeployStatus } from '../../types';

const oldStartedAt = Date.now() - 10 * 60 * 1000;

function status(overrides: Partial<DeployStatus>): DeployStatus {
  return {
    nodeId: 'node-progress-test',
    step: 'agent',
    status: 'running',
    message: 'uploading',
    progress: 60,
    startedAt: oldStartedAt,
    ...overrides,
  };
}

describe('deployProgressStore', () => {
  it('keeps long-running deployments past the completed-status TTL', () => {
    setDeployStatus('node-progress-test', status({ status: 'running' }));

    expect(getDeployStatus('node-progress-test')?.status).toBe('running');

    clearDeployStatus('node-progress-test');
  });

  it('expires stale terminal deployments', () => {
    setDeployStatus('node-progress-test', status({ status: 'success' }));

    expect(getDeployStatus('node-progress-test')).toBeNull();
  });
});
