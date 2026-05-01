const GRAFANA_URL = import.meta.env.VITE_GRAFANA_URL ?? 'http://10.0.1.11:3001'

export function MonitoringPage() {
  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-xl font-bold">Security Monitoring</h2>
        <p className="text-sm text-gray-400 mt-0.5">
          Live Cassandra metrics via Prometheus + Grafana
        </p>
      </div>

      <div className="rounded-xl overflow-hidden border border-gray-700 bg-gray-900">
        <div className="flex items-center justify-between px-4 py-2 bg-gray-800 border-b border-gray-700">
          <span className="text-xs font-mono text-gray-400">Grafana Dashboard</span>
          <a
            href={`${GRAFANA_URL}/d/cis-cassandra-overview`}
            target="_blank"
            rel="noreferrer"
            className="text-xs text-brand-400 hover:underline"
          >
            Open full screen ↗
          </a>
        </div>
        <iframe
          src={`${GRAFANA_URL}/d/cis-cassandra-overview?orgId=1&refresh=30s&kiosk`}
          title="Grafana CIS Cassandra Dashboard"
          className="w-full"
          style={{ height: 'calc(100vh - 240px)', minHeight: '600px', border: 'none' }}
        />
      </div>

      {/* Quick links */}
      <div className="grid grid-cols-3 gap-3">
        {[
          { label: 'Grafana', url: GRAFANA_URL, icon: '📊' },
          { label: 'Prometheus', url: 'http://10.0.1.11:9090', icon: '🔥' },
          { label: 'API Docs', url: 'http://10.0.1.11:8000/docs', icon: '📖' },
        ].map(link => (
          <a
            key={link.label}
            href={link.url}
            target="_blank"
            rel="noreferrer"
            className="flex items-center gap-2 px-4 py-3 rounded-lg bg-gray-900 border border-gray-700 hover:border-gray-500 transition-colors text-sm"
          >
            <span className="text-xl">{link.icon}</span>
            <div>
              <p className="font-medium">{link.label}</p>
              <p className="text-xs text-gray-500 font-mono">{link.url}</p>
            </div>
          </a>
        ))}
      </div>
    </div>
  )
}
