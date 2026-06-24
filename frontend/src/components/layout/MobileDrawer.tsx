import { Icon } from '@iconify/react'
import Link from 'next/link'
import { useRouter } from 'next/router'
import { useEffect, useState } from 'react'
import { createPortal } from 'react-dom'
import { useAppContext } from '@/context/AppContext'
import ThemeToggle from '@/components/ThemeToggle'

const NAV_ITEMS = [
  { href: '/',         icon: 'ph:gauge-bold',     label: '仪表盘' },
  { href: '/actions',  icon: 'ph:lightning-bold',  label: '操作' },
  { href: '/api-docs', icon: 'ph:globe-bold',      label: 'API 文档' },
]

export default function MobileDrawer() {
  const { mobileDrawerOpen, setMobileDrawerOpen } = useAppContext()
  const router = useRouter()

  // Close on route change
  useEffect(() => {
    setMobileDrawerOpen(false)
  }, [router.pathname, setMobileDrawerOpen])

  // Close on Escape
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setMobileDrawerOpen(false)
    }
    document.addEventListener('keydown', handler)
    return () => document.removeEventListener('keydown', handler)
  }, [setMobileDrawerOpen])

  // Prevent scroll when open
  useEffect(() => {
    document.body.style.overflow = mobileDrawerOpen ? 'hidden' : ''
    return () => { document.body.style.overflow = '' }
  }, [mobileDrawerOpen])

  const [mounted, setMounted] = useState(false)
  useEffect(() => { setMounted(true) }, [])
  if (!mounted) return null

  return createPortal(
    <>
      {/* Backdrop */}
      <div
        className="fixed inset-0 z-50 lg:hidden"
        style={{
          backgroundColor: 'rgba(0,0,0,0.45)',
          opacity: mobileDrawerOpen ? 1 : 0,
          pointerEvents: mobileDrawerOpen ? 'auto' : 'none',
          transition: 'opacity 200ms ease',
          backdropFilter: 'blur(2px)',
        }}
        onClick={() => setMobileDrawerOpen(false)}
      />

      {/* Drawer */}
      <div
        className="fixed left-0 top-0 bottom-0 z-50 flex flex-col lg:hidden"
        style={{
          width: '280px',
          background: 'var(--sidebar)',
          borderRight: '1px solid var(--sidebar-border)',
          boxShadow: '4px 0 24px rgba(0,0,0,0.12)',
          transform: mobileDrawerOpen ? 'translateX(0)' : 'translateX(-100%)',
          transition: 'transform 200ms cubic-bezier(0.16, 1, 0.3, 1)',
        }}
      >
        {/* Header */}
        <div
          className="flex items-center justify-between px-4"
          style={{ borderBottom: '1px solid var(--sidebar-border)', minHeight: '56px' }}
        >
          <div className="flex items-center gap-2">
            <Icon
              icon="ph:plant-bold"
              className="w-5 h-5"
              style={{ color: 'var(--fern)', animation: 'sway 4s ease-in-out infinite' }}
            />
            <span
              className="font-semibold text-[0.9375rem]"
              style={{ fontFamily: 'var(--font-display)', color: 'var(--sidebar-foreground)' }}
            >
              Mio Garden
            </span>
          </div>
          <button
            onClick={() => setMobileDrawerOpen(false)}
            className="p-2 rounded-lg transition-colors duration-200"
            style={{ color: 'var(--muted-foreground)', background: 'transparent', border: 'none', cursor: 'pointer' }}
            onMouseEnter={e => (e.currentTarget.style.backgroundColor = 'var(--sidebar-accent)')}
            onMouseLeave={e => (e.currentTarget.style.backgroundColor = 'transparent')}
          >
            <Icon icon="ph:x-bold" className="w-4 h-4" />
          </button>
        </div>

        {/* Nav items */}
        <nav className="flex-1 py-3 space-y-0.5">
          {NAV_ITEMS.map(item => {
            const isActive = router.pathname === item.href
            return (
              <Link
                key={item.href}
                href={item.href}
                className="relative flex items-center gap-3 rounded-lg mx-2 px-3 py-2.5 transition-colors duration-200"
                style={{
                  backgroundColor: isActive ? 'var(--sidebar-accent)' : 'transparent',
                  color: isActive ? 'var(--sidebar-primary)' : 'var(--sidebar-foreground)',
                }}
              >
                {isActive && (
                  <span
                    className="absolute left-0 rounded-r-full"
                    style={{ top: '50%', transform: 'translateY(-50%)', width: '3px', height: '60%', background: 'var(--fern)' }}
                  />
                )}
                <Icon icon={item.icon} className="w-5 h-5 flex-shrink-0" />
                <span className="text-sm font-medium">{item.label}</span>
              </Link>
            )
          })}
        </nav>

        {/* Bottom */}
        <div className="border-t p-4 flex items-center gap-3" style={{ borderColor: 'var(--sidebar-border)' }}>
          <ThemeToggle />
          <span className="text-sm" style={{ color: 'var(--muted-foreground)' }}>切换主题</span>
        </div>
      </div>
    </>,
    document.body
  )
}
