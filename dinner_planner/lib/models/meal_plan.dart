class MealPlan {
  final int? id;
  final String userId;
  final DateTime weekStart;
  final int dayOfWeek; // 0=Mon, 1=Tue, 2=Wed, 3=Thu, 4=Fri, 5=Sat, 6=Sun
  final String mealSlot; // 'breakfast' | 'lunch' | 'dinner' | 'snack'
  final int? mealId;
  final String? mealName;
  final String? mealImageUrl;

  // Per-serving nutrition (total ingredients / servings)
  final double mealCalories;
  final double mealProtein;
  final double mealCarbs;
  final double mealFat;

  MealPlan({
    this.id,
    required this.userId,
    required this.weekStart,
    required this.dayOfWeek,
    required this.mealSlot,
    this.mealId,
    this.mealName,
    this.mealImageUrl,
    this.mealCalories = 0,
    this.mealProtein = 0,
    this.mealCarbs = 0,
    this.mealFat = 0,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    final mealData = json['meals'] as Map<String, dynamic>?;
    final ingredients = (mealData?['ingredients'] as List?) ?? [];
    final servings = ((mealData?['servings']) as int?) ?? 1;

    double totalCal = 0, totalPro = 0, totalCarbs = 0, totalFat = 0;
    for (final ing in ingredients) {
      totalCal += (ing['calories'] as num?)?.toDouble() ?? 0;
      totalPro += (ing['protein'] as num?)?.toDouble() ?? 0;
      totalCarbs += (ing['carbs'] as num?)?.toDouble() ?? 0;
      totalFat += (ing['fat'] as num?)?.toDouble() ?? 0;
    }
    final s = servings > 0 ? servings : 1;

    return MealPlan(
      id: json['id'],
      userId: json['user_id'],
      weekStart: DateTime.parse(json['week_start']),
      dayOfWeek: json['day_of_week'],
      mealSlot: json['meal_slot'],
      mealId: json['meal_id'],
      mealName: mealData?['name'],
      mealImageUrl: mealData?['image_url'],
      mealCalories: totalCal / s,
      mealProtein: totalPro / s,
      mealCarbs: totalCarbs / s,
      mealFat: totalFat / s,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'week_start': weekStart.toIso8601String().substring(0, 10),
        'day_of_week': dayOfWeek,
        'meal_slot': mealSlot,
        'meal_id': mealId,
      };
}
