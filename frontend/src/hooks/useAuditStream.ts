import { useState, useCallback, useRef, useEffect } from 'react'
import { api } from '../api'
import type { AuditReport } from '../types'

export type StreamState =
  | { status: 'idle' }
  | { status: 'streaming'; node: string }
  | { status: 'done'; report: AuditReport }
  | { status: 'error'; message: string }

export function useAuditStream() {
  const [state, setState] = useState<StreamState>({ status: 'idle' })
  const esRef = useRef<EventSource | null>(null)

  // C1: Close EventSource on unmount to prevent resource leaks
  useEffect(() => {
    return () => {
      esRef.current?.close()
      esRef.current = null
    }
  }, [])

  const startStream = useCallback((
    nodeIp: string,
    section = 'all',
    onLine?: (raw: string) => void,   // optional per-line callback for live terminal
  ) => {
    esRef.current?.close()
    esRef.current = null
    setState({ status: 'streaming', node: nodeIp })

    const es = new EventSource(api.auditStreamUrl(nodeIp, section))
    esRef.current = es

    es.onmessage = (ev: MessageEvent) => {
      // Emit raw text line to caller before parsing (powers Audit Live terminal)
      if (onLine && typeof ev.data === 'string') onLine(ev.data)

      try {
        const payload = JSON.parse(ev.data as string) as Record<string, unknown>
        if (payload.status === 'done') {
          es.close()
          esRef.current = null
          return
        }
        if (payload.status === 'error') {
          setState({ status: 'error', message: String(payload.detail ?? 'Unknown error') })
          es.close()
          esRef.current = null
          return
        }
        // C2: Validate required fields before casting to AuditReport
        if (
          payload.node &&
          payload.score &&
          typeof (payload.score as Record<string, unknown>).total === 'number' &&
          Array.isArray(payload.checks)
        ) {
          setState({ status: 'done', report: payload as unknown as AuditReport })
          es.close()
          esRef.current = null
        }
      } catch {
        setState({ status: 'error', message: 'Failed to parse SSE payload' })
        es.close()
        esRef.current = null
      }
    }

    es.onerror = () => {
      setState({ status: 'error', message: 'SSE connection lost' })
      es.close()
      esRef.current = null
    }
  }, [])

  const stop = useCallback(() => {
    esRef.current?.close()
    esRef.current = null
    setState({ status: 'idle' })
  }, [])

  return { state, startStream, stop }
}
