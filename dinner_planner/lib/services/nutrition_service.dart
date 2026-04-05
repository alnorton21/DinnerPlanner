import 'dart:convert';
import 'package:http/http.dart' as http;

class NutritionService {

  static const apiKey = "VlQkgbKYMMonAfxW2tsvkDSdiDzFoa4cgyOoUaox";

  static Future<List> searchFood(String query) async {

    final url = Uri.parse(
      "https://api.nal.usda.gov/fdc/v1/foods/search?query=$query&api_key=$apiKey"
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(response.body);

    return data["foods"] ?? [];
  }

  static Future<Map<String, dynamic>?> lookupBarcode(String barcode) async {
    final url = Uri.parse(
      'https://world.openfoodfacts.org/api/v0/product/$barcode.json',
    );
    final response = await http.get(url);
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    if (data['status'] != 1) return null;
    final product = data['product'] as Map<String, dynamic>;
    final nutriments = (product['nutriments'] as Map<String, dynamic>?) ?? {};
    return {
      'name': (product['product_name'] as String?)?.trim() ?? 'Unknown Product',
      'calories': (nutriments['energy-kcal_100g'] as num?)?.toDouble() ?? 0,
      'protein': (nutriments['proteins_100g'] as num?)?.toDouble() ?? 0,
      'carbs': (nutriments['carbohydrates_100g'] as num?)?.toDouble() ?? 0,
      'fat': (nutriments['fat_100g'] as num?)?.toDouble() ?? 0,
    };
  }

  static Map<String, double> extractNutrition(List nutrients) {

    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;

    for (var n in nutrients) {

      switch (n["nutrientId"]) {

        case 1008:
          calories = (n["value"] ?? 0).toDouble();
          break;

        case 1003:
          protein = (n["value"] ?? 0).toDouble();
          break;

        case 1005:
          carbs = (n["value"] ?? 0).toDouble();
          break;

        case 1004:
          fat = (n["value"] ?? 0).toDouble();
          break;
      }
    }

    return {
      "calories": calories,
      "protein": protein,
      "carbs": carbs,
      "fat": fat
    };
  }
}