import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import App from '../App'

// Mock the page components
vi.mock('../pages/DashboardPage', () => ({
  DashboardPage: () => <div data-testid="dashboard-page">Dashboard Content</div>,
}))
vi.mock('../pages/CompliancePage', () => ({
  CompliancePage: () => <div data-testid="compliance-page">Compliance Content</div>,
}))
vi.mock('../pages/AuditLivePage', () => ({
  AuditLivePage: () => <div data-testid="audit-live-page">Audit Live Content</div>,
}))

describe('App', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders the app shell', () => {
    render(<App />)
    expect(screen.getByText('CIS Cassandra')).toBeInTheDocument()
    expect(screen.getByText('Compliance Dashboard')).toBeInTheDocument()
  })

  it('shows the Dashboard tab by default', () => {
    render(<App />)
    expect(screen.getByTestId('dashboard-page')).toBeInTheDocument()
    expect(screen.queryByTestId('compliance-page')).not.toBeInTheDocument()
  })

  it('switches to Compliance tab on click', () => {
    render(<App />)
    const complianceTab = screen.getByRole('tab', { name: /Compliance/ })
    fireEvent.click(complianceTab)
    expect(screen.getByTestId('compliance-page')).toBeInTheDocument()
    expect(screen.queryByTestId('dashboard-page')).not.toBeInTheDocument()
  })

  it('shows version badge', () => {
    render(<App />)
    expect(screen.getByText('v1.3.0')).toBeInTheDocument()
  })
})
