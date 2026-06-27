"use client";

import { useState } from 'react';
import { Icon } from '@iconify/react';
import type { NodeStatus } from '@/server/types';
import { NodeDetail } from './NodeDetail';

interface NodeCardProps {
  node: NodeStatus;
  onUpdate?: (nodeId: string) => void;
  onHealthCheck?: (nodeId: string) => void;
}

export function NodeCard({ node, onUpdate, onHealthCheck }: NodeCardProps) {
  const [expanded, setExpanded] = useState(false);

  const kernelLabel = (k: string) => {
    switch (k) {
      case 'sing-box': return 'Sing-Box';
      case 'xray': return 'Xray';
      case 'v2ray': return 'V2Ray';
      default: return k;
    }
  };

  const kernelColor = (k: string) => {
    switch (k) {
      case 'sing-box': return { bg: 'var(--fern)', color: '#fff' };
      case 'xray': return { bg: 'var(--marigold)', color: '#1a1d1a' };
      case 'v2ray': return { bg: 'var(--info)', color: '#fff' };
      default: return { bg: 'var(--muted)', color: 'var(--muted-foreground)' };
    }
  };

  const formatUptime = (s?: number) => {
    if (!s && s !== 0) return '-';
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    return `${h}h ${m}m`;
  };

  return (
    <>
      <div
        className="garden-card p-5 cursor-pointer transition-all hover:shadow-[var(--shadow-card-hover)]"
        onClick={() => setExpanded(!expanded)}
        role="button"
        tabIndex={0}
        onKeyDown={(e) => { if (e.key === 'Enter') setExpanded(!expanded); }}
      >
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-3">
            <div className={`live-dot ${node.online ? 'live-dot-active' : ''}`} />
            <h3
              className="text-base font-semibold"
              style={{ fontFamily: 'var(--font-display)', color: 'var(--foreground)' }}
            >
              {node.name}
            </h3>
            {node.nodeId === 'local' && (
              <span
                className="text-[10px] px-2 py-0.5 rounded-full font-medium"
                style={{
                  backgroundColor: 'var(--primary)',
                  color: 'var(--primary-foreground)',
                }}
              >
                本机
              </span>
            )}
          </div>
          <div className="flex items-center gap-2">
            <span
              className="text-[10px] px-2 py-0.5 rounded-full font-medium"
              style={{
                backgroundColor: kernelColor(node.kernel).bg,
                color: kernelColor(node.kernel).color,
              }}
            >
              {kernelLabel(node.kernel)}
            </span>
            <Icon
              icon={expanded ? 'ph:caret-up-bold' : 'ph:caret-down-bold'}
              className="w-4 h-4"
              style={{ color: 'var(--muted-foreground)' }}
            />
          </div>
        </div>

        <div className="flex items-center gap-4 text-sm" style={{ color: 'var(--muted-foreground)' }}>
          <span className="flex items-center gap-1">
            <Icon icon="ph:map-pin" className="w-3.5 h-3.5" />
            {node.location}
          </span>
          {node.online && (
            <>
              <span className="flex items-center gap-1">
                <Icon icon="ph:tree-structure" className="w-3.5 h-3.5" />
                {node.nodesCount ?? '-'} 代理
              </span>
              {node.latency !== undefined && node.latency > 0 && (
                <span className="flex items-center gap-1">
                  <Icon icon="ph:lightning" className="w-3.5 h-3.5" />
                  {node.latency}ms
                </span>
              )}
            </>
          )}
          {!node.online && node.error && (
            <span className="flex items-center gap-1" style={{ color: 'var(--destructive)' }}>
              <Icon icon="ph:warning-circle-bold" className="w-3.5 h-3.5" />
              {node.error}
            </span>
          )}
        </div>
      </div>

      {expanded && (
        <NodeDetail
          node={node}
          onClose={() => setExpanded(false)}
          onUpdate={onUpdate}
          onHealthCheck={onHealthCheck}
        />
      )}
    </>
  );
}
