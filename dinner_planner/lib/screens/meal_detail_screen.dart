import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_ingredient_screen.dart';

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

    await supabase
        .from('meals')
        .delete()
        .eq('id', widget.mealId);

    Navigator.pop(context);
  }

  Future<void> deleteIngredient(int ingredientId) async {

    await supabase
        .from('ingredients')
        .delete()
        .eq('id', ingredientId);

    loadMeal();
  }

  Map<String, double> calculateNutrition(List ingredients) {

    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;

    for (var ingredient in ingredients) {

      calories += (ingredient['calories'] ?? 0).toDouble();
      protein += (ingredient['protein'] ?? 0).toDouble();
      carbs += (ingredient['carbs'] ?? 0).toDouble();
      fat += (ingredient['fat'] ?? 0).toDouble();

    }

    return {
      "calories": calories,
      "protein": protein,
      "carbs": carbs,
      "fat": fat
    };
  }

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final nutrition = calculateNutrition(ingredients);

    return Scaffold(

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddIngredientScreen(mealId: widget.mealId),
            ),
          );

          loadMeal();
        },
      ),

      body: CustomScrollView(

        slivers: [

          SliverAppBar(
            expandedHeight: 260,
            pinned: true,

            actions: [

              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: deleteMeal,
              )

            ],

            flexibleSpace: FlexibleSpaceBar(

              title: Text(meal!['name']),

              background: meal!['image_url'] != null
                  ? Image.network(
                      meal!['image_url'],
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.restaurant,
                        size: 120,
                      ),
                    ),
            ),
          ),

          SliverToBoxAdapter(

            child: Padding(
              padding: const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  const Text(
                    "Nutrition",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),

                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceAround,

                        children: [

                          Column(
                            children: [
                              const Text("Calories"),
                              Text(
                                nutrition['calories']!
                                    .toStringAsFixed(0),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),

                          Column(
                            children: [
                              const Text("Protein"),
                              Text(
                                "${nutrition['protein']!.toStringAsFixed(1)} g",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),

                          Column(
                            children: [
                              const Text("Carbs"),
                              Text(
                                "${nutrition['carbs']!.toStringAsFixed(1)} g",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),

                          Column(
                            children: [
                              const Text("Fat"),
                              Text(
                                "${nutrition['fat']!.toStringAsFixed(1)} g",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),

                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    "Ingredients",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  ingredients.isEmpty
                      ? const Text("No ingredients yet")

                      : Column(
                          children: ingredients.map((ingredient) {

                            return Card(

                              margin:
                                  const EdgeInsets.only(bottom: 10),

                              child: ListTile(

                                leading:
                                    const Icon(Icons.kitchen),

                                title: Text(ingredient['name']),

                                subtitle: Text(
                                  "${ingredient['quantity']} ${ingredient['unit']}",
                                ),

                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,

                                  children: [

                                    IconButton(
                                      icon:
                                          const Icon(Icons.edit),
                                      onPressed: () {

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AddIngredientScreen(
                                                    mealId: widget.mealId,
                                                    ingredient: ingredient),
                                          ),
                                        ).then((_) =>
                                            loadMeal());
                                      },
                                    ),

                                    IconButton(
                                      icon:
                                          const Icon(Icons.delete),
                                      onPressed: () {

                                        deleteIngredient(
                                            ingredient['id']);
                                      },
                                    ),

                                  ],
                                ),
                              ),
                            );

                          }).toList(),
                        ),

                  const SizedBox(height: 30),

                  const Text(
                    "Instructions",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: Text(
                      meal!['instructions'] ??
                          "No instructions",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),

                  const SizedBox(height: 40)

                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}