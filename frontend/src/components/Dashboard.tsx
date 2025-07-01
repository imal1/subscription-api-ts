'use client';

import { useState, useEffect, useTransition } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { apiService, ApiStatus, UpdateResult } from '@/lib/api';
import { Icon } from '@iconify/react';

interface StatusCardProps {
  title: string;
  value: string | number;
  description?: string;
  icon?: React.ReactNode;
  status?: 'success' | 'error' | 'warning' | 'info';
}

const StatusCard = ({ title, value, description, icon, status = 'info' }: StatusCardProps) => {
  const statusColors = {
    success: 'text-green-600 bg-green-50 border-green-200',
    error: 'text-red-600 bg-red-50 border-red-200',
    warning: 'text-yellow-600 bg-yellow-50 border-yellow-200',
    info: 'text-blue-600 bg-blue-50 border-blue-200'
  };

  return (
    <Card className={`${statusColors[status]} transition-all hover:shadow-md`}>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium">{title}</CardTitle>
        {icon}
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">{value}</div>
        {description && (
          <p className="text-xs text-muted-foreground mt-1">{description}</p>
        )}
      </CardContent>
    </Card>
  );
};

const Dashboard = () => {
  const [status, setStatus] = useState<ApiStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [updateResult, setUpdateResult] = useState<UpdateResult | null>(null);
  
  // React 19.x useTransition for better UX
  const [isPending, startTransition] = useTransition();

  const fetchStatus = async () => {
    try {
      setError(null);
      const statusData = await apiService.getStatus();
      setStatus(statusData);
    } catch (err) {
      setError(err instanceof Error ? err.message : '获取状态失败');
    } finally {
      setLoading(false);
    }
  };

  const handleUpdate = async () => {
    // React 19.x useTransition for non-blocking updates
    startTransition(() => {
      setUpdating(true);
      setUpdateResult(null);
    });
    
    try {
      const result = await apiService.updateSubscription();
      startTransition(() => {
        setUpdateResult(result);
      });
      // 更新完成后重新获取状态
      await fetchStatus();
    } catch (err) {
      startTransition(() => {
        setError(err instanceof Error ? err.message : '更新失败');
      });
    } finally {
      startTransition(() => {
        setUpdating(false);
      });
    }
  };

  const handleDownload = (filename: string) => {
    const url = apiService.getDownloadUrl(filename);
    window.open(url, '_blank');
  };

  useEffect(() => {
    fetchStatus();
    // 设置定时刷新
    const interval = setInterval(fetchStatus, 30000); // 每30秒刷新一次
    return () => clearInterval(interval);
  }, []);

  const formatUptime = (seconds: number) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return `${hours}小时 ${minutes}分钟`;
  };

  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString('zh-CN');
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="flex items-center space-x-2">
          <Icon icon="mdi:loading" className="w-4 h-4 animate-spin" />
          <span>加载中...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">
            Subscription API Dashboard
          </h1>
          <p className="text-gray-600">
            TypeScript 订阅转换服务控制面板
          </p>
        </div>

        {/* Error Alert */}
        {error && (
          <Card className="mb-6 border-red-200 bg-red-50">
            <CardContent className="pt-6">
              <div className="flex items-center space-x-2 text-red-600">
                <Icon icon="mdi:alert-circle" className="w-5 h-5" />
                <span className="font-medium">错误</span>
              </div>
              <p className="text-red-700 mt-2">{error}</p>
            </CardContent>
          </Card>
        )}

        {/* Update Result */}
        {updateResult && (
          <Card className={`mb-6 ${updateResult.success ? 'border-green-200 bg-green-50' : 'border-red-200 bg-red-50'}`}>
            <CardContent className="pt-6">
              <div className={`flex items-center space-x-2 ${updateResult.success ? 'text-green-600' : 'text-red-600'}`}>
                {updateResult.success ? (
                  <Icon icon="mdi:check-circle" className="w-5 h-5" />
                ) : (
                  <Icon icon="mdi:close-circle" className="w-5 h-5" />
                )}
                <span className="font-medium">更新结果</span>
              </div>
              <p className={`mt-2 ${updateResult.success ? 'text-green-700' : 'text-red-700'}`}>
                {updateResult.message}
              </p>
              {updateResult.errors && updateResult.errors.length > 0 && (
                <div className="mt-2">
                  <p className="text-sm font-medium text-red-600">错误详情：</p>
                  <ul className="text-sm text-red-700 mt-1">
                    {updateResult.errors.map((error, index) => (
                      <li key={index}>• {error}</li>
                    ))}
                  </ul>
                </div>
              )}
            </CardContent>
          </Card>
        )}

        {/* Quick Actions */}
        <Card className="mb-6">
          <CardHeader>
            <CardTitle className="flex items-center space-x-2">
              <Icon icon="mdi:lightning-bolt" className="w-5 h-5" />
              <span>快速操作</span>
            </CardTitle>
            <CardDescription>
              常用功能的快速入口
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex flex-wrap gap-3">
              <Button 
                onClick={handleUpdate}
                disabled={updating}
                className="flex items-center space-x-2"
              >
                <Icon icon={updating ? "mdi:loading" : "mdi:refresh"} className={`w-4 h-4 ${updating ? 'animate-spin' : ''}`} />
                <span>{updating ? '更新中...' : '更新订阅'}</span>
              </Button>
              
              <Button 
                variant="outline"
                onClick={() => handleDownload('subscription.txt')}
                className="flex items-center space-x-2"
              >
                <Icon icon="mdi:download" className="w-4 h-4" />
                <span>下载订阅文件</span>
              </Button>
              
              <Button 
                variant="outline"
                onClick={() => handleDownload('clash.yaml')}
                className="flex items-center space-x-2"
              >
                <Icon icon="mdi:download" className="w-4 h-4" />
                <span>下载Clash配置</span>
              </Button>
              
              <Button 
                variant="outline"
                onClick={() => handleDownload('raw.txt')}
                className="flex items-center space-x-2"
              >
                <Icon icon="mdi:download" className="w-4 h-4" />
                <span>下载原始链接</span>
              </Button>
              
              <Button 
                variant="outline"
                onClick={fetchStatus}
                className="flex items-center space-x-2"
              >
                <Icon icon="mdi:refresh" className="w-4 h-4" />
                <span>刷新状态</span>
              </Button>
            </div>
          </CardContent>
        </Card>

        {status && (
          <>
            {/* Status Overview */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-6">
              <StatusCard
                title="订阅文件"
                value={status.subscriptionExists ? '✅ 已生成' : '❌ 未生成'}
                description={status.subscriptionExists && status.subscriptionLastUpdated 
                  ? `更新于 ${formatDate(status.subscriptionLastUpdated)}`
                  : '需要更新订阅'}
                icon={<Icon icon="mdi:file-document" className="w-4 h-4" />}
                status={status.subscriptionExists ? 'success' : 'error'}
              />
              
              <StatusCard
                title="Clash 配置"
                value={status.clashExists ? '✅ 已生成' : '❌ 未生成'}
                description={status.clashExists && status.clashLastUpdated 
                  ? `更新于 ${formatDate(status.clashLastUpdated)}`
                  : '需要更新订阅'}
                icon={<Icon icon="mdi:shield-check" className="w-4 h-4" />}
                status={status.clashExists ? 'success' : 'error'}
              />
              
              <StatusCard
                title="节点数量"
                value={status.nodesCount || 0}
                description="当前可用节点数"
                icon={<Icon icon="mdi:account-group" className="w-4 h-4" />}
                status={status.nodesCount && status.nodesCount > 0 ? 'success' : 'warning'}
              />
              
              <StatusCard
                title="服务运行时间"
                value={formatUptime(status.uptime)}
                description="当前服务实例运行时间"
                icon={<Icon icon="mdi:clock-outline" className="w-4 h-4" />}
                status="info"
              />
            </div>

            {/* Service Status */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center space-x-2">
                    <Icon icon="mdi:server" className="w-5 h-5" />
                    <span>服务状态</span>
                  </CardTitle>
                  <CardDescription>
                    依赖服务的运行状态
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-3">
                    <div className="flex items-center justify-between">
                      <span className="text-sm font-medium">Subconverter</span>
                      <div className="flex items-center space-x-2">
                        {status.subconverterRunning ? (
                          <Icon icon="mdi:check-circle" className="w-4 h-4 text-green-600" />
                        ) : (
                          <Icon icon="mdi:close-circle" className="w-4 h-4 text-red-600" />
                        )}
                        <span className={`text-sm ${status.subconverterRunning ? 'text-green-600' : 'text-red-600'}`}>
                          {status.subconverterRunning ? '运行中' : '离线'}
                        </span>
                      </div>
                    </div>
                    
                    <div className="flex items-center justify-between">
                      <span className="text-sm font-medium">Sing-box</span>
                      <div className="flex items-center space-x-2">
                        {status.singBoxAccessible ? (
                          <Icon icon="mdi:check-circle" className="w-4 h-4 text-green-600" />
                        ) : (
                          <Icon icon="mdi:close-circle" className="w-4 h-4 text-red-600" />
                        )}
                        <span className={`text-sm ${status.singBoxAccessible ? 'text-green-600' : 'text-red-600'}`}>
                          {status.singBoxAccessible ? '可访问' : '不可访问'}
                        </span>
                      </div>
                    </div>
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center space-x-2">
                    <Icon icon="mdi:chart-line" className="w-5 h-5" />
                    <span>文件信息</span>
                  </CardTitle>
                  <CardDescription>
                    生成文件的详细信息
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-3">
                    {status.subscriptionExists && (
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-medium">订阅文件大小</span>
                        <span className="text-sm text-gray-600">
                          {status.subscriptionSize ? formatFileSize(status.subscriptionSize) : 'N/A'}
                        </span>
                      </div>
                    )}
                    
                    {status.clashExists && (
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-medium">Clash 文件大小</span>
                        <span className="text-sm text-gray-600">
                          {status.clashSize ? formatFileSize(status.clashSize) : 'N/A'}
                        </span>
                      </div>
                    )}
                    
                    <div className="flex items-center justify-between">
                      <span className="text-sm font-medium">API 版本</span>
                      <span className="text-sm text-gray-600">{status.version}</span>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* API Documentation */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center space-x-2">
                  <Icon icon="mdi:earth" className="w-5 h-5" />
                  <span>API 接口文档</span>
                </CardTitle>
                <CardDescription>
                  可用的 API 端点和使用说明
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b">
                        <th className="text-left p-2">方法</th>
                        <th className="text-left p-2">端点</th>
                        <th className="text-left p-2">描述</th>
                        <th className="text-left p-2">操作</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr className="border-b">
                        <td className="p-2"><span className="bg-green-100 text-green-800 px-2 py-1 rounded text-xs">GET</span></td>
                        <td className="p-2 font-mono">/api/status</td>
                        <td className="p-2">获取服务状态</td>
                        <td className="p-2">
                          <Button variant="outline" size="sm" onClick={() => window.open('/api/status', '_blank')}>
                            测试
                          </Button>
                        </td>
                      </tr>
                      <tr className="border-b">
                        <td className="p-2"><span className="bg-green-100 text-green-800 px-2 py-1 rounded text-xs">GET</span></td>
                        <td className="p-2 font-mono">/api/update</td>
                        <td className="p-2">更新订阅</td>
                        <td className="p-2">
                          <Button variant="outline" size="sm" onClick={handleUpdate}>
                            执行
                          </Button>
                        </td>
                      </tr>
                      <tr className="border-b">
                        <td className="p-2"><span className="bg-green-100 text-green-800 px-2 py-1 rounded text-xs">GET</span></td>
                        <td className="p-2 font-mono">/subscription.txt</td>
                        <td className="p-2">下载订阅文件</td>
                        <td className="p-2">
                          <Button variant="outline" size="sm" onClick={() => handleDownload('subscription.txt')}>
                            下载
                          </Button>
                        </td>
                      </tr>
                      <tr className="border-b">
                        <td className="p-2"><span className="bg-green-100 text-green-800 px-2 py-1 rounded text-xs">GET</span></td>
                        <td className="p-2 font-mono">/clash.yaml</td>
                        <td className="p-2">下载 Clash 配置</td>
                        <td className="p-2">
                          <Button variant="outline" size="sm" onClick={() => handleDownload('clash.yaml')}>
                            下载
                          </Button>
                        </td>
                      </tr>
                      <tr className="border-b">
                        <td className="p-2"><span className="bg-green-100 text-green-800 px-2 py-1 rounded text-xs">GET</span></td>
                        <td className="p-2 font-mono">/raw.txt</td>
                        <td className="p-2">下载原始链接</td>
                        <td className="p-2">
                          <Button variant="outline" size="sm" onClick={() => handleDownload('raw.txt')}>
                            下载
                          </Button>
                        </td>
                      </tr>
                      <tr>
                        <td className="p-2"><span className="bg-green-100 text-green-800 px-2 py-1 rounded text-xs">GET</span></td>
                        <td className="p-2 font-mono">/health</td>
                        <td className="p-2">健康检查</td>
                        <td className="p-2">
                          <Button variant="outline" size="sm" onClick={() => window.open('/health', '_blank')}>
                            测试
                          </Button>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </CardContent>
            </Card>
          </>
        )}
      </div>
    </div>
  );
};

export default Dashboard;
