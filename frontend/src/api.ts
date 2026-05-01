import type {
  ClusterAuditReport, AuditReport, NodeStatus, HardenRequest, HardenResult,
  StudentResponse, StudentCreate, StudentList
} from './types'

const BASE = import.meta.env.VITE_API_URL ?? ''

async function get<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`)
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
  return res.json() as Promise<T>
}

async function post<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
  return res.json() as Promise<T>
}

async function del<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`, { method: 'DELETE' })
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
  return res.json() as Promise<T>
}

export const api = {
  clusterStatus: () => get<NodeStatus[]>('/api/cluster/status'),
  auditCluster: (section = 'all') =>
    get<ClusterAuditReport>(`/api/audit/cluster?section=${encodeURIComponent(section)}`),
  auditNode: (ip: string, section = 'all') =>
    get<AuditReport>(`/api/audit/node/${ip}?section=${encodeURIComponent(section)}`),
  hardenNode: (ip: string, req: HardenRequest) =>
    post<HardenResult>(`/api/harden/node/${ip}`, req),
  auditStreamUrl: (ip: string, section = 'all') =>
    `${BASE}/api/audit/stream/${ip}?section=${encodeURIComponent(section)}`,
  
  // Student data management (backend endpoints remain student-oriented)
  createStudent: (data: StudentCreate) =>
    post<StudentResponse>('/api/data/students', data),
  listStudents: () =>
    get<StudentList>('/api/data/students'),
  deleteStudent: (id: string) =>
    del<{ status: string; id: string }>(`/api/data/students/${id}`),

  // Generic aliases for UI: keep these pointing at the same endpoints
  createRecord: (data: StudentCreate) =>
    post<StudentResponse>('/api/data/students', data),
  listRecords: () =>
    get<StudentList>('/api/data/students'),
  deleteRecord: (id: string) =>
    del<{ status: string; id: string }>(`/api/data/students/${id}`),
}
