export interface Ingredient {
  id?: number
  mealId?: number
  name: string
  quantity: number
  unit: string
  calories: number
  protein: number
  carbs: number
  fat: number
}

export function ingredientFromJson(json: any): Ingredient {
  return {
    id: json.id,
    mealId: json.meal_id,
    name: json.name,
    quantity: Number(json.quantity ?? 0),
    unit: json.unit ?? '',
    calories: Number(json.calories ?? 0),
    protein: Number(json.protein ?? 0),
    carbs: Number(json.carbs ?? 0),
    fat: Number(json.fat ?? 0),
  }
}

export function ingredientToJson(ingredient: Ingredient): Record<string, unknown> {
  return {
    name: ingredient.name,
    quantity: ingredient.quantity,
    unit: ingredient.unit,
    calories: ingredient.calories,
    protein: ingredient.protein,
    carbs: ingredient.carbs,
    fat: ingredient.fat,
  }
}
