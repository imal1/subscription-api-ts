"use client";

import { useState } from 'react';
import { Icon } from '@iconify/react';
import InfoRow from '@/components/shared/InfoRow';
import StatusBadge from '@/components/shared/StatusBadge';
import type { NodeStatus } from '@/server/types';

interface NodeDetailProps {
  node: NodeStatus;
  onClose: () => void;
  onUpdate?: (nodeId: string) => void;
  onHealthCheck?: (nodeId: string) => void;
}

export function NodeDetail({
  node,
  onClose,
  onUpdate,
  onHealthCheck,
}: NodeDetailProps) {
  const [updating, setUpdating] = useState(false);
  const [checking, setChecking] = useState(false);

  const formatUptime = (s?: number) => {
    if (!s && s !== 0) return '-';
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    return `${h}h ${m}m`;
  };

  const handleUpdate = async () => {
    if (!onUpdate) return;
    setUpdating(true);
    try {
      await onUpdate(node.nodeId);
    } finally {
      setUpdating(false);
    }
  };

  const handleHealthCheck = async () => {
    if (!onHealthCheck) return;
    setChecking(true);
    try {
      await onHealthCheck(node.nodeId);
    } finally {
      setChecking(false);
    }
  };

  const agentStatusLabel = (status?: string) => {
    switch (status) {
      case 'running': return '运行中';
      case 'stopped': return '已停止';
      case 'deploying': return '部署中';
      case 'error': return '异常';
      case 'not_deployed':
      default: return '未部署';
    }
  };

  const agentStatusColor = (status?: string) => {
    switch (status) {
      case 'running': return 'success';
      case 'error': return 'danger';
      case 'deploying': return 'warning';
      case 'not_deployed':
      default: return 'warning';
    }
  };

  return (
    <div
      className="garden-card p-5 mb-3 -mt-2 border-t-0"
      style={{
        borderTopLeftRadius: 0,
        borderTopRightRadius: 0,
        borderTop: 'none',
      }}
    >
      <div className="flex items-center justify-between mb-4">
        <h4
          className="text-sm font-semibold uppercase tracking-widest"
          style={{ color: 'var(--muted-foreground)', fontFamily: 'var(--font-display)' }}
        >
          节点详情
        </h4>
        <button
          onClick={onClose}
          className="p-1 rounded-md hover:bg-[var(--muted)] transition-colors"
          aria-label="关闭"
        >
          <Icon icon="ph:x-bold" className="w-4 h-4" style={{ color: 'var(--muted-foreground)' }} />
        </button>
      </div>

      {!node.online ? (
        <div className="garden-alert garden-alert-danger mb-4">
          <Icon icon="ph:warning-circle-bold" className="w-5 h-5 flex-shrink-0 mt-0.5" />
          <div>
            <p className="text-sm font-semibold">节点离线</p>
            <p className="text-sm mt-0.5 opacity-90">{node.error || '未知错误'}</p>
          </div>
        </div>
      ) : (
        <div className="space-y-1 divide-y" style={{ borderColor: 'var(--border)' }}>
          <InfoRow label="订阅文件">
            <StatusBadge
              label={node.subscriptionExists ? '已生成' : '未生成'}
              status={node.subscriptionExists ? 'success' : 'danger'}
            />
          </InfoRow>
          <InfoRow label="Clash 配置">
            <StatusBadge
              label={node.clashExists ? '已生成' : '未生成'}
              status={node.clashExists ? 'success' : 'danger'}
            />
          </InfoRow>
          <InfoRow label="Mihomo">
            <StatusBadge
              label={node.mihomoAvailable ? '可用' : '不可用'}
              status={node.mihomoAvailable ? 'success' : 'danger'}
            />
          </InfoRow>
          <InfoRow label="内核可访问">
            <StatusBadge
              label={node.kernelAccessible ? '可访问' : '不可访问'}
              status={node.kernelAccessible ? 'success' : 'danger'}
            />
          </InfoRow>
          <InfoRow label="代理数">
            <span className="font-mono text-sm" style={{ color: 'var(--foreground)' }}>
              {node.nodesCount ?? '-'}
            </span>
          </InfoRow>
          <InfoRow label="运行时间">
            <span className="text-sm" style={{ color: 'var(--muted-foreground)' }}>
              {formatUptime(node.uptime)}
            </span>
          </InfoRow>
          <InfoRow label="版本">
            <span className="font-mono text-xs" style={{ color: 'var(--muted-foreground)' }}>
              {node.version ?? '-'}
            </span>
          </InfoRow>
          {node.latency !== undefined && node.latency > 0 && (
            <InfoRow label="延迟">
              <span className="font-mono text-sm" style={{ color: 'var(--foreground)' }}>
                {node.latency}ms
              </span>
            </InfoRow>
          )}
        </div>
      )}

      {/* Agent deployment info — only for remote nodes */}
      {node.nodeId !== 'local' && node.agent && (
        <div className="mt-4 pt-3" style={{ borderTop: '1px solid var(--border)' }}>
          <h4
            className="text-xs font-semibold uppercase tracking-widest mb-2"
            style={{ color: 'var(--muted-foreground)', fontFamily: 'var(--font-display)' }}
          >
            部署信息
          </h4>
          <div className="space-y-1">
            <InfoRow label="Agent">
              <span className="text-sm" style={{ color: 'var(--foreground)' }}>
                {node.agent.version || '-'}
              </span>
              <StatusBadge
                label={agentStatusLabel(node.agent.status)}
                status={agentStatusColor(node.agent.status)}
              />
            </InfoRow>
            {node.agent.lastDeploy && (
              <InfoRow label="部署时间">
                <span className="text-sm" style={{ color: 'var(--muted-foreground)' }}>
                  {new Date(node.agent.lastDeploy).toLocaleString('zh-CN')}
                </span>
              </InfoRow>
            )}
          </div>
        </div>
      )}

      {/* Action buttons */}
      <div className="flex gap-3 mt-4 pt-3" style={{ borderTop: '1px solid var(--border)' }}>
        {onUpdate && (
          <button
            onClick={handleUpdate}
            disabled={updating}
            className="flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all active:scale-[0.98]"
            style={{
              backgroundColor: 'var(--primary)',
              color: 'var(--primary-foreground)',
              opacity: updating ? 0.6 : 1,
            }}
          >
            <Icon icon={updating ? 'ph:spinner-bold' : 'ph:arrow-clockwise-bold'} className={`w-4 h-4 ${updating ? 'animate-spin' : ''}`} />
            更新订阅
          </button>
        )}
        {onHealthCheck && (
          <button
            onClick={handleHealthCheck}
            disabled={checking}
            className="flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all active:scale-[0.98]"
            style={{
              backgroundColor: 'var(--secondary)',
              color: 'var(--secondary-foreground)',
              opacity: checking ? 0.6 : 1,
            }}
          >
            <Icon icon={checking ? 'ph:spinner-bold' : 'ph:heartbeat-bold'} className={`w-4 h-4 ${checking ? 'animate-spin' : ''}`} />
            健康检查
          </button>
        )}
      </div>
    </div>
  );
}
