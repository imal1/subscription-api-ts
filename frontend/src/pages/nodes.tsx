import type { GetServerSideProps } from 'next'
import { useCallback, useMemo, useState } from 'react'
import { Icon } from '@iconify/react'
import { toast } from 'sonner'
import { apiService } from '@/lib/api'
import type { ClusterStatus, KernelType, NodeStatus } from '@/server/types'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select } from '@/components/ui/select'
import { Separator } from '@/components/ui/separator'
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Textarea } from '@/components/ui/textarea'
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip'

interface NodesPageProps {
  initialCluster: ClusterStatus | null
  initialError: string | null
}

type Filter = 'all' | 'online' | 'offline' | 'undeployed'

const FILTERS: Array<{ value: Filter; label: string }> = [
  { value: 'all', label: '全部' },
  { value: 'online', label: '在线' },
  { value: 'offline', label: '异常' },
  { value: 'undeployed', label: '未部署' },
]

const kernelLabels: Record<string, string> = {
  'sing-box': 'Sing-Box',
  xray: 'Xray',
  v2ray: 'V2Ray',
}

function agentLabel(node: NodeStatus) {
  if (node.nodeId === 'local') return '主节点'
  switch (node.agent?.status) {
    case 'running': return '运行中'
    case 'deploying': return '部署中'
    case 'stopped': return '已停止'
    case 'error': return '异常'
    default: return '未部署'
  }
}

function agentVariant(node: NodeStatus): 'default' | 'secondary' | 'destructive' | 'outline' {
  if (node.nodeId === 'local') return 'secondary'
  if (node.agent?.status === 'running') return 'secondary'
  if (node.agent?.status === 'error') return 'destructive'
  return 'outline'
}

function emptyNodeForm() {
  return {
    name: '',
    host: '',
    kernel: 'sing-box' as KernelType,
    location: '',
    sshUser: 'root',
    sshKey: '',
    sshPassword: '',
  }
}

export default function NodesPage({ initialCluster, initialError }: NodesPageProps) {
  const [cluster, setCluster] = useState(initialCluster)
  const [error, setError] = useState<string | null>(initialError)
  const [filter, setFilter] = useState<Filter>('all')
  const [selectedNode, setSelectedNode] = useState<NodeStatus | null>(null)
  const [addOpen, setAddOpen] = useState(false)
  const [form, setForm] = useState(emptyNodeForm)
  const [busyNode, setBusyNode] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  const refresh = useCallback(async () => {
    const result = await apiService.getClusterStatus()
    if (result.success) setCluster(result.data as ClusterStatus)
  }, [])

  const nodes = useMemo(() => {
    const list = cluster?.nodes || []
    if (filter === 'online') return list.filter(node => node.online)
    if (filter === 'offline') return list.filter(node => !node.online)
    if (filter === 'undeployed') return list.filter(node => node.nodeId !== 'local' && !node.agent?.deployed)
    return list
  }, [cluster?.nodes, filter])

  const runNodeAction = useCallback(async (nodeId: string, action: () => Promise<unknown>) => {
    setBusyNode(nodeId)
    setError(null)
    try {
      await action()
      await refresh()
      toast.success('节点操作已触发')
    } catch (err) {
      const message = err instanceof Error ? err.message : '操作失败，请查看日志'
      setError(message)
      toast.error('节点操作失败', { description: message })
    } finally {
      setBusyNode(null)
    }
  }, [refresh])

  const submitAddNode = useCallback(async (event: React.FormEvent) => {
    event.preventDefault()
    setSubmitting(true)
    setError(null)
    try {
      const result = await apiService.addNode(form)
      if (!result.success) throw new Error(result.error || '添加节点失败')
      setAddOpen(false)
      setForm(emptyNodeForm())
      await refresh()
      toast.success('节点已添加', { description: form.name })
    } catch (err) {
      const message = err instanceof Error ? err.message : '添加节点失败'
      setError(message)
      toast.error('添加节点失败', { description: message })
    } finally {
      setSubmitting(false)
    }
  }, [form, refresh])

  return (
    <TooltipProvider>
    <main className="mx-auto max-w-7xl space-y-6 px-4 py-6 sm:px-6 lg:px-8">
      <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-normal text-foreground">节点</h1>
          <p className="mt-1 text-sm text-muted-foreground">管理主节点和远端 Agent，按状态筛选并执行健康检查或部署。</p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button variant="outline" onClick={refresh}>
            <Icon icon="ph:arrow-clockwise-bold" />
            刷新
          </Button>
          <Button onClick={() => setAddOpen(true)}>
            <Icon icon="ph:plus-bold" />
            添加节点
          </Button>
        </div>
      </div>

      {error ? (
        <Alert variant="destructive" className="flex gap-3">
          <Icon icon="ph:warning-circle-bold" className="mt-0.5 h-5 w-5" />
          <div>
            <AlertTitle>节点操作失败</AlertTitle>
            <AlertDescription>{error}</AlertDescription>
          </div>
        </Alert>
      ) : null}

      <div className="grid gap-4 md:grid-cols-3">
        <Card variant="elevated">
          <CardHeader className="pb-3"><CardDescription>节点总数</CardDescription><CardTitle className="text-3xl">{cluster?.totalNodes ?? 0}</CardTitle></CardHeader>
        </Card>
        <Card variant="elevated">
          <CardHeader className="pb-3"><CardDescription>在线节点</CardDescription><CardTitle className="text-3xl">{cluster?.onlineNodes ?? 0}</CardTitle></CardHeader>
        </Card>
        <Card variant="elevated">
          <CardHeader className="pb-3"><CardDescription>代理总数</CardDescription><CardTitle className="text-3xl">{cluster?.totalProxies ?? 0}</CardTitle></CardHeader>
        </Card>
      </div>

      <Card>
        <CardHeader className="gap-4 md:flex-row md:items-center md:justify-between">
          <div>
            <CardTitle className="text-base">节点列表</CardTitle>
            <CardDescription className="flex items-center gap-1">
              子节点只暴露节点源，订阅文件由主节点统一生成。
              <Tooltip>
                <TooltipTrigger asChild>
                  <Icon icon="ph:info-bold" className="h-3.5 w-3.5 cursor-help" />
                </TooltipTrigger>
                <TooltipContent>主节点负责生成 raw.txt、subscription.txt 和 clash.yaml</TooltipContent>
              </Tooltip>
            </CardDescription>
          </div>
          <Tabs value={filter} onValueChange={value => setFilter(value as Filter)}>
            <TabsList>
              {FILTERS.map(item => <TabsTrigger key={item.value} value={item.value}>{item.label}</TabsTrigger>)}
            </TabsList>
          </Tabs>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>节点</TableHead>
                <TableHead>状态</TableHead>
                <TableHead>Agent</TableHead>
                <TableHead>内核</TableHead>
                <TableHead>代理</TableHead>
                <TableHead>延迟</TableHead>
                <TableHead className="text-right">操作</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {nodes.map(node => (
                <TableRow key={node.nodeId}>
                  <TableCell>
                    <button className="text-left" onClick={() => setSelectedNode(node)}>
                      <span className="block font-medium">{node.name}</span>
                      <span className="block text-xs text-muted-foreground">{node.location} · {node.nodeId}</span>
                    </button>
                  </TableCell>
                  <TableCell>
                    <Badge variant={node.online ? 'secondary' : 'destructive'}>{node.online ? '在线' : '异常'}</Badge>
                  </TableCell>
                  <TableCell><Badge variant={agentVariant(node)}>{agentLabel(node)}</Badge></TableCell>
                  <TableCell>{kernelLabels[node.kernel] || node.kernel}</TableCell>
                  <TableCell className="font-mono">{node.nodesCount ?? '-'}</TableCell>
                  <TableCell className="font-mono">{node.latency ? `${node.latency}ms` : '-'}</TableCell>
                  <TableCell>
                    <div className="flex justify-end gap-2">
                      <Button size="sm" variant="outline" disabled={busyNode === node.nodeId} onClick={() => runNodeAction(node.nodeId, () => apiService.clusterHealthCheck(node.nodeId))}>检查</Button>
                      {node.nodeId !== 'local' && !node.agent?.deployed ? (
                        <Button size="sm" disabled={busyNode === node.nodeId} onClick={() => runNodeAction(node.nodeId, () => apiService.deployNode(node.nodeId))}>部署</Button>
                      ) : null}
                      {node.nodeId !== 'local' && node.agent?.status === 'running' ? (
                        <Button size="sm" variant="outline" disabled={busyNode === node.nodeId} onClick={() => runNodeAction(node.nodeId, () => apiService.restartAgent(node.nodeId))}>重启</Button>
                      ) : null}
                    </div>
                  </TableCell>
                </TableRow>
              ))}
              {nodes.length === 0 ? (
                <TableRow><TableCell colSpan={7} className="py-10 text-center text-muted-foreground">没有匹配的节点</TableCell></TableRow>
              ) : null}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <Dialog open={!!selectedNode} onOpenChange={open => { if (!open) setSelectedNode(null) }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{selectedNode?.name}</DialogTitle>
            <DialogDescription>{selectedNode?.location} · {selectedNode?.nodeId}</DialogDescription>
          </DialogHeader>
          <Separator />
          {selectedNode ? (
            <div className="grid gap-3 text-sm">
              {[
                ['在线状态', selectedNode.online ? '在线' : selectedNode.error || '异常'],
                ['内核', kernelLabels[selectedNode.kernel] || selectedNode.kernel],
                ['代理数量', selectedNode.nodesCount ?? '-'],
                ['版本', selectedNode.version || '-'],
                ['Agent', selectedNode.nodeId === 'local' ? '主节点' : `${agentLabel(selectedNode)} ${selectedNode.agent?.version || ''}`],
              ].map(([label, value]) => (
                <div key={label} className="flex items-center justify-between gap-4 rounded-2xl bg-[var(--surface-container)] p-3">
                  <span className="text-muted-foreground">{label}</span>
                  <span className="min-w-0 break-words text-right font-medium">{value}</span>
                </div>
              ))}
            </div>
          ) : null}
        </DialogContent>
      </Dialog>

      <Dialog open={addOpen} onOpenChange={setAddOpen}>
        <DialogContent className="max-h-[90vh] overflow-y-auto">
          <form onSubmit={submitAddNode}>
            <DialogHeader>
              <DialogTitle>添加节点</DialogTitle>
              <DialogDescription>添加远端节点后可立即进入部署页查看 Agent 安装进度。</DialogDescription>
            </DialogHeader>
            <div className="grid gap-4 py-4">
              <div className="grid gap-2">
                <Label htmlFor="node-name">节点名称</Label>
                <Input id="node-name" name="name" value={form.name} onChange={event => setForm(prev => ({ ...prev, name: event.target.value }))} placeholder="例如：东京节点…" required autoComplete="off" />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="node-host">主机地址</Label>
                <Input id="node-host" name="host" value={form.host} onChange={event => setForm(prev => ({ ...prev, host: event.target.value }))} placeholder="sg.example.com…" required autoComplete="off" />
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <div className="grid gap-2">
                  <Label htmlFor="node-kernel">内核类型</Label>
                  <Select id="node-kernel" name="kernel" value={form.kernel} onChange={event => setForm(prev => ({ ...prev, kernel: event.target.value as KernelType }))}>
                    <option value="sing-box">Sing-Box</option>
                    <option value="xray">Xray</option>
                    <option value="v2ray">V2Ray</option>
                  </Select>
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="node-location">地域标签</Label>
                  <Input id="node-location" name="location" value={form.location} onChange={event => setForm(prev => ({ ...prev, location: event.target.value }))} placeholder="例如：新加坡…" required autoComplete="off" />
                </div>
              </div>
              <div className="grid gap-2">
                <Label htmlFor="ssh-user">SSH 用户</Label>
                <Input id="ssh-user" name="sshUser" value={form.sshUser} onChange={event => setForm(prev => ({ ...prev, sshUser: event.target.value }))} autoComplete="off" />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="ssh-key">SSH 私钥</Label>
                <Textarea id="ssh-key" name="sshKey" value={form.sshKey} onChange={event => setForm(prev => ({ ...prev, sshKey: event.target.value }))} placeholder="-----BEGIN OPENSSH PRIVATE KEY-----…" className="font-mono" />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="ssh-password">SSH 密码</Label>
                <Input id="ssh-password" name="sshPassword" type="password" value={form.sshPassword} onChange={event => setForm(prev => ({ ...prev, sshPassword: event.target.value }))} placeholder="密钥为空时使用密码…" autoComplete="off" />
              </div>
            </div>
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setAddOpen(false)}>取消</Button>
              <Button type="submit" disabled={submitting}>
                <Icon icon={submitting ? 'ph:spinner-bold' : 'ph:plus-bold'} className={submitting ? 'animate-spin' : ''} />
                添加节点
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </main>
    </TooltipProvider>
  )
}

export const getServerSideProps: GetServerSideProps<NodesPageProps> = async () => {
  try {
    const { NodeManager } = await import('@/server/services/nodeManager')
    const cluster = await NodeManager.getInstance().getClusterStatus()
    return { props: { initialCluster: JSON.parse(JSON.stringify(cluster)), initialError: null } }
  } catch (error) {
    return { props: { initialCluster: null, initialError: error instanceof Error ? error.message : '获取节点失败' } }
  }
}
