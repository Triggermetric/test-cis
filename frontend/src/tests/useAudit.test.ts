import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import { useAudit } from '../hooks/useAudit'
import { api } from '../api'
import type { ClusterAuditReport } from '../types'

vi.mock('../api', () => ({
  api: {
    auditCluster: vi.fn(),
  },
}))

const MOCK_CLUSTER: ClusterAuditReport = {
  timestamp: '2026-04-01T10:00:00Z',
  nodes: [],
  cluster_score: {
    total: 0, automated: 0, manual: 0,
    passed: 0, failed: 0, needs_review: 0, compliance_pct: 0,
  },
}

describe('useAudit', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('starts in idle state', () => {
    const { result } = renderHook(() => useAudit())
    expect(result.current.state.status).toBe('idle')
  })

  it('transitions to loading then success', async () => {
    vi.mocked(api.auditCluster).mockResolvedValue(MOCK_CLUSTER)

    const { result } = renderHook(() => useAudit())
    expect(result.current.state.status).toBe('idle')

    await act(async () => {
      result.current.runAudit()
    })

    expect(result.current.state.status).toBe('success')
    if (result.current.state.status === 'success') {
      expect(result.current.state.data).toEqual(MOCK_CLUSTER)
    }
  })

  it('transitions to error on API failure', async () => {
    vi.mocked(api.auditCluster).mockRejectedValue(new Error('Network error'))

    const { result } = renderHook(() => useAudit())

    await act(async () => {
      result.current.runAudit()
    })

    expect(result.current.state.status).toBe('error')
    if (result.current.state.status === 'error') {
      expect(result.current.state.message).toContain('Network error')
    }
  })

  it('reset returns to idle', async () => {
    vi.mocked(api.auditCluster).mockResolvedValue(MOCK_CLUSTER)

    const { result } = renderHook(() => useAudit())

    await act(async () => {
      result.current.runAudit()
    })

    expect(result.current.state.status).toBe('success')

    act(() => {
      result.current.reset()
    })

    expect(result.current.state.status).toBe('idle')
  })

  it('passes section parameter to api.auditCluster', async () => {
    vi.mocked(api.auditCluster).mockResolvedValue(MOCK_CLUSTER)

    const { result } = renderHook(() => useAudit())

    await act(async () => {
      result.current.runAudit('2')
    })

    expect(api.auditCluster).toHaveBeenCalledWith('2')
  })
})
