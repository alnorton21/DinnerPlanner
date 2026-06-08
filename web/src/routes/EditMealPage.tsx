import { useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { type Ingredient, ingredientFromJson } from '../types/ingredient'
import { uploadMealImage, updateMealImage } from '../services/supabaseService'
import { compressImage } from '../utils/imageHelper'
import { PageHeader } from '../components/PageHeader'
import { IngredientEditorModal } from '../components/IngredientEditorModal'
import { ConfirmDialog } from '../components/ConfirmDialog'

interface EditableMeal {
  id: number
  name: string
  instructions: string
  image_url: string | null
  servings: number
}

async function fetchMeal(id: number): Promise<EditableMeal> {
  const { data, error } = await supabase
    .from('meals')
    .select('id, name, instructions, image_url, servings')
    .eq('id', id)
    .single()
  if (error) throw error
  return data
}

async function fetchIngredients(mealId: number): Promise<Ingredient[]> {
  const { data, error } = await supabase.from('ingredients').select().eq('meal_id', mealId).order('id')
  if (error) throw error
  return (data ?? []).map(ingredientFromJson)
}

export function EditMealPage() {
  const { id } = useParams<{ id: string }>()
  const mealId = Number(id)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const { data: meal, isLoading } = useQuery({ queryKey: ['meal', mealId], queryFn: () => fetchMeal(mealId) })
  const {
    data: ingredients = [],
    isLoading: ingredientsLoading,
    refetch: refetchIngredients,
  } = useQuery({ queryKey: ['meal', mealId, 'ingredients'], queryFn: () => fetchIngredients(mealId) })

  const [name, setName] = useState('')
  const [instructions, setInstructions] = useState('')
  const [servings, setServings] = useState('')
  const [initialized, setInitialized] = useState(false)

  const [newImageFile, setNewImageFile] = useState<File | null>(null)
  const [newImagePreview, setNewImagePreview] = useState<string | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const [editingIngredient, setEditingIngredient] = useState<Ingredient | null>(null)
  const [addingIngredient, setAddingIngredient] = useState(false)
  const [pendingDeleteIngredient, setPendingDeleteIngredient] = useState<Ingredient | null>(null)

  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  if (meal && !initialized) {
    setName(meal.name ?? '')
    setInstructions(meal.instructions ?? '')
    setServings(String(meal.servings ?? 1))
    setInitialized(true)
  }

  function handleImageSelected(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    e.target.value = ''
    if (!file) return
    setNewImageFile(file)
    setNewImagePreview((prev) => {
      if (prev) URL.revokeObjectURL(prev)
      return URL.createObjectURL(file)
    })
  }

  async function deleteIngredient(ing: Ingredient) {
    if (!ing.id) return
    await supabase.from('ingredients').delete().eq('id', ing.id)
    setPendingDeleteIngredient(null)
    refetchIngredients()
  }

  async function save() {
    if (!meal) return
    setSaving(true)
    setError(null)
    try {
      let imageUrl = meal.image_url
      if (newImageFile) {
        const compressed = await compressImage(newImageFile)
        imageUrl = await uploadMealImage(compressed, meal.id)
        await updateMealImage(meal.id, imageUrl)
      }
      const { error: updateError } = await supabase
        .from('meals')
        .update({
          name: name.trim(),
          instructions: instructions.trim(),
          servings: parseInt(servings.trim(), 10) || 1,
          image_url: imageUrl,
        })
        .eq('id', meal.id)
      if (updateError) throw updateError

      queryClient.invalidateQueries({ queryKey: ['meals'] })
      queryClient.invalidateQueries({ queryKey: ['meal', meal.id] })
      navigate(-1)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error saving meal')
    } finally {
      setSaving(false)
    }
  }

  if (isLoading || !meal) {
    return (
      <div>
        <PageHeader title="Edit Meal" />
        <div className="page-content empty-state">
          <span className="spinner" />
        </div>
      </div>
    )
  }

  const displayImage = newImagePreview ?? meal.image_url

  return (
    <div>
      <PageHeader
        title={`Edit ${meal.name}`}
        actions={
          <button className="btn-text" onClick={save} disabled={saving}>
            {saving ? <span className="spinner" /> : 'Save'}
          </button>
        }
      />
      <div className="page-content" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        {error && <div className="error-banner">{error}</div>}

        <label className="field">
          Meal Name
          <input value={name} onChange={(e) => setName(e.target.value)} />
        </label>

        <div>
          <p style={{ margin: '0 0 8px', fontWeight: 700, fontSize: 14 }}>Image</p>
          <div
            style={{
              height: 200,
              width: '100%',
              borderRadius: 12,
              overflow: 'hidden',
              cursor: 'pointer',
              background: 'var(--color-surface-container-highest)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexDirection: 'column',
              gap: 8,
            }}
            onClick={() => fileInputRef.current?.click()}
          >
            {displayImage ? (
              <img src={displayImage} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
            ) : (
              <>
                <span style={{ fontSize: 40, opacity: 0.5 }}>📷</span>
                <span style={{ opacity: 0.5, fontSize: 13 }}>Tap to add image</span>
              </>
            )}
          </div>
          {displayImage && (
            <button className="btn-text" style={{ marginTop: 6 }} onClick={() => fileInputRef.current?.click()}>
              🖼️ Change image
            </button>
          )}
          <input ref={fileInputRef} type="file" accept="image/*" style={{ display: 'none' }} onChange={handleImageSelected} />
        </div>

        <label className="field" style={{ width: 120 }}>
          Servings
          <input value={servings} onChange={(e) => setServings(e.target.value)} inputMode="numeric" />
        </label>

        <label className="field">
          Instructions
          <textarea rows={6} value={instructions} onChange={(e) => setInstructions(e.target.value)} />
        </label>

        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <p style={{ margin: 0, fontWeight: 700, fontSize: 14 }}>Ingredients</p>
          <button className="btn btn-secondary" onClick={() => setAddingIngredient(true)}>
            + Add ingredient
          </button>
        </div>

        {ingredientsLoading ? (
          <div className="empty-state">
            <span className="spinner" />
          </div>
        ) : ingredients.length === 0 ? (
          <p style={{ opacity: 0.6, fontSize: 14 }}>No ingredients yet. Tap "+ Add ingredient" to add one.</p>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {ingredients.map((ing) => (
              <div key={ing.id} className="card" style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                <span style={{ fontSize: 20 }}>🥕</span>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <p style={{ margin: 0, fontWeight: 600, fontSize: 14 }}>{ing.name}</p>
                  <p style={{ margin: 0, fontSize: 12, opacity: 0.6 }}>
                    {ing.quantity} {ing.unit} · {ing.calories.toFixed(0)} cal
                  </p>
                </div>
                <button className="icon-btn" title="Edit" onClick={() => setEditingIngredient(ing)}>
                  ✏️
                </button>
                <button className="icon-btn" title="Delete" onClick={() => setPendingDeleteIngredient(ing)}>
                  🗑️
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {(addingIngredient || editingIngredient) && (
        <IngredientEditorModal
          mealId={meal.id}
          ingredient={editingIngredient ?? undefined}
          onClose={() => {
            setAddingIngredient(false)
            setEditingIngredient(null)
          }}
          onSaved={() => refetchIngredients()}
        />
      )}

      {pendingDeleteIngredient && (
        <ConfirmDialog
          title="Delete ingredient?"
          message={`Remove "${pendingDeleteIngredient.name}" from this meal?`}
          onCancel={() => setPendingDeleteIngredient(null)}
          onConfirm={() => deleteIngredient(pendingDeleteIngredient)}
        />
      )}
    </div>
  )
}
