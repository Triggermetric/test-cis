import { useState } from 'react'
import { api } from '../api'
import type { ClusterAuditReport } from '../types'

const DEMO_SCENARIOS = [
  { id: 'auth', label: 'Authentication (Section 2)', section: '2', color: 'bg-blue-900/30', border: 'border-blue-700' },
  { id: 'access', label: 'Access Control (Section 3)', section: '3', color: 'bg-purple-900/30', border: 'border-purple-700' },
  { id: 'encrypt', label: 'Encryption (Section 5)', section: '5', color: 'bg-green-900/30', border: 'border-green-700' },
  { id: 'all', label: 'Full Audit (All Sections)', section: 'all', color: 'bg-indigo-900/30', border: 'border-indigo-700' },
]

export function DemoPresetsPage() {
  const [activeScenario, setActiveScenario] = useState<string | null>(null)
  const [report, setReport] = useState<ClusterAuditReport | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const runDemo = async (scenario: (typeof DEMO_SCENARIOS)[0]) => {
    setActiveScenario(scenario.id)
    setLoading(true)
    setError(null)
    try {
      const r = await api.auditCluster(scenario.section)
      setReport(r)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Audit failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold mb-2">🎬 Demo Scenarios</h2>
        <p className="text-gray-400 text-sm">
          Run quick audits for specific CIS sections to see compliance status
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {DEMO_SCENARIOS.map((scenario) => (
          <button
            key={scenario.id}
            onClick={() => runDemo(scenario)}
            disabled={loading}
            className={`p-6 rounded-lg border-2 transition-all text-left ${
              activeScenario === scenario.id
                ? `${scenario.color} ${scenario.border}`
                : 'bg-gray-800/50 border-gray-700 hover:border-gray-600'
            } disabled:opacity-50 disabled:cursor-not-allowed`}
          >
            <p className="font-semibold">{scenario.label}</p>
            <p className="text-xs text-gray-400 mt-1">
              {loading && activeScenario === scenario.id ? '⟳ Running...' : `Section ${scenario.section}`}
            </p>
          </button>
        ))}
      </div>

      {error && (
        <div className="bg-red-900/30 border border-red-700 p-4 rounded-lg">
          <p className="text-sm text-red-200">❌ Error: {error}</p>
        </div>
      )}

      {report && (
        <div className="space-y-4">
          <div className="bg-gray-800 p-6 rounded-lg">
            <h3 className="font-bold mb-4 text-lg">📊 Audit Results</h3>

            {/* Summary Cards */}
            <div className="grid grid-cols-4 gap-4 mb-6">
              <div className="text-center">
                <p className="text-3xl font-bold text-green-400">
                  {report.cluster_score.passed}
                </p>
                <p className="text-xs text-gray-400 mt-1">Passed</p>
              </div>
              <div className="text-center">
                <p className="text-3xl font-bold text-red-400">
                  {report.cluster_score.failed}
                </p>
                <p className="text-xs text-gray-400 mt-1">Failed</p>
              </div>
              <div className="text-center">
                <p className="text-3xl font-bold text-yellow-400">
                  {report.cluster_score.needs_review}
                </p>
                <p className="text-xs text-gray-400 mt-1">Review</p>
              </div>
              <div className="text-center">
                <p className="text-3xl font-bold text-blue-400">
                  {report.cluster_score.compliance_pct}%
                </p>
                <p className="text-xs text-gray-400 mt-1">Compliant</p>
              </div>
            </div>

            {/* Per-Node Summary */}
            <div className="bg-gray-900 rounded-lg overflow-hidden">
              <table className="w-full text-sm">
                <thead className="border-b border-gray-700 bg-gray-800">
                  <tr>
                    <th className="px-4 py-2 text-left">Node</th>
                    <th className="px-4 py-2 text-center">Passed</th>
                    <th className="px-4 py-2 text-center">Failed</th>
                    <th className="px-4 py-2 text-center">Compliance</th>
                  </tr>
                </thead>
                <tbody>
                  {report.nodes.map((node) => (
                    <tr key={node.node} className="border-b border-gray-700 hover:bg-gray-800/50">
                      <td className="px-4 py-2 font-mono text-xs">{node.node}</td>
                      <td className="px-4 py-2 text-center text-green-400 font-semibold">
                        {node.score.passed}
                      </td>
                      <td className="px-4 py-2 text-center text-red-400 font-semibold">
                        {node.score.failed}
                      </td>
                      <td className="px-4 py-2 text-center font-semibold">
                        <span className={
                          node.score.compliance_pct >= 80 ? 'text-green-400' :
                          node.score.compliance_pct >= 60 ? 'text-yellow-400' :
                          'text-red-400'
                        }>
                          {node.score.compliance_pct}%
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          {/* Failed Checks Summary */}
          {report.nodes[0]?.checks.filter(c => c.status === 'FAIL').length > 0 && (
            <div className="bg-gray-800 p-6 rounded-lg">
              <h3 className="font-bold mb-4">⚠️ Failed Checks (First Node)</h3>
              <div className="space-y-3 max-h-64 overflow-y-auto">
                {report.nodes[0]?.checks
                  .filter(c => c.status === 'FAIL')
                  .slice(0, 5)
                  .map((check) => (
                    <div key={check.id} className="bg-gray-900 p-3 rounded border border-red-800/50">
                      <div className="flex items-start justify-between mb-1">
                        <p className="text-xs font-mono text-red-400">{check.id}</p>
                        {check.remediable && (
                          <span className="text-xs bg-blue-900 px-2 py-0.5 rounded">Remediable</span>
                        )}
                      </div>
                      <p className="text-sm text-gray-200">{check.title}</p>
                    </div>
                  ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
