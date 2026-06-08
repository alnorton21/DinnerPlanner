import { useEffect, useRef, useState } from 'react'
import { supabase } from '../lib/supabase'
import { type Ingredient } from '../types/ingredient'
import { searchFood, lookupBarcode, extractNutrition } from '../services/nutritionService'
import { BarcodeScannerModal } from './BarcodeScannerModal'

const UNIT_TO_GRAM: Record<string, number> = {
  g: 1,
  kg: 1000,
  oz: 28.3495,
  lb: 453.592,
  cup: 240,
  tbsp: 15,
  tsp: 5,
}

interface NutritionBase {
  calories: number
  protein: number
  carbs: number
  fat: number
}

interface FoodOption {
  fdcId?: number
  name: string
  calories: number
  protein: number
  carbs: number
  fat: number
  fromCache: boolean
}

interface SavedIngredient {
  name: string
  quantity: string
  unit: string
  calories: number
  protein: number
  carbs: number
  fat: number
}

interface IngredientEditorModalProps {
  mealId: number
  ingredient?: Ingredient
  onClose: () => void
  onSaved: () => void
}

export function IngredientEditorModal({ mealId, ingredient, onClose, onSaved }: IngredientEditorModalProps) {
  const isEditing = !!ingredient

  const [name, setName] = useState(ingredient?.name ?? '')
  const [quantity, setQuantity] = useState(ingredient ? String(ingredient.quantity) : '')
  const [selectedUnit, setSelectedUnit] = useState(
    ingredient && UNIT_TO_GRAM[ingredient.unit] ? ingredient.unit : 'g',
  )
  const [calories, setCalories] = useState(ingredient ? ingredient.calories.toFixed(1) : '')
  const [protein, setProtein] = useState(ingredient ? ingredient.protein.toFixed(1) : '')
  const [carbs, setCarbs] = useState(ingredient ? ingredient.carbs.toFixed(1) : '')
  const [fat, setFat] = useState(ingredient ? ingredient.fat.toFixed(1) : '')

  const baseNutrition = useRef<NutritionBase>({ calories: 0, protein: 0, carbs: 0, fat: 0 })

  const [mode, setMode] = useState<'database' | 'mine'>('database')
  const [query, setQuery] = useState(ingredient?.name ?? '')
  const [results, setResults] = useState<FoodOption[]>([])
  const [searching, setSearching] = useState(false)

  const [myIngredients, setMyIngredients] = useState<SavedIngredient[] | null>(null)
  const [myFilter, setMyFilter] = useState('')

  const [showScanner, setShowScanner] = useState(false)
  const [message, setMessage] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  // Reverse-engineer per-100g base from initial values when editing
  useEffect(() => {
    if (!ingredient) return
    const qtyNum = parseFloat(String(ingredient.quantity)) || 100
    const grams = qtyNum * (UNIT_TO_GRAM[selectedUnit] ?? 1)
    if (grams > 0) {
      baseNutrition.current = {
        calories: (ingredient.calories / grams) * 100,
        protein: (ingredient.protein / grams) * 100,
        carbs: (ingredient.carbs / grams) * 100,
        fat: (ingredient.fat / grams) * 100,
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

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

  function handleQuantityChange(value: string) {
    setQuantity(value)
    applyScaledNutrition(value, selectedUnit)
  }

  function handleUnitChange(value: string) {
    setSelectedUnit(value)
    applyScaledNutrition(quantity, value)
  }

  // ── Food database search (debounced) ────────────────────────────────────

  useEffect(() => {
    if (mode !== 'database' || query.trim().length < 2) {
      setResults([])
      return
    }
    let cancelled = false
    setSearching(true)
    const timer = setTimeout(async () => {
      const options = await searchFoodOptions(query.trim())
      if (!cancelled) {
        setResults(options)
        setSearching(false)
      }
    }, 350)
    return () => {
      cancelled = true
      clearTimeout(timer)
    }
  }, [query, mode])

  async function searchFoodOptions(q: string): Promise<FoodOption[]> {
    const { data: cached } = await supabase.from('food_cache').select().ilike('name', `%${q}%`).limit(10)
    if (cached && cached.length > 0) {
      return cached.map((f) => ({
        name: f.name,
        calories: Number(f.calories ?? 0),
        protein: Number(f.protein ?? 0),
        carbs: Number(f.carbs ?? 0),
        fat: Number(f.fat ?? 0),
        fromCache: true,
      }))
    }
    const apiFoods = await searchFood(q)
    return apiFoods.slice(0, 10).map((food) => {
      const nutrients = extractNutrition(food.foodNutrients ?? [])
      return {
        fdcId: food.fdcId,
        name: food.description as string,
        calories: nutrients.calories,
        protein: nutrients.protein,
        carbs: nutrients.carbs,
        fat: nutrients.fat,
        fromCache: false,
      }
    })
  }

  async function selectFood(food: FoodOption) {
    if (!food.fromCache && food.fdcId) {
      await supabase.from('food_cache').insert({
        fdc_id: food.fdcId,
        name: food.name,
        calories: food.calories,
        protein: food.protein,
        carbs: food.carbs,
        fat: food.fat,
      })
    }
    baseNutrition.current = {
      calories: food.calories,
      protein: food.protein,
      carbs: food.carbs,
      fat: food.fat,
    }
    setName(food.name)
    setQuery(food.name)
    setResults([])
    setSelectedUnit('g')
    setQuantity('100')
    applyScaledNutrition('100', 'g')
  }

  // ── My Ingredients ───────────────────────────────────────────────────────

  async function loadMyIngredients() {
    const { data: meals } = await supabase.from('meals').select('id')
    const mealIds = (meals ?? []).map((m) => m.id)
    if (mealIds.length === 0) {
      setMyIngredients([])
      return
    }
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
    setMyIngredients(deduped)
  }

  function selectMyIngredient(ing: SavedIngredient) {
    const qtyNum = parseFloat(ing.quantity) || 100
    const safeUnit = UNIT_TO_GRAM[ing.unit] ? ing.unit : 'g'
    const grams = qtyNum * (UNIT_TO_GRAM[safeUnit] ?? 1)
    if (grams > 0) {
      baseNutrition.current = {
        calories: (ing.calories / grams) * 100,
        protein: (ing.protein / grams) * 100,
        carbs: (ing.carbs / grams) * 100,
        fat: (ing.fat / grams) * 100,
      }
    }
    setName(ing.name)
    setQuery(ing.name)
    setSelectedUnit(safeUnit)
    setQuantity('100')
    applyScaledNutrition('100', safeUnit)
  }

  // ── Barcode scan ─────────────────────────────────────────────────────────

  async function handleBarcodeDetected(barcode: string) {
    setShowScanner(false)
    setMessage('Looking up product...')
    const result = await lookupBarcode(barcode)
    if (!result) {
      setMessage('Product not found. Enter details manually.')
      return
    }
    baseNutrition.current = {
      calories: result.calories,
      protein: result.protein,
      carbs: result.carbs,
      fat: result.fat,
    }
    setName(result.name)
    setQuery(result.name)
    setSelectedUnit('g')
    setQuantity('100')
    applyScaledNutrition('100', 'g')
    setMessage(null)
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  async function save() {
    if (!name.trim() || !quantity.trim()) {
      setMessage('Please enter a name and quantity.')
      return
    }
    setSaving(true)
    const data = {
      meal_id: mealId,
      name: name.trim(),
      quantity: quantity.trim(),
      unit: selectedUnit,
      calories: parseFloat(calories) || 0,
      protein: parseFloat(protein) || 0,
      carbs: parseFloat(carbs) || 0,
      fat: parseFloat(fat) || 0,
    }
    try {
      if (isEditing && ingredient?.id) {
        const { error } = await supabase.from('ingredients').update(data).eq('id', ingredient.id)
        if (error) throw error
      } else {
        const { error } = await supabase.from('ingredients').insert(data)
        if (error) throw error
      }
      onSaved()
      onClose()
    } catch (e) {
      setMessage(e instanceof Error ? e.message : 'Error saving ingredient')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.4)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 16,
        zIndex: 150,
      }}
      onClick={onClose}
    >
      <div
        className="card"
        style={{ maxWidth: 460, width: '100%', maxHeight: '88vh', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 12 }}
        onClick={(e) => e.stopPropagation()}
      >
        <h3 style={{ margin: 0 }}>{isEditing ? 'Edit Ingredient' : 'Add Ingredient'}</h3>

        <div style={{ display: 'flex', gap: 8 }}>
          <button
            className={`chip${mode === 'database' ? ' selected' : ''}`}
            style={{ flex: 1, justifyContent: 'center' }}
            onClick={() => setMode('database')}
          >
            Food Database
          </button>
          <button
            className={`chip${mode === 'mine' ? ' selected' : ''}`}
            style={{ flex: 1, justifyContent: 'center' }}
            onClick={() => {
              setMode('mine')
              if (myIngredients === null) loadMyIngredients()
            }}
          >
            My Ingredients
          </button>
        </div>

        <button className="btn btn-secondary" onClick={() => setShowScanner(true)}>
          📷 Scan Barcode
        </button>

        {mode === 'database' ? (
          <div style={{ position: 'relative' }}>
            <label className="field">
              Ingredient Name
              <input
                value={query}
                onChange={(e) => {
                  setQuery(e.target.value)
                  setName(e.target.value)
                }}
                placeholder="Type chicken, rice, egg..."
              />
            </label>
            {searching && <p style={{ fontSize: 12, opacity: 0.6, margin: '4px 0 0' }}>Searching...</p>}
            {results.length > 0 && (
              <div
                className="card"
                style={{ position: 'absolute', top: '100%', left: 0, right: 0, zIndex: 10, padding: 6, maxHeight: 220, overflowY: 'auto' }}
              >
                {results.map((food, i) => (
                  <button
                    key={i}
                    onClick={() => selectFood(food)}
                    style={{
                      display: 'block',
                      width: '100%',
                      textAlign: 'left',
                      padding: '8px 10px',
                      background: 'none',
                      border: 'none',
                      borderRadius: 8,
                      cursor: 'pointer',
                      color: 'inherit',
                      font: 'inherit',
                      fontSize: 13,
                    }}
                  >
                    {food.name}
                  </button>
                ))}
              </div>
            )}
          </div>
        ) : (
          <div>
            <input
              placeholder="Filter my ingredients..."
              value={myFilter}
              onChange={(e) => setMyFilter(e.target.value)}
              style={{ marginBottom: 8 }}
            />
            <div style={{ maxHeight: 200, overflowY: 'auto', border: '1px solid var(--color-outline-variant)', borderRadius: 8 }}>
              {myIngredients === null ? (
                <div className="empty-state">
                  <span className="spinner" />
                </div>
              ) : myIngredients.length === 0 ? (
                <p style={{ padding: 12, fontSize: 13, opacity: 0.6 }}>No saved ingredients yet.</p>
              ) : (
                myIngredients
                  .filter((ing) => !myFilter || ing.name.toLowerCase().includes(myFilter.toLowerCase()))
                  .map((ing, i) => (
                    <button
                      key={i}
                      onClick={() => selectMyIngredient(ing)}
                      style={{
                        display: 'block',
                        width: '100%',
                        textAlign: 'left',
                        padding: '8px 10px',
                        background: 'none',
                        border: 'none',
                        borderBottom: '1px solid var(--color-outline-variant)',
                        cursor: 'pointer',
                        color: 'inherit',
                        font: 'inherit',
                      }}
                    >
                      <p style={{ margin: 0, fontWeight: 600, fontSize: 13 }}>{ing.name}</p>
                      <p style={{ margin: 0, fontSize: 11, opacity: 0.6 }}>
                        {ing.unit || 'g'} · {ing.calories.toFixed(0)} cal
                      </p>
                    </button>
                  ))
              )}
            </div>
          </div>
        )}

        <div style={{ display: 'flex', gap: 8 }}>
          <label className="field" style={{ flex: 1 }}>
            Quantity
            <input value={quantity} onChange={(e) => handleQuantityChange(e.target.value)} inputMode="decimal" />
          </label>
          <label className="field" style={{ flex: 1 }}>
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

        {message && <div className="error-banner">{message}</div>}

        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
          <button className="btn btn-secondary" onClick={onClose}>
            Cancel
          </button>
          <button className="btn btn-primary" onClick={save} disabled={saving}>
            {saving ? <span className="spinner" /> : isEditing ? 'Save Changes' : 'Save Ingredient'}
          </button>
        </div>
      </div>

      {showScanner && <BarcodeScannerModal onDetected={handleBarcodeDetected} onClose={() => setShowScanner(false)} />}
    </div>
  )
}
