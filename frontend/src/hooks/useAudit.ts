import { useState, useCallback } from 'react'
import { api } from '../api'
import type { ClusterAuditReport } from '../types'

export type AuditState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: ClusterAuditReport }
  | { status: 'error'; message: string }

export function useAudit() {
  const [state, setState] = useState<AuditState>({ status: 'idle' })

  const runAudit = useCallback(async (section = 'all') => {
    setState({ status: 'loading' })
    try {
      const data = await api.auditCluster(section)
      setState({ status: 'success', data })
    } catch (err) {
      setState({ status: 'error', message: String(err) })
    }
  }, [])

  const reset = useCallback(() => setState({ status: 'idle' }), [])

  return { state, runAudit, reset }
}
