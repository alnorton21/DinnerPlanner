import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { supabase } from '../lib/supabase'
import { useAuth } from './useAuth'

interface ThemeContextValue {
  isDark: boolean
  setIsDark: (value: boolean) => void
}

const ThemeContext = createContext<ThemeContextValue | null>(null)

export function ThemeProvider({ children }: { children: ReactNode }) {
  const { session } = useAuth()
  const [isDark, setIsDarkState] = useState(false)

  // Load the user's saved preference whenever they sign in; reset to light on sign-out.
  useEffect(() => {
    let cancelled = false
    if (!session) {
      setIsDarkState(false)
      return
    }
    supabase
      .from('user_profiles')
      .select('dark_mode')
      .eq('user_id', session.user.id)
      .maybeSingle()
      .then(({ data }) => {
        if (!cancelled) setIsDarkState(Boolean(data?.dark_mode ?? false))
      })
      .catch(() => {})
    return () => {
      cancelled = true
    }
  }, [session])

  useEffect(() => {
    document.documentElement.dataset.theme = isDark ? 'dark' : 'light'
  }, [isDark])

  const setIsDark = (value: boolean) => setIsDarkState(value)

  return <ThemeContext.Provider value={{ isDark, setIsDark }}>{children}</ThemeContext.Provider>
}

export function useTheme(): ThemeContextValue {
  const ctx = useContext(ThemeContext)
  if (!ctx) throw new Error('useTheme must be used within a ThemeProvider')
  return ctx
}
