import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { CheckRow } from '../components/CheckRow'
import type { CheckResult } from '../types'

const makeCheck = (status: CheckResult['status'], remediable = false): CheckResult => ({
  id: '2.1',
  title: 'Ensure authentication is enabled',
  status,
  type: 'automated',
  section: 'Authentication',
  evidence: 'authenticator: PasswordAuthenticator',
  remediable,
})

describe('CheckRow', () => {
  it('renders check id and title', () => {
    render(<CheckRow check={makeCheck('PASS')} />)
    expect(screen.getByText('CIS 2.1')).toBeInTheDocument()
    expect(screen.getByText(/Ensure authentication/)).toBeInTheDocument()
  })

  it('shows PASS status label', () => {
    render(<CheckRow check={makeCheck('PASS')} />)
    expect(screen.getByText('PASS')).toBeInTheDocument()
  })

  it('shows FAIL status label', () => {
    render(<CheckRow check={makeCheck('FAIL')} />)
    expect(screen.getByText('FAIL')).toBeInTheDocument()
  })

  it('shows REVIEW status label for NEEDS_REVIEW', () => {
    render(<CheckRow check={makeCheck('NEEDS_REVIEW')} />)
    expect(screen.getByText('REVIEW')).toBeInTheDocument()
  })

  it('does not show evidence drawer initially', () => {
    render(<CheckRow check={makeCheck('PASS')} />)
    expect(screen.queryByText('Evidence:')).not.toBeInTheDocument()
  })

  it('expands evidence drawer on click', () => {
    render(<CheckRow check={makeCheck('FAIL')} />)
    fireEvent.click(screen.getByRole('button'))
    expect(screen.getByText('Evidence:')).toBeInTheDocument()
    expect(screen.getByText('authenticator: PasswordAuthenticator')).toBeInTheDocument()
  })

  it('collapses drawer on second click', () => {
    render(<CheckRow check={makeCheck('FAIL')} />)
    const btn = screen.getByRole('button')
    fireEvent.click(btn) // open
    expect(screen.getByText('Evidence:')).toBeInTheDocument()
    fireEvent.click(btn) // close
    expect(screen.queryByText('Evidence:')).not.toBeInTheDocument()
  })

  it('shows remediate button for remediable FAIL checks', () => {
    const onRemediate = vi.fn()
    render(<CheckRow check={makeCheck('FAIL', true)} onRemediate={onRemediate} />)
    fireEvent.click(screen.getByRole('button')) // expand
    expect(screen.getByText(/Auto-Remediate/)).toBeInTheDocument()
  })

  it('does NOT show remediate button when remediable=false', () => {
    render(<CheckRow check={makeCheck('FAIL', false)} onRemediate={vi.fn()} />)
    fireEvent.click(screen.getByRole('button')) // expand
    expect(screen.queryByText(/Auto-Remediate/)).not.toBeInTheDocument()
  })

  it('calls onRemediate when remediate button clicked', () => {
    const onRemediate = vi.fn()
    render(<CheckRow check={makeCheck('FAIL', true)} onRemediate={onRemediate} />)
    fireEvent.click(screen.getByRole('button')) // expand
    fireEvent.click(screen.getByText(/Auto-Remediate/))
    expect(onRemediate).toHaveBeenCalledWith(expect.objectContaining({ id: '2.1' }))
  })
})
