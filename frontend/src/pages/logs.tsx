import { useCallback, useEffect, useState } from 'react'
import { Icon } from '@iconify/react'
import { toast } from 'sonner'
import { apiService, type LogsResult } from '@/lib/api'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { ResizableHandle, ResizablePanel, ResizablePanelGroup } from '@/components/ui/resizable'
import { Select } from '@/components/ui/select'

const LEVELS = [
  { value: 'all', label: '全部级别' },
  { value: 'error', label: 'ERROR' },
  { value: 'warn', label: 'WARN' },
  { value: 'info', label: 'INFO' },
  { value: 'debug', label: 'DEBUG' },
]

export default function LogsPage() {
  const [logs, setLogs] = useState<LogsResult | null>(null)
  const [file, setFile] = useState('')
  const [level, setLevel] = useState('all')
  const [query, setQuery] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  const loadLogs = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const result = await apiService.getLogs(file, level, query)
      if (!result.success || !result.data) throw new Error(result.error || '读取日志失败')
      setLogs(result.data)
      if (!file) setFile(result.data.file)
      toast.success('日志已刷新', { description: `${result.data.file} · ${result.data.lines.length} 行` })
    } catch (err) {
      const message = err instanceof Error ? err.message : '读取日志失败'
      setError(message)
      toast.error('读取日志失败', { description: message })
    } finally {
      setLoading(false)
    }
  }, [file, level, query])

  useEffect(() => {
    loadLogs().catch(() => {})
  }, [])

  return (
    <main className="mx-auto max-w-7xl space-y-6 px-4 py-6 sm:px-6 lg:px-8">
      <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-normal text-foreground">日志</h1>
          <p className="mt-1 text-sm text-muted-foreground">查看服务端运行日志，过滤部署、转换和健康检查错误。</p>
        </div>
        <Button variant="outline" onClick={loadLogs} disabled={loading}>
          <Icon icon={loading ? 'ph:spinner-bold' : 'ph:arrow-clockwise-bold'} className={loading ? 'animate-spin' : ''} />
          刷新
        </Button>
      </div>

      {error ? (
        <Alert variant="destructive" className="flex gap-3">
          <Icon icon="ph:warning-circle-bold" className="mt-0.5 h-5 w-5" />
          <div>
            <AlertTitle>日志读取失败</AlertTitle>
            <AlertDescription>{error}</AlertDescription>
          </div>
        </Alert>
      ) : null}

      <Card className="min-h-0 md:min-h-[72vh]">
        <ResizablePanelGroup direction="horizontal" className="min-h-0 rounded-lg md:min-h-[72vh]">
          <ResizablePanel defaultSize={28} minSize={22}>
            <CardHeader>
              <CardTitle className="text-base">过滤器</CardTitle>
              <CardDescription>读取日志尾部 256 KB，避免页面加载过重。</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid gap-2">
                <Label htmlFor="log-file">日志文件</Label>
                <Select id="log-file" value={file} onChange={event => setFile(event.target.value)}>
                  {(logs?.files || ['combined.log', 'error.log']).map(item => <option key={item} value={item}>{item}</option>)}
                </Select>
              </div>
              <div className="grid gap-2">
                <Label htmlFor="log-level">级别</Label>
                <Select id="log-level" value={level} onChange={event => setLevel(event.target.value)}>
                  {LEVELS.map(item => <option key={item.value} value={item.value}>{item.label}</option>)}
                </Select>
              </div>
              <div className="grid gap-2">
                <Label htmlFor="log-query">关键词</Label>
                <Input id="log-query" value={query} onChange={event => setQuery(event.target.value)} placeholder="节点名、错误关键词或接口路径…" autoComplete="off" />
              </div>
              <Button className="w-full" onClick={loadLogs} disabled={loading}>应用过滤</Button>
            </CardContent>
          </ResizablePanel>
          <ResizableHandle withHandle />
          <ResizablePanel defaultSize={72} minSize={44}>
            <CardHeader>
              <CardTitle className="text-base">日志流</CardTitle>
              <CardDescription>{logs ? `${logs.file} · ${logs.lines.length} 行 · ${new Date(logs.updatedAt).toLocaleString('zh-CN')}` : '等待加载'}</CardDescription>
            </CardHeader>
            <CardContent>
              <pre className="max-h-[58vh] overflow-auto rounded-2xl bg-[var(--surface-container-lowest)] p-4 font-mono text-xs leading-6 text-foreground shadow-[var(--shadow-card)] md:max-h-[60vh] md:rounded-3xl">
                {logs?.lines.length ? logs.lines.join('\n') : '暂无日志内容'}
              </pre>
            </CardContent>
          </ResizablePanel>
        </ResizablePanelGroup>
      </Card>
    </main>
  )
}
