"use client";

import { Icon } from '@iconify/react'
import { useCallback, useEffect, useState } from 'react'
import { apiService } from '@/lib/api'
import { useClusterSSE } from '@/lib/useClusterSSE'
import type { ClusterStatus } from '@/server/types'
import { ClusterOverview } from '@/components/cluster/ClusterOverview'
import { NodeCard } from '@/components/cluster/NodeCard'
import SectionHeading from '@/components/shared/SectionHeading'

interface DashboardProps {
  initialCluster?: ClusterStatus | null
  initialError?: string | null
}

export default function Dashboard({ initialCluster = null, initialError = null }: DashboardProps) {
  const cluster = useClusterSSE(initialCluster)
  const [error, setError] = useState<string | null>(initialError)
  const [hasAnimated, setHasAnimated] = useState(false)

  useEffect(() => {
    setHasAnimated(true)
  }, [])

  const handleUpdate = useCallback(async (nodeId: string) => {
    try {
      setError(null)
      await apiService.triggerClusterUpdate(nodeId)
    } catch (err) {
      setError(err instanceof Error ? err.message : '更新失败')
    }
  }, [])

  const handleHealthCheck = useCallback(async (nodeId: string) => {
    try {
      setError(null)
      await apiService.clusterHealthCheck(nodeId)
    } catch (err) {
      setError(err instanceof Error ? err.message : '健康检查失败')
    }
  }, [])

  return (
    <div className="px-6 py-8 max-w-5xl mx-auto space-y-8">
      {/* Error */}
      {error && (
        <div className="garden-alert garden-alert-danger">
          <Icon icon="ph:warning-circle-bold" className="w-5 h-5 flex-shrink-0 mt-0.5" />
          <div>
            <p className="text-sm font-semibold">获取状态失败</p>
            <p className="text-sm mt-0.5 opacity-90">{error}</p>
          </div>
        </div>
      )}

      {/* Cluster Overview */}
      {cluster && <ClusterOverview cluster={cluster} />}

      {/* Node Cards */}
      {cluster && cluster.nodes && cluster.nodes.length > 0 && (
        <section>
          <SectionHeading
            icon="ph:hard-drives-bold"
            title="节点列表"
            desc={`${cluster.nodes.length} 个节点`}
          />
          <div className={`grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 ${hasAnimated ? 'stagger-slide-up' : ''}`}>
            {cluster.nodes.map((node) => (
              <NodeCard
                key={node.nodeId}
                node={node}
                onUpdate={handleUpdate}
                onHealthCheck={handleHealthCheck}
              />
            ))}
          </div>
        </section>
      )}

      {/* Empty state — no cluster data */}
      {!cluster && !error && (
        <section className="text-center py-12">
          <Icon icon="ph:circles-three-plus" className="w-12 h-12 mx-auto mb-4" style={{ color: 'var(--muted-foreground)' }} />
          <p className="text-sm" style={{ color: 'var(--muted-foreground)' }}>等待集群数据...</p>
        </section>
      )}

      <footer className="text-center pt-4 pb-8">
        <p className="text-xs" style={{ color: 'var(--muted-foreground)' }}>
          Mio Garden · Next.js SSR · Botanical Garden Theme
        </p>
      </footer>
    </div>
  )
}
