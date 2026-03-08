import 'ingredient.dart';

class Meal {
  final int? id;
  final String name;
  final String instructions;
  final String? imageUrl;

  Meal({
    this.id,
    required this.name,
    required this.instructions,
    this.imageUrl,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'],
      name: json['name'],
      instructions: json['instructions'],
      imageUrl: json['image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'instructions': instructions,
      'image_url': imageUrl,
    };
  }
}