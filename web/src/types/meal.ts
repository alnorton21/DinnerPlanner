export interface Meal {
  id?: number
  name: string
  instructions: string
  imageUrl: string | null
  servings: number
  sourceUrl: string | null
  categories: string[]
}

export function mealFromJson(json: any): Meal {
  return {
    id: json.id,
    name: json.name,
    instructions: json.instructions ?? '',
    imageUrl: json.image_url ?? null,
    servings: json.servings ?? 1,
    sourceUrl: json.source_url ?? null,
    categories: json.categories ?? [],
  }
}

export function mealToJson(meal: Meal): Record<string, unknown> {
  return {
    name: meal.name,
    instructions: meal.instructions,
    image_url: meal.imageUrl,
    servings: meal.servings,
    ...(meal.sourceUrl ? { source_url: meal.sourceUrl } : {}),
    categories: meal.categories,
  }
}

export const MEAL_CATEGORIES = ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Main', 'Side'] as const
