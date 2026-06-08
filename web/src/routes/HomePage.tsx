import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { useAuth } from '../hooks/useAuth'

const NAV_CARDS = [
  { to: '/meals', icon: '📖', title: 'My Meals', subtitle: 'Browse and manage your saved recipes' },
  { to: '/meals/new', icon: '➕', title: 'Add New Meal', subtitle: 'Create a recipe with ingredients & nutrition' },
  { to: '/calendar', icon: '📅', title: 'Meal Planner', subtitle: 'Plan your week & generate a shopping list' },
  { to: '/groceries', icon: '🧊', title: 'My Groceries', subtitle: "Track what's in your kitchen" },
  { to: '/profile', icon: '👤', title: 'Profile & Goals', subtitle: 'Set your daily nutrition targets' },
]

export function HomePage() {
  const { session } = useAuth()
  const email = session?.user.email ?? ''

  return (
    <div>
      <div
        className="card"
        style={{
          background: 'var(--color-primary)',
          color: 'var(--color-on-primary)',
          border: 'none',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          marginBottom: 18,
        }}
      >
        <div>
          <p style={{ margin: 0, fontSize: 12, opacity: 0.8 }}>Signed in as</p>
          <p style={{ margin: '2px 0 0', fontSize: 16, fontWeight: 700 }}>{email}</p>
        </div>
        <button
          className="icon-btn"
          style={{ color: 'inherit' }}
          onClick={() => supabase.auth.signOut()}
          aria-label="Sign out"
          title="Sign out"
        >
          ⎋
        </button>
      </div>

      <h2 style={{ fontSize: 16, fontWeight: 700, margin: '0 0 12px' }}>What would you like to do?</h2>
      <div className="nav-grid">
        {NAV_CARDS.map((card) => (
          <Link key={card.to} to={card.to} className="card nav-card">
            <span className="nav-icon">{card.icon}</span>
            <div>
              <h3>{card.title}</h3>
              <p>{card.subtitle}</p>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}
