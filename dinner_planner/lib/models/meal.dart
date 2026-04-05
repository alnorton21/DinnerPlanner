
class Meal {
  final int? id;
  final String name;
  final String instructions;
  final String? imageUrl;
  final int servings;

  Meal({
    this.id,
    required this.name,
    required this.instructions,
    this.imageUrl,
    this.servings = 1,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'],
      name: json['name'],
      instructions: json['instructions'],
      imageUrl: json['image_url'],
      servings: (json['servings'] as int?) ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'instructions': instructions,
      'image_url': imageUrl,
      'servings': servings,
    };
  }
}
