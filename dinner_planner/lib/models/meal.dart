
class Meal {
  final int? id;
  final String name;
  final String instructions;
  final String? imageUrl;
  final int servings;
  final String? sourceUrl;

  Meal({
    this.id,
    required this.name,
    required this.instructions,
    this.imageUrl,
    this.servings = 1,
    this.sourceUrl,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'],
      name: json['name'],
      instructions: json['instructions'],
      imageUrl: json['image_url'],
      servings: (json['servings'] as int?) ?? 1,
      sourceUrl: json['source_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'instructions': instructions,
      'image_url': imageUrl,
      'servings': servings,
      if (sourceUrl != null) 'source_url': sourceUrl,
    };
  }
}
