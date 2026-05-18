import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal.dart';
import '../services/local_cache_service.dart';
import 'add_meal_screen.dart';
import 'meal_detail_screen.dart';

const _kAllCategories = [
  'Breakfast', 'Lunch', 'Dinner', 'Snack', 'Main', 'Side',
];

class MealListScreen extends StatefulWidget {
  const MealListScreen({super.key});

  @override
  State<MealListScreen> createState() => _MealListScreenState();
}

class _MealListScreenState extends State<MealListScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Meal> _meals = [];
  List<Meal> _filtered = [];
  final Set<String> _selectedCategories = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _loadFromCache();
    _loadFromSupabase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFromCache() async {
    final rows = await LocalCacheService.getMeals();
    if (rows.isEmpty || !mounted) return;
    final meals = rows.map((r) => Meal.fromJson(r)).toList();
    setState(() {
      _meals = meals;
      _loading = false;
    });
    _applyFilters();
  }

  Future<void> _loadFromSupabase() async {
    try {
      final data = await supabase
          .from('meals')
          .select()
          .order('id', ascending: false);
      final rows = List<Map<String, dynamic>>.from(data as List);

      if (!mounted) return;
      final meals = rows.map((r) => Meal.fromJson(r)).toList();
      setState(() {
        _meals = meals;
        _loading = false;
      });
      _applyFilters();

      LocalCacheService.upsertMeals(rows).catchError((_) {});
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _meals.where((m) {
        final matchesSearch =
            q.isEmpty || m.name.toLowerCase().contains(q);
        final matchesCategory = _selectedCategories.isEmpty ||
            m.categories.any((c) => _selectedCategories.contains(c));
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _loadFromSupabase();
  }

  Future<void> _deleteMeal(int id) async {
    await supabase.from('meals').delete().eq('id', id);
    await LocalCacheService.deleteMeal(id);
    await _loadFromSupabase();
  }

  Future<void> _confirmDelete(Meal meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text('Remove "${meal.name}" from your recipes?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && meal.id != null) _deleteMeal(meal.id!);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Meals')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddMealScreen()),
          );
          _refresh();
        },
      ),
      body: Column(children: [
        // ── Search ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search meals...',
              prefixIcon: Icon(Icons.search,
                  color: cs.onSurface.withValues(alpha: 0.5)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
            ),
          ),
        ),

        // ── Category chips ─────────────────────────────────────────────────
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: _kAllCategories.map((cat) {
              final selected = _selectedCategories.contains(cat);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (val) {
                    setState(() => val
                        ? _selectedCategories.add(cat)
                        : _selectedCategories.remove(cat));
                    _applyFilters();
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // ── List ───────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: _filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.restaurant_menu,
                                    size: 64,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.2)),
                                const SizedBox(height: 16),
                                Text(
                                  _meals.isEmpty
                                      ? 'No meals yet'
                                      : 'No meals match your filters',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.5)),
                                ),
                                if (_meals.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap + to add your first meal',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.4)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final meal = _filtered[index];
                            return _MealCard(
                              meal: meal,
                              onTap: () {
                                if (meal.id != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MealDetailScreen(
                                          mealId: meal.id!),
                                    ),
                                  );
                                }
                              },
                              onDelete: () => _confirmDelete(meal),
                            );
                          },
                        ),
                ),
        ),
      ]),
    );
  }
}

class _MealCard extends StatelessWidget {
  final Meal meal;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MealCard({
    required this.meal,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Info ──────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (meal.categories.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: meal.categories
                            .map((c) => _CategoryPill(label: c))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${meal.servings} serving${meal.servings == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // ── Thumbnail ─────────────────────────────────────────────
              _Thumbnail(imageUrl: meal.imageUrl, name: meal.name),
              const SizedBox(width: 4),

              // ── Delete ────────────────────────────────────────────────
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 20,
                    color: cs.onSurface.withValues(alpha: 0.35)),
                onPressed: onDelete,
                style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(36, 36)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? imageUrl;
  final String name;
  const _Thumbnail({this.imageUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: imageUrl != null
          ? Image.network(
              imageUrl!,
              width: 68,
              height: 68,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(cs),
            )
          : _placeholder(cs),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Container(
      width: 68,
      height: 68,
      color: cs.primaryContainer,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: cs.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  const _CategoryPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cs.onSecondaryContainer,
        ),
      ),
    );
  }
}
