import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IngredientSearchScreen extends StatefulWidget {
  const IngredientSearchScreen({super.key});

  @override
  State<IngredientSearchScreen> createState() => _IngredientSearchScreenState();
}

class _IngredientSearchScreenState extends State<IngredientSearchScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _allIngredients = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filter);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final mealsResponse = await _supabase.from('meals').select('id');
    final mealIds =
        (mealsResponse as List).map((m) => m['id']).toList();

    if (mealIds.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final rows = await _supabase
        .from('ingredients')
        .select('name, quantity, unit, calories, protein, carbs, fat')
        .inFilter('meal_id', mealIds);

    final seen = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (final row in rows as List) {
      final name = (row['name'] as String).toLowerCase();
      if (seen.add(name)) deduped.add(Map<String, dynamic>.from(row));
    }
    deduped.sort((a, b) =>
        (a['name'] as String).compareTo(b['name'] as String));

    setState(() {
      _allIngredients = deduped;
      _filtered = deduped;
      _loading = false;
    });
  }

  void _filter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allIngredients
          : _allIngredients
              .where((i) =>
                  (i['name'] as String).toLowerCase().contains(q))
              .toList();
    });
  }

  void _showDetail(Map<String, dynamic> ing) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            ing['name'] as String,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _NutritionRow(ing: ing),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context); // close sheet
                Navigator.pop(context, ing); // return selection
              },
              child: const Text('Select Ingredient'),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Ingredients')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search ingredients...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Text(
                        _allIngredients.isEmpty
                            ? 'No saved ingredients yet.\nAdd some meals with ingredients first.'
                            : 'No ingredients match your search.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final ing = _filtered[i];
                        final cal = (ing['calories'] as num?)
                                ?.toStringAsFixed(0) ??
                            '0';
                        final unit = ing['unit'] as String? ?? 'g';
                        return ListTile(
                          title: Text(ing['name'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text('per 100 $unit · $cal cal'),
                          trailing: Icon(Icons.chevron_right,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                          onTap: () => _showDetail(ing),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

class _NutritionRow extends StatelessWidget {
  final Map<String, dynamic> ing;
  const _NutritionRow({required this.ing});

  @override
  Widget build(BuildContext context) {
    String fmt(String key) =>
        (ing[key] as num?)?.toStringAsFixed(1) ?? '0';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Macro(label: 'Calories', value: '${fmt("calories")} cal',
            color: Colors.orange),
        _Macro(label: 'Protein', value: '${fmt("protein")}g',
            color: Colors.blue),
        _Macro(label: 'Carbs', value: '${fmt("carbs")}g',
            color: Colors.green),
        _Macro(label: 'Fat', value: '${fmt("fat")}g',
            color: Colors.redAccent),
      ],
    );
  }
}

class _Macro extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Macro({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
    ]);
  }
}
