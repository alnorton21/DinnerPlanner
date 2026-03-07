class Ingredient {
  final String name;
  final double quantity;
  final String unit;

  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  Ingredient({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}