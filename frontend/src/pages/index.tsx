import type { GetServerSideProps } from 'next'
import Dashboard from '@/components/Dashboard'
import type { ApiStatus } from '@/lib/api'

interface HomeProps {
  initialStatus: ApiStatus | null
  initialError: string | null
}

export default function Home({ initialStatus, initialError }: HomeProps) {
  return <Dashboard initialStatus={initialStatus} initialError={initialError} />
}

// 服务端渲染：在同进程内直接调用 service 取实时状态，首屏即带数据
export const getServerSideProps: GetServerSideProps<HomeProps> = async () => {
  // 仅在服务端 import 后端 service，避免打进客户端 bundle
  const { MioBridgeService } = await import('@/server/services/mioBridgeService')
  try {
    const status = await MioBridgeService.getInstance().getStatus()
    return {
      props: {
        // 经 JSON 序列化保证可传递（去掉 undefined）
        initialStatus: JSON.parse(JSON.stringify(status)) as ApiStatus,
        initialError: null,
      },
    }
  } catch (error) {
    return {
      props: {
        initialStatus: null,
        initialError: error instanceof Error ? error.message : '获取状态失败',
      },
    }
  }
}
