export interface MealPlan {
  id?: number
  userId: string
  weekStart: string // ISO date 'YYYY-MM-DD'
  dayOfWeek: number // 0=Mon ... 6=Sun
  mealSlot: 'breakfast' | 'lunch' | 'dinner' | 'snack'
  mealId?: number | null
  mealName?: string | null
  mealImageUrl?: string | null

  // Per-serving nutrition (sum of ingredient nutrition / servings)
  mealCalories: number
  mealProtein: number
  mealCarbs: number
  mealFat: number
}

export function mealPlanFromJson(json: any): MealPlan {
  const mealData = json.meals as
    | { name?: string; image_url?: string; servings?: number; ingredients?: any[] }
    | null
    | undefined
  const ingredients = mealData?.ingredients ?? []
  const servings = mealData?.servings ?? 1

  let totalCal = 0
  let totalPro = 0
  let totalCarbs = 0
  let totalFat = 0
  for (const ing of ingredients) {
    totalCal += Number(ing.calories ?? 0)
    totalPro += Number(ing.protein ?? 0)
    totalCarbs += Number(ing.carbs ?? 0)
    totalFat += Number(ing.fat ?? 0)
  }
  const s = servings > 0 ? servings : 1

  return {
    id: json.id,
    userId: json.user_id,
    weekStart: json.week_start,
    dayOfWeek: json.day_of_week,
    mealSlot: json.meal_slot,
    mealId: json.meal_id,
    mealName: mealData?.name,
    mealImageUrl: mealData?.image_url,
    mealCalories: totalCal / s,
    mealProtein: totalPro / s,
    mealCarbs: totalCarbs / s,
    mealFat: totalFat / s,
  }
}

export function mealPlanToJson(plan: MealPlan): Record<string, unknown> {
  return {
    user_id: plan.userId,
    week_start: plan.weekStart,
    day_of_week: plan.dayOfWeek,
    meal_slot: plan.mealSlot,
    meal_id: plan.mealId,
  }
}

export const MEAL_SLOTS = ['breakfast', 'lunch', 'dinner', 'snack'] as const
export const DAY_NAMES = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
