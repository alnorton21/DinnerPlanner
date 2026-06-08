import { useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'

export function AuthPage() {
  const [isSignUp, setIsSignUp] = useState(false)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [info, setInfo] = useState<string | null>(null)

  async function submit(e: FormEvent) {
    e.preventDefault()
    const trimmedEmail = email.trim()
    const trimmedPassword = password.trim()
    if (!trimmedEmail || !trimmedPassword) {
      setError('Please enter your email and password.')
      return
    }
    setLoading(true)
    setError(null)
    setInfo(null)
    try {
      if (isSignUp) {
        const { error: signUpError } = await supabase.auth.signUp({
          email: trimmedEmail,
          password: trimmedPassword,
        })
        if (signUpError) throw signUpError
        setInfo('Account created! Check your email to confirm, then sign in.')
      } else {
        const { error: signInError } = await supabase.auth.signInWithPassword({
          email: trimmedEmail,
          password: trimmedPassword,
        })
        if (signInError) throw signInError
      }
    } catch (err: any) {
      setError(err?.message ?? 'An unexpected error occurred.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ maxWidth: 420, margin: '0 auto', padding: '48px 24px' }}>
      <div style={{ textAlign: 'center', marginBottom: 28 }}>
        <div
          style={{
            width: 64,
            height: 64,
            borderRadius: 20,
            background: 'var(--color-primary)',
            color: 'var(--color-on-primary)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: 30,
            margin: '0 auto 12px',
          }}
        >
          🍽️
        </div>
        <h1 style={{ margin: 0, fontSize: 22, fontWeight: 800 }}>Dinner Planner</h1>
      </div>

      <form onSubmit={submit} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        <div>
          <h2 style={{ fontSize: 20, fontWeight: 800, margin: '0 0 4px' }}>
            {isSignUp ? 'Create account' : 'Welcome back'}
          </h2>
          <p style={{ margin: 0, fontSize: 14, color: 'color-mix(in srgb, var(--color-on-surface) 60%, transparent)' }}>
            {isSignUp ? 'Start planning your meals today' : 'Sign in to continue'}
          </p>
        </div>

        <label className="field">
          Email address
          <input
            type="email"
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </label>

        <label className="field">
          Password
          <div style={{ position: 'relative' }}>
            <input
              type={showPassword ? 'text' : 'password'}
              autoComplete={isSignUp ? 'new-password' : 'current-password'}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              style={{ paddingRight: 44 }}
            />
            <button
              type="button"
              className="icon-btn"
              style={{ position: 'absolute', right: 2, top: 2, width: 36, height: 36 }}
              onClick={() => setShowPassword((v) => !v)}
              aria-label={showPassword ? 'Hide password' : 'Show password'}
            >
              {showPassword ? '🙈' : '👁️'}
            </button>
          </div>
        </label>

        {!isSignUp && (
          <Link to="/reset-password" className="btn-text" style={{ alignSelf: 'flex-end', fontSize: 13 }}>
            Forgot password?
          </Link>
        )}

        {error && (
          <div className="error-banner">
            <span>⚠️</span> {error}
          </div>
        )}
        {info && (
          <div className="error-banner" style={{ background: 'var(--color-primary-container)', color: 'var(--color-on-primary-container)' }}>
            <span>✓</span> {info}
          </div>
        )}

        <button className="btn btn-primary" type="submit" disabled={loading}>
          {loading ? <span className="spinner" /> : isSignUp ? 'Sign up' : 'Sign in'}
        </button>

        <button
          type="button"
          className="btn-text"
          style={{ alignSelf: 'center' }}
          onClick={() => {
            setIsSignUp((v) => !v)
            setError(null)
            setInfo(null)
          }}
        >
          {isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Sign up"}
        </button>
      </form>
    </div>
  )
}
