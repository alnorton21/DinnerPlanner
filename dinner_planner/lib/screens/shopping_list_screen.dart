import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/meal_plan.dart';
import '../models/shopping_item.dart';

class ShoppingListScreen extends StatefulWidget {
  final List<MealPlan> plans;
  final DateTime weekStart;

  const ShoppingListScreen({
    super.key,
    required this.plans,
    required this.weekStart,
  });

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  static const List<String> _dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const List<String> _monthAbbr = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const double _calorieTarget = 2000;
  static const double _proteinTarget = 150;

  bool _loading = true;
  List<ShoppingItem> _items = [];
  List<Map<String, double>> _dailyNutrition =
      List.generate(7, (_) => {'calories': 0, 'protein': 0});

  @override
  void initState() {
    super.initState();
    _buildShoppingList();
  }

  Future<void> _buildShoppingList() async {
    // Count how many times each meal appears in the week so quantities multiply correctly
    // e.g. if Chicken Salad is planned Monday AND Thursday, buy 2x the ingredients
    final mealIdCounts = <int, int>{};
    for (final p in widget.plans.where((p) => p.mealId != null)) {
      mealIdCounts[p.mealId!] = (mealIdCounts[p.mealId!] ?? 0) + 1;
    }

    if (mealIdCounts.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final response = await Supabase.instance.client
        .from('ingredients')
        .select()
        .inFilter('meal_id', mealIdCounts.keys.toList());

    final rows = response as List;

    // Aggregate shopping items — multiply each ingredient by how many times its meal appears
    final Map<String, ShoppingItem> aggregated = {};
    for (final row in rows) {
      final name = (row['name'] as String? ?? '').trim();
      final unit = (row['unit'] as String? ?? '').trim();
      final key = '${name.toLowerCase()}_${unit.toLowerCase()}';
      final count = mealIdCounts[row['meal_id']] ?? 1;
      final qty = (double.tryParse(row['quantity'].toString()) ?? 0.0) * count;
      final cal = ((row['calories'] as num?)?.toDouble() ?? 0.0) * count;
      final pro = ((row['protein'] as num?)?.toDouble() ?? 0.0) * count;
      final carb = ((row['carbs'] as num?)?.toDouble() ?? 0.0) * count;
      final fat = ((row['fat'] as num?)?.toDouble() ?? 0.0) * count;

      if (aggregated.containsKey(key)) {
        aggregated[key]!.totalQuantity += qty;
        aggregated[key]!.totalCalories += cal;
        aggregated[key]!.totalProtein += pro;
        aggregated[key]!.totalCarbs += carb;
        aggregated[key]!.totalFat += fat;
      } else {
        aggregated[key] = ShoppingItem(
          name: name,
          totalQuantity: qty,
          unit: unit,
          totalCalories: cal,
          totalProtein: pro,
          totalCarbs: carb,
          totalFat: fat,
        );
      }
    }

    final items = aggregated.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // Compute daily nutrition — count per-day meal occurrences for accuracy
    final dailyNutrition = List.generate(7, (_) => {'calories': 0.0, 'protein': 0.0});
    for (int day = 0; day < 7; day++) {
      // Build a count map for this specific day
      final dayMealCounts = <int, int>{};
      for (final p in widget.plans.where((p) => p.dayOfWeek == day && p.mealId != null)) {
        dayMealCounts[p.mealId!] = (dayMealCounts[p.mealId!] ?? 0) + 1;
      }
      for (final row in rows) {
        final mealId = row['meal_id'];
        final count = dayMealCounts[mealId] ?? 0;
        if (count > 0) {
          dailyNutrition[day]['calories'] =
              (dailyNutrition[day]['calories'] ?? 0) +
              ((row['calories'] as num?)?.toDouble() ?? 0.0) * count;
          dailyNutrition[day]['protein'] =
              (dailyNutrition[day]['protein'] ?? 0) +
              ((row['protein'] as num?)?.toDouble() ?? 0.0) * count;
        }
      }
    }

    setState(() {
      _items = items;
      _dailyNutrition = dailyNutrition;
      _loading = false;
    });
  }

  Future<void> _openNearbyStores() async {
    final uri = Uri.parse('https://www.google.com/maps/search/grocery+stores+near+me');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _searchIngredientInStores(String ingredientName) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Find "$ingredientName"',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Divider(),
              _StoreOption(
                icon: Icons.map_rounded,
                iconColor: Colors.green,
                label: 'Nearby grocery stores',
                subtitle: 'Opens Google Maps',
                onTap: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(
                      'https://www.google.com/maps/search/grocery+stores+near+me');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _StoreOption(
                icon: Icons.search_rounded,
                iconColor: Colors.blue,
                label: 'Google Shopping',
                subtitle: 'Compare prices online',
                onTap: () async {
                  Navigator.pop(ctx);
                  final encoded = Uri.encodeComponent(ingredientName);
                  final uri = Uri.parse(
                      'https://www.google.com/search?q=$encoded&tbm=shop');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _StoreOption(
                icon: Icons.shopping_cart_rounded,
                iconColor: const Color(0xFF007DC6),
                label: 'Walmart',
                subtitle: 'Search Walmart grocery',
                onTap: () async {
                  Navigator.pop(ctx);
                  final encoded = Uri.encodeComponent(ingredientName);
                  final uri = Uri.parse(
                      'https://www.walmart.com/search?q=$encoded&cat_id=976759');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _StoreOption(
                icon: Icons.local_shipping_rounded,
                iconColor: const Color(0xFFFF9900),
                label: 'Amazon Fresh',
                subtitle: 'Order for delivery',
                onTap: () async {
                  Navigator.pop(ctx);
                  final encoded = Uri.encodeComponent(ingredientName);
                  final uri = Uri.parse(
                      'https://www.amazon.com/s?k=$encoded&i=amazonfresh');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _StoreOption(
                icon: Icons.storefront_rounded,
                iconColor: const Color(0xFFCC0000),
                label: 'Target',
                subtitle: 'Search Target grocery',
                onTap: () async {
                  Navigator.pop(ctx);
                  final encoded = Uri.encodeComponent(ingredientName);
                  final uri = Uri.parse(
                      'https://www.target.com/s?searchTerm=$encoded&category=grocery');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _StoreOption(
                icon: Icons.local_grocery_store_rounded,
                iconColor: const Color(0xFF009A44),
                label: 'ShopRite',
                subtitle: 'Search ShopRite grocery',
                onTap: () async {
                  Navigator.pop(ctx);
                  final encoded = Uri.encodeComponent(ingredientName);
                  final uri = Uri.parse(
                      'https://www.shoprite.com/sm/planning/rsid/3000/results?q=$encoded');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _StoreOption(
                icon: Icons.savings_rounded,
                iconColor: const Color(0xFF00539B),
                label: 'Aldi',
                subtitle: 'Browse Aldi products',
                onTap: () async {
                  Navigator.pop(ctx);
                  final encoded = Uri.encodeComponent(ingredientName);
                  final uri = Uri.parse(
                      'https://www.aldi.us/en/grocery-items/?q=$encoded');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyList() {
    if (_items.isEmpty) return;
    final buffer = StringBuffer();
    buffer.writeln(
        'Shopping List – Week of ${_monthAbbr[widget.weekStart.month]} ${widget.weekStart.day}');
    buffer.writeln('');
    for (final item in _items) {
      final qty = item.totalQuantity % 1 == 0
          ? item.totalQuantity.toInt().toString()
          : item.totalQuantity.toStringAsFixed(1);
      buffer.writeln('- ${item.name}: $qty ${item.unit}');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shopping list copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekLabel =
        '${_monthAbbr[widget.weekStart.month]} ${widget.weekStart.day}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Week of $weekLabel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.store_rounded),
            tooltip: 'Find nearby grocery stores',
            onPressed: _openNearbyStores,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy list',
            onPressed: _copyList,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNutritionSection(),
                const Divider(height: 1),
                _buildShoppingListSection(),
              ],
            ),
    );
  }

  Widget _buildNutritionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('Daily Nutrition',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 7,
            itemBuilder: (_, i) => _buildDayNutritionCard(i),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDayNutritionCard(int dayIndex) {
    final date = widget.weekStart.add(Duration(days: dayIndex));
    final cal = _dailyNutrition[dayIndex]['calories'] ?? 0.0;
    final pro = _dailyNutrition[dayIndex]['protein'] ?? 0.0;
    final calProgress = (cal / _calorieTarget).clamp(0.0, 1.0);
    final proProgress = (pro / _proteinTarget).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_dayAbbr[dayIndex]} ${date.day}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text('${cal.toInt()} kcal', style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 2),
            LinearProgressIndicator(
              value: calProgress,
              color: Colors.orange,
              backgroundColor: Colors.orange.shade100,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 6),
            Text('${pro.toInt()}g protein', style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 2),
            LinearProgressIndicator(
              value: proProgress,
              color: Colors.blue,
              backgroundColor: Colors.blue.shade100,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShoppingListSection() {
    if (_items.isEmpty) {
      return const Expanded(
        child: Center(child: Text('No meals planned this week.')),
      );
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  'Ingredients (${_items.length} items)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Text(
                  'Tap  to find in stores',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const Icon(Icons.store_rounded, size: 14, color: Colors.grey),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final item = _items[i];
                final qty = item.totalQuantity % 1 == 0
                    ? item.totalQuantity.toInt().toString()
                    : item.totalQuantity.toStringAsFixed(1);
                final displayName =
                    item.name[0].toUpperCase() + item.name.substring(1);
                return ListTile(
                  leading: const Icon(Icons.shopping_basket_outlined),
                  title: Text(displayName),
                  subtitle: Text('$qty ${item.unit}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.totalCalories > 0)
                        Text(
                          '${item.totalCalories.toInt()} kcal',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.store_rounded, size: 20),
                        color: Colors.green,
                        tooltip: 'Find in stores',
                        onPressed: () =>
                            _searchIngredientInStores(item.name),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _StoreOption({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withValues(alpha: 0.12),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(label),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }
}
