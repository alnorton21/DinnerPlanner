import 'ingredient.dart';

class Meal {
  final String id;
  final String name;
  final List<Ingredient> ingredients;
  final String instructions;

  Meal({
    required this.id,
    required this.name,
    required this.ingredients,
    required this.instructions,
  });
}