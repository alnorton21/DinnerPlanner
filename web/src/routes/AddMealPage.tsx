import { useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { useAuth } from '../hooks/useAuth'
import { MEAL_CATEGORIES } from '../types/meal'
import { uploadMealImage, updateMealImage } from '../services/supabaseService'
import { lookupBarcode } from '../services/nutritionService'
import { compressImage } from '../utils/imageHelper'
import { PageHeader } from '../components/PageHeader'
import { IngredientSearchModal } from '../components/IngredientSearchModal'
import { BarcodeScannerModal } from '../components/BarcodeScannerModal'

const UNIT_TO_GRAM: Record<string, number> = {
  g: 1,
  kg: 1000,
  oz: 28.3495,
  lb: 453.592,
  cup: 240,
  tbsp: 15,
  tsp: 5,
}

interface IngredientEntry {
  name: string
  quantity: string
  unit: string
  calories: number
  protein: number
  carbs: number
  fat: number
}

interface PrefillSource {
  name: string
  quantity?: string | number
  unit?: string
  calories?: number
  protein?: number
  carbs?: number
  fat?: number
}

export function AddMealPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { session } = useAuth()

  // Meal details
  const [name, setName] = useState('')
  const [servings, setServings] = useState('1')
  const [sourceUrl, setSourceUrl] = useState('')
  const [showSourceUrl, setShowSourceUrl] = useState(false)
  const [selectedCategories, setSelectedCategories] = useState<Set<string>>(new Set())

  // Photo
  const [imageFile, setImageFile] = useState<File | null>(null)
  const [imagePreview, setImagePreview] = useState<string | null>(null)
  const galleryInputRef = useRef<HTMLInputElement>(null)
  const cameraInputRef = useRef<HTMLInputElement>(null)

  // Ingredient form
  const [ingName, setIngName] = useState('')
  const [qty, setQty] = useState('')
  const [selectedUnit, setSelectedUnit] = useState('g')
  const [calories, setCalories] = useState('')
  const [protein, setProtein] = useState('')
  const [carbs, setCarbs] = useState('')
  const [fat, setFat] = useState('')
  const baseNutrition = useRef({ calories: 0, protein: 0, carbs: 0, fat: 0 })
  const [ingredientMessage, setIngredientMessage] = useState<string | null>(null)

  const [ingredients, setIngredients] = useState<IngredientEntry[]>([])
  const [editingIndex, setEditingIndex] = useState<number | null>(null)

  const [showIngredientSearch, setShowIngredientSearch] = useState(false)
  const [showScanner, setShowScanner] = useState(false)

  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // ── Photo ────────────────────────────────────────────────────────────────

  function handleImageSelected(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    e.target.value = ''
    if (!file) return
    setImageFile(file)
    setImagePreview((prev) => {
      if (prev) URL.revokeObjectURL(prev)
      return URL.createObjectURL(file)
    })
  }

  // ── Nutrition scaling ────────────────────────────────────────────────────

  function applyScaledNutrition(qtyStr: string, unit: string) {
    const qtyNum = parseFloat(qtyStr) || 0
    const grams = qtyNum * (UNIT_TO_GRAM[unit] ?? 1)
    if (grams <= 0) return
    const base = baseNutrition.current
    setCalories(((base.calories * grams) / 100).toFixed(1))
    setProtein(((base.protein * grams) / 100).toFixed(1))
    setCarbs(((base.carbs * grams) / 100).toFixed(1))
    setFat(((base.fat * grams) / 100).toFixed(1))
  }

  function handleQtyChange(value: string) {
    setQty(value)
    applyScaledNutrition(value, selectedUnit)
  }

  function handleUnitChange(value: string) {
    setSelectedUnit(value)
    applyScaledNutrition(qty, value)
  }

  function prefillIngredient(ing: PrefillSource) {
    const qtyNum = parseFloat(String(ing.quantity ?? '100')) || 100
    const unit = ing.unit ?? 'g'
    const safeUnit = UNIT_TO_GRAM[unit] ? unit : 'g'
    const grams = qtyNum * (UNIT_TO_GRAM[safeUnit] ?? 1)
    if (grams > 0) {
      baseNutrition.current = {
        calories: ((ing.calories ?? 0) / grams) * 100,
        protein: ((ing.protein ?? 0) / grams) * 100,
        carbs: ((ing.carbs ?? 0) / grams) * 100,
        fat: ((ing.fat ?? 0) / grams) * 100,
      }
    }
    setIngName(ing.name ?? '')
    setSelectedUnit(safeUnit)
    setQty('100')
    applyScaledNutrition('100', safeUnit)
  }

  // ── Barcode scan ─────────────────────────────────────────────────────────

  async function handleBarcodeDetected(barcode: string) {
    setShowScanner(false)
    setIngredientMessage('Looking up product...')
    const result = await lookupBarcode(barcode)
    if (!result) {
      setIngredientMessage('Product not found. Enter details manually.')
      return
    }
    baseNutrition.current = {
      calories: result.calories,
      protein: result.protein,
      carbs: result.carbs,
      fat: result.fat,
    }
    setIngName(result.name)
    setSelectedUnit('g')
    setQty('100')
    applyScaledNutrition('100', 'g')
    setIngredientMessage(null)
  }

  // ── Add / update ingredient ──────────────────────────────────────────────

  function addIngredient() {
    if (!ingName.trim() || !qty.trim()) {
      setIngredientMessage('Please fill in ingredient name and quantity')
      return
    }
    const entry: IngredientEntry = {
      name: ingName.trim(),
      quantity: qty.trim(),
      unit: selectedUnit,
      calories: parseFloat(calories) || 0,
      protein: parseFloat(protein) || 0,
      carbs: parseFloat(carbs) || 0,
      fat: parseFloat(fat) || 0,
    }
    setIngredients((prev) => {
      if (editingIndex !== null) {
        const next = [...prev]
        next[editingIndex] = entry
        return next
      }
      return [...prev, entry]
    })
    setEditingIndex(null)
    clearIngredientForm()
  }

  function clearIngredientForm() {
    setIngName('')
    setQty('')
    setCalories('')
    setProtein('')
    setCarbs('')
    setFat('')
    setSelectedUnit('g')
    baseNutrition.current = { calories: 0, protein: 0, carbs: 0, fat: 0 }
    setIngredientMessage(null)
  }

  function editIngredient(index: number) {
    const ing = ingredients[index]
    const safeUnit = UNIT_TO_GRAM[ing.unit] ? ing.unit : 'g'
    const qtyNum = parseFloat(ing.quantity) || 100
    const grams = qtyNum * (UNIT_TO_GRAM[safeUnit] ?? 1)
    if (grams > 0) {
      baseNutrition.current = {
        calories: (ing.calories / grams) * 100,
        protein: (ing.protein / grams) * 100,
        carbs: (ing.carbs / grams) * 100,
        fat: (ing.fat / grams) * 100,
      }
    }
    setIngName(ing.name)
    setQty(ing.quantity)
    setSelectedUnit(safeUnit)
    setCalories(String(ing.calories))
    setProtein(String(ing.protein))
    setCarbs(String(ing.carbs))
    setFat(String(ing.fat))
    setEditingIndex(index)
    setIngredientMessage(null)
  }

  function removeIngredient(index: number) {
    setIngredients((prev) => prev.filter((_, i) => i !== index))
    if (editingIndex === index) {
      setEditingIndex(null)
      clearIngredientForm()
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  async function saveMeal() {
    if (!name.trim()) {
      setError('Please enter a meal name')
      return
    }
    setSaving(true)
    setError(null)
    try {
      const userId = session!.user.id
      const { data: mealRow, error: insertError } = await supabase
        .from('meals')
        .insert({
          name: name.trim(),
          instructions: '',
          image_url: null,
          user_id: userId,
          servings: parseInt(servings.trim(), 10) || 1,
          categories: [...selectedCategories],
          ...(sourceUrl.trim() ? { source_url: sourceUrl.trim() } : {}),
        })
        .select()
        .single()
      if (insertError) throw insertError

      const mealId = mealRow.id as number

      if (imageFile) {
        const compressed = await compressImage(imageFile)
        const url = await uploadMealImage(compressed, mealId)
        await updateMealImage(mealId, url)
      }

      if (ingredients.length > 0) {
        const { error: ingError } = await supabase
          .from('ingredients')
          .insert(ingredients.map((ing) => ({ meal_id: mealId, ...ing })))
        if (ingError) throw ingError
      }

      queryClient.invalidateQueries({ queryKey: ['meals'] })
      navigate(-1)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error saving meal')
    } finally {
      setSaving(false)
    }
  }

  function toggleCategory(cat: string) {
    setSelectedCategories((prev) => {
      const next = new Set(prev)
      if (next.has(cat)) next.delete(cat)
      else next.add(cat)
      return next
    })
  }

  return (
    <div>
      <PageHeader
        title="Add Meal"
        actions={
          <button className="btn-text" onClick={saveMeal} disabled={saving}>
            {saving ? <span className="spinner" /> : 'Save'}
          </button>
        }
      />
      <div className="page-content" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        {error && <div className="error-banner">{error}</div>}

        {/* Meal Details */}
        <SectionCard title="MEAL DETAILS">
          <label className="field">
            Meal Name *
            <input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Chicken Stir Fry" />
          </label>
          <div style={{ display: 'flex', gap: 10, alignItems: 'flex-end', flexWrap: 'wrap' }}>
            <label className="field" style={{ width: 90 }}>
              Servings
              <input value={servings} onChange={(e) => setServings(e.target.value)} inputMode="numeric" />
            </label>
            {showSourceUrl ? (
              <label className="field" style={{ flex: 1, minWidth: 160 }}>
                Source URL
                <input
                  value={sourceUrl}
                  onChange={(e) => setSourceUrl(e.target.value)}
                  placeholder="https://..."
                  inputMode="url"
                  autoCorrect="off"
                />
              </label>
            ) : (
              <button className="btn-text" onClick={() => setShowSourceUrl(true)} style={{ fontSize: 13 }}>
                🔗 Add source URL
              </button>
            )}
          </div>
        </SectionCard>

        {/* Category */}
        <SectionCard title="CATEGORY">
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
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
        </SectionCard>

        {/* Photo */}
        <SectionCard title="PHOTO">
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div
              style={{
                width: 72,
                height: 72,
                borderRadius: 8,
                overflow: 'hidden',
                flexShrink: 0,
                background: 'var(--color-surface-container-highest)',
                border: '1px solid var(--color-outline-variant)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: 26,
                opacity: imagePreview ? 1 : 0.4,
              }}
            >
              {imagePreview ? (
                <img src={imagePreview} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
              ) : (
                '📷'
              )}
            </div>
            <div style={{ display: 'flex', gap: 8, flex: 1 }}>
              <button className="btn btn-secondary" style={{ flex: 1 }} onClick={() => galleryInputRef.current?.click()}>
                🖼️ Gallery
              </button>
              <button className="btn btn-secondary" style={{ flex: 1 }} onClick={() => cameraInputRef.current?.click()}>
                📸 Camera
              </button>
            </div>
            <input
              ref={galleryInputRef}
              type="file"
              accept="image/*"
              style={{ display: 'none' }}
              onChange={handleImageSelected}
            />
            <input
              ref={cameraInputRef}
              type="file"
              accept="image/*"
              capture="environment"
              style={{ display: 'none' }}
              onChange={handleImageSelected}
            />
          </div>
        </SectionCard>

        {/* Ingredients */}
        <SectionCard title="INGREDIENTS">
          <div style={{ display: 'flex', gap: 8 }}>
            <label className="field" style={{ flex: 3 }}>
              Ingredient
              <input value={ingName} onChange={(e) => setIngName(e.target.value)} />
            </label>
            <label className="field" style={{ width: 70 }}>
              Qty
              <input value={qty} onChange={(e) => handleQtyChange(e.target.value)} inputMode="decimal" />
            </label>
            <label className="field" style={{ width: 90 }}>
              Unit
              <select value={selectedUnit} onChange={(e) => handleUnitChange(e.target.value)}>
                {Object.keys(UNIT_TO_GRAM).map((u) => (
                  <option key={u} value={u}>
                    {u}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <div style={{ display: 'flex', gap: 8 }}>
            <label className="field" style={{ flex: 1 }}>
              Calories
              <input value={calories} onChange={(e) => setCalories(e.target.value)} inputMode="decimal" />
            </label>
            <label className="field" style={{ flex: 1 }}>
              Protein (g)
              <input value={protein} onChange={(e) => setProtein(e.target.value)} inputMode="decimal" />
            </label>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <label className="field" style={{ flex: 1 }}>
              Carbs (g)
              <input value={carbs} onChange={(e) => setCarbs(e.target.value)} inputMode="decimal" />
            </label>
            <label className="field" style={{ flex: 1 }}>
              Fat (g)
              <input value={fat} onChange={(e) => setFat(e.target.value)} inputMode="decimal" />
            </label>
          </div>

          {ingredientMessage && (
            <div
              className="error-banner"
              style={
                ingredientMessage.startsWith('Please') || ingredientMessage.startsWith('Product not found')
                  ? undefined
                  : { background: 'var(--color-primary-container)', color: 'var(--color-on-primary-container)' }
              }
            >
              {ingredientMessage}
            </div>
          )}

          <div style={{ display: 'flex', gap: 8 }}>
            <button className="btn btn-secondary" style={{ flex: 1, fontSize: 13 }} onClick={() => setShowScanner(true)}>
              📷 Scan Barcode
            </button>
            <button
              className="btn btn-secondary"
              style={{ flex: 1, fontSize: 13 }}
              onClick={() => setShowIngredientSearch(true)}
            >
              🔍 My Ingredients
            </button>
          </div>

          <button className="btn btn-primary" style={{ width: '100%' }} onClick={addIngredient}>
            {editingIndex === null ? '+ Add Ingredient' : '✓ Save Changes'}
          </button>
        </SectionCard>

        {/* Added ingredients */}
        {ingredients.length > 0 && (
          <SectionCard title={`ADDED (${ingredients.length})`}>
            {ingredients.map((ing, index) => (
              <div key={index} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <p style={{ margin: 0, fontWeight: 600, fontSize: 13 }}>
                    {ing.quantity} {ing.unit} {ing.name}
                  </p>
                  <p style={{ margin: 0, fontSize: 11, opacity: 0.6 }}>
                    {ing.calories.toFixed(0)} cal · P {ing.protein.toFixed(0)}g · C {ing.carbs.toFixed(0)}g · F{' '}
                    {ing.fat.toFixed(0)}g
                  </p>
                </div>
                <button className="icon-btn" title="Edit" onClick={() => editIngredient(index)}>
                  ✏️
                </button>
                <button className="icon-btn" title="Remove" onClick={() => removeIngredient(index)}>
                  🗑️
                </button>
              </div>
            ))}
          </SectionCard>
        )}
      </div>

      {showIngredientSearch && (
        <IngredientSearchModal onSelect={prefillIngredient} onClose={() => setShowIngredientSearch(false)} />
      )}
      {showScanner && <BarcodeScannerModal onDetected={handleBarcodeDetected} onClose={() => setShowScanner(false)} />}
    </div>
  )
}

function SectionCard({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      <p style={{ margin: 0, fontSize: 11, fontWeight: 700, letterSpacing: 0.6, opacity: 0.54, textTransform: 'uppercase' }}>
        {title}
      </p>
      {children}
    </div>
  )
}
