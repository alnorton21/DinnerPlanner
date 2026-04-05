import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal.dart';
import 'add_meal_screen.dart';
import 'meal_detail_screen.dart';

class MealListScreen extends StatefulWidget {
  const MealListScreen({super.key});

  @override
  State<MealListScreen> createState() => _MealListScreenState();
}

class _MealListScreenState extends State<MealListScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Meal> meals = [];
  List<Meal> _filteredMeals = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => _filterMeals(_searchController.text));
    loadMeals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadMeals() async {
    setState(() {
      loading = true;
    });

    final data = await supabase
        .from('meals')
        .select()
        .order('id', ascending: false);

    meals = (data as List).map((meal) => Meal.fromJson(meal)).toList();
    _filteredMeals = List.from(meals);

    setState(() {
      loading = false;
    });
  }

  void _filterMeals(String query) {
    setState(() {
      _filteredMeals = query.isEmpty
          ? List.from(meals)
          : meals
              .where((m) => m.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  Future<void> deleteMeal(int id) async {
    await supabase.from('meals').delete().eq('id', id);
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
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search meals...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: loadMeals,
                    child: _filteredMeals.isEmpty
                        ? Center(
                            child: Text(meals.isEmpty
                                ? 'No meals yet'
                                : 'No meals match your search'),
                          )
                        : ListView.builder(
                            itemCount: _filteredMeals.length,
                            itemBuilder: (context, index) {
                              final meal = _filteredMeals[index];

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                child: ListTile(
                                  onTap: () {
                                    if (meal.id != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              MealDetailScreen(mealId: meal.id!),
                                        ),
                                      );
                                    }
                                  },
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
                ),
              ],
            ),
    );
  }
}
