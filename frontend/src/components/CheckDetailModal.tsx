import type { CheckResult } from '../types'

const CHECK_REMEDIATION: Record<string, string> = {
  '1.1': 'Create cassandra user: useradd -g cassandra cassandra',
  '1.2': 'Update Cassandra version via package manager',
  '2.1': 'Enable authentication in cassandra.yaml: authenticator: PasswordAuthenticator',
  '2.2': 'Change default credentials in cassandra.yaml or Cassandra shell',
  '3.1': 'Restrict permissions using CQL GRANT/REVOKE statements',
  '3.2': 'Configure role-based access control in cassandra.yaml',
  '5.1': 'Enable TLS: server_encryption_options.enabled: true in cassandra.yaml',
  '5.2': 'Enable encryption at rest in cassandra.yaml',
}

export function CheckDetailModal({
  check,
  onClose,
}: {
  check: CheckResult
  onClose: () => void
}) {
  const remediation = CHECK_REMEDIATION[check.id] || `Run: cis-tool.sh harden ${check.section}`

  return (
    <div className="fixed inset-0 bg-black/80 flex items-center justify-center p-4 z-50">
      <div className="bg-gray-800 rounded-lg max-w-2xl w-full p-6 max-h-96 overflow-y-auto">
        {/* Header */}
        <div className="flex items-start justify-between mb-4">
          <div className="flex-1">
            <p className="text-xs text-gray-400 font-mono">Check {check.id}</p>
            <h3 className="text-lg font-bold mt-1">{check.title}</h3>
            <p className="text-xs text-gray-500 mt-1">Section: {check.section}</p>
          </div>
          <span
            className={`px-3 py-1 rounded-full text-xs font-bold flex-shrink-0 ml-4 ${
              check.status === 'PASS'
                ? 'bg-green-900 text-green-200'
                : check.status === 'FAIL'
                  ? 'bg-red-900 text-red-200'
                  : 'bg-yellow-900 text-yellow-200'
            }`}
          >
            {check.status}
          </span>
        </div>

        <div className="space-y-4 mb-6">
          {/* Type */}
          <div>
            <p className="text-xs font-semibold text-gray-400 mb-1">Check Type</p>
            <span className="text-xs bg-gray-700 px-2 py-1 rounded">
              {check.type === 'automated' ? '🤖 Automated' : '👤 Manual'}
            </span>
            {check.remediable && (
              <span className="text-xs bg-blue-900 px-2 py-1 rounded ml-2">✨ Remediable</span>
            )}
          </div>

          {/* Evidence */}
          {check.evidence && (
            <div>
              <p className="text-xs font-semibold text-gray-400 mb-1">📋 Evidence</p>
              <pre className="bg-gray-900 p-3 rounded text-xs text-gray-300 overflow-auto max-h-32 border border-gray-700">
                {check.evidence}
              </pre>
            </div>
          )}

          {/* Remediation */}
          {check.status === 'FAIL' && check.remediable && (
            <div>
              <p className="text-xs font-semibold text-gray-400 mb-1">💡 How to Fix</p>
              <code className="bg-blue-900/30 px-3 py-2 rounded text-xs text-blue-200 block border border-blue-800">
                {remediation}
              </code>
            </div>
          )}

          {check.status === 'FAIL' && !check.remediable && (
            <div className="bg-yellow-900/20 border border-yellow-800 p-3 rounded">
              <p className="text-xs text-yellow-200">
                ⚠️ This check requires manual remediation. Review CIS Benchmark v1.3.0 documentation
                for detailed guidance.
              </p>
            </div>
          )}
        </div>

        {/* Footer */}
        <button
          onClick={onClose}
          className="w-full px-4 py-2 bg-gray-700 hover:bg-gray-600 rounded-lg text-sm font-semibold transition-colors"
        >
          Close
        </button>
      </div>
    </div>
  )
}
