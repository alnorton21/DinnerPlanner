import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'meal_planner_screen.dart';

class MonthlyCalendarScreen extends StatefulWidget {
  const MonthlyCalendarScreen({super.key});

  @override
  State<MonthlyCalendarScreen> createState() => _MonthlyCalendarScreenState();
}

class _MonthlyCalendarScreenState extends State<MonthlyCalendarScreen> {
  late DateTime _displayMonth;
  DateTime? _selectedWeekStart;
  // Set of day strings "yyyy-MM-dd" that have planned meals
  Set<String> _plannedDays = {};

  static const _dayHeaders = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month, 1);
    _selectedWeekStart = _weekStart(now);
    _loadPlannedDays();
  }

  DateTime _weekStart(DateTime date) {
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadPlannedDays() async {
    // Load the whole month plus neighbouring weeks
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final lastDay = DateTime(_displayMonth.year, _displayMonth.month + 1, 0);
    final weekBeforeStart = _weekStart(firstDay);
    final weekAfterEnd = _weekStart(lastDay).add(const Duration(days: 6));

    try {
      final response = await Supabase.instance.client
          .from('meal_plans')
          .select('week_start, day_of_week')
          .gte('week_start', _dayKey(weekBeforeStart))
          .lte('week_start', _dayKey(weekAfterEnd));

      final planned = <String>{};
      for (final row in response as List) {
        final ws = DateTime.tryParse(row['week_start'] as String);
        final dow = row['day_of_week'] as int?;
        if (ws != null && dow != null) {
          planned.add(_dayKey(ws.add(Duration(days: dow))));
        }
      }
      if (mounted) setState(() => _plannedDays = planned);
    } catch (_) {
      // Non-critical — just won't show dots
    }
  }

  void _navigateMonth(int direction) {
    setState(() {
      _displayMonth = DateTime(
        _displayMonth.year,
        _displayMonth.month + direction,
        1,
      );
    });
    _loadPlannedDays();
  }

  // Returns a list of weeks; each week is a list of 7 DateTime? (null = padding)
  List<List<DateTime?>> _buildCalendarWeeks() {
    final firstOfMonth = _displayMonth;
    final daysInMonth =
        DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
    // weekday: Monday=1 … Sunday=7
    final startPad = firstOfMonth.weekday - 1;

    final cells = <DateTime?>[];
    for (int i = 0; i < startPad; i++) {
      cells.add(null);
    }
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(firstOfMonth.year, firstOfMonth.month, d));
    }
    // Pad to full weeks
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final weeks = <List<DateTime?>>[];
    for (int i = 0; i < cells.length; i += 7) {
      weeks.add(cells.sublist(i, i + 7));
    }
    return weeks;
  }

  DateTime? _weekStartForRow(List<DateTime?> row) {
    final first = row.firstWhere((d) => d != null, orElse: () => null);
    if (first == null) return null;
    // Monday of that week
    return _weekStart(first);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayKey = _dayKey(today);
    final selectedKey =
        _selectedWeekStart != null ? _dayKey(_selectedWeekStart!) : null;
    final weeks = _buildCalendarWeeks();
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Planner'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _displayMonth =
                    DateTime(today.year, today.month, 1);
                _selectedWeekStart = _weekStart(today);
              });
              _loadPlannedDays();
            },
            child: const Text('Today', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Month navigation header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _navigateMonth(-1),
                ),
                Expanded(
                  child: Text(
                    '${_monthNames[_displayMonth.month]} ${_displayMonth.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _navigateMonth(1),
                ),
              ],
            ),
          ),

          // Day-of-week headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: _dayHeaders
                  .map((h) => Expanded(
                        child: Text(
                          h,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),

          // Calendar grid
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
              itemCount: weeks.length,
              itemBuilder: (_, weekIdx) {
                final week = weeks[weekIdx];
                final weekStartDate = _weekStartForRow(week);
                final isSelectedWeek = weekStartDate != null &&
                    selectedKey != null &&
                    _dayKey(weekStartDate) == selectedKey;

                return GestureDetector(
                  onTap: weekStartDate == null
                      ? null
                      : () {
                          setState(
                              () => _selectedWeekStart = weekStartDate);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MealPlannerScreen(
                                  initialWeekStart: weekStartDate),
                            ),
                          ).then((_) => _loadPlannedDays());
                        },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelectedWeek
                          ? primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelectedWeek
                          ? Border.all(
                              color: primary.withValues(alpha: 0.35),
                              width: 1.5)
                          : null,
                    ),
                    child: Row(
                      children: week.map((day) {
                        if (day == null) {
                          return const Expanded(child: SizedBox(height: 52));
                        }
                        final key = _dayKey(day);
                        final isToday = key == todayKey;
                        final isCurrentMonth =
                            day.month == _displayMonth.month;
                        final hasPlanned = _plannedDays.contains(key);

                        return Expanded(
                          child: SizedBox(
                            height: 52,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: isToday
                                      ? BoxDecoration(
                                          color: primary,
                                          shape: BoxShape.circle,
                                        )
                                      : null,
                                  child: Center(
                                    child: Text(
                                      '${day.day}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isToday
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isToday
                                            ? Colors.white
                                            : isCurrentMonth
                                                ? Theme.of(context).colorScheme.onSurface
                                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (hasPlanned)
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: primary,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                else
                                  const SizedBox(height: 5),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),

          // "Open week" button
          if (_selectedWeekStart != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MealPlannerScreen(
                            initialWeekStart: _selectedWeekStart),
                      ),
                    ).then((_) => _loadPlannedDays());
                  },
                  icon: const Icon(Icons.calendar_view_week),
                  label: const Text('View Selected Week'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
