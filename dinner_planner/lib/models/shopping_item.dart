class ShoppingItem {
  final String name;
  double totalQuantity;
  final String unit;
  double totalCalories;
  double totalProtein;
  double totalCarbs;
  double totalFat;
  final bool isCustom;

  ShoppingItem({
    required this.name,
    required this.totalQuantity,
    required this.unit,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    this.isCustom = false,
  });

  factory ShoppingItem.fromCustomJson(Map<String, dynamic> json) => ShoppingItem(
        name: json['name'] as String,
        totalQuantity: (json['qty'] as num).toDouble(),
        unit: (json['unit'] as String? ?? ''),
        totalCalories: 0,
        totalProtein: 0,
        totalCarbs: 0,
        totalFat: 0,
        isCustom: true,
      );

  Map<String, dynamic> toCustomJson() => {
        'name': name,
        'qty': totalQuantity,
        'unit': unit,
      };
}
