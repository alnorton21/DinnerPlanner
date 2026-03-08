import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class MealDetailScreen extends StatefulWidget {
  final int mealId;

  const MealDetailScreen({super.key, required this.mealId});

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {

  Map<String, dynamic>? meal;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadMeal();
  }

  Future<void> loadMeal() async {
    final supabase = SupabaseService.client;

    final data = await supabase
        .from('meals')
        .select('*, ingredients(*)')
        .eq('id', widget.mealId)
        .single();

    setState(() {
      meal = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final ingredients = meal!['ingredients'] as List;

    return Scaffold(
      appBar: AppBar(
        title: Text(meal!['name']),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            if (meal!['image_url'] != null)
              Image.network(meal!['image_url']),

            const SizedBox(height: 20),

            const Text(
              "Ingredients",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                itemCount: ingredients.length,
                itemBuilder: (context, index) {
                  final ingredient = ingredients[index];

                  return ListTile(
                    title: Text(ingredient['name']),
                    subtitle: Text(ingredient['amount'] ?? ''),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}