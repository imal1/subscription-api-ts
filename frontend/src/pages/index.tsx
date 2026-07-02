import type { GetServerSideProps } from 'next'
import Dashboard from '@/components/Dashboard'
import type { ClusterStatus } from '@/server/types'
import type { ApiStatus } from '@/lib/api'

interface HomeProps {
  initialCluster: ClusterStatus | null
  initialStatus: ApiStatus | null
  initialError: string | null
}

export default function Home({ initialCluster, initialStatus, initialError }: HomeProps) {
  return <Dashboard initialCluster={initialCluster} initialStatus={initialStatus} initialError={initialError} />
}

// 服务端渲染：同进程内直接调用服务，不自调用 HTTP
export const getServerSideProps: GetServerSideProps<HomeProps> = async () => {
  const { NodeManager } = await import('@/server/services/nodeManager')
  const { MioBridgeService } = await import('@/server/services/mioBridgeService')
  try {
    const [cluster, status] = await Promise.all([
      NodeManager.getInstance().getClusterStatus(),
      MioBridgeService.getInstance().getStatus(),
    ])
    return {
      props: {
        initialCluster: JSON.parse(JSON.stringify(cluster)) as ClusterStatus,
        initialStatus: JSON.parse(JSON.stringify(status)) as ApiStatus,
        initialError: null,
      },
    }
  } catch (error) {
    return {
      props: {
        initialCluster: null,
        initialStatus: null,
        initialError: error instanceof Error ? error.message : '获取集群状态失败',
      },
    }
  }
}
