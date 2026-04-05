import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_meal_screen.dart';

class MealDetailScreen extends StatefulWidget {
  final int mealId;

  const MealDetailScreen({super.key, required this.mealId});

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {

  final supabase = Supabase.instance.client;

  Map<String, dynamic>? meal;
  List ingredients = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadMeal();
  }

  Future<void> loadMeal() async {
    final data = await supabase
        .from('meals')
        .select('*, ingredients(*)')
        .eq('id', widget.mealId)
        .single();

    setState(() {
      meal = data;
      ingredients = data['ingredients'];
      loading = false;
    });
  }

  Future<void> deleteMeal() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete meal?'),
        content: const Text('This will permanently delete the meal and all its ingredients.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await supabase.from('meals').delete().eq('id', widget.mealId);
    if (mounted) Navigator.pop(context);
  }

  Map<String, double> _calcNutrition() {
    double calories = 0, protein = 0, carbs = 0, fat = 0;
    for (var ing in ingredients) {
      calories += (ing['calories'] ?? 0).toDouble();
      protein += (ing['protein'] ?? 0).toDouble();
      carbs += (ing['carbs'] ?? 0).toDouble();
      fat += (ing['fat'] ?? 0).toDouble();
    }
    return {'calories': calories, 'protein': protein, 'carbs': carbs, 'fat': fat};
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final servings = (meal!['servings'] as int?) ?? 1;
    final total = _calcNutrition();
    final nutrition = servings > 1
        ? {
            'calories': total['calories']! / servings,
            'protein': total['protein']! / servings,
            'carbs': total['carbs']! / servings,
            'fat': total['fat']! / servings,
          }
        : total;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit meal',
                onPressed: () async {
                  final updated = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditMealScreen(meal: meal!),
                    ),
                  );
                  if (updated == true) loadMeal();
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: deleteMeal,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(meal!['name']),
              background: meal!['image_url'] != null
                  ? Image.network(meal!['image_url'], fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.restaurant, size: 120),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text('Nutrition',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(
                        servings > 1
                            ? 'per serving ($servings servings)'
                            : 'per serving',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _nutritionCol('Calories', nutrition['calories']!.toStringAsFixed(0)),
                          _nutritionCol('Protein', '${nutrition['protein']!.toStringAsFixed(1)} g'),
                          _nutritionCol('Carbs', '${nutrition['carbs']!.toStringAsFixed(1)} g'),
                          _nutritionCol('Fat', '${nutrition['fat']!.toStringAsFixed(1)} g'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text('Ingredients',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ingredients.isEmpty
                      ? const Text('No ingredients yet')
                      : Column(
                          children: ingredients.map((ing) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.kitchen),
                              title: Text(ing['name']),
                              subtitle: Text('${ing['quantity']} ${ing['unit']}'),
                              trailing: Text(
                                '${(ing['calories'] ?? 0).toStringAsFixed(0)} cal',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          )).toList(),
                        ),
                  const SizedBox(height: 25),
                  const Text('Instructions',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      meal!['instructions'] ?? 'No instructions',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nutritionCol(String label, String value) {
    return Column(
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
