import type { AuditReport, NodeStatus } from '../types'

interface Props {
  report: AuditReport
  status?: NodeStatus
  selected: boolean
  onClick: () => void
}

function StatusDot({ ok, label }: { ok: boolean; label: string }) {
  return (
    <span
      role="img"
      aria-label={ok ? `${label} reachable` : `${label} unreachable`}
      className={`inline-block w-2.5 h-2.5 rounded-full mr-2 ${ok ? 'bg-green-400' : 'bg-red-500'}`}
    />
  )
}

export function NodeScoreCard({ report, status, selected, onClick }: Props) {
  const pct = report.score.compliance_pct
  const ringColor =
    pct >= 80 ? 'ring-green-500' : pct >= 60 ? 'ring-yellow-500' : 'ring-red-500'
  const pctColor =
    pct >= 80 ? 'text-green-400' : pct >= 60 ? 'text-yellow-400' : 'text-red-400'

  return (
    <button
      onClick={onClick}
      className={`w-full text-left rounded-xl p-4 border transition-all
        ${selected
          ? 'border-brand-500 bg-brand-900/40 ring-2 ' + ringColor
          : 'border-gray-700 bg-gray-900 hover:border-gray-500'
        }`}
    >
      <div className="flex items-center justify-between mb-3">
        <div>
          <p className="text-xs text-gray-400 font-mono mb-0.5">Node</p>
          <p className="text-sm font-semibold font-mono">{report.node}</p>
        </div>
        <div className="text-right">
          <p className={`text-2xl font-bold ${pctColor}`}>{pct}%</p>
          <p className="text-xs text-gray-400">compliance</p>
        </div>
      </div>

      {/* Progress bar */}
      <div className="w-full bg-gray-700 rounded-full h-1.5 mb-3">
        <div
          className={`h-1.5 rounded-full transition-all ${
            pct >= 80 ? 'bg-green-500' : pct >= 60 ? 'bg-yellow-500' : 'bg-red-500'
          }`}
          style={{ width: `${pct}%` }}
        />
      </div>

      {/* Check counts */}
      <div className="flex gap-3 text-xs">
        <span className="text-green-400">{report.score.passed} passed</span>
        <span className="text-red-400">{report.score.failed} failed</span>
        <span className="text-yellow-400">{report.score.needs_review} review</span>
      </div>

      {/* Node reachability */}
      {status && (
        <div className="mt-2 flex gap-3 text-xs text-gray-400">
          <span><StatusDot ok={status.reachable} label="SSH" />SSH</span>
          <span><StatusDot ok={status.cassandra_running} label="Cassandra" />Cassandra</span>
          {status.latency_ms != null && <span>{status.latency_ms}ms</span>}
        </div>
      )}

      {report.error && (
        <p className="mt-2 text-xs text-red-400 truncate">Error: {report.error}</p>
      )}
    </button>
  )
}
