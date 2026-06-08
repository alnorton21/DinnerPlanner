import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { useAuth } from '../hooks/useAuth'
import { useTheme } from '../hooks/useTheme'
import { PageHeader } from '../components/PageHeader'

export function ProfilePage() {
  const { session } = useAuth()
  const { isDark, setIsDark } = useTheme()
  const navigate = useNavigate()
  const userId = session!.user.id

  const [displayName, setDisplayName] = useState('')
  const [calorieGoal, setCalorieGoal] = useState(2000)
  const [proteinGoal, setProteinGoal] = useState(150)
  const [carbGoal, setCarbGoal] = useState(250)
  const [fatGoal, setFatGoal] = useState(65)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    Promise.resolve(
      supabase.from('user_profiles').select().eq('user_id', userId).maybeSingle(),
    )
      .then(({ data }) => {
        if (cancelled || !data) return
        setDisplayName(data.display_name ?? '')
        setCalorieGoal(Number(data.calorie_goal ?? 2000))
        setProteinGoal(Number(data.protein_goal ?? 150))
        setCarbGoal(Number(data.carb_goal ?? 250))
        setFatGoal(Number(data.fat_goal ?? 65))
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [userId])

  async function save() {
    setSaving(true)
    setMessage(null)
    try {
      const { error } = await supabase.from('user_profiles').upsert({
        user_id: userId,
        display_name: displayName.trim(),
        calorie_goal: Math.round(calorieGoal),
        protein_goal: Math.round(proteinGoal),
        carb_goal: Math.round(carbGoal),
        fat_goal: Math.round(fatGoal),
        dark_mode: isDark,
      })
      if (error) throw error
      setMessage('Profile saved')
    } catch (err: any) {
      setMessage(`Error: ${err?.message ?? 'failed to save'}`)
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return (
      <div>
        <PageHeader title="Profile & Goals" />
        <div className="page-content empty-state">
          <span className="spinner" />
        </div>
      </div>
    )
  }

  return (
    <div>
      <PageHeader
        title="Profile & Goals"
        actions={
          <button className="btn-text" onClick={save} disabled={saving}>
            {saving ? <span className="spinner" /> : 'Save'}
          </button>
        }
      />
      <div className="page-content" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <p style={{ margin: 0, fontSize: 12, fontWeight: 700, textTransform: 'uppercase', opacity: 0.6 }}>
            Account
          </p>
          <p style={{ margin: 0, fontSize: 14 }}>{session?.user.email}</p>
          <label className="field">
            Display name
            <input value={displayName} onChange={(e) => setDisplayName(e.target.value)} />
          </label>
        </div>

        <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <p style={{ margin: 0, fontSize: 12, fontWeight: 700, textTransform: 'uppercase', opacity: 0.6 }}>
            Daily nutrition goals
          </p>
          <GoalField label="Calories" value={calorieGoal} onChange={setCalorieGoal} unit="kcal" />
          <GoalField label="Protein" value={proteinGoal} onChange={setProteinGoal} unit="g" />
          <GoalField label="Carbs" value={carbGoal} onChange={setCarbGoal} unit="g" />
          <GoalField label="Fat" value={fatGoal} onChange={setFatGoal} unit="g" />
        </div>

        <div className="card" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <p style={{ margin: 0, fontWeight: 700, fontSize: 14 }}>Dark mode</p>
            <p style={{ margin: 0, fontSize: 12, opacity: 0.6 }}>Switch between light and dark themes</p>
          </div>
          <label style={{ display: 'inline-flex', alignItems: 'center', cursor: 'pointer' }}>
            <input
              type="checkbox"
              checked={isDark}
              onChange={(e) => setIsDark(e.target.checked)}
              style={{ width: 'auto' }}
            />
          </label>
        </div>

        {message && (
          <div
            className="error-banner"
            style={
              message.startsWith('Error')
                ? undefined
                : { background: 'var(--color-primary-container)', color: 'var(--color-on-primary-container)' }
            }
          >
            {message}
          </div>
        )}

        <button
          className="btn btn-secondary"
          onClick={() => navigate(-1)}
          style={{ alignSelf: 'flex-start' }}
        >
          Done
        </button>
      </div>
    </div>
  )
}

function GoalField({
  label,
  value,
  onChange,
  unit,
}: {
  label: string
  value: number
  onChange: (v: number) => void
  unit: string
}) {
  return (
    <label className="field">
      {label} ({unit})
      <input
        type="number"
        min={0}
        value={value}
        onChange={(e) => onChange(Number(e.target.value) || 0)}
      />
    </label>
  )
}
