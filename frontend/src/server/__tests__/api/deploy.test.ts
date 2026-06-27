import { describe, it, expect } from 'vitest';

describe('Deploy API endpoints', () => {
  it('deploy handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/deploy');
    expect(typeof mod.default).toBe('function');
  });

  it('deploy/progress handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/deploy/progress');
    expect(typeof mod.default).toBe('function');
  });

  it('agent/update handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/agent/update');
    expect(typeof mod.default).toBe('function');
  });

  it('agent/uninstall handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/agent/uninstall');
    expect(typeof mod.default).toBe('function');
  });

  it('agent/restart handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/agent/restart');
    expect(typeof mod.default).toBe('function');
  });

  it('agent/stop handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/agent/stop');
    expect(typeof mod.default).toBe('function');
  });

  it('agent/start handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/agent/start');
    expect(typeof mod.default).toBe('function');
  });

  it('kernel/install handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/kernel/install');
    expect(typeof mod.default).toBe('function');
  });

  it('kernel/uninstall handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/kernel/uninstall');
    expect(typeof mod.default).toBe('function');
  });
});
