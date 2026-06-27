"use client";

import { Icon } from '@iconify/react';
import type { DeployStep } from '@/server/services/deployManager';

interface DeployProgressDialogProps {
  isOpen: boolean;
  nodeName: string;
  steps: DeployStep[];
  onClose: () => void;
}

const STEP_LABELS: Record<string, string> = {
  connect: 'SSH 连接',
  bun: '安装 Bun',
  kernel: '安装内核',
  agent: '部署 Agent',
  start: '启动服务',
  verify: '健康验证',
  done: '完成',
};

const STATUS_ICONS: Record<string, string> = {
  pending: 'ph:circle',
  running: 'ph:spinner-bold',
  success: 'ph:check-circle-bold',
  error: 'ph:x-circle-bold',
};

const STATUS_COLORS: Record<string, string> = {
  pending: 'var(--muted-foreground)',
  running: 'var(--primary)',
  success: 'var(--fern)',
  error: 'var(--terracotta)',
};

export function DeployProgressDialog({ isOpen, nodeName, steps, onClose }: DeployProgressDialogProps) {
  if (!isOpen) return null;

  const lastStep = steps[steps.length - 1];
  const isDone = lastStep?.step === 'done' || lastStep?.status === 'error';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={isDone ? onClose : undefined}>
      <div className="garden-card p-6 max-w-md w-full mx-4" onClick={e => e.stopPropagation()}>
        <div className="flex items-center gap-3 mb-4">
          <Icon icon="ph:rocket-launch-bold" className="w-6 h-6" style={{ color: 'var(--primary)' }} />
          <h3 className="text-lg font-semibold" style={{ fontFamily: 'var(--font-display)' }}>
            正在部署 {nodeName}
          </h3>
        </div>

        {/* Progress bar */}
        <div className="mb-4 h-2 rounded-full overflow-hidden" style={{ backgroundColor: 'var(--muted)' }}>
          <div
            className="h-full rounded-full transition-all duration-500"
            style={{
              width: `${lastStep?.progress || 0}%`,
              backgroundColor: lastStep?.status === 'error' ? 'var(--terracotta)' : 'var(--fern)',
            }}
          />
        </div>

        {/* Steps */}
        <div className="space-y-2 mb-4">
          {steps.map((step) => (
            <div key={step.step} className="flex items-center gap-3">
              <Icon
                icon={step.status === 'running' ? 'ph:spinner-bold' : STATUS_ICONS[step.status] || 'ph:circle'}
                className={`w-5 h-5 ${step.status === 'running' ? 'animate-spin' : ''}`}
                style={{ color: STATUS_COLORS[step.status] || 'var(--muted-foreground)' }}
              />
              <span className="text-sm" style={{ color: step.status === 'pending' ? 'var(--muted-foreground)' : 'var(--foreground)' }}>
                {step.message || STEP_LABELS[step.step] || step.step}
              </span>
            </div>
          ))}
        </div>

        {isDone && (
          <button onClick={onClose}
            className="w-full px-4 py-2 rounded-lg text-sm font-medium transition-all"
            style={{ backgroundColor: 'var(--primary)', color: 'var(--primary-foreground)' }}>
            {lastStep?.status === 'error' ? '关闭' : '完成'}
          </button>
        )}
      </div>
    </div>
  );
}
