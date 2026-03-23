class MealPlan {
  final int? id;
  final String userId;
  final DateTime weekStart;
  final int dayOfWeek; // 0=Mon, 1=Tue, 2=Wed, 3=Thu, 4=Fri, 5=Sat, 6=Sun
  final String mealSlot; // 'breakfast' | 'lunch' | 'dinner' | 'snack'
  final int? mealId;
  final String? mealName;
  final String? mealImageUrl;

  MealPlan({
    this.id,
    required this.userId,
    required this.weekStart,
    required this.dayOfWeek,
    required this.mealSlot,
    this.mealId,
    this.mealName,
    this.mealImageUrl,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    final mealData = json['meals'] as Map<String, dynamic>?;
    return MealPlan(
      id: json['id'],
      userId: json['user_id'],
      weekStart: DateTime.parse(json['week_start']),
      dayOfWeek: json['day_of_week'],
      mealSlot: json['meal_slot'],
      mealId: json['meal_id'],
      mealName: mealData?['name'],
      mealImageUrl: mealData?['image_url'],
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
