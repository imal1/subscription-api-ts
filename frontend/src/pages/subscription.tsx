"use client";

import { useCallback, useState } from 'react'
import { Editor } from '@monaco-editor/react'
import { Icon } from '@iconify/react'
import { toast } from 'sonner'
import { apiService, type UpdateResult } from '@/lib/api'
import { useTheme } from '@/components/ThemeProvider'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { ResizableHandle, ResizablePanel, ResizablePanelGroup } from '@/components/ui/resizable'
import { Textarea } from '@/components/ui/textarea'

export default function SubscriptionPage() {
  const { theme } = useTheme()
  const [inputText, setInputText] = useState('')
  const [outputYaml, setOutputYaml] = useState('')
  const [loading, setLoading] = useState<'convert' | 'update' | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [updateResult, setUpdateResult] = useState<UpdateResult | null>(null)
  const [copied, setCopied] = useState(false)

  const handleConvert = useCallback(async () => {
    if (!inputText.trim()) {
      setError('请输入原始订阅文本')
      return
    }
    setLoading('convert')
    setError(null)
    try {
      const result = await apiService.convertContent(inputText)
      if (result.success && result.data?.clashConfig) {
        setOutputYaml(result.data.clashConfig)
        toast.success('转换完成', { description: `生成 ${result.data.configLength} 字符 YAML` })
      } else {
        const message = result.error || '转换失败，请检查输入内容'
        setError(message)
        toast.error('转换失败', { description: message })
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : '转换失败，请查看日志'
      setError(message)
      toast.error('转换失败', { description: message })
    } finally {
      setLoading(null)
    }
  }, [inputText])

  const handleUpdate = useCallback(async () => {
    setLoading('update')
    setError(null)
    setUpdateResult(null)
    try {
      const result = await apiService.updateSubscription()
      setUpdateResult(result)
      if (result.success) toast.success('订阅更新完成', { description: `生成 ${result.nodesCount} 个节点` })
      else toast.error('订阅更新失败', { description: result.message })
    } catch (err) {
      const message = err instanceof Error ? err.message : '更新失败，请查看日志'
      setError(message)
      toast.error('更新失败', { description: message })
    } finally {
      setLoading(null)
    }
  }, [])

  const handleCopy = useCallback(async () => {
    if (!outputYaml) return
    await navigator.clipboard.writeText(outputYaml)
    setCopied(true)
    toast.success('已复制 YAML')
    setTimeout(() => setCopied(false), 1600)
  }, [outputYaml])

  return (
    <main className="mx-auto max-w-7xl space-y-6 px-4 py-6 sm:px-6 lg:px-8">
      <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-normal text-foreground">订阅</h1>
          <p className="mt-1 text-sm text-muted-foreground">更新主节点产物，或把原始节点文本转换为 Clash YAML。</p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button onClick={handleUpdate} disabled={loading !== null}>
            <Icon icon={loading === 'update' ? 'ph:spinner-bold' : 'ph:arrows-clockwise-bold'} className={loading === 'update' ? 'animate-spin' : ''} />
            {loading === 'update' ? '更新中…' : '更新订阅'}
          </Button>
          {['subscription.txt', 'clash.yaml', 'raw.txt'].map(file => (
            <Button key={file} asChild variant="outline">
              <a href={apiService.getDownloadUrl(file)} target="_blank" rel="noreferrer">{file}</a>
            </Button>
          ))}
        </div>
      </div>

      {error ? (
        <Alert variant="destructive" className="flex gap-3">
          <Icon icon="ph:warning-circle-bold" className="mt-0.5 h-5 w-5" />
          <div>
            <AlertTitle>操作失败</AlertTitle>
            <AlertDescription>{error}</AlertDescription>
          </div>
        </Alert>
      ) : null}

      {updateResult ? (
        <Alert variant={updateResult.success ? 'success' : 'destructive'}>
          <div className="space-y-3">
            <div className="flex flex-wrap items-center gap-2">
              <Badge variant={updateResult.success ? 'secondary' : 'destructive'}>{updateResult.success ? '更新完成' : '更新失败'}</Badge>
              <span className="text-sm">{updateResult.message}</span>
            </div>
            {updateResult.success ? (
              <div className="flex flex-wrap gap-2">
                <Badge variant="outline">节点 {updateResult.nodesCount}</Badge>
                <Badge variant="outline">Clash {updateResult.clashGenerated ? '已生成' : '未生成'}</Badge>
                {updateResult.backupCreated ? <Badge variant="outline">备份 {updateResult.backupCreated}</Badge> : null}
              </div>
            ) : null}
          </div>
        </Alert>
      ) : null}

      <Card className="min-h-[680px]">
        <ResizablePanelGroup direction="horizontal" className="min-h-[680px] rounded-lg">
          <ResizablePanel defaultSize={48} minSize={32}>
          <CardHeader>
            <div className="flex items-start justify-between gap-3">
              <div>
                <CardTitle className="text-base">原始订阅文本</CardTitle>
                <CardDescription>支持 vmess、vless、ss、trojan、hysteria2、tuic。</CardDescription>
              </div>
              <Button variant="outline" size="sm" onClick={() => setInputText('')} disabled={!inputText}>清空</Button>
            </div>
          </CardHeader>
          <CardContent className="flex min-h-0 flex-1 flex-col gap-3">
            <Textarea
              className="min-h-[460px] flex-1 resize-none font-mono text-sm"
              value={inputText}
              onChange={event => setInputText(event.target.value)}
              placeholder="粘贴原始节点链接，每行一条…"
            />
            <Button onClick={handleConvert} disabled={loading !== null || !inputText.trim()}>
              <Icon icon={loading === 'convert' ? 'ph:spinner-bold' : 'ph:arrows-left-right-bold'} className={loading === 'convert' ? 'animate-spin' : ''} />
              {loading === 'convert' ? '转换中…' : '转换为 Clash YAML'}
            </Button>
          </CardContent>
          </ResizablePanel>

          <ResizableHandle withHandle />
          <ResizablePanel defaultSize={52} minSize={34}>
          <CardHeader>
            <div className="flex items-start justify-between gap-3">
              <div>
                <CardTitle className="text-base">Clash YAML 预览</CardTitle>
                <CardDescription>转换结果只在浏览器中预览，保存以服务端更新订阅为准。</CardDescription>
              </div>
              <Button variant="outline" size="sm" onClick={handleCopy} disabled={!outputYaml}>
                <Icon icon={copied ? 'ph:check-bold' : 'ph:copy-simple'} />
                {copied ? '已复制' : '复制'}
              </Button>
            </div>
          </CardHeader>
          <CardContent className="min-h-0 flex-1">
            <div className="h-[540px] overflow-hidden rounded-3xl bg-[var(--surface-container-lowest)] shadow-[var(--shadow-card)]">
              <Editor
                height="100%"
                defaultLanguage="yaml"
                value={outputYaml}
                options={{
                  readOnly: true,
                  minimap: { enabled: false },
                  lineNumbers: 'on',
                  wordWrap: 'on',
                  scrollBeyondLastLine: false,
                  fontSize: 13,
                  tabSize: 2,
                  automaticLayout: true,
                }}
                theme={theme === 'dark' ? 'vs-dark' : 'vs'}
              />
            </div>
          </CardContent>
          </ResizablePanel>
        </ResizablePanelGroup>
      </Card>
    </main>
  )
}
