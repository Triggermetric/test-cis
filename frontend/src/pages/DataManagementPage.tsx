import { useState, useEffect } from 'react'
import { api } from '../api'
import type { RecordResponse } from '../types'

export function DataManagementPage() {
  const [records, setRecords] = useState<RecordResponse[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  
  // Form state (mapped to backend student fields)
  const [title, setTitle] = useState('')
  const [meta, setMeta] = useState('')
  const [contact, setContact] = useState('')
  const [identifier, setIdentifier] = useState('')
  const [submitting, setSubmitting] = useState(false)

  // Load students on mount
  useEffect(() => {
    loadStudents()
  }, [])

  const loadStudents = async () => {
    setLoading(true)
    setError(null)
      try {
      const data = await api.listRecords()
      setRecords(data.students)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load records')
    } finally {
      setLoading(false)
    }
  }

  const handleAddRecord = async (e: React.FormEvent) => {
    e.preventDefault()
    setSubmitting(true)
    setError(null)
    try {
      const newRecord = await api.createRecord({
        first_name: title,
        last_name: meta,
        email: contact,
        student_id: identifier,
      })
      setRecords([...records, newRecord])

      // Reset form
      setTitle('')
      setMeta('')
      setContact('')
      setIdentifier('')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to add record')
    } finally {
      setSubmitting(false)
    }
  }

  const handleDeleteRecord = async (id: string) => {
    if (!confirm('Are you sure you want to delete this record?')) return

    setError(null)
    try {
      await api.deleteRecord(id)
      setRecords(records.filter(s => s.id !== id))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to delete record')
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold mb-2">Data Records</h2>
        <p className="text-gray-400 text-sm">Add and manage demo records stored in Cassandra</p>
      </div>

      {error && (
        <div className="bg-red-900/30 border border-red-700 p-4 rounded-lg">
          <p className="text-sm text-red-200">❌ {error}</p>
        </div>
      )}

      {/* Add Student Form */}
      <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
        <h3 className="font-bold mb-4 text-lg">Add Record</h3>
        <form onSubmit={handleAddRecord} className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium mb-1">Title</label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                required
                className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded text-white focus:outline-none focus:border-blue-500"
                placeholder="Example title"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Meta</label>
              <input
                type="text"
                value={meta}
                onChange={(e) => setMeta(e.target.value)}
                required
                className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded text-white focus:outline-none focus:border-blue-500"
                placeholder="Short description"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Contact</label>
              <input
                type="email"
                value={contact}
                onChange={(e) => setContact(e.target.value)}
                required
                className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded text-white focus:outline-none focus:border-blue-500"
                placeholder="contact@example.com"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Identifier</label>
              <input
                type="text"
                value={identifier}
                onChange={(e) => setIdentifier(e.target.value)}
                required
                className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded text-white focus:outline-none focus:border-blue-500"
                placeholder="REC001"
              />
            </div>
          </div>
          <button
            type="submit"
            disabled={submitting}
            className="w-full px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 disabled:cursor-not-allowed rounded font-medium transition-colors"
          >
            {submitting ? 'Adding...' : 'Add Record'}
          </button>
        </form>
      </div>

      {/* Students List */}
      <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
        <h3 className="font-bold mb-4 text-lg">Records ({records.length})</h3>

        {loading ? (
          <p className="text-gray-400">Loading...</p>
        ) : records.length === 0 ? (
          <p className="text-gray-400">No records yet. Add one to get started!</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-gray-700 bg-gray-900">
                <tr>
                  <th className="px-4 py-2 text-left">Name</th>
                  <th className="px-4 py-2 text-left">Email</th>
                  <th className="px-4 py-2 text-left">Student ID</th>
                  <th className="px-4 py-2 text-left">Created</th>
                  <th className="px-4 py-2 text-center">Action</th>
                </tr>
              </thead>
              <tbody>
                {records.map((r) => (
                  <tr key={r.id} className="border-b border-gray-700 hover:bg-gray-700/50">
                    <td className="px-4 py-2">
                      {r.first_name} {r.last_name}
                    </td>
                    <td className="px-4 py-2 text-gray-400">{r.email}</td>
                    <td className="px-4 py-2 font-mono text-xs text-gray-400">{r.student_id}</td>
                    <td className="px-4 py-2 text-xs text-gray-500">{new Date(r.created_at).toLocaleDateString()}</td>
                    <td className="px-4 py-2 text-center">
                      <button
                        onClick={() => handleDeleteRecord(r.id)}
                        className="px-3 py-1 bg-red-900/50 hover:bg-red-900 text-red-200 text-xs rounded transition-colors"
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
