// @vitest-environment jsdom
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import React from 'react';

describe('AddNodeForm', () => {
  it('should render form with required fields', async () => {
    const { AddNodeForm } = await import('@/components/cluster/AddNodeForm');
    render(
      React.createElement(AddNodeForm, {
        isOpen: true,
        onClose: () => {},
        onSubmit: () => {},
      })
    );
    expect(screen.getByText('SSH 连接信息')).toBeDefined();
  });
});

describe('DeployProgressDialog', () => {
  it('should render progress steps', async () => {
    const { DeployProgressDialog } = await import('@/components/cluster/DeployProgressDialog');
    const steps = [
      { step: 'connect' as const, status: 'success' as const, message: '连接成功', progress: 20 },
      { step: 'bun' as const, status: 'running' as const, message: '安装 Bun...', progress: 40 },
    ];
    render(
      React.createElement(DeployProgressDialog, {
        isOpen: true,
        nodeName: '新加坡',
        steps,
        onClose: () => {},
      })
    );
    expect(screen.getByText('正在部署 新加坡')).toBeDefined();
    expect(screen.getByText('连接成功')).toBeDefined();
    expect(screen.getByText('安装 Bun...')).toBeDefined();
  });
});
