// @vitest-environment jsdom
// Tests for ClusterOverview, NodeCard, and NodeDetail components
// Using @testing-library/react for DOM-based assertions

import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import React from 'react';
import { ClusterOverview } from '../ClusterOverview';
import { NodeCard } from '../NodeCard';
import { NodeDetail } from '../NodeDetail';
import type { NodeStatus, ClusterStatus } from '@/server/types';

const mockNode: NodeStatus = {
  nodeId: 'node-sg',
  name: '新加坡',
  kernel: 'xray',
  location: '新加坡',
  online: true,
  latency: 45,
  nodesCount: 12,
  subscriptionExists: true,
  clashExists: true,
  mihomoAvailable: true,
  kernelAccessible: true,
  version: '1.0.0',
  uptime: 3600,
};

const mockOfflineNode: NodeStatus = {
  nodeId: 'node-jp',
  name: '东京',
  kernel: 'sing-box',
  location: '东京',
  online: false,
  error: '连接超时',
};

const mockCluster: ClusterStatus = {
  totalNodes: 3,
  onlineNodes: 2,
  totalProxies: 35,
  nodes: [
    { ...mockNode },
    { ...mockOfflineNode },
    {
      nodeId: 'local',
      name: '本地',
      kernel: 'sing-box',
      location: '本地',
      online: true,
      latency: 0,
      nodesCount: 23,
      subscriptionExists: true,
      clashExists: true,
      mihomoAvailable: true,
      kernelAccessible: true,
      version: '1.0.0',
      uptime: 7200,
    },
  ],
  lastUpdated: new Date().toISOString(),
};

describe('ClusterOverview', () => {
  it('should render total nodes count', () => {
    render(<ClusterOverview cluster={mockCluster} />);
    expect(screen.getByText('3')).toBeDefined();
  });

  it('should render online nodes count', () => {
    render(<ClusterOverview cluster={mockCluster} />);
    expect(screen.getByText('2')).toBeDefined();
  });

  it('should render total proxies count', () => {
    render(<ClusterOverview cluster={mockCluster} />);
    expect(screen.getByText('35')).toBeDefined();
  });

  it('should render section heading', () => {
    render(<ClusterOverview cluster={mockCluster} />);
    expect(screen.getByText('集群总览')).toBeDefined();
  });
});

describe('NodeCard', () => {
  it('should render node name', () => {
    render(<NodeCard node={mockNode} />);
    expect(screen.getByRole('heading', { name: '新加坡' })).toBeDefined();
  });

  it('should render kernel type badge', () => {
    render(<NodeCard node={mockNode} />);
    expect(screen.getByText('Xray')).toBeDefined();
  });

  it('should render proxy count', () => {
    render(<NodeCard node={mockNode} />);
    expect(screen.getByText(/12.*代理/)).toBeDefined();
  });

  it('should show offline indicator for offline node', () => {
    render(<NodeCard node={mockOfflineNode} />);
    expect(screen.getByText(/连接超时/)).toBeDefined();
  });

  it('should expand to show detail on click', () => {
    render(<NodeCard node={mockNode} />);
    fireEvent.click(screen.getByRole('heading', { name: '新加坡' }));
    expect(screen.getByRole('dialog', { name: '新加坡' })).toBeDefined();
    expect(screen.getByText('节点角色')).toBeDefined();
  });
});

describe('NodeDetail', () => {
  const onClose = vi.fn();
  const onUpdate = vi.fn();
  const onHealthCheck = vi.fn();

  it('should render subscription file status', () => {
    render(
      <NodeDetail
        node={mockNode}
        isOpen={true}
        onClose={onClose}
        onUpdate={onUpdate}
        onHealthCheck={onHealthCheck}
      />
    );
    expect(screen.getByText('节点角色')).toBeDefined();
    expect(screen.getByText('节点源')).toBeDefined();
  });

  it('should render clash file status', () => {
    render(
      <NodeDetail
        node={{ ...mockNode, nodeId: 'local', name: '本地', location: '本地' }}
        isOpen={true}
        onClose={onClose}
        onUpdate={onUpdate}
        onHealthCheck={onHealthCheck}
      />
    );
    expect(screen.getByText('订阅文件')).toBeDefined();
    expect(screen.getByText('Clash 配置')).toBeDefined();
  });

  it('should render update and health check buttons', () => {
    render(
      <NodeDetail
        node={mockNode}
        isOpen={true}
        onClose={onClose}
        onUpdate={onUpdate}
        onHealthCheck={onHealthCheck}
      />
    );
    expect(screen.getByText('更新订阅')).toBeDefined();
    expect(screen.getByText('健康检查')).toBeDefined();
  });

  it('should show offline state for offline node', () => {
    render(
      <NodeDetail
        node={mockOfflineNode}
        isOpen={true}
        onClose={onClose}
        onUpdate={onUpdate}
        onHealthCheck={onHealthCheck}
      />
    );
    expect(screen.getByText(/离线/)).toBeDefined();
  });
});
