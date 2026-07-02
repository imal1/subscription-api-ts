"use client";

import Link from 'next/link'
import { Icon } from '@iconify/react'
import { useCallback, useState } from 'react'
import { motion } from 'motion/react'
import { toast } from 'sonner'
import { Area, AreaChart, Bar, BarChart, CartesianGrid, XAxis, YAxis } from 'recharts'
import { apiService, type ApiStatus, type UpdateResult } from '@/lib/api'
import type { ClusterStatus } from '@/server/types'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { ChartContainer, ChartTooltip, ChartTooltipContent, type ChartConfig } from '@/components/ui/chart'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { ResizableHandle, ResizablePanel, ResizablePanelGroup } from '@/components/ui/resizable'
import { Separator } from '@/components/ui/separator'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip'

interface DashboardProps {
  initialCluster?: ClusterStatus | null
  initialStatus?: ApiStatus | null
  initialError?: string | null
}

const FILES = [
  { name: 'subscription.txt', label: '订阅文件', key: 'subscriptionExists' },
  { name: 'clash.yaml', label: 'Clash 配置', key: 'clashExists' },
  { name: 'raw.txt', label: '原始链接', key: 'rawExists' },
] as const

function formatDate(value?: string) {
  if (!value) return '-'
  return new Intl.DateTimeFormat('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value))
}

function formatBytes(value?: number) {
  if (!value) return '-'
  return new Intl.NumberFormat('zh-CN', { maximumFractionDigits: 1 }).format(value / 1024) + ' KB'
}

export default function Dashboard({ initialCluster = null, initialStatus = null, initialError = null }: DashboardProps) {
  const [status, setStatus] = useState(initialStatus)
  const [cluster, setCluster] = useState(initialCluster)
  const [updateResult, setUpdateResult] = useState<UpdateResult | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(initialError)

  const refresh = useCallback(async () => {
    const [nextStatus, nextCluster] = await Promise.all([
      apiService.getStatus(),
      apiService.getClusterStatus(),
    ])
    setStatus(nextStatus)
    if (nextCluster.success) setCluster(nextCluster.data as ClusterStatus)
  }, [])

  const handleUpdate = useCallback(async () => {
    setLoading(true)
    setError(null)
    setUpdateResult(null)
    try {
      const result = await apiService.updateSubscription()
      setUpdateResult(result)
      await refresh()
      if (result.success) toast.success('订阅更新完成', { description: `生成 ${result.nodesCount} 个节点` })
      else toast.error('订阅更新失败', { description: result.message })
    } catch (err) {
      const message = err instanceof Error ? err.message : '更新失败，请查看日志页定位原因'
      setError(message)
      toast.error('更新失败', { description: message })
    } finally {
      setLoading(false)
    }
  }, [refresh])

  const offlineNodes = cluster?.nodes.filter(node => !node.online) || []
  const missingFiles = status ? FILES.filter(file => !status[file.key]) : []
  const readyChecks = [
    { name: '订阅', value: status?.subscriptionExists ? 1 : 0 },
    { name: 'Clash', value: status?.clashExists ? 1 : 0 },
    { name: 'Raw', value: status?.rawExists ? 1 : 0 },
    { name: 'Mihomo', value: status?.mihomoAvailable ? 1 : 0 },
    { name: 'sing-box', value: status?.singBoxAccessible ? 1 : 0 },
  ]
  const healthData = [
    { name: '在线', nodes: cluster?.onlineNodes || 0 },
    { name: '异常', nodes: Math.max((cluster?.totalNodes || 0) - (cluster?.onlineNodes || 0), 0) },
    { name: '代理', nodes: cluster?.totalProxies || status?.nodesCount || 0 },
  ]
  const trendData = [
    { name: 'Raw', size: status?.rawExists ? Math.max(1, Math.round((status.subscriptionSize || 0) / 1024)) : 0 },
    { name: 'Clash', size: status?.clashExists ? Math.max(1, Math.round((status.clashSize || 0) / 1024)) : 0 },
  ]
  const readinessConfig = {
    value: { label: '状态', color: 'var(--fern)' },
  } satisfies ChartConfig
  const nodeConfig = {
    nodes: { label: '数量', color: 'var(--info)' },
  } satisfies ChartConfig
  const sizeConfig = {
    size: { label: 'KB', color: 'var(--marigold)' },
  } satisfies ChartConfig

  return (
    <TooltipProvider>
    <main className="mx-auto max-w-7xl space-y-6 px-4 py-6 sm:px-6 lg:px-8">
      <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-normal text-foreground">总览</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            订阅生成、集群健康和关键产物的当前状态。
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button onClick={handleUpdate} disabled={loading}>
            <Icon icon={loading ? 'ph:spinner-bold' : 'ph:arrows-clockwise-bold'} className={loading ? 'animate-spin' : ''} />
            {loading ? '更新中…' : '立即更新订阅'}
          </Button>
          <Button asChild variant="outline">
            <Link href="/subscription">
              <Icon icon="ph:code-bold" />
              打开订阅工作台
            </Link>
          </Button>
        </div>
      </div>

      {error ? (
        <Alert variant="destructive" className="flex gap-3">
          <Icon icon="ph:warning-circle-bold" className="mt-0.5 h-5 w-5 flex-shrink-0" />
          <div>
            <AlertTitle>状态异常</AlertTitle>
            <AlertDescription>{error}</AlertDescription>
          </div>
        </Alert>
      ) : null}

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <motion.div whileHover={{ y: -1 }} transition={{ duration: 0.16, ease: 'easeOut' }} className="rounded-lg">
        <Card variant="elevated" className="transition-shadow hover:shadow-[var(--shadow-card-hover)]">
          <CardHeader className="pb-3">
            <CardDescription className="flex items-center gap-1">
              订阅节点
              <Tooltip>
                <TooltipTrigger asChild>
                  <Icon icon="ph:info-bold" className="h-3.5 w-3.5 cursor-help" />
                </TooltipTrigger>
                <TooltipContent>来自当前生成产物或集群聚合状态</TooltipContent>
              </Tooltip>
            </CardDescription>
            <CardTitle className="text-3xl">{status?.nodesCount ?? cluster?.totalProxies ?? 0}</CardTitle>
          </CardHeader>
          <CardContent className="text-sm text-muted-foreground">
            Clash: {status?.clashExists ? '已生成' : '未生成'} · Raw: {status?.rawExists ? '已生成' : '未生成'}
          </CardContent>
        </Card>
        </motion.div>
        <motion.div whileHover={{ y: -1 }} transition={{ duration: 0.16, ease: 'easeOut' }} className="rounded-lg">
        <Card variant="elevated" className="transition-shadow hover:shadow-[var(--shadow-card-hover)]">
          <CardHeader className="pb-3">
            <CardDescription>集群在线</CardDescription>
            <CardTitle className="text-3xl">{cluster ? `${cluster.onlineNodes}/${cluster.totalNodes}` : '-'}</CardTitle>
          </CardHeader>
          <CardContent className="text-sm text-muted-foreground">
            {offlineNodes.length > 0 ? `${offlineNodes.length} 个节点异常` : '所有已注册节点正常'}
          </CardContent>
        </Card>
        </motion.div>
        <motion.div whileHover={{ y: -1 }} transition={{ duration: 0.16, ease: 'easeOut' }} className="rounded-lg">
        <Card variant="elevated" className="transition-shadow hover:shadow-[var(--shadow-card-hover)]">
          <CardHeader className="pb-3">
            <CardDescription>Mihomo</CardDescription>
            <CardTitle className="text-3xl">{status?.mihomoAvailable ? '可用' : '不可用'}</CardTitle>
          </CardHeader>
          <CardContent className="truncate text-sm text-muted-foreground">
            {status?.mihomoVersion || '未检测到版本'}
          </CardContent>
        </Card>
        </motion.div>
        <motion.div whileHover={{ y: -1 }} transition={{ duration: 0.16, ease: 'easeOut' }} className="rounded-lg">
        <Card variant="elevated" className="transition-shadow hover:shadow-[var(--shadow-card-hover)]">
          <CardHeader className="pb-3">
            <CardDescription>最近生成</CardDescription>
            <CardTitle className="text-3xl">{formatDate(status?.clashLastUpdated || status?.subscriptionLastUpdated)}</CardTitle>
          </CardHeader>
          <CardContent className="text-sm text-muted-foreground">
            Clash {formatBytes(status?.clashSize)}
          </CardContent>
        </Card>
        </motion.div>
      </div>

      {updateResult ? (
        <Alert variant={updateResult.success ? 'success' : 'destructive'} className="flex gap-3">
          <Icon icon={updateResult.success ? 'ph:check-circle-bold' : 'ph:x-circle-bold'} className="mt-0.5 h-5 w-5 flex-shrink-0" />
          <div className="min-w-0">
            <AlertTitle>{updateResult.success ? '更新完成' : '更新失败'}</AlertTitle>
            <AlertDescription className="break-words">{updateResult.message}</AlertDescription>
          </div>
        </Alert>
      ) : null}

      <div className="grid min-w-0 gap-4 xl:grid-cols-[0.9fr_1.1fr]">
        <Card className="min-w-0">
          <CardHeader>
            <CardTitle className="text-base">健康度</CardTitle>
            <CardDescription>产物、二进制和集群规模的概览图。</CardDescription>
          </CardHeader>
          <CardContent>
            <Tabs defaultValue="readiness">
              <TabsList>
                <TabsTrigger value="readiness">就绪</TabsTrigger>
                <TabsTrigger value="cluster">集群</TabsTrigger>
                <TabsTrigger value="size">文件</TabsTrigger>
              </TabsList>
              <TabsContent value="readiness">
                <ChartContainer config={readinessConfig} className="h-[260px] w-full">
                  <BarChart data={readyChecks} accessibilityLayer>
                    <CartesianGrid vertical={false} />
                    <XAxis dataKey="name" tickLine={false} axisLine={false} />
                    <YAxis hide domain={[0, 1]} />
                    <ChartTooltip content={<ChartTooltipContent />} />
                    <Bar dataKey="value" fill="var(--color-value)" radius={6} />
                  </BarChart>
                </ChartContainer>
              </TabsContent>
              <TabsContent value="cluster">
                <ChartContainer config={nodeConfig} className="h-[260px] w-full">
                  <BarChart data={healthData} accessibilityLayer>
                    <CartesianGrid vertical={false} />
                    <XAxis dataKey="name" tickLine={false} axisLine={false} />
                    <ChartTooltip content={<ChartTooltipContent />} />
                    <Bar dataKey="nodes" fill="var(--color-nodes)" radius={6} />
                  </BarChart>
                </ChartContainer>
              </TabsContent>
              <TabsContent value="size">
                <ChartContainer config={sizeConfig} className="h-[260px] w-full">
                  <AreaChart data={trendData} accessibilityLayer>
                    <CartesianGrid vertical={false} />
                    <XAxis dataKey="name" tickLine={false} axisLine={false} />
                    <ChartTooltip content={<ChartTooltipContent />} />
                    <Area dataKey="size" type="monotone" fill="var(--color-size)" fillOpacity={0.25} stroke="var(--color-size)" />
                  </AreaChart>
                </ChartContainer>
              </TabsContent>
            </Tabs>
          </CardContent>
        </Card>

        <Card className="min-h-0 min-w-0 md:min-h-[360px]">
          <ResizablePanelGroup direction="horizontal" className="min-h-0 rounded-[28px] md:min-h-[360px]">
            <ResizablePanel defaultSize={58} minSize={42}>
              <Tabs defaultValue="files" className="h-full">
                <CardHeader>
                  <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                    <div>
                      <CardTitle className="text-base">运行工作台</CardTitle>
                      <CardDescription>桌面可拖动中线调整产物和建议区域。</CardDescription>
                    </div>
                    <TabsList>
                      <TabsTrigger value="files">产物</TabsTrigger>
                      <TabsTrigger value="status">能力</TabsTrigger>
                    </TabsList>
                  </div>
                </CardHeader>
                <CardContent className="space-y-3">
                  <TabsContent value="files" className="mt-0 space-y-3">
                    {FILES.map(file => (
                      <div key={file.name} className="flex flex-col gap-3 rounded-2xl bg-[var(--surface-container)] p-3 sm:flex-row sm:items-center sm:justify-between">
                        <div className="min-w-0">
                          <p className="text-sm font-medium">{file.label}</p>
                          <p className="truncate font-mono text-xs text-muted-foreground">/{file.name}</p>
                        </div>
                        <div className="flex items-center gap-2">
                          <Badge variant={status?.[file.key] ? 'secondary' : 'destructive'}>
                            {status?.[file.key] ? '可用' : '缺失'}
                          </Badge>
                          <Button asChild size="sm" variant="outline">
                            <a href={apiService.getDownloadUrl(file.name)} target="_blank" rel="noreferrer">下载</a>
                          </Button>
                        </div>
                      </div>
                    ))}
                  </TabsContent>
                  <TabsContent value="status" className="mt-0 space-y-3">
                    {readyChecks.map(check => (
                      <div key={check.name} className="flex items-center justify-between rounded-2xl bg-[var(--surface-container)] p-3">
                        <span className="text-sm font-medium">{check.name}</span>
                        <Badge variant={check.value ? 'secondary' : 'destructive'}>{check.value ? '可用' : '不可用'}</Badge>
                      </div>
                    ))}
                  </TabsContent>
                </CardContent>
              </Tabs>
            </ResizablePanel>
            <ResizableHandle withHandle />
            <ResizablePanel defaultSize={42} minSize={32}>
              <CardHeader>
                <CardTitle className="text-base">下一步</CardTitle>
                <CardDescription>根据当前状态推荐处理路径。</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4 text-sm">
                {missingFiles.length > 0 ? (
                  <p className="text-muted-foreground">缺少 {missingFiles.map(file => file.name).join('、')}，先执行一次订阅更新。</p>
                ) : offlineNodes.length > 0 ? (
                  <p className="text-muted-foreground">有节点离线，进入节点页执行健康检查或重新部署 Agent。</p>
                ) : (
                  <p className="text-muted-foreground">核心产物和集群状态正常，可以下载配置或查看日志。</p>
                )}
                <Separator />
                <div className="flex flex-wrap gap-2">
                  <Button asChild variant="outline" size="sm"><Link href="/nodes">查看节点</Link></Button>
                  <Button asChild variant="outline" size="sm"><Link href="/deploy">查看部署</Link></Button>
                  <Button asChild variant="outline" size="sm"><Link href="/logs">查看日志</Link></Button>
                </div>
              </CardContent>
            </ResizablePanel>
          </ResizablePanelGroup>
        </Card>
      </div>

    </main>
    </TooltipProvider>
  )
}
