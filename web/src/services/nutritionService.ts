const USDA_API_KEY = 'VlQkgbKYMMonAfxW2tsvkDSdiDzFoa4cgyOoUaox'

export async function searchFood(query: string): Promise<any[]> {
  const url = `https://api.nal.usda.gov/fdc/v1/foods/search?query=${encodeURIComponent(query)}&api_key=${USDA_API_KEY}`
  const response = await fetch(url)
  if (!response.ok) return []
  const data = await response.json()
  return data.foods ?? []
}

export interface BarcodeProduct {
  name: string
  calories: number
  protein: number
  carbs: number
  fat: number
}

export async function lookupBarcode(barcode: string): Promise<BarcodeProduct | null> {
  const url = `https://world.openfoodfacts.org/api/v0/product/${encodeURIComponent(barcode)}.json`
  const response = await fetch(url)
  if (!response.ok) return null
  const data = await response.json()
  if (data.status !== 1) return null
  const product = data.product ?? {}
  const nutriments = product.nutriments ?? {}
  return {
    name: (product.product_name as string | undefined)?.trim() || 'Unknown Product',
    calories: Number(nutriments['energy-kcal_100g'] ?? 0),
    protein: Number(nutriments['proteins_100g'] ?? 0),
    carbs: Number(nutriments['carbohydrates_100g'] ?? 0),
    fat: Number(nutriments['fat_100g'] ?? 0),
  }
}

export interface ExtractedNutrition {
  calories: number
  protein: number
  carbs: number
  fat: number
}

export function extractNutrition(nutrients: any[]): ExtractedNutrition {
  let calories = 0
  let protein = 0
  let carbs = 0
  let fat = 0

  for (const n of nutrients) {
    switch (n.nutrientId) {
      case 1008:
        calories = n.value ?? 0
        break
      case 1003:
        protein = n.value ?? 0
        break
      case 1005:
        carbs = n.value ?? 0
        break
      case 1004:
        fat = n.value ?? 0
        break
    }
  }

  return { calories, protein, carbs, fat }
}
