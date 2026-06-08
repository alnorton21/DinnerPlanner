import type { Meal } from '../types/meal'

interface MealCardProps {
  meal: Meal
  onClick: () => void
  onDelete?: () => void
}

export function MealCard({ meal, onClick, onDelete }: MealCardProps) {
  return (
    <div
      className="card"
      style={{ display: 'flex', alignItems: 'center', gap: 14, cursor: 'pointer' }}
      onClick={onClick}
    >
      <div
        style={{
          width: 64,
          height: 64,
          borderRadius: 12,
          overflow: 'hidden',
          flexShrink: 0,
          background: 'var(--color-surface-container-highest)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: 24,
        }}
      >
        {meal.imageUrl ? (
          <img src={meal.imageUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        ) : (
          '🍽️'
        )}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <p style={{ margin: 0, fontWeight: 700, fontSize: 15, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
          {meal.name}
        </p>
        <p style={{ margin: '2px 0 0', fontSize: 12, opacity: 0.6 }}>
          {meal.servings} serving{meal.servings === 1 ? '' : 's'}
        </p>
        {meal.categories.length > 0 && (
          <div style={{ display: 'flex', gap: 6, marginTop: 6, flexWrap: 'wrap' }}>
            {meal.categories.map((c) => (
              <span key={c} className="chip">
                {c}
              </span>
            ))}
          </div>
        )}
      </div>
      {onDelete && (
        <button
          className="icon-btn"
          aria-label="Delete meal"
          onClick={(e) => {
            e.stopPropagation()
            onDelete()
          }}
        >
          🗑️
        </button>
      )}
    </div>
  )
}
