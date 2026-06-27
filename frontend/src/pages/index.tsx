import type { GetServerSideProps } from 'next'
import Dashboard from '@/components/Dashboard'
import type { ClusterStatus } from '@/server/types'

interface HomeProps {
  initialCluster: ClusterStatus | null
  initialError: string | null
}

export default function Home({ initialCluster, initialError }: HomeProps) {
  return <Dashboard initialCluster={initialCluster} initialError={initialError} />
}

// 服务端渲染：同进程内直接调用 NodeManager 获取集群状态
export const getServerSideProps: GetServerSideProps<HomeProps> = async () => {
  const { NodeManager } = await import('@/server/services/nodeManager')
  try {
    const cluster = await NodeManager.getInstance().getClusterStatus()
    return {
      props: {
        initialCluster: JSON.parse(JSON.stringify(cluster)) as ClusterStatus,
        initialError: null,
      },
    }
  } catch (error) {
    return {
      props: {
        initialCluster: null,
        initialError: error instanceof Error ? error.message : '获取集群状态失败',
      },
    }
  }
}
