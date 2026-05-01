import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { NodeScoreCard } from '../components/NodeScoreCard'
import type { AuditReport, NodeStatus } from '../types'

const makeReport = (pct: number): AuditReport => ({
  node: '10.0.1.11',
  timestamp: '2026-04-01T10:00:00Z',
  score: {
    total: 10,
    automated: 8,
    manual: 2,
    passed: Math.round(pct / 10),
    failed: Math.round((100 - pct) / 10),
    needs_review: 0,
    compliance_pct: pct,
  },
  checks: [],
  error: null,
})

const nodeStatus: NodeStatus = {
  ip: '10.0.1.11',
  reachable: true,
  cassandra_running: true,
  latency_ms: 4.2,
}

describe('NodeScoreCard', () => {
  it('renders node IP', () => {
    render(<NodeScoreCard report={makeReport(80)} selected={false} onClick={vi.fn()} />)
    expect(screen.getByText('10.0.1.11')).toBeInTheDocument()
  })

  it('renders compliance percentage', () => {
    render(<NodeScoreCard report={makeReport(75)} selected={false} onClick={vi.fn()} />)
    expect(screen.getByText('75%')).toBeInTheDocument()
  })

  it('shows passed/failed counts', () => {
    render(<NodeScoreCard report={makeReport(80)} selected={false} onClick={vi.fn()} />)
    // passed = round(80/10) = 8
    expect(screen.getByText(/8 pass/)).toBeInTheDocument()
    expect(screen.getByText(/2 fail/)).toBeInTheDocument()
  })

  it('shows node status indicators when status prop provided', () => {
    render(
      <NodeScoreCard
        report={makeReport(80)}
        status={nodeStatus}
        selected={false}
        onClick={vi.fn()}
      />
    )
    expect(screen.getByText(/SSH/)).toBeInTheDocument()
    expect(screen.getByText(/Cassandra/)).toBeInTheDocument()
    expect(screen.getByText(/4\.2ms/)).toBeInTheDocument()
  })

  it('calls onClick when clicked', () => {
    const onClick = vi.fn()
    render(<NodeScoreCard report={makeReport(80)} selected={false} onClick={onClick} />)
    fireEvent.click(screen.getByRole('button'))
    expect(onClick).toHaveBeenCalledOnce()
  })

  it('shows ring class when selected', () => {
    const { container } = render(
      <NodeScoreCard report={makeReport(80)} selected={true} onClick={vi.fn()} />
    )
    const btn = container.querySelector('button')
    expect(btn?.className).toContain('ring-2')
  })

  it('shows error message when report has error', () => {
    const report = { ...makeReport(0), error: 'SSH connection failed' }
    render(<NodeScoreCard report={report} selected={false} onClick={vi.fn()} />)
    expect(screen.getByText(/SSH connection failed/)).toBeInTheDocument()
  })
})
