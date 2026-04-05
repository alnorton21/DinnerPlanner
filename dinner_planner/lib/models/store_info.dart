import 'package:flutter/material.dart';

class StoreInfo {
  final String name;
  final Color color;
  final IconData icon;

  const StoreInfo({
    required this.name,
    required this.color,
    required this.icon,
  });

  String searchUrl(String ingredient) {
    final q = Uri.encodeComponent(ingredient);
    switch (name) {
      case 'Kroger':
        return 'https://www.kroger.com/search?query=$q';
      case 'Walmart':
        return 'https://www.walmart.com/search?q=$q&cat_id=976759';
      case 'Target':
        return 'https://www.target.com/s?searchTerm=$q&category=grocery';
      case 'Amazon Fresh':
        return 'https://www.amazon.com/s?k=$q&i=amazonfresh';
      case 'Instacart':
        return 'https://www.instacart.com/store/s?k=$q';
      case 'ShopRite':
        return 'https://www.shoprite.com/sm/planning/rsid/3000/results?q=$q';
      case 'Aldi':
        return 'https://www.aldi.us/en/grocery-items/?q=$q';
      case 'Publix':
        return 'https://www.publix.com/products/search?text=$q';
      case 'Safeway':
        return 'https://www.safeway.com/shop/search-results.html?q=$q';
      case 'Whole Foods':
        return 'https://www.wholefoodsmarket.com/search?text=$q';
      default:
        return 'https://www.google.com/search?q=${Uri.encodeComponent("$ingredient grocery")}';
    }
  }
}

const List<StoreInfo> kAvailableStores = [
  StoreInfo(name: 'Kroger',       color: Color(0xFF003087), icon: Icons.store),
  StoreInfo(name: 'Walmart',      color: Color(0xFF007DC6), icon: Icons.store),
  StoreInfo(name: 'Target',       color: Color(0xFFCC0000), icon: Icons.storefront),
  StoreInfo(name: 'Amazon Fresh', color: Color(0xFFFF9900), icon: Icons.local_shipping),
  StoreInfo(name: 'Instacart',    color: Color(0xFF43B02A), icon: Icons.shopping_cart),
  StoreInfo(name: 'ShopRite',     color: Color(0xFF009A44), icon: Icons.local_grocery_store),
  StoreInfo(name: 'Aldi',         color: Color(0xFF00539B), icon: Icons.savings),
  StoreInfo(name: 'Publix',       color: Color(0xFF007749), icon: Icons.store),
  StoreInfo(name: 'Safeway',      color: Color(0xFFD40000), icon: Icons.store),
  StoreInfo(name: 'Whole Foods',  color: Color(0xFF00674B), icon: Icons.eco),
];

StoreInfo? storeByName(String name) {
  try {
    return kAvailableStores.firstWhere((s) => s.name == name);
  } catch (_) {
    return null;
  }
}
