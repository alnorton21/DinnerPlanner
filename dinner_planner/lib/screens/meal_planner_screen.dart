import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal.dart';
import '../models/meal_plan.dart';
import '../services/supabase_service.dart';
import 'shopping_list_screen.dart';

class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  late DateTime _currentWeekStart;
  List<MealPlan> _plans = [];
  List<Meal> _allMeals = [];
  bool _loading = true;

  static const List<String> _slots = ['breakfast', 'lunch', 'dinner', 'snack'];
  static const List<String> _dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  static const List<String> _monthAbbr = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _getWeekStart(DateTime.now());
    _loadWeek();
  }

  DateTime _getWeekStart(DateTime date) {
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
  }

  String _fmtDate(DateTime d) => '${_monthAbbr[d.month]} ${d.day}';

  String get _weekLabel {
    final end = _currentWeekStart.add(const Duration(days: 6));
    return '${_fmtDate(_currentWeekStart)} – ${_fmtDate(end)}';
  }

  Future<void> _loadWeek() async {
    setState(() => _loading = true);
    final plans = await SupabaseService().getMealPlan(_currentWeekStart);
    setState(() {
      _plans = plans;
      _loading = false;
    });
  }

  Future<void> _loadAllMeals() async {
    final response = await Supabase.instance.client
        .from('meals')
        .select()
        .order('id', ascending: false);
    setState(() {
      _allMeals = (response as List).map((e) => Meal.fromJson(e)).toList();
    });
  }

  void _navigateWeek(int direction) {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(Duration(days: 7 * direction));
    });
    _loadWeek();
  }

  List<MealPlan> _getMealsForSlot(int dayIndex, String slot) {
    return _plans
        .where((p) => p.dayOfWeek == dayIndex && p.mealSlot == slot && p.mealId != null)
        .toList();
  }

  Future<void> _onAddToSlot(int dayIndex, String slot) async {
    if (_allMeals.isEmpty) await _loadAllMeals();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Add meal to ${_dayNames[dayIndex]} ${slot[0].toUpperCase()}${slot.substring(1)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            Expanded(
              child: _allMeals.isEmpty
                  ? const Center(child: Text('No meals found. Add meals first.'))
                  : ListView.builder(
                      controller: controller,
                      itemCount: _allMeals.length,
                      itemBuilder: (_, i) {
                        final meal = _allMeals[i];
                        return ListTile(
                          leading: meal.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    meal.imageUrl!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.restaurant, size: 48),
                                  ),
                                )
                              : const Icon(Icons.restaurant, size: 48),
                          title: Text(meal.name),
                          onTap: () {
                            Navigator.pop(ctx);
                            _assignMeal(dayIndex, slot, meal);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignMeal(int dayIndex, String slot, Meal meal) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final plan = MealPlan(
      userId: userId,
      weekStart: _currentWeekStart,
      dayOfWeek: dayIndex,
      mealSlot: slot,
      mealId: meal.id,
      mealName: meal.name,
      mealImageUrl: meal.imageUrl,
    );
    await SupabaseService().addMealPlanEntry(plan);
    await _loadWeek();
  }

  Future<void> _removeEntry(int planId) async {
    await SupabaseService().clearMealPlanSlot(planId);
    await _loadWeek();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Flutter auto-adds back button as leading when there's a previous route
        title: Text(_weekLabel),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous week',
            onPressed: () => _navigateWeek(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next week',
            onPressed: () => _navigateWeek(1),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            tooltip: 'Shopping List',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShoppingListScreen(
                    plans: _plans,
                    weekStart: _currentWeekStart,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (int dayIndex = 0; dayIndex < 7; dayIndex++)
                    _buildDaySection(dayIndex),
                ],
              ),
            ),
    );
  }

  Widget _buildDaySection(int dayIndex) {
    final date = _currentWeekStart.add(Duration(days: dayIndex));
    final dayLabel = '${_dayNames[dayIndex]}, ${_fmtDate(date)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            dayLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        const SizedBox(height: 4),
        for (final slot in _slots) _buildSlotSection(dayIndex, slot),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSlotSection(int dayIndex, String slot) {
    final meals = _getMealsForSlot(dayIndex, slot);
    final slotLabel = slot[0].toUpperCase() + slot.substring(1);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Slot header row
            Row(
              children: [
                Text(
                  slotLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _onAddToSlot(dayIndex, slot),
                ),
              ],
            ),
            // Assigned meals list
            if (meals.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'No meals added',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              )
            else
              for (final plan in meals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      plan.mealImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                plan.mealImageUrl!,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.restaurant, size: 36),
                              ),
                            )
                          : const Icon(Icons.restaurant, size: 36),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          plan.mealName ?? '',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _removeEntry(plan.id!),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
