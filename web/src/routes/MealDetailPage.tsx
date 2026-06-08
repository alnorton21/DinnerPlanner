import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { type Ingredient, ingredientFromJson } from '../types/ingredient'
import { PageHeader } from '../components/PageHeader'
import { ConfirmDialog } from '../components/ConfirmDialog'

interface MealWithIngredients {
  id: number
  name: string
  instructions: string
  image_url: string | null
  servings: number
  source_url: string | null
  categories: string[]
  ingredients: Ingredient[]
}

async function fetchMeal(id: number): Promise<MealWithIngredients> {
  const { data, error } = await supabase
    .from('meals')
    .select('*, ingredients(*)')
    .eq('id', id)
    .single()
  if (error) throw error
  return {
    ...data,
    ingredients: (data.ingredients ?? []).map(ingredientFromJson),
  }
}

function totalNutrition(ingredients: Ingredient[]) {
  return ingredients.reduce(
    (acc, ing) => ({
      calories: acc.calories + ing.calories,
      protein: acc.protein + ing.protein,
      carbs: acc.carbs + ing.carbs,
      fat: acc.fat + ing.fat,
    }),
    { calories: 0, protein: 0, carbs: 0, fat: 0 },
  )
}

export function MealDetailPage() {
  const { id } = useParams<{ id: string }>()
  const mealId = Number(id)
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [confirmingDelete, setConfirmingDelete] = useState(false)

  const { data: meal, isLoading } = useQuery({
    queryKey: ['meal', mealId],
    queryFn: () => fetchMeal(mealId),
  })

  async function deleteMeal() {
    await supabase.from('meals').delete().eq('id', mealId)
    queryClient.invalidateQueries({ queryKey: ['meals'] })
    navigate(-1)
  }

  if (isLoading || !meal) {
    return (
      <div>
        <PageHeader title="Meal" />
        <div className="page-content empty-state">
          <span className="spinner" />
        </div>
      </div>
    )
  }

  const servings = meal.servings || 1
  const total = totalNutrition(meal.ingredients)
  const perServing =
    servings > 1
      ? {
          calories: total.calories / servings,
          protein: total.protein / servings,
          carbs: total.carbs / servings,
          fat: total.fat / servings,
        }
      : total

  return (
    <div>
      <PageHeader
        title={meal.name}
        actions={
          <div style={{ display: 'flex', gap: 4 }}>
            <button className="icon-btn" title="Edit meal" onClick={() => navigate(`/meals/${mealId}/edit`)}>
              ✏️
            </button>
            <button className="icon-btn" title="Delete meal" onClick={() => setConfirmingDelete(true)}>
              🗑️
            </button>
          </div>
        }
      />
      <div className="page-content">
        {meal.image_url ? (
          <img
            src={meal.image_url}
            alt={meal.name}
            style={{ width: '100%', height: 220, objectFit: 'cover', borderRadius: 16, marginBottom: 16 }}
          />
        ) : (
          <div
            style={{
              width: '100%',
              height: 220,
              borderRadius: 16,
              marginBottom: 16,
              background: 'var(--color-surface-container-highest)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 64,
              opacity: 0.4,
            }}
          >
            🍽️
          </div>
        )}

        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 10 }}>
          <h2 style={{ fontSize: 22, fontWeight: 800, margin: 0 }}>Nutrition</h2>
          <span style={{ fontSize: 13, opacity: 0.6 }}>
            {servings > 1 ? `per serving (${servings} servings)` : 'per serving'}
          </span>
        </div>
        <div className="card" style={{ display: 'flex', justifyContent: 'space-around', marginBottom: 16 }}>
          <NutritionCol label="Calories" value={perServing.calories.toFixed(0)} />
          <NutritionCol label="Protein" value={`${perServing.protein.toFixed(1)} g`} />
          <NutritionCol label="Carbs" value={`${perServing.carbs.toFixed(1)} g`} />
          <NutritionCol label="Fat" value={`${perServing.fat.toFixed(1)} g`} />
        </div>

        {meal.categories.length > 0 && (
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 16 }}>
            {meal.categories.map((c) => (
              <span key={c} className="chip">
                {c}
              </span>
            ))}
          </div>
        )}

        <h2 style={{ fontSize: 22, fontWeight: 800, margin: '0 0 10px' }}>Ingredients</h2>
        {meal.ingredients.length === 0 ? (
          <p style={{ opacity: 0.6 }}>No ingredients yet</p>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 8 }}>
            {meal.ingredients.map((ing, i) => (
              <div key={i} className="card" style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                <span style={{ fontSize: 20 }}>🥕</span>
                <div style={{ flex: 1 }}>
                  <p style={{ margin: 0, fontWeight: 600, fontSize: 14 }}>{ing.name}</p>
                  <p style={{ margin: 0, fontSize: 12, opacity: 0.6 }}>
                    {ing.quantity} {ing.unit}
                  </p>
                </div>
                <span style={{ fontWeight: 600, fontSize: 13 }}>{ing.calories.toFixed(0)} cal</span>
              </div>
            ))}
          </div>
        )}

        <h2 style={{ fontSize: 22, fontWeight: 800, margin: '25px 0 10px' }}>Instructions</h2>
        <div
          className="card"
          style={{ background: 'var(--color-surface-container-highest)', whiteSpace: 'pre-wrap', fontSize: 15 }}
        >
          {meal.instructions || 'No instructions'}
        </div>

        {meal.source_url && (
          <a
            href={meal.source_url}
            target="_blank"
            rel="noopener noreferrer"
            className="btn btn-secondary"
            style={{ marginTop: 16, textDecoration: 'none', display: 'inline-flex' }}
          >
            🔗 View original recipe
          </a>
        )}
      </div>

      {confirmingDelete && (
        <ConfirmDialog
          title="Delete meal?"
          message="This will permanently delete the meal and all its ingredients."
          onCancel={() => setConfirmingDelete(false)}
          onConfirm={deleteMeal}
        />
      )}
    </div>
  )
}

function NutritionCol({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ textAlign: 'center' }}>
      <p style={{ margin: 0, fontSize: 12, opacity: 0.6 }}>{label}</p>
      <p style={{ margin: 0, fontWeight: 700 }}>{value}</p>
    </div>
  )
}
