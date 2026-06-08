import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'

interface SavedIngredient {
  name: string
  quantity: string
  unit: string
  calories: number
  protein: number
  carbs: number
  fat: number
}

interface IngredientSearchModalProps {
  onSelect: (ingredient: SavedIngredient) => void
  onClose: () => void
}

async function loadSavedIngredients(): Promise<SavedIngredient[]> {
  const { data: meals } = await supabase.from('meals').select('id')
  const mealIds = (meals ?? []).map((m) => m.id)
  if (mealIds.length === 0) return []

  const { data: rows } = await supabase
    .from('ingredients')
    .select('name, quantity, unit, calories, protein, carbs, fat')
    .in('meal_id', mealIds)

  const seen = new Set<string>()
  const deduped: SavedIngredient[] = []
  for (const row of rows ?? []) {
    const key = (row.name as string).toLowerCase()
    if (seen.has(key)) continue
    seen.add(key)
    deduped.push(row as SavedIngredient)
  }
  deduped.sort((a, b) => a.name.localeCompare(b.name))
  return deduped
}

export function IngredientSearchModal({ onSelect, onClose }: IngredientSearchModalProps) {
  const [ingredients, setIngredients] = useState<SavedIngredient[] | null>(null)
  const [search, setSearch] = useState('')
  const [detail, setDetail] = useState<SavedIngredient | null>(null)

  useEffect(() => {
    loadSavedIngredients().then(setIngredients)
  }, [])

  const filtered = useMemo(() => {
    if (!ingredients) return []
    const q = search.toLowerCase()
    return q ? ingredients.filter((i) => i.name.toLowerCase().includes(q)) : ingredients
  }, [ingredients, search])

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.4)',
        display: 'flex',
        alignItems: 'flex-end',
        justifyContent: 'center',
        zIndex: 150,
      }}
      onClick={onClose}
    >
      <div
        className="card"
        style={{
          width: '100%',
          maxWidth: 480,
          maxHeight: '80vh',
          display: 'flex',
          flexDirection: 'column',
          borderRadius: '20px 20px 0 0',
          margin: 0,
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <h3 style={{ marginTop: 0 }}>My Ingredients</h3>
        <input
          placeholder="Search ingredients..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ marginBottom: 12 }}
        />

        <div style={{ overflowY: 'auto', flex: 1 }}>
          {ingredients === null ? (
            <div className="empty-state">
              <span className="spinner" />
            </div>
          ) : filtered.length === 0 ? (
            <p style={{ opacity: 0.6, textAlign: 'center', padding: '24px 0' }}>
              {ingredients.length === 0
                ? 'No saved ingredients yet. Add some meals with ingredients first.'
                : 'No ingredients match your search.'}
            </p>
          ) : (
            filtered.map((ing, i) => (
              <button
                key={i}
                onClick={() => setDetail(ing)}
                style={{
                  display: 'flex',
                  width: '100%',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  padding: '12px 4px',
                  background: 'none',
                  border: 'none',
                  borderBottom: '1px solid var(--color-outline-variant)',
                  textAlign: 'left',
                  cursor: 'pointer',
                  color: 'inherit',
                  font: 'inherit',
                }}
              >
                <span>
                  <p style={{ margin: 0, fontWeight: 600, fontSize: 14 }}>{ing.name}</p>
                  <p style={{ margin: 0, fontSize: 12, opacity: 0.6 }}>
                    per 100 {ing.unit || 'g'} · {ing.calories.toFixed(0)} cal
                  </p>
                </span>
                <span style={{ opacity: 0.4 }}>›</span>
              </button>
            ))
          )}
        </div>
      </div>

      {detail && (
        <div
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.4)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 160 }}
          onClick={() => setDetail(null)}
        >
          <div className="card" style={{ maxWidth: 360, width: '100%' }} onClick={(e) => e.stopPropagation()}>
            <h3 style={{ marginTop: 0 }}>{detail.name}</h3>
            <div style={{ display: 'flex', justifyContent: 'space-around', margin: '16px 0' }}>
              <Macro label="Calories" value={`${detail.calories.toFixed(1)} cal`} />
              <Macro label="Protein" value={`${detail.protein.toFixed(1)}g`} />
              <Macro label="Carbs" value={`${detail.carbs.toFixed(1)}g`} />
              <Macro label="Fat" value={`${detail.fat.toFixed(1)}g`} />
            </div>
            <button
              className="btn btn-primary"
              style={{ width: '100%' }}
              onClick={() => {
                onSelect(detail)
                setDetail(null)
                onClose()
              }}
            >
              Select Ingredient
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

function Macro({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ textAlign: 'center' }}>
      <p style={{ margin: 0, fontWeight: 700, fontSize: 15 }}>{value}</p>
      <p style={{ margin: 0, fontSize: 11, opacity: 0.6 }}>{label}</p>
    </div>
  )
}
