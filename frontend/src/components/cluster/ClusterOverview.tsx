"use client";

import StatCard from '@/components/shared/StatCard';
import SectionHeading from '@/components/shared/SectionHeading';
import type { ClusterStatus } from '@/server/types';

interface ClusterOverviewProps {
  cluster: ClusterStatus;
}

export function ClusterOverview({ cluster }: ClusterOverviewProps) {
  return (
    <section>
      <SectionHeading
        icon="ph:graph-bold"
        title="集群总览"
        desc={`${cluster.totalNodes} 个节点 · ${cluster.onlineNodes} 在线 · 最后更新 ${new Date(cluster.lastUpdated).toLocaleTimeString('zh-CN')}`}
      />
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 stagger-slide-up">
        <StatCard
          label="节点总数"
          value={cluster.totalNodes}
          sub="已注册节点"
          icon="ph:hard-drives"
          status="info"
        />
        <StatCard
          label="在线节点"
          value={cluster.onlineNodes}
          sub={cluster.totalNodes > 0
            ? `${cluster.onlineNodes}/${cluster.totalNodes} 在线`
            : '无节点'}
          icon="ph:wifi-high"
          status={cluster.onlineNodes === cluster.totalNodes ? 'success' : 'warning'}
        />
        <StatCard
          label="代理总数"
          value={cluster.totalProxies}
          sub="全集群代理节点"
          icon="ph:tree-structure"
          status={cluster.totalProxies > 0 ? 'success' : 'warning'}
        />
      </div>
    </section>
  );
}
