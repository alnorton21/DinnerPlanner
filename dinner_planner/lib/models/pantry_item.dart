class PantryItem {
  final int? id;
  final String name;
  double quantity;
  final String unit;
  final String? barcode;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final DateTime? expirationDate;
  final DateTime createdAt;

  PantryItem({
    this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.barcode,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.expirationDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExpired =>
      expirationDate != null &&
      expirationDate!.isBefore(DateTime.now());

  bool get isExpiringSoon {
    if (expirationDate == null) return false;
    final daysLeft =
        expirationDate!.difference(DateTime.now()).inDays;
    return daysLeft <= 2 && !isExpired;
  }

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    return PantryItem(
      id: json['id'] as int?,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      barcode: json['barcode'] as String?,
      calories: (json['calories'] as num?)?.toDouble(),
      protein: (json['protein'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      expirationDate: json['expiration_date'] != null
          ? DateTime.tryParse(json['expiration_date'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        if (barcode != null) 'barcode': barcode,
        if (calories != null) 'calories': calories,
        if (protein != null) 'protein': protein,
        if (carbs != null) 'carbs': carbs,
        if (fat != null) 'fat': fat,
        if (expirationDate != null)
          'expiration_date':
              '${expirationDate!.year.toString().padLeft(4, '0')}-'
              '${expirationDate!.month.toString().padLeft(2, '0')}-'
              '${expirationDate!.day.toString().padLeft(2, '0')}',
      };
}
