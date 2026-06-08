import { useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'

export function ResetPasswordPage() {
  const [email, setEmail] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [sent, setSent] = useState(false)

  async function submit(e: FormEvent) {
    e.preventDefault()
    const trimmed = email.trim()
    if (!trimmed) {
      setError('Please enter your email address.')
      return
    }
    setLoading(true)
    setError(null)
    try {
      const redirectTo = `${window.location.origin}${import.meta.env.BASE_URL}#/update-password`
      const { error: resetError } = await supabase.auth.resetPasswordForEmail(trimmed, { redirectTo })
      if (resetError) throw resetError
      setSent(true)
    } catch (err: any) {
      setError(err?.message ?? 'An unexpected error occurred.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ maxWidth: 420, margin: '0 auto', padding: '48px 24px' }}>
      <h2 style={{ fontSize: 20, fontWeight: 800, margin: '0 0 4px' }}>Reset password</h2>
      <p style={{ marginTop: 0, fontSize: 14, color: 'color-mix(in srgb, var(--color-on-surface) 60%, transparent)' }}>
        We'll email you a link to set a new password.
      </p>

      {sent ? (
        <div className="error-banner" style={{ background: 'var(--color-primary-container)', color: 'var(--color-on-primary-container)' }}>
          <span>✓</span> Check your email for a password reset link.
        </div>
      ) : (
        <form onSubmit={submit} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <label className="field">
            Email address
            <input type="email" autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} />
          </label>
          {error && (
            <div className="error-banner">
              <span>⚠️</span> {error}
            </div>
          )}
          <button className="btn btn-primary" type="submit" disabled={loading}>
            {loading ? <span className="spinner" /> : 'Send reset link'}
          </button>
        </form>
      )}

      <Link to="/auth" className="btn-text" style={{ display: 'inline-block', marginTop: 16 }}>
        ← Back to sign in
      </Link>
    </div>
  )
}
