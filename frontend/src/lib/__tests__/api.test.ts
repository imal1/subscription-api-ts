import { describe, it, expect } from 'vitest';
import { apiService } from '../api';

// 测试 apiService 上 cluster 方法是否存在（接口契约）
describe('API Client - Cluster Methods', () => {
  it('should expose getClusterStatus method', () => {
    expect(typeof apiService.getClusterStatus).toBe('function');
  });

  it('should expose triggerClusterUpdate method', () => {
    expect(typeof apiService.triggerClusterUpdate).toBe('function');
  });

  it('should expose clusterHealthCheck method', () => {
    expect(typeof apiService.clusterHealthCheck).toBe('function');
  });
});
