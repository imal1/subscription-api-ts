export default function MethodBadge({ method }: { method: string }) {
  const isGet = method === 'GET'
  return (
    <span
      className="inline-flex items-center rounded-md px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wider"
      style={isGet
        ? { background: 'var(--success-bg)', color: 'var(--fern)',    border: '1px solid var(--success-border)' }
        : { background: 'var(--warning-bg)', color: 'var(--warning)', border: '1px solid var(--warning-border)' }
      }
    >
      {method}
    </span>
  )
}
