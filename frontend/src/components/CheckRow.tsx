import { useState } from 'react'
import type { CheckResult } from '../types'

interface Props {
  check: CheckResult
  onRemediate?: (check: CheckResult) => void
}

const STATUS_CONFIG = {
  PASS: { label: 'PASS', bg: 'bg-green-900/40', text: 'text-green-400', border: 'border-green-700' },
  FAIL: { label: 'FAIL', bg: 'bg-red-900/40', text: 'text-red-400', border: 'border-red-700' },
  NEEDS_REVIEW: { label: 'REVIEW', bg: 'bg-yellow-900/40', text: 'text-yellow-400', border: 'border-yellow-700' },
}

export function CheckRow({ check, onRemediate }: Props) {
  const [expanded, setExpanded] = useState(false)
  const cfg = STATUS_CONFIG[check.status]

  return (
    <div className={`rounded-lg border ${cfg.border} ${cfg.bg} mb-2 overflow-hidden`}>
      {/* Header row */}
      <button
        className="w-full flex items-center justify-between px-4 py-3 text-left hover:bg-white/5 transition-colors"
        onClick={() => setExpanded(v => !v)}
      >
        <div className="flex items-center gap-3 min-w-0">
          <span className={`shrink-0 px-2 py-0.5 rounded text-xs font-bold ${cfg.text} bg-black/30`}>
            CIS {check.id}
          </span>
          <span className="text-sm truncate">{check.title}</span>
        </div>
        <div className="flex items-center gap-2 shrink-0 ml-2">
          <span className={`text-xs font-semibold ${cfg.text}`}>{cfg.label}</span>
          <span className="text-gray-500 text-xs">{expanded ? '▲' : '▼'}</span>
        </div>
      </button>

      {/* Expanded evidence drawer */}
      {expanded && (
        <div className="px-4 pb-4 border-t border-gray-700/50">
          <div className="mt-3 space-y-2">
            <div className="flex gap-2 text-xs text-gray-400">
              <span className="bg-gray-800 px-2 py-0.5 rounded">{check.type}</span>
              <span className="bg-gray-800 px-2 py-0.5 rounded">{check.section}</span>
            </div>
            {check.evidence && (
              <div>
                <p className="text-xs text-gray-400 mb-1">Evidence:</p>
                <pre className="text-xs bg-gray-950 rounded p-2 overflow-x-auto text-gray-300 whitespace-pre-wrap break-all">
                  {check.evidence}
                </pre>
              </div>
            )}
            {check.remediable && onRemediate && (
              <button
                onClick={(e) => { e.stopPropagation(); onRemediate(check) }}
                className="mt-1 px-3 py-1 rounded text-xs font-medium bg-brand-600 hover:bg-brand-700 text-white transition-colors"
              >
                🔧 Auto-Remediate
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
