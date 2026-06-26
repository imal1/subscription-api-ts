// TDD RED phase for Task 3: NodeManager service
// These tests verify the NodeManager singleton, HMAC signing, and node loading

import { describe, it, expect, beforeEach } from 'vitest';

// The module doesn't exist yet — these imports will fail until GREEN phase
import { NodeManager } from '../nodeManager';
import type { NodeConfig } from '../../types';

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
});
