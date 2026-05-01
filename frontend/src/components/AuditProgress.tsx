import type { StreamState } from '../hooks/useAuditStream'

interface Props {
  state: StreamState
}

export function AuditProgress({ state }: Props) {
  if (state.status === 'idle') return null

  return (
    <div className="fixed bottom-6 right-6 z-50 max-w-sm w-full">
      <div className={`rounded-xl p-4 shadow-2xl border backdrop-blur-sm
        ${state.status === 'error'
          ? 'bg-red-950/90 border-red-700'
          : state.status === 'done'
          ? 'bg-green-950/90 border-green-700'
          : 'bg-gray-900/90 border-gray-700'
        }`}
      >
        {state.status === 'streaming' && (
          <>
            <div className="flex items-center gap-2 mb-2">
              <div className="w-4 h-4 rounded-full border-2 border-brand-400 animate-spin" />
              <span className="text-sm font-medium">Auditing {state.node}…</span>
            </div>
            <div className="w-full bg-gray-700 rounded-full h-1">
              <div className="h-1 rounded-full bg-brand-500 animate-pulse w-3/4" />
            </div>
          </>
        )}
        {state.status === 'done' && (
          <p className="text-sm font-medium text-green-400">
            Audit complete — {state.report.score.passed}/{state.report.score.total} checks passed
          </p>
        )}
        {state.status === 'error' && (
          <p className="text-sm font-medium text-red-400">Error: {state.message}</p>
        )}
      </div>
    </div>
  )
}
