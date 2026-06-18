import { Icon } from '@iconify/react'
import { useRouter } from 'next/router'
import ThemeToggle from '@/components/ThemeToggle'
import { useAppContext } from '@/context/AppContext'

const PAGE_TITLES: Record<string, string> = {
  '/':         '仪表盘',
  '/actions':  '操作',
  '/api-docs': 'API 文档',
}

export default function MobileHeader() {
  const { setMobileDrawerOpen } = useAppContext()
  const router = useRouter()
  const title = PAGE_TITLES[router.pathname] ?? 'Subscription Garden'

  return (
    <header
      className="sticky top-0 z-30 flex items-center justify-between px-4"
      style={{
        height: '56px',
        background: 'var(--background)',
        borderBottom: '1px solid var(--border)',
        boxShadow: '0 1px 4px rgba(0,0,0,0.04)',
      }}
    >
      <button
        onClick={() => setMobileDrawerOpen(true)}
        className="p-2 -ml-1 rounded-lg transition-colors duration-200"
        style={{ color: 'var(--foreground)', background: 'transparent', border: 'none', cursor: 'pointer' }}
        aria-label="打开菜单"
      >
        <Icon icon="ph:list-bold" className="w-5 h-5" />
      </button>

      <div className="flex items-center gap-1.5">
        <Icon icon="ph:plant-bold" className="w-4 h-4" style={{ color: 'var(--fern)' }} />
        <span
          className="font-semibold text-sm"
          style={{ fontFamily: 'var(--font-display)', color: 'var(--foreground)' }}
        >
          {title}
        </span>
      </div>

      <ThemeToggle />
    </header>
  )
}
