import { Icon } from '@iconify/react'

interface StatCardProps {
  label: string
  value: string | number
  sub?: string
  icon: string
  status: 'success' | 'warning' | 'danger' | 'info'
}

export default function StatCard({ label, value, sub, icon, status }: StatCardProps) {
  const borderColor = {
    success: 'var(--fern)',
    warning: 'var(--marigold)',
    danger:  'var(--terracotta)',
    info:    'var(--info)',
  }[status]

  return (
    <div className="garden-card p-5" style={{ borderLeft: `3px solid ${borderColor}` }}>
      <div className="flex items-start justify-between">
        <div className="flex-1 min-w-0">
          <p className="text-xs font-semibold uppercase tracking-widest mb-2" style={{ color: 'var(--muted-foreground)' }}>
            {label}
          </p>
          <p className="text-2xl font-bold truncate" style={{ fontFamily: 'var(--font-display)', color: 'var(--foreground)' }}>
            {value}
          </p>
          {sub && (
            <p className="text-xs mt-1.5 truncate" style={{ color: 'var(--muted-foreground)' }}>
              {sub}
            </p>
          )}
        </div>
        <div className="flex-shrink-0 w-9 h-9 rounded-lg flex items-center justify-center" style={{ backgroundColor: 'var(--muted)' }}>
          <Icon icon={icon} className="w-[18px] h-[18px]" style={{ color: 'var(--foreground)' }} />
        </div>
      </div>
    </div>
  )
}
