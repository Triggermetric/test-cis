export type CheckStatus = 'PASS' | 'FAIL' | 'NEEDS_REVIEW'
export type CheckType = 'automated' | 'manual'
export type Tab = 'dashboard' | 'compliance' | 'audit-live' | 'monitoring' | 'demo' | 'data'

export interface CheckResult {
  id: string
  title: string
  status: CheckStatus
  type: CheckType
  section: string
  evidence: string
  remediable: boolean
}

export interface AuditScore {
  total: number
  automated: number
  manual: number
  passed: number
  failed: number
  needs_review: number
  compliance_pct: number
}

export interface AuditReport {
  node: string
  timestamp: string
  score: AuditScore
  checks: CheckResult[]
  error?: string | null
}

export interface ClusterAuditReport {
  timestamp: string
  nodes: AuditReport[]
  cluster_score: AuditScore
}

export interface NodeStatus {
  ip: string
  reachable: boolean
  cassandra_running: boolean
  latency_ms: number | null
}

export interface HardenRequest {
  section: string
  dry_run: boolean
}

export interface StudentResponse {
  id: string
  first_name: string
  last_name: string
  email: string
  student_id: string
  created_at: string
}

export interface StudentCreate {
  first_name: string
  last_name: string
  email: string
  student_id: string
}

export interface StudentList {
  students: StudentResponse[]
  total: number
}

// Generic aliases for demo UI (keeps backend Student API unchanged)
export type RecordResponse = StudentResponse
export type RecordCreate = StudentCreate
export type RecordList = StudentList

export interface HardenResult {
  node: string
  section: string
  exit_code: number
  stdout: string
  stderr: string
  success: boolean
}

export interface StreamLogLine {
  ts: string       // ISO timestamp
  level: 'info' | 'pass' | 'fail' | 'warn'
  message: string
}
