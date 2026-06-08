import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { type Meal, mealFromJson, MEAL_CATEGORIES } from '../types/meal'
import { PageHeader } from '../components/PageHeader'
import { MealCard } from '../components/MealCard'
import { ConfirmDialog } from '../components/ConfirmDialog'

async function fetchMeals(): Promise<Meal[]> {
  const { data, error } = await supabase.from('meals').select().order('id', { ascending: false })
  if (error) throw error
  return (data ?? []).map(mealFromJson)
}

export function MealListPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { data: meals = [], isLoading } = useQuery({ queryKey: ['meals'], queryFn: fetchMeals })

  const [search, setSearch] = useState('')
  const [selectedCategories, setSelectedCategories] = useState<Set<string>>(new Set())
  const [pendingDelete, setPendingDelete] = useState<Meal | null>(null)

  const filtered = useMemo(() => {
    const q = search.toLowerCase()
    return meals.filter((m) => {
      const matchesSearch = !q || m.name.toLowerCase().includes(q)
      const matchesCategory =
        selectedCategories.size === 0 || m.categories.some((c) => selectedCategories.has(c))
      return matchesSearch && matchesCategory
    })
  }, [meals, search, selectedCategories])

  function toggleCategory(cat: string) {
    setSelectedCategories((prev) => {
      const next = new Set(prev)
      if (next.has(cat)) next.delete(cat)
      else next.add(cat)
      return next
    })
  }

  async function confirmDelete() {
    if (!pendingDelete?.id) return
    await supabase.from('meals').delete().eq('id', pendingDelete.id)
    setPendingDelete(null)
    queryClient.invalidateQueries({ queryKey: ['meals'] })
  }

  return (
    <div>
      <PageHeader
        title="My Meals"
        actions={
          <button className="btn-text" onClick={() => navigate('/meals/new')}>
            + Add
          </button>
        }
      />
      <div className="page-content">
        <input
          placeholder="Search meals..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ marginBottom: 12 }}
        />

        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 16 }}>
          {MEAL_CATEGORIES.map((cat) => (
            <button
              key={cat}
              className={`chip${selectedCategories.has(cat) ? ' selected' : ''}`}
              onClick={() => toggleCategory(cat)}
            >
              {cat}
            </button>
          ))}
        </div>

        {isLoading ? (
          <div className="empty-state">
            <span className="spinner" />
          </div>
        ) : filtered.length === 0 ? (
          <div className="empty-state">
            <p style={{ fontSize: 16, fontWeight: 500 }}>
              {meals.length === 0 ? 'No meals yet' : 'No meals match your filters'}
            </p>
            {meals.length === 0 && <p style={{ fontSize: 13 }}>Tap "+ Add" to add your first meal</p>}
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {filtered.map((meal) => (
              <MealCard
                key={meal.id}
                meal={meal}
                onClick={() => navigate(`/meals/${meal.id}`)}
                onDelete={() => setPendingDelete(meal)}
              />
            ))}
          </div>
        )}
      </div>

      {pendingDelete && (
        <ConfirmDialog
          title="Delete meal?"
          message={`Remove "${pendingDelete.name}" from your recipes?`}
          onCancel={() => setPendingDelete(null)}
          onConfirm={confirmDelete}
        />
      )}
    </div>
  )
}
