import { useEffect, useState, useCallback } from 'react'
import { api } from '../api'
import { CheckDetailModal } from '../components/CheckDetailModal'
import type { ClusterAuditReport, NodeStatus, CheckResult } from '../types'
import demoReport from '../fixtures/demo-report.json'

// SVG arc gauge component
function ScoreGauge({ pct, size = 120 }: { pct: number; size?: number }) {
  const r = (size / 2) * 0.78
  const cx = size / 2
  const cy = size / 2
  const circumference = Math.PI * r  // half circle
  const dash = (pct / 100) * circumference
  const color = pct >= 80 ? '#22c55e' : pct >= 60 ? '#eab308' : '#ef4444'

  return (
    <svg width={size} height={size * 0.6} viewBox={`0 0 ${size} ${size * 0.6}`}>
      {/* Background arc */}
      <path
        d={`M ${cx - r} ${cy} A ${r} ${r} 0 0 1 ${cx + r} ${cy}`}
        fill="none"
        stroke="#374151"
        strokeWidth={size * 0.09}
        strokeLinecap="round"
      />
      {/* Value arc */}
      <path
        d={`M ${cx - r} ${cy} A ${r} ${r} 0 0 1 ${cx + r} ${cy}`}
        fill="none"
        stroke={color}
        strokeWidth={size * 0.09}
        strokeLinecap="round"
        strokeDasharray={`${dash} ${circumference}`}
        style={{ transition: 'stroke-dasharray 0.8s ease' }}
      />
      {/* Percentage text */}
      <text
        x={cx}
        y={cy - 2}
        textAnchor="middle"
        fill={color}
        fontSize={size * 0.22}
        fontWeight="bold"
        fontFamily="monospace"
      >
        {pct}%
      </text>
    </svg>
  )
}

export function DashboardPage() {
  const [report, setReport] = useState<ClusterAuditReport | null>(demoReport as any)
  const [statuses, setStatuses] = useState<NodeStatus[]>([])
  const [loading, setLoading] = useState(false)
  const [lastRun, setLastRun] = useState<string | null>('Pre-loaded fixture')
  const [error, setError] = useState<string | null>(null)
  const [selectedCheck, setSelectedCheck] = useState<CheckResult | null>(null)

  const fetchStatus = useCallback(() => {
    api.clusterStatus().then(setStatuses).catch(() => {})
  }, [])

  const runAudit = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const r = await api.auditCluster('all')
      setReport(r)
      setLastRun(new Date().toLocaleTimeString())
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Audit failed')
    } finally {
      setLoading(false)
    }
  }, [])

  // Load status on mount; auto-refresh status every 30s
  useEffect(() => {
    fetchStatus()
    const interval = setInterval(fetchStatus, 30_000)
    return () => clearInterval(interval)
  }, [fetchStatus])

  const clusterScore = report?.cluster_score

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold">Cluster Overview</h2>
          <p className="text-sm text-gray-400 mt-0.5">
            {lastRun ? `Last audit: ${lastRun}` : 'No audit run yet'}
          </p>
        </div>
        <button
          onClick={runAudit}
          disabled={loading}
          className="px-5 py-2 rounded-lg bg-brand-600 hover:bg-brand-700 disabled:opacity-50 text-sm font-semibold transition-colors"
        >
          {loading ? 'Auditing…' : 'Audit All Nodes'}
        </button>
      </div>

      {error && (
        <div className="rounded-xl bg-red-950 border border-red-700 p-4 text-sm text-red-300">
          Error: {error}
        </div>
      )}

      {/* Cluster score banner */}
      {clusterScore && (
        <div className="rounded-xl bg-gray-900 border border-gray-700 p-6">
          <div className="flex flex-col items-center mb-4">
            <ScoreGauge pct={clusterScore.compliance_pct} size={160} />
            <p className="text-sm text-gray-400 mt-1">Cluster Compliance Score</p>
          </div>
          <div className="grid grid-cols-4 gap-4 text-center border-t border-gray-700 pt-4">
            <div>
              <p className="text-2xl font-bold text-white">{clusterScore.total}</p>
              <p className="text-xs text-gray-400">Total Checks</p>
            </div>
            <div>
              <p className="text-2xl font-bold text-green-400">{clusterScore.passed}</p>
              <p className="text-xs text-gray-400">Passed</p>
            </div>
            <div>
              <p className="text-2xl font-bold text-red-400">{clusterScore.failed}</p>
              <p className="text-xs text-gray-400">Failed</p>
            </div>
            <div>
              <p className="text-2xl font-bold text-yellow-400">{clusterScore.needs_review}</p>
              <p className="text-xs text-gray-400">Needs Review</p>
            </div>
          </div>
        </div>
      )}

      {/* Per-node cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {(report?.nodes ?? [null, null, null]).map((node, i) => {
          const ip = node?.node ?? `10.0.1.1${i + 1}`
          const status = statuses.find(s => s.ip === ip)
          const pct = node?.score.compliance_pct ?? 0

          return (
            <div
              key={ip}
              className="rounded-xl bg-gray-900 border border-gray-700 p-5 flex flex-col items-center gap-3"
            >
              <p className="text-xs text-gray-400 font-mono self-start">Node {i + 1}</p>
              <p className="text-sm font-semibold font-mono self-start">{ip}</p>

              {node ? (
                <>
                  <ScoreGauge pct={pct} size={100} />
                  {/* Failed checks - clickable */}
                  {node.score.failed > 0 && (
                    <button
                      onClick={() => setSelectedCheck(node.checks.find(c => c.status === 'FAIL') || null)}
                      className="text-xs text-red-400 hover:text-red-300 underline"
                    >
                      View failed checks →
                    </button>
                  )}
                </>
              ) : (
                <div className="h-14 flex items-center">
                  <span className="text-xs text-gray-500">Run audit to see score</span>
                </div>
              )}

              {/* Reachability */}
              <div className="flex gap-3 text-xs w-full">
                <span className={status?.reachable ? 'text-green-400' : 'text-gray-500'}>
                  {status?.reachable ? 'reachable' : 'unreachable'} SSH
                </span>
                <span className={status?.cassandra_running ? 'text-green-400' : 'text-gray-500'}>
                  {status?.cassandra_running ? 'running' : 'stopped'} Cassandra
                </span>
                {status?.latency_ms != null && (
                  <span className="text-gray-400 ml-auto">{status.latency_ms}ms</span>
                )}
              </div>

              {node && (
                <div className="flex gap-2 text-xs w-full">
                  <span className="text-green-400">✅ {node.score.passed} pass</span>
                  <span className="text-red-400">❌ {node.score.failed} fail</span>
                  <span className="text-yellow-400">⚠️ {node.score.needs_review} review</span>
                </div>
              )}
            </div>
          )
        })}
      </div>

      {/* Empty state */}
      {!report && !loading && (
        <div className="rounded-xl bg-gray-900 border border-gray-700 border-dashed p-10 text-center text-gray-500">
          <p className="text-4xl mb-3">🛡️</p>
          <p className="font-medium text-gray-300">Ready to audit</p>
          <p className="text-sm mt-1">Click &quot;Audit All Nodes&quot; to scan the cluster against CIS Benchmark v1.3.0</p>
        </div>
      )}

      {/* Check Detail Modal */}
      {selectedCheck && (
        <CheckDetailModal check={selectedCheck} onClose={() => setSelectedCheck(null)} />
      )}
    </div>
  )
}
