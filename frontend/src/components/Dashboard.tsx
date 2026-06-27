"use client";

import { Icon } from '@iconify/react'
import { useCallback, useEffect, useState } from 'react'
import { apiService } from '@/lib/api'
import { useClusterSSE } from '@/lib/useClusterSSE'
import type { ClusterStatus } from '@/server/types'
import type { DeployStep } from '@/server/services/deployManager'
import { ClusterOverview } from '@/components/cluster/ClusterOverview'
import { NodeCard } from '@/components/cluster/NodeCard'
import { BatchActions } from '@/components/cluster/BatchActions'
import { AddNodeForm } from '@/components/cluster/AddNodeForm'
import type { NodeFormData } from '@/components/cluster/AddNodeForm'
import { DeployProgressDialog } from '@/components/cluster/DeployProgressDialog'
import SectionHeading from '@/components/shared/SectionHeading'

interface DashboardProps {
  initialCluster?: ClusterStatus | null
  initialError?: string | null
}

export default function Dashboard({ initialCluster = null, initialError = null }: DashboardProps) {
  const cluster = useClusterSSE(initialCluster)
  const [error, setError] = useState<string | null>(initialError)
  const [hasAnimated, setHasAnimated] = useState(false)
  const [showAddNode, setShowAddNode] = useState(false)
  const [deployProgress, setDeployProgress] = useState<{ nodeName: string; steps: DeployStep[] } | null>(null)

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

  const handleUpdateAll = useCallback(async () => {
    setError(null)
    await apiService.triggerClusterUpdate()
  }, [])

  const handleHealthCheckAll = useCallback(async () => {
    setError(null)
    await apiService.clusterHealthCheck()
  }, [])

  const handleAddNode = useCallback(async (data: NodeFormData) => {
    setShowAddNode(false)
  }, [])

  const handleDeploy = useCallback(async (nodeId: string) => {
    setDeployProgress({ nodeName: nodeId, steps: [{ step: 'connect', status: 'running', message: '正在连接...', progress: 0 }] })
    try {
      await apiService.deployNode(nodeId)
    } catch (err) {
      setError(err instanceof Error ? err.message : '部署失败')
      setDeployProgress(null)
    }
  }, [])

  const handleUpdateAgent = useCallback(async (nodeId: string) => {
    try {
      await apiService.updateAgent(nodeId)
    } catch (err) {
      setError(err instanceof Error ? err.message : '更新失败')
    }
  }, [])

  const handleRestartAgent = useCallback(async (nodeId: string) => {
    try {
      await apiService.restartAgent(nodeId)
    } catch (err) {
      setError(err instanceof Error ? err.message : '重启失败')
    }
  }, [])

  const handleUninstallAgent = useCallback(async (nodeId: string) => {
    if (!confirm('确定要卸载 Agent？内核将保留。')) return
    try {
      await apiService.uninstallAgent(nodeId)
    } catch (err) {
      setError(err instanceof Error ? err.message : '卸载失败')
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

      {/* Batch Actions */}
      {cluster && (
        <BatchActions
          totalNodes={cluster.totalNodes}
          onlineNodes={cluster.onlineNodes}
          onUpdateAll={handleUpdateAll}
          onHealthCheckAll={handleHealthCheckAll}
        />
      )}

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
                onDeploy={handleDeploy}
                onUpdateAgent={handleUpdateAgent}
                onRestartAgent={handleRestartAgent}
                onUninstallAgent={handleUninstallAgent}
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

      {/* Add Node Form */}
      <AddNodeForm
        isOpen={showAddNode}
        onClose={() => setShowAddNode(false)}
        onSubmit={handleAddNode}
      />

      {/* Deploy Progress Dialog */}
      {deployProgress && (
        <DeployProgressDialog
          isOpen={!!deployProgress}
          nodeName={deployProgress.nodeName}
          steps={deployProgress.steps}
          onClose={() => setDeployProgress(null)}
        />
      )}

      {/* Floating add node button */}
      <button
        onClick={() => setShowAddNode(true)}
        className="fixed bottom-6 right-6 z-40 w-14 h-14 rounded-full flex items-center justify-center shadow-lg transition-all hover:scale-110 active:scale-95"
        style={{ backgroundColor: 'var(--primary)', color: 'var(--primary-foreground)' }}>
        <Icon icon="ph:plus-bold" className="w-6 h-6" />
      </button>
    </div>
  )
}
