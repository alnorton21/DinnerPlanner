export interface StoreInfo {
  name: string
  color: string
  icon: string // icon key, mapped to an SVG/emoji in the UI layer
}

function searchUrl(storeName: string, ingredient: string): string {
  const q = encodeURIComponent(ingredient)
  switch (storeName) {
    case 'Kroger':
      return `https://www.kroger.com/search?query=${q}`
    case 'Walmart':
      return `https://www.walmart.com/search?q=${q}&cat_id=976759`
    case 'Target':
      return `https://www.target.com/s?searchTerm=${q}&category=grocery`
    case 'Amazon Fresh':
      return `https://www.amazon.com/s?k=${q}&i=amazonfresh`
    case 'Instacart':
      return `https://www.instacart.com/store/s?k=${q}`
    case 'ShopRite':
      return `https://www.shoprite.com/sm/planning/rsid/3000/results?q=${q}`
    case 'Aldi':
      return `https://www.aldi.us/en/grocery-items/?q=${q}`
    case 'Publix':
      return `https://www.publix.com/products/search?text=${q}`
    case 'Safeway':
      return `https://www.safeway.com/shop/search-results.html?q=${q}`
    case 'Whole Foods':
      return `https://www.wholefoodsmarket.com/search?text=${q}`
    default:
      return `https://www.google.com/search?q=${encodeURIComponent(`${ingredient} grocery`)}`
  }
}

export function storeSearchUrl(store: StoreInfo, ingredient: string): string {
  return searchUrl(store.name, ingredient)
}

export const AVAILABLE_STORES: StoreInfo[] = [
  { name: 'Kroger', color: '#003087', icon: 'store' },
  { name: 'Walmart', color: '#007DC6', icon: 'store' },
  { name: 'Target', color: '#CC0000', icon: 'storefront' },
  { name: 'Amazon Fresh', color: '#FF9900', icon: 'local_shipping' },
  { name: 'Instacart', color: '#43B02A', icon: 'shopping_cart' },
  { name: 'ShopRite', color: '#009A44', icon: 'local_grocery_store' },
  { name: 'Aldi', color: '#00539B', icon: 'savings' },
  { name: 'Publix', color: '#007749', icon: 'store' },
  { name: 'Safeway', color: '#D40000', icon: 'store' },
  { name: 'Whole Foods', color: '#00674B', icon: 'eco' },
]

export function storeByName(name: string): StoreInfo | undefined {
  return AVAILABLE_STORES.find((s) => s.name === name)
}
