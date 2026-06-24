"use client";

import { Icon } from '@iconify/react'
import { useCallback, useEffect, useState } from 'react'
import { apiService, type ApiStatus } from '@/lib/api'
import StatCard from '@/components/shared/StatCard'
import StatusBadge from '@/components/shared/StatusBadge'
import SectionHeading from '@/components/shared/SectionHeading'
import InfoRow from '@/components/shared/InfoRow'

interface DashboardProps {
  initialStatus?: ApiStatus | null
  initialError?: string | null
}

export default function Dashboard({ initialStatus = null, initialError = null }: DashboardProps) {
  const [status, setStatus] = useState<ApiStatus | null>(initialStatus)
  const [error, setError] = useState<string | null>(initialError)
  const [hasAnimated, setHasAnimated] = useState(false)

  const fetchStatus = useCallback(async () => {
    try {
      setError(null)
      const s = await apiService.getStatus()
      setStatus(s)
    } catch (err) {
      setError(err instanceof Error ? err.message : '获取状态失败')
    }
  }, [])

  useEffect(() => {
    setHasAnimated(true)
    fetchStatus()
    const timer = setInterval(fetchStatus, 30000)
    return () => clearInterval(timer)
  }, [fetchStatus])

  const formatUptime = (s: number) => {
    if (!s && s !== 0) return '-'
    const h = Math.floor(s / 3600)
    const m = Math.floor((s % 3600) / 60)
    return `${h}h ${m}m`
  }

  const formatSize = (b: number) => {
    if (!b) return '-'
    const i = Math.floor(Math.log(b) / Math.log(1024))
    return `${(b / Math.pow(1024, i)).toFixed(1)} ${['B', 'KB', 'MB', 'GB'][i]}`
  }

  const formatDate = (d: string) => new Date(d).toLocaleString('zh-CN')

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

      {/* Stat cards */}
      <section>
        <SectionHeading icon="ph:gauge-bold" title="状态概览" desc="服务与订阅文件的实时状态" />
        <div className={`grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 ${hasAnimated ? 'stagger-slide-up' : ''}`}>
          <StatCard
            label="订阅文件"
            value={status?.subscriptionExists ? '已生成' : '未生成'}
            sub={status?.subscriptionExists && status?.subscriptionLastUpdated
              ? formatDate(status.subscriptionLastUpdated) : '尚未更新'}
            icon="ph:file-text"
            status={status?.subscriptionExists ? 'success' : 'danger'}
          />
          <StatCard
            label="Clash 配置"
            value={status?.clashExists ? '已生成' : '未生成'}
            sub={status?.clashExists && status?.clashLastUpdated
              ? formatDate(status.clashLastUpdated) : '尚未更新'}
            icon="ph:shield-check"
            status={status?.clashExists ? 'success' : 'danger'}
          />
          <StatCard
            label="节点数量"
            value={status?.nodesCount ?? 0}
            sub="可用节点"
            icon="ph:tree-structure"
            status={status?.nodesCount && status.nodesCount > 0 ? 'success' : 'warning'}
          />
          <StatCard
            label="运行时间"
            value={status ? formatUptime(status.uptime) : '-'}
            sub="服务实例"
            icon="ph:clock"
            status="info"
          />
        </div>
      </section>

      {/* Services + Files */}
      <section>
        <SectionHeading icon="ph:hard-drives-bold" title="服务与文件" desc="依赖服务及生成文件详情" />
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {/* Services */}
          <div className="garden-card p-5">
            <h3 className="text-xs font-semibold uppercase tracking-widest mb-4" style={{ color: 'var(--muted-foreground)' }}>
              核心服务
            </h3>
            <div className="space-y-1 divide-y" style={{ borderColor: 'var(--border)' }}>
              <InfoRow label="Mihomo">
                <StatusBadge
                  label={status?.mihomoAvailable ? '可用' : '不可用'}
                  status={status?.mihomoAvailable ? 'success' : 'danger'}
                />
                {status?.mihomoVersion && (
                  <span className="text-xs" style={{ color: 'var(--muted-foreground)' }}>
                    v{status.mihomoVersion}
                  </span>
                )}
              </InfoRow>
              <InfoRow label="Sing-box">
                <StatusBadge
                  label={status?.singBoxAccessible ? '可访问' : '不可访问'}
                  status={status?.singBoxAccessible ? 'success' : 'danger'}
                />
              </InfoRow>
              <InfoRow label="API 版本">
                <span className="font-mono text-xs" style={{ color: 'var(--muted-foreground)' }}>
                  {status?.version ?? '-'}
                </span>
              </InfoRow>
            </div>
          </div>

          {/* File info */}
          <div className="garden-card p-5">
            <h3 className="text-xs font-semibold uppercase tracking-widest mb-4" style={{ color: 'var(--muted-foreground)' }}>
              文件信息
            </h3>
            <div className="space-y-1 divide-y" style={{ borderColor: 'var(--border)' }}>
              <InfoRow label="subscription.txt">
                {status?.subscriptionSize ? formatSize(status.subscriptionSize) : '-'}
              </InfoRow>
              <InfoRow label="clash.yaml">
                {status?.clashSize ? formatSize(status.clashSize) : '-'}
              </InfoRow>
              <InfoRow label="raw.txt">
                {status?.rawExists
                  ? <StatusBadge label="已生成" status="success" />
                  : <StatusBadge label="未生成" status="warning" />
                }
              </InfoRow>
            </div>
          </div>
        </div>
      </section>

      <footer className="text-center pt-4 pb-8">
        <p className="text-xs" style={{ color: 'var(--muted-foreground)' }}>
          Subscription Garden · Next.js SSR · Botanical Garden Theme
          {status?.version && <> · v{status.version}</>}
        </p>
        {status?.gitCommit && (
          <p className="text-[10px] mt-1 font-mono" style={{ color: 'var(--muted-foreground)' }}>
            {status.gitCommit}
            {status.buildTime && <> · built {new Date(status.buildTime).toLocaleDateString('zh-CN')}</>}
          </p>
        )}
      </footer>
    </div>
  )
}
