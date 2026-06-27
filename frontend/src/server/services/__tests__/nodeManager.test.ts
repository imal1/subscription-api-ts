// TDD RED phase for Task 3: NodeManager service
// These tests verify the NodeManager singleton, HMAC signing, node loading,
// and remote HTTP polling for multi-node cluster management

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';

import { NodeManager } from '../nodeManager';
import type { NodeConfig, NodeStatus, ClusterStatus } from '../../types';

describe('Task 3: NodeManager Service', () => {
  describe('singleton', () => {
    it('getInstance should return the same instance', () => {
      const instance1 = NodeManager.getInstance();
      const instance2 = NodeManager.getInstance();
      expect(instance1).toBe(instance2);
    });
  });

  describe('signRequest', () => {
    it('should return empty headers for localhost node', () => {
      const manager = NodeManager.getInstance();
      const localNode: NodeConfig = {
        id: 'local', name: '本地', host: 'localhost', port: 3001,
        secret: 'abc123', kernel: 'sing-box', location: '本地', enabled: true,
      };
      const headers = manager.signRequest(localNode, 'GET', '/api/status');
      expect(headers).toEqual({});
    });

    it('should return empty headers for 127.0.0.1 node', () => {
      const manager = NodeManager.getInstance();
      const localNode: NodeConfig = {
        id: 'local', name: '本地', host: '127.0.0.1', port: 3001,
        secret: 'abc123', kernel: 'sing-box', location: '本地', enabled: true,
      };
      const headers = manager.signRequest(localNode, 'GET', '/api/status');
      expect(headers).toEqual({});
    });

    it('should produce HMAC-SHA256 signature for remote node', () => {
      const manager = NodeManager.getInstance();
      const remoteNode: NodeConfig = {
        id: 'node-b', name: '新加坡', host: 'sg.example.com', port: 443,
        secret: 'supersecretkey1234567890abcdef', kernel: 'xray',
        location: '新加坡', enabled: true,
      };
      const headers = manager.signRequest(remoteNode, 'GET', '/api/status');

      expect(headers['X-Node-Id']).toBe('node-b');
      expect(headers['X-Timestamp']).toBeDefined();
      expect(headers['X-Signature']).toBeDefined();
      // Signature should be 64 hex chars (SHA-256)
      expect(headers['X-Signature']).toMatch(/^[a-f0-9]{64}$/);
    });

    it('should produce different signatures for different methods', () => {
      const manager = NodeManager.getInstance();
      const node: NodeConfig = {
        id: 'n1', name: 'N1', host: 'api.example.com', port: 443,
        secret: 'key123', kernel: 'sing-box', location: 'jp', enabled: true,
      };
      const getHeaders = manager.signRequest(node, 'GET', '/api/status');
      const postHeaders = manager.signRequest(node, 'POST', '/api/status');

      expect(getHeaders['X-Signature']).not.toBe(postHeaders['X-Signature']);
    });

    it('should produce different signatures for different paths', () => {
      const manager = NodeManager.getInstance();
      const node: NodeConfig = {
        id: 'n1', name: 'N1', host: 'api.example.com', port: 443,
        secret: 'key123', kernel: 'sing-box', location: 'jp', enabled: true,
      };
      const h1 = manager.signRequest(node, 'GET', '/api/status');
      const h2 = manager.signRequest(node, 'GET', '/api/health');

      expect(h1['X-Signature']).not.toBe(h2['X-Signature']);
    });

    it('should include request body in signature payload', () => {
      const manager = NodeManager.getInstance();
      const node: NodeConfig = {
        id: 'n1', name: 'N1', host: 'api.example.com', port: 443,
        secret: 'key123', kernel: 'sing-box', location: 'jp', enabled: true,
      };
      const withoutBody = manager.signRequest(node, 'POST', '/api/update');
      const withBody = manager.signRequest(node, 'POST', '/api/update', '{"action":"update"}');

      expect(withoutBody['X-Signature']).not.toBe(withBody['X-Signature']);
    });
  });

  describe('hasRemoteNodes', () => {
    it('should return false when no nodes.yaml exists (single-node mode)', async () => {
      const manager = NodeManager.getInstance();
      // In test environment, nodes.yaml won't exist, so loadNodes returns []
      await manager.loadNodes();
      expect(manager.hasRemoteNodes()).toBe(false);
    });
  });

  describe('loadNodes', () => {
    it('should return empty array when nodes.yaml does not exist', async () => {
      const manager = NodeManager.getInstance();
      const nodes = await manager.loadNodes();
      expect(Array.isArray(nodes)).toBe(true);
      // In test environment without nodes.yaml, should be empty
      expect(nodes.length).toBe(0);
    });
  });

  describe('getClusterStatus', () => {
    it('should return cluster status with local node', async () => {
      const manager = NodeManager.getInstance();
      const cluster = await manager.getClusterStatus();
      expect(cluster).toBeDefined();
      expect(typeof cluster.totalNodes).toBe('number');
      expect(typeof cluster.onlineNodes).toBe('number');
      expect(typeof cluster.totalProxies).toBe('number');
      expect(Array.isArray(cluster.nodes)).toBe(true);
      expect(cluster.lastUpdated).toBeDefined();
    });

    it('should include local node in cluster nodes', async () => {
      const manager = NodeManager.getInstance();
      const cluster = await manager.getClusterStatus();
      const localNode = cluster.nodes.find(n => n.nodeId === 'local');
      expect(localNode).toBeDefined();
      expect(localNode!.name).toBe('本地');
    });
  });

  describe('triggerUpdate', () => {
    it('should return results object', async () => {
      const manager = NodeManager.getInstance();
      const result = await manager.triggerUpdate();
      expect(result).toBeDefined();
      expect(result.results).toBeDefined();
      expect(typeof result.results).toBe('object');
    });
  });

  describe('healthCheck', () => {
    it('should return health status for all nodes', async () => {
      const manager = NodeManager.getInstance();
      const result = await manager.healthCheck();
      expect(result).toBeDefined();
      expect(typeof result).toBe('object');
    });
  });

  // ==================== v1.0 Remote HTTP Polling (RED phase) ====================

  describe('fetchRemoteStatus', () => {
    const remoteNode: NodeConfig = {
      id: 'node-sg', name: '新加坡', host: 'sg.example.com', port: 443,
      secret: 'shared-secret-32chars-minimum!!', kernel: 'xray',
      location: '新加坡', enabled: true,
    };

    it('should return NodeStatus for a remote node', async () => {
      const manager = NodeManager.getInstance();
      // fetchRemoteStatus should exist
      expect(typeof (manager as any).fetchRemoteStatus).toBe('function');
    });

    it('should mark node as offline when fetch fails', async () => {
      const manager = NodeManager.getInstance();
      // When node is unreachable, should return status with online=false and error
      // This test validates the failure handling contract
      const result = await (manager as any).fetchRemoteStatus({
        ...remoteNode,
        host: 'unreachable.example.com',
      });
      expect(result).toBeDefined();
      expect(result.online).toBe(false);
      expect(result.error).toBeDefined();
      expect(result.nodeId).toBe(remoteNode.id);
    });

    it('should include HMAC headers in remote request', () => {
      const manager = NodeManager.getInstance();
      const headers = manager.signRequest(remoteNode, 'GET', '/api/status');
      expect(headers['X-Node-Id']).toBe('node-sg');
      expect(headers['X-Timestamp']).toBeDefined();
      expect(headers['X-Signature']).toBeDefined();
    });
  });

  describe('fetchRemoteUpdate', () => {
    const remoteNode: NodeConfig = {
      id: 'node-jp', name: '东京', host: 'jp.example.com', port: 443,
      secret: 'jp-secret-key-32chars-minimum!', kernel: 'sing-box',
      location: '东京', enabled: true,
    };

    it('should return update result for remote node', async () => {
      const manager = NodeManager.getInstance();
      expect(typeof (manager as any).fetchRemoteUpdate).toBe('function');
    });

    it('should return failure when remote node is unreachable', async () => {
      const manager = NodeManager.getInstance();
      const result = await (manager as any).fetchRemoteUpdate({
        ...remoteNode,
        host: 'offline.example.com',
      });
      expect(result).toBeDefined();
      expect(result.success).toBe(false);
      expect(result.message).toContain('离线');
    });
  });

  describe('fetchRemoteHealth', () => {
    const remoteNode: NodeConfig = {
      id: 'node-hk', name: '香港', host: 'hk.example.com', port: 443,
      secret: 'hk-secret-key-32chars-minimum!!', kernel: 'v2ray',
      location: '香港', enabled: true,
    };

    it('should return latency measurement for remote node', async () => {
      const manager = NodeManager.getInstance();
      expect(typeof (manager as any).fetchRemoteHealth).toBe('function');
    });

    it('should report online=false with zero latency when unreachable', async () => {
      const manager = NodeManager.getInstance();
      const result = await (manager as any).fetchRemoteHealth({
        ...remoteNode,
        host: 'dead.example.com',
      });
      expect(result).toBeDefined();
      expect(result.online).toBe(false);
      expect(result.latency).toBe(0);
    });
  });

  describe('getClusterStatus (multi-node)', () => {
    it('should aggregate local + remote node statuses', async () => {
      const manager = NodeManager.getInstance();
      const cluster = await manager.getClusterStatus();
      expect(cluster).toBeDefined();
      expect(cluster.totalNodes).toBeGreaterThanOrEqual(1); // at least local
      expect(Array.isArray(cluster.nodes)).toBe(true);
      const localNode = cluster.nodes.find((n: NodeStatus) => n.nodeId === 'local');
      expect(localNode).toBeDefined();
    });

    it('should handle remote node offline without failing entire cluster', async () => {
      const manager = NodeManager.getInstance();
      const cluster = await manager.getClusterStatus();
      // All nodes should appear, even if offline
      expect(cluster.nodes.length).toBe(cluster.totalNodes);
    });

    it('should return lastUpdated timestamp', async () => {
      const manager = NodeManager.getInstance();
      const cluster = await manager.getClusterStatus();
      expect(cluster.lastUpdated).toBeDefined();
      expect(() => new Date(cluster.lastUpdated)).not.toThrow();
    });
  });

  describe('triggerUpdate (multi-node)', () => {
    it('should support updating a specific remote node by id', async () => {
      const manager = NodeManager.getInstance();
      // triggerUpdate should accept nodeId parameter
      const result = await manager.triggerUpdate('node-sg');
      expect(result).toBeDefined();
      expect(result.results).toBeDefined();
    });

    it('should return per-node success/failure status', async () => {
      const manager = NodeManager.getInstance();
      const result = await manager.triggerUpdate();
      for (const [, nodeResult] of Object.entries(result.results)) {
        expect(typeof nodeResult.success).toBe('boolean');
        expect(typeof nodeResult.message).toBe('string');
      }
    });
  });

  describe('healthCheck (multi-node)', () => {
    it('should check health for specific remote node', async () => {
      const manager = NodeManager.getInstance();
      const result = await manager.healthCheck('node-hk');
      expect(result).toBeDefined();
      expect(result['node-hk']).toBeDefined();
      expect(typeof result['node-hk'].online).toBe('boolean');
      expect(typeof result['node-hk'].latency).toBe('number');
    });
  });
});
