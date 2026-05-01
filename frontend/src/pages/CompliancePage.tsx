import { useEffect, useState } from 'react'
import { useAudit } from '../hooks/useAudit'
import { useAuditStream } from '../hooks/useAuditStream'
import { NodeScoreCard } from '../components/NodeScoreCard'
import { CheckRow } from '../components/CheckRow'
import { AuditProgress } from '../components/AuditProgress'
import { api } from '../api'
import type { NodeStatus, AuditReport } from '../types'

export function CompliancePage() {
  const { state, runAudit } = useAudit()
  const { state: streamState, startStream } = useAuditStream()
  const [nodeStatuses, setNodeStatuses] = useState<NodeStatus[]>([])
  const [selectedNode, setSelectedNode] = useState<string | null>(null)
  const [remediating, setRemediating] = useState<string | null>(null)
  // C3: Track status fetch failures so the UI can warn the user
  const [statusError, setStatusError] = useState<boolean>(false)

  // Load cluster status on mount
  useEffect(() => {
    api.clusterStatus()
      .then(s => { setNodeStatuses(s); setStatusError(false) })
      .catch(() => setStatusError(true))
  }, [])

  const handleRunAudit = () => runAudit('all')

  const handleRemediate = async (nodeIp: string, checkId: string) => {
    setRemediating(`${nodeIp}-${checkId}`)
    try {
      await api.hardenNode(nodeIp, { section: checkId, dry_run: false })
      // Re-audit that node after remediation
      startStream(nodeIp, checkId)
    } finally {
      setRemediating(null)
    }
  }

  // I1: Respect explicit null (user deselected) — do NOT auto-fallback to nodes[0]
  const selectedReport: AuditReport | null =
    state.status === 'success' && selectedNode !== null
      ? (state.data.nodes.find(n => n.node === selectedNode) ?? null)
      : null

  return (
    <div className="space-y-6">
      {/* Header bar */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold">CIS Benchmark Compliance</h2>
          <p className="text-sm text-gray-400 mt-0.5">CIS Apache Cassandra 4.0 Benchmark v1.3.0</p>
        </div>
        <button
          onClick={handleRunAudit}
          disabled={state.status === 'loading'}
          className="px-5 py-2 rounded-lg bg-brand-600 hover:bg-brand-700 disabled:opacity-50 text-sm font-semibold transition-colors"
        >
          {state.status === 'loading' ? 'Auditing…' : 'Run Audit'}
        </button>
      </div>

      {/* C3: Backend connectivity warning */}
      {statusError && (
        <div className="rounded-lg bg-yellow-950 border border-yellow-700 px-4 py-2 text-xs text-yellow-300">
          Warning: Could not reach backend for node status — connectivity indicators unavailable
        </div>
      )}

      {/* Cluster summary banner */}
      {state.status === 'success' && (
        <div className="rounded-xl bg-gray-900 border border-gray-700 p-4">
          <div className="grid grid-cols-4 gap-4 text-center">
            <div>
              <p className="text-2xl font-bold text-white">
                {state.data.cluster_score.compliance_pct}%
              </p>
              <p className="text-xs text-gray-400">Cluster Compliance</p>
            </div>
            <div>
              <p className="text-2xl font-bold text-green-400">
                {state.data.cluster_score.passed}
              </p>
              <p className="text-xs text-gray-400">Passed</p>
            </div>
            <div>
              <p className="text-2xl font-bold text-red-400">
                {state.data.cluster_score.failed}
              </p>
              <p className="text-xs text-gray-400">Failed</p>
            </div>
            <div>
              <p className="text-2xl font-bold text-yellow-400">
                {state.data.cluster_score.needs_review}
              </p>
              <p className="text-xs text-gray-400">Needs Review</p>
            </div>
          </div>
        </div>
      )}

      {state.status === 'error' && (
        <div className="rounded-xl bg-red-950 border border-red-700 p-4 text-sm text-red-300">
          Audit failed: {state.message}
        </div>
      )}

      {state.status === 'idle' && (
        <div className="rounded-xl bg-gray-900 border border-gray-700 border-dashed p-8 text-center text-gray-500">
          <p className="text-4xl mb-2">Search</p>
          <p className="text-sm mt-1">Click "Run Audit" to scan all 3 nodes</p>
        </div>
      )}

      {/* Node cards */}
      {state.status === 'success' && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {state.data.nodes.map(report => (
            <NodeScoreCard
              key={report.node}
              report={report}
              status={nodeStatuses.find(s => s.ip === report.node)}
              selected={selectedNode === report.node}
              onClick={() => setSelectedNode(
                selectedNode === report.node ? null : report.node
              )}
            />
          ))}
        </div>
      )}

      {/* Check list for selected node */}
      {selectedReport && (
        <div>
          <div className="flex items-center justify-between mb-3">
            <h3 className="text-base font-semibold">
              Checks — {selectedReport.node}
            </h3>
            <button
              onClick={() => startStream(selectedReport.node)}
              className="px-3 py-1 text-xs rounded bg-gray-700 hover:bg-gray-600 transition-colors"
            >
              Re-audit node
            </button>
          </div>

          {/* Group checks by status */}
          {(['FAIL', 'NEEDS_REVIEW', 'PASS'] as const).map(status => {
            const checks = selectedReport.checks.filter(c => c.status === status)
            if (!checks.length) return null
            return (
              <div key={status} className="mb-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wider mb-2">
                  {status === 'FAIL' ? 'Failed' : status === 'NEEDS_REVIEW' ? 'Needs Review' : 'Passed'}
                  {' '}({checks.length})
                </p>
                {checks.map(check => (
                  <CheckRow
                    key={check.id}
                    check={check}
                    onRemediate={check.remediable
                      ? (c) => handleRemediate(selectedReport.node, c.id)
                      : undefined
                    }
                  />
                ))}
              </div>
            )
          })}
        </div>
      )}

      <AuditProgress state={streamState} />
      {remediating && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-gray-900 border border-gray-700 rounded-xl p-6 text-sm">
            <p className="animate-pulse">🔧 Remediating {remediating}…</p>
          </div>
        </div>
      )}
    </div>
  )
}
