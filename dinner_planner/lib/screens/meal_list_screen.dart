import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal.dart';
import 'add_meal_screen.dart';

class MealListScreen extends StatefulWidget {
  const MealListScreen({super.key});

  @override
  State<MealListScreen> createState() => _MealListScreenState();
}

class _MealListScreenState extends State<MealListScreen> {

  final supabase = Supabase.instance.client;

  List<Meal> meals = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadMeals();
  }

  Future<void> loadMeals() async {

    setState(() {
      loading = true;
    });

    final data = await supabase
        .from('meals')
        .select()
        .order('id', ascending: false);

    meals = (data as List)
        .map((meal) => Meal.fromJson(meal))
        .toList();

    setState(() {
      loading = false;
    });
  }

  Future<void> deleteMeal(int id) async {

    await supabase
        .from('meals')
        .delete()
        .eq('id', id);

    loadMeals();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Meals"),
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddMealScreen(),
            ),
          );

          loadMeals();
        },
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(

              onRefresh: loadMeals,

              child: meals.isEmpty
                  ? const Center(child: Text("No meals yet"))

                  : ListView.builder(

                      itemCount: meals.length,

                      itemBuilder: (context, index) {

                        final meal = meals[index];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),

                          child: ListTile(

                            leading: meal.imageUrl != null
                                ? ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(6),
                                    child: Image.network(
                                      meal.imageUrl!,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(
                                    Icons.restaurant,
                                    size: 40,
                                  ),

                            title: Text(
                              meal.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),

                            subtitle: Text(
                              meal.instructions,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {

                                if (meal.id != null) {
                                  deleteMeal(meal.id!);
                                }

                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}