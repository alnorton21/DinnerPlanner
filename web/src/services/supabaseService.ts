import { supabase } from '../lib/supabase'
import { type MealPlan, mealPlanFromJson, mealPlanToJson } from '../types/mealPlan'
import { type PantryItem, pantryItemFromJson } from '../types/pantryItem'

export async function addMeal(name: string, instructions: string): Promise<number> {
  const { data, error } = await supabase
    .from('meals')
    .insert({ name, instructions })
    .select()
    .single()
  if (error) throw error
  return data.id
}

export async function updateMealImage(mealId: number, imageUrl: string): Promise<void> {
  const { error } = await supabase.from('meals').update({ image_url: imageUrl }).eq('id', mealId)
  if (error) throw error
}

export async function uploadMealImage(file: Blob, mealId: number): Promise<string> {
  const path = `meals/${mealId}.jpg`
  const { error } = await supabase.storage
    .from('meal-images')
    .upload(path, file, { upsert: true, contentType: 'image/jpeg' })
  if (error) throw error
  const { data } = supabase.storage.from('meal-images').getPublicUrl(path)
  return data.publicUrl
}

export async function getMealPlan(weekStart: string): Promise<MealPlan[]> {
  const { data, error } = await supabase
    .from('meal_plans')
    .select('*, meals(name, image_url, servings, ingredients(calories, protein, carbs, fat))')
    .eq('week_start', weekStart)
  if (error) throw error
  return (data ?? []).map(mealPlanFromJson)
}

export async function addMealPlanEntry(plan: MealPlan): Promise<void> {
  const { error } = await supabase.from('meal_plans').insert(mealPlanToJson(plan))
  if (error) throw error
}

export async function clearMealPlanSlot(planId: number): Promise<void> {
  const { error } = await supabase.from('meal_plans').delete().eq('id', planId)
  if (error) throw error
}

export async function loadShoppingState(
  userId: string,
  weekStart: string,
): Promise<Record<string, any> | null> {
  const { data } = await supabase
    .from('shopping_list_state')
    .select()
    .eq('user_id', userId)
    .eq('week_start', weekStart)
    .maybeSingle()
  return data
}

export async function saveShoppingState(
  userId: string,
  weekStart: string,
  assignments: Record<string, unknown>,
  prices: Record<string, unknown>,
  customItems: Array<Record<string, unknown>>,
  checkedItems: string[],
): Promise<void> {
  const { error } = await supabase.from('shopping_list_state').upsert(
    {
      user_id: userId,
      week_start: weekStart,
      assignments,
      prices,
      custom_items: customItems,
      checked_items: checkedItems,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'user_id,week_start' },
  )
  if (error) throw error
}

// ── Pantry ────────────────────────────────────────────────────────────────

export async function getPantryItems(userId: string): Promise<PantryItem[]> {
  const { data, error } = await supabase
    .from('pantry_items')
    .select()
    .eq('user_id', userId)
    .order('expiration_date', { ascending: true, nullsFirst: false })
    .order('name', { ascending: true })
  if (error) throw error
  return (data ?? []).map(pantryItemFromJson)
}

export async function addPantryItem(
  userId: string,
  data: Record<string, unknown>,
): Promise<PantryItem> {
  const { data: row, error } = await supabase
    .from('pantry_items')
    .insert({ user_id: userId, ...data })
    .select()
    .single()
  if (error) throw error
  return pantryItemFromJson(row)
}

export async function updatePantryItem(id: number, data: Record<string, unknown>): Promise<void> {
  const { error } = await supabase.from('pantry_items').update(data).eq('id', id)
  if (error) throw error
}

export async function deletePantryItem(id: number): Promise<void> {
  const { error } = await supabase.from('pantry_items').delete().eq('id', id)
  if (error) throw error
}
