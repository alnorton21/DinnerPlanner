import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal.dart';
import '../models/meal_plan.dart';
import '../services/supabase_service.dart';
import 'meal_detail_screen.dart';
import 'shopping_list_screen.dart';

class MealPlannerScreen extends StatefulWidget {
  final DateTime? initialWeekStart;
  const MealPlannerScreen({super.key, this.initialWeekStart});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  late DateTime _currentWeekStart;
  List<MealPlan> _plans = [];
  List<Meal> _allMeals = [];
  bool _loading = true;
  bool _summaryExpanded = true;

  double _calTarget = 2000;
  double _proTarget = 150;
  double _carbTarget = 250;
  double _fatTarget = 65;

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
    _currentWeekStart = widget.initialWeekStart ?? _getWeekStart(DateTime.now());
    _loadGoals();
    _loadWeek();
  }

  Future<void> _loadGoals() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final data = await Supabase.instance.client
        .from('user_profiles')
        .select('calorie_goal, protein_goal, carb_goal, fat_goal')
        .eq('user_id', userId)
        .maybeSingle();
    if (data != null && mounted) {
      setState(() {
        _calTarget  = (data['calorie_goal'] as num?)?.toDouble() ?? _calTarget;
        _proTarget  = (data['protein_goal'] as num?)?.toDouble() ?? _proTarget;
        _carbTarget = (data['carb_goal']    as num?)?.toDouble() ?? _carbTarget;
        _fatTarget  = (data['fat_goal']     as num?)?.toDouble() ?? _fatTarget;
      });
    }
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

  Map<String, double> _getDayNutrition(int dayIndex) {
    final dayPlans = _plans.where((p) => p.dayOfWeek == dayIndex && p.mealId != null);
    double cal = 0, protein = 0, carbs = 0, fat = 0;
    for (final p in dayPlans) {
      cal += p.mealCalories;
      protein += p.mealProtein;
      carbs += p.mealCarbs;
      fat += p.mealFat;
    }
    return {'calories': cal, 'protein': protein, 'carbs': carbs, 'fat': fat};
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

  /// Returns per-day calories (index 0–6) and weekly averages.
  Map<String, dynamic> _getWeekNutritionSummary() {
    final dayCals = List<double>.generate(7, (i) => _getDayNutrition(i)['calories']!);
    double totalCal = 0, totalPro = 0, totalCarb = 0, totalFat = 0;
    int daysWithData = 0;
    for (int i = 0; i < 7; i++) {
      final n = _getDayNutrition(i);
      if (n['calories']! > 0) {
        totalCal += n['calories']!;
        totalPro += n['protein']!;
        totalCarb += n['carbs']!;
        totalFat += n['fat']!;
        daysWithData++;
      }
    }
    final d = daysWithData > 0 ? daysWithData.toDouble() : 1;
    return {
      'dayCals': dayCals,
      'avgCal': totalCal / d,
      'avgPro': totalPro / d,
      'avgCarb': totalCarb / d,
      'avgFat': totalFat / d,
      'daysWithData': daysWithData,
    };
  }

  Widget _buildWeeklySummary() {
    final summary = _getWeekNutritionSummary();
    final dayCals = summary['dayCals'] as List<double>;
    final daysWithData = summary['daysWithData'] as int;
    const dayAbbr = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const barMaxHeight = 56.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          // Header row — tappable to collapse
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            onTap: () => setState(() => _summaryExpanded = !_summaryExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(
                children: [
                  const Text('Weekly Summary',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const Spacer(),
                  if (daysWithData > 0)
                    Text(
                      '${summary['avgCal'].toStringAsFixed(0)} cal/day avg',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    _summaryExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
          // Collapsible body
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _summaryExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    child: Column(
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        // Daily calorie bars
                        if (daysWithData == 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Add meals to see your weekly summary',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13),
                            ),
                          )
                        else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(7, (i) {
                              final cal = dayCals[i];
                              final ratio = (cal / _calTarget).clamp(0.0, 1.5);
                              final barH = ratio * barMaxHeight;
                              final color = cal <= _calTarget
                                  ? Colors.green
                                  : cal <= _calTarget * 1.2
                                      ? Colors.orange
                                      : Colors.red;
                              return Expanded(
                                child: Column(
                                  children: [
                                    // Target line spacer so all bars align at bottom
                                    SizedBox(height: barMaxHeight - barH.clamp(0, barMaxHeight)),
                                    Container(
                                      height: barH.clamp(2.0, barMaxHeight * 1.5),
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      decoration: BoxDecoration(
                                        color: cal > 0 ? color : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dayAbbr[i],
                                      style: TextStyle(
                                          fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                    ),
                                    if (cal > 0)
                                      Text(
                                        cal.toStringAsFixed(0),
                                        style: const TextStyle(fontSize: 9),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 10),
                            child: Text(
                              'Target: ${_calTarget.toStringAsFixed(0)} cal/day',
                              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          // Weekly macro averages
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Weekly avg:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('${summary['avgPro'].toStringAsFixed(1)} g protein',
                                  style: const TextStyle(fontSize: 12, color: Colors.blue)),
                              Text('${summary['avgCarb'].toStringAsFixed(1)} g carbs',
                                  style: const TextStyle(fontSize: 12, color: Colors.green)),
                              Text('${summary['avgFat'].toStringAsFixed(1)} g fat',
                                  style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous week',
              onPressed: () => _navigateWeek(-1),
              visualDensity: VisualDensity.compact,
            ),
            Flexible(
              child: Text(
                _weekLabel,
                style: const TextStyle(fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next week',
              onPressed: () => _navigateWeek(1),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        centerTitle: true,
        actions: [
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
                  _buildWeeklySummary(),
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
    final nutrition = _getDayNutrition(dayIndex);
    final hasNutrition = nutrition['calories']! > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dayLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (hasNutrition)
                    Text(
                      '${nutrition['calories']!.toStringAsFixed(0)} cal',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                    ),
                ],
              ),
              if (hasNutrition) ...[
                const SizedBox(height: 8),
                _MacroBar(
                  label: 'Cal',
                  value: nutrition['calories']!,
                  target: _calTarget,
                  unit: 'cal',
                  color: Colors.orange,
                ),
                const SizedBox(height: 4),
                _MacroBar(
                  label: 'Protein',
                  value: nutrition['protein']!,
                  target: _proTarget,
                  unit: 'g',
                  color: Colors.blue,
                ),
                const SizedBox(height: 4),
                _MacroBar(
                  label: 'Carbs',
                  value: nutrition['carbs']!,
                  target: _carbTarget,
                  unit: 'g',
                  color: Colors.green,
                ),
                const SizedBox(height: 4),
                _MacroBar(
                  label: 'Fat',
                  value: nutrition['fat']!,
                  target: _fatTarget,
                  unit: 'g',
                  color: Colors.redAccent,
                ),
              ],
            ],
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
            if (meals.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'No meals added',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              )
            else
              for (final plan in meals)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: plan.mealId != null
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MealDetailScreen(mealId: plan.mealId!),
                            ),
                          )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.mealName ?? '',
                                style: const TextStyle(fontSize: 14),
                              ),
                              if (plan.mealCalories > 0)
                                Text(
                                  '${plan.mealCalories.toStringAsFixed(0)} cal / serving',
                                  style: TextStyle(
                                      fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                ),
                            ],
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
                ),
          ],
        ),
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final String unit;
  final Color color;

  const _MacroBar({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (value / target).clamp(0.0, 1.0);
    final valueText = value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    final targetText = target == target.truncateToDouble()
        ? target.toInt().toString()
        : target.toStringAsFixed(0);

    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 72,
          child: Text(
            '$valueText / $targetText $unit',
            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
