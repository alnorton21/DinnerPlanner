export interface PantryItem {
  id?: number
  name: string
  quantity: number
  unit: string
  barcode?: string | null
  calories?: number | null
  protein?: number | null
  carbs?: number | null
  fat?: number | null
  expirationDate?: string | null // 'YYYY-MM-DD'
  createdAt: string
}

export function isExpired(item: PantryItem): boolean {
  if (!item.expirationDate) return false
  return new Date(item.expirationDate) < new Date(new Date().toDateString())
}

export function isExpiringSoon(item: PantryItem): boolean {
  if (!item.expirationDate) return false
  const today = new Date(new Date().toDateString())
  const exp = new Date(item.expirationDate)
  const daysLeft = Math.round((exp.getTime() - today.getTime()) / (1000 * 60 * 60 * 24))
  return daysLeft <= 2 && !isExpired(item)
}

export function pantryItemFromJson(json: any): PantryItem {
  return {
    id: json.id,
    name: json.name,
    quantity: Number(json.quantity ?? 0),
    unit: json.unit,
    barcode: json.barcode ?? null,
    calories: json.calories != null ? Number(json.calories) : null,
    protein: json.protein != null ? Number(json.protein) : null,
    carbs: json.carbs != null ? Number(json.carbs) : null,
    fat: json.fat != null ? Number(json.fat) : null,
    expirationDate: json.expiration_date ?? null,
    createdAt: json.created_at ?? new Date().toISOString(),
  }
}

export function pantryItemToJson(item: PantryItem): Record<string, unknown> {
  return {
    name: item.name,
    quantity: item.quantity,
    unit: item.unit,
    ...(item.barcode != null ? { barcode: item.barcode } : {}),
    ...(item.calories != null ? { calories: item.calories } : {}),
    ...(item.protein != null ? { protein: item.protein } : {}),
    ...(item.carbs != null ? { carbs: item.carbs } : {}),
    ...(item.fat != null ? { fat: item.fat } : {}),
    ...(item.expirationDate ? { expiration_date: item.expirationDate } : {}),
  }
}
