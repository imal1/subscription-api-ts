import { Icon } from '@iconify/react'
import Link from 'next/link'
import { useRouter } from 'next/router'
import { memo } from 'react'
import ThemeToggle from '@/components/ThemeToggle'
import { useAppContext } from '@/context/AppContext'

const NAV_ITEMS = [
  { href: '/',         icon: 'ph:gauge-bold',     label: '仪表盘' },
  { href: '/actions',  icon: 'ph:lightning-bold',  label: '操作' },
  { href: '/api-docs', icon: 'ph:globe-bold',      label: 'API 文档' },
]

interface NavItemProps {
  href: string
  icon: string
  label: string
  isActive: boolean
  isCollapsed: boolean
}

function NavItem({ href, icon, label, isActive, isCollapsed }: NavItemProps) {
  return (
    <Link
      href={href}
      title={isCollapsed ? label : undefined}
      className="relative flex items-center rounded-lg mx-2 transition-colors duration-200"
      style={{
        gap: isCollapsed ? 0 : '0.75rem',
        padding: isCollapsed ? '0.625rem' : '0.625rem 0.75rem',
        justifyContent: isCollapsed ? 'center' : 'flex-start',
        backgroundColor: isActive ? 'var(--sidebar-accent)' : 'transparent',
        color: isActive ? 'var(--sidebar-primary)' : 'var(--sidebar-foreground)',
      }}
      onMouseEnter={e => {
        if (!isActive) (e.currentTarget as HTMLElement).style.backgroundColor = 'var(--sidebar-accent)'
      }}
      onMouseLeave={e => {
        if (!isActive) (e.currentTarget as HTMLElement).style.backgroundColor = 'transparent'
      }}
    >
      {/* Active indicator bar */}
      <span
        className="absolute left-0 rounded-r-full"
        style={{
          top: '50%',
          transform: 'translateY(-50%)',
          width: '3px',
          height: isActive ? '60%' : '0%',
          background: 'var(--fern)',
          transition: 'height 250ms cubic-bezier(0.34, 1.56, 0.64, 1)',
          opacity: isActive ? 1 : 0,
        }}
      />

      <Icon icon={icon} className="w-5 h-5 flex-shrink-0" />

      {/* Label fades in/out */}
      <span
        className="text-sm font-medium whitespace-nowrap overflow-hidden"
        style={{
          maxWidth: isCollapsed ? '0' : '160px',
          opacity: isCollapsed ? 0 : 1,
          transition: 'opacity 150ms ease, max-width 300ms cubic-bezier(0.16, 1, 0.3, 1)',
        }}
      >
        {label}
      </span>
    </Link>
  )
}

const Sidebar = memo(function Sidebar() {
  const { sidebarCollapsed, setSidebarCollapsed } = useAppContext()
  const router = useRouter()

  return (
    <aside
      className="fixed left-0 top-0 bottom-0 z-40 flex flex-col overflow-hidden"
      style={{
        width: sidebarCollapsed ? '64px' : '240px',
        transition: 'width 300ms cubic-bezier(0.16, 1, 0.3, 1)',
        background: 'var(--sidebar)',
        borderRight: '1px solid var(--sidebar-border)',
        boxShadow: '1px 0 8px rgba(0,0,0,0.04)',
      }}
    >
      {/* Logo */}
      <div
        className="flex items-center overflow-hidden"
        style={{
          padding: sidebarCollapsed ? '1.25rem 0' : '1.25rem 1rem',
          justifyContent: sidebarCollapsed ? 'center' : 'flex-start',
          gap: '0.625rem',
          borderBottom: '1px solid var(--sidebar-border)',
          minHeight: '64px',
          transition: 'padding 300ms cubic-bezier(0.16, 1, 0.3, 1)',
        }}
      >
        <Icon
          icon="ph:plant-bold"
          className="w-6 h-6 flex-shrink-0"
          style={{ color: 'var(--fern)', animation: 'sway 4s ease-in-out infinite' }}
        />
        <span
          className="font-semibold whitespace-nowrap overflow-hidden"
          style={{
            fontFamily: 'var(--font-display)',
            fontSize: '0.9375rem',
            color: 'var(--sidebar-foreground)',
            maxWidth: sidebarCollapsed ? '0' : '160px',
            opacity: sidebarCollapsed ? 0 : 1,
            transition: 'opacity 150ms ease, max-width 300ms cubic-bezier(0.16, 1, 0.3, 1)',
          }}
        >
          MioBridge
        </span>
      </div>

      {/* Nav items */}
      <nav className="flex-1 py-3 space-y-0.5 overflow-hidden">
        {NAV_ITEMS.map(item => (
          <NavItem
            key={item.href}
            {...item}
            isActive={router.pathname === item.href}
            isCollapsed={sidebarCollapsed}
          />
        ))}
      </nav>

      {/* Bottom controls */}
      <div
        className="border-t py-3 space-y-1"
        style={{ borderColor: 'var(--sidebar-border)' }}
      >
        {/* Theme toggle */}
        <div
          className="flex items-center mx-2 rounded-lg overflow-hidden transition-colors duration-200"
          style={{
            padding: sidebarCollapsed ? '0.625rem' : '0.375rem 0.75rem',
            justifyContent: sidebarCollapsed ? 'center' : 'flex-start',
            gap: sidebarCollapsed ? 0 : '0.75rem',
          }}
        >
          <div className="flex-shrink-0"><ThemeToggle /></div>
          <span
            className="text-sm whitespace-nowrap overflow-hidden"
            style={{
              color: 'var(--muted-foreground)',
              maxWidth: sidebarCollapsed ? '0' : '120px',
              opacity: sidebarCollapsed ? 0 : 1,
              transition: 'opacity 150ms ease, max-width 300ms cubic-bezier(0.16, 1, 0.3, 1)',
            }}
          >
            切换主题
          </span>
        </div>

        {/* Collapse button */}
        <button
          onClick={() => setSidebarCollapsed(!sidebarCollapsed)}
          title={sidebarCollapsed ? '展开侧边栏' : '收起侧边栏'}
          className="w-full flex items-center rounded-lg mx-2 transition-colors duration-200"
          style={{
            padding: sidebarCollapsed ? '0.625rem' : '0.625rem 0.75rem',
            justifyContent: sidebarCollapsed ? 'center' : 'flex-start',
            gap: '0.75rem',
            width: 'calc(100% - 1rem)',
            color: 'var(--muted-foreground)',
            background: 'transparent',
            border: 'none',
            cursor: 'pointer',
          }}
          onMouseEnter={e => (e.currentTarget.style.backgroundColor = 'var(--sidebar-accent)')}
          onMouseLeave={e => (e.currentTarget.style.backgroundColor = 'transparent')}
        >
          <Icon
            icon="ph:sidebar-bold"
            className="w-5 h-5 flex-shrink-0"
            style={{
              transform: sidebarCollapsed ? 'scaleX(-1)' : 'scaleX(1)',
              transition: 'transform 300ms cubic-bezier(0.16, 1, 0.3, 1)',
            }}
          />
          <span
            className="text-sm whitespace-nowrap overflow-hidden"
            style={{
              maxWidth: sidebarCollapsed ? '0' : '120px',
              opacity: sidebarCollapsed ? 0 : 1,
              transition: 'opacity 150ms ease, max-width 300ms cubic-bezier(0.16, 1, 0.3, 1)',
            }}
          >
            收起侧边栏
          </span>
        </button>

        {/* Version */}
        {!sidebarCollapsed && (
          <p
            className="text-center text-[10px] px-4 pb-1"
            style={{ color: 'var(--muted-foreground)', opacity: 0.6 }}
          >
            MioBridge
          </p>
        )}
      </div>
    </aside>
  )
})

export default Sidebar
