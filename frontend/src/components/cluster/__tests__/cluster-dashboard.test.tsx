// @vitest-environment jsdom
// Phase C GREEN: Cluster Dashboard integration tests
// Tests verify Dashboard renders cluster view with SSE updates

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, act } from '@testing-library/react';
import React from 'react';

// Mock EventSource for SSE
class MockEventSource {
  url: string;
  onmessage: ((e: any) => void) | null = null;
  onerror: ((e: any) => void) | null = null;
  onopen: ((e: any) => void) | null = null;
  readyState: number = 0;
  static instances: MockEventSource[] = [];

  constructor(url: string) {
    this.url = url;
    MockEventSource.instances.push(this);
  }

  close() {
    this.readyState = 2;
  }
}

// Mock apiService for action callbacks
const mockTriggerClusterUpdate = vi.fn().mockResolvedValue({ success: true, data: {} });
const mockClusterHealthCheck = vi.fn().mockResolvedValue({ success: true, data: {} });

vi.mock('@/lib/api', () => ({
  apiService: {
    triggerClusterUpdate: (...args: any[]) => mockTriggerClusterUpdate(...args),
    clusterHealthCheck: (...args: any[]) => mockClusterHealthCheck(...args),
  },
}));

// Mock SSE hook to return controlled data
vi.mock('@/lib/useClusterSSE', () => ({
  useClusterSSE: (initial: any) => initial,
}));

const mockClusterData = {
  totalNodes: 3,
  onlineNodes: 2,
  totalProxies: 35,
  nodes: [
    {
      nodeId: 'local', name: '本地', kernel: 'sing-box' as const, location: '本地',
      online: true, latency: 0, nodesCount: 23,
      subscriptionExists: true, clashExists: true,
      mihomoAvailable: true, kernelAccessible: true,
      version: '0.2.0', uptime: 7200,
    },
    {
      nodeId: 'node-sg', name: '新加坡', kernel: 'xray' as const, location: '新加坡',
      online: true, latency: 45, nodesCount: 12,
      subscriptionExists: true, clashExists: true,
      mihomoAvailable: true, kernelAccessible: true,
      version: '0.2.0', uptime: 3600,
    },
    {
      nodeId: 'node-jp', name: '东京', kernel: 'sing-box' as const, location: '东京',
      online: false, error: '连接超时',
    },
  ],
  lastUpdated: new Date().toISOString(),
};

describe('Phase C: Cluster Dashboard Page', () => {
  beforeEach(() => {
    MockEventSource.instances = [];
    (globalThis as any).EventSource = MockEventSource;
    mockTriggerClusterUpdate.mockClear();
    mockClusterHealthCheck.mockClear();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('should render cluster overview with total nodes', async () => {
    const Dashboard = (await import('@/components/Dashboard')).default;
    render(<Dashboard initialCluster={mockClusterData} initialError={null} />);
    expect(screen.getByText('集群总览')).toBeDefined();
    expect(screen.getByText('3')).toBeDefined(); // totalNodes
    expect(screen.getByText('2')).toBeDefined(); // onlineNodes
  });

  it('should render node cards for each node', async () => {
    const Dashboard = (await import('@/components/Dashboard')).default;
    render(<Dashboard initialCluster={mockClusterData} initialError={null} />);
    expect(screen.getByRole('heading', { name: '新加坡' })).toBeDefined();
    expect(screen.getByRole('heading', { name: '东京' })).toBeDefined();
    expect(screen.getByRole('heading', { name: '本地' })).toBeDefined();
  });

  it('should display error alert when initialError is set', async () => {
    const Dashboard = (await import('@/components/Dashboard')).default;
    render(<Dashboard initialCluster={null} initialError="网络错误" />);
    expect(screen.getByText('网络错误')).toBeDefined();
  });

  it('should show empty state when no cluster data and no error', async () => {
    const Dashboard = (await import('@/components/Dashboard')).default;
    render(<Dashboard initialCluster={null} initialError={null} />);
    expect(screen.getByText('等待集群数据...')).toBeDefined();
  });

  it('should render BatchActions with update and health check buttons', async () => {
    const Dashboard = (await import('@/components/Dashboard')).default;
    render(<Dashboard initialCluster={mockClusterData} initialError={null} />);
    expect(screen.getByText('批量操作')).toBeDefined();
    expect(screen.getByText('全部更新')).toBeDefined();
    expect(screen.getByText('全部健康检查')).toBeDefined();
  });
});
