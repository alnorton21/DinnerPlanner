import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal.dart';
import '../models/ingredient.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

  // -------------------
  // Fetch all meals
  // -------------------
  Future<List<Meal>> fetchMeals() async {
    try {
      // fetch meals and related ingredients
      final List<dynamic> data = await _client
          .from('meals')
          .select('*, ingredients(*)');

      return data.map((meal) {
        final ingredientsData = meal['ingredients'] as List<dynamic>;
        final ingredients = ingredientsData.map((i) => Ingredient(
          name: i['name'],
          quantity: (i['quantity'] as num).toDouble(),
          unit: i['unit'],
          calories: (i['calories'] as num).toDouble(),
          protein: (i['protein'] as num).toDouble(),
          carbs: (i['carbs'] as num).toDouble(),
          fat: (i['fat'] as num).toDouble(),
        )).toList();

        return Meal(
          id: meal['id'].toString(),
          name: meal['name'],
          instructions: meal['instructions'],
          ingredients: ingredients,
        );
      }).toList();
    } catch (e) {
      print('Error fetching meals: $e');
      return [];
    }
  }

  // -------------------
  // Add a meal with ingredients
  // -------------------
  Future<void> addMeal(Meal meal) async {
    try {
      // insert meal and get inserted row
      final mealData = await _client
          .from('meals')
          .insert({
            'name': meal.name,
            'instructions': meal.instructions,
          })
          .select(); // returns inserted row

      final mealId = mealData[0]['id'];

      // insert ingredients
      for (final ingredient in meal.ingredients) {
        await _client.from('ingredients').insert({
          'meal_id': mealId,
          'name': ingredient.name,
          'quantity': ingredient.quantity,
          'unit': ingredient.unit,
          'calories': ingredient.calories,
          'protein': ingredient.protein,
          'carbs': ingredient.carbs,
          'fat': ingredient.fat,
        });
      }
    } catch (e) {
      print('Error adding meal: $e');
    }
  }

  // -------------------
  // Update meal and its ingredients
  // -------------------
  Future<void> updateMeal(Meal meal) async {
    try {
      // update meal info
      await _client
          .from('meals')
          .update({
            'name': meal.name,
            'instructions': meal.instructions,
          })
          .eq('id', meal.id);

      // delete old ingredients
      await _client.from('ingredients').delete().eq('meal_id', meal.id);

      // insert new ingredients
      for (final ingredient in meal.ingredients) {
        await _client.from('ingredients').insert({
          'meal_id': meal.id,
          'name': ingredient.name,
          'quantity': ingredient.quantity,
          'unit': ingredient.unit,
          'calories': ingredient.calories,
          'protein': ingredient.protein,
          'carbs': ingredient.carbs,
          'fat': ingredient.fat,
        });
      }
    } catch (e) {
      print('Error updating meal: $e');
    }
  }

  // -------------------
  // Delete a meal and its ingredients
  // -------------------
  Future<void> deleteMeal(String mealId) async {
    try {
      await _client.from('ingredients').delete().eq('meal_id', mealId);
      await _client.from('meals').delete().eq('id', mealId);
    } catch (e) {
      print('Error deleting meal: $e');
    }
  }
}