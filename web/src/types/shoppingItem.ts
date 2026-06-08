export interface ShoppingItem {
  name: string
  totalQuantity: number
  unit: string
  totalCalories: number
  totalProtein: number
  totalCarbs: number
  totalFat: number
  isCustom: boolean
}

export function shoppingItemFromCustomJson(json: any): ShoppingItem {
  return {
    name: json.name,
    totalQuantity: Number(json.qty ?? 0),
    unit: json.unit ?? '',
    totalCalories: 0,
    totalProtein: 0,
    totalCarbs: 0,
    totalFat: 0,
    isCustom: true,
  }
}

export function shoppingItemToCustomJson(item: ShoppingItem): Record<string, unknown> {
  return {
    name: item.name,
    qty: item.totalQuantity,
    unit: item.unit,
  }
}
