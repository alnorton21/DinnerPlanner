import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/nutrition_service.dart';

class AddIngredientScreen extends StatefulWidget {
  final int mealId;

  const AddIngredientScreen({super.key, required this.mealId});

  @override
  State<AddIngredientScreen> createState() => _AddIngredientScreenState();
}

class _AddIngredientScreenState extends State<AddIngredientScreen> {

  final supabase = Supabase.instance.client;

  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();

  final caloriesController = TextEditingController();
  final proteinController = TextEditingController();
  final carbsController = TextEditingController();
  final fatController = TextEditingController();

  Future<List<Map<String, dynamic>>> searchFoods(String query) async {

    if (query.length < 2) {
      return [];
    }

    /// check local cache first
    final cached = await supabase
        .from('food_cache')
        .select()
        .ilike('name', '%$query%')
        .limit(10);

    if (cached.isNotEmpty) {

      return cached.map<Map<String, dynamic>>((f) {
        return {
          "name": f["name"],
          "calories": f["calories"],
          "protein": f["protein"],
          "carbs": f["carbs"],
          "fat": f["fat"]
        };
      }).toList();
    }

    /// call USDA API
    final apiFoods = await NutritionService.searchFood(query);

    return apiFoods.map<Map<String, dynamic>>((food) {

      return {
        "fdcId": food["fdcId"],
        "name": food["description"],
        "nutrients": food["foodNutrients"]
      };

    }).toList();
  }

  Future<void> selectFood(Map food) async {

    nameController.text = food["name"];

    /// API result
    if (food.containsKey("nutrients")) {

      final nutrients =
          NutritionService.extractNutrition(food["nutrients"]);

      caloriesController.text = nutrients["calories"].toString();
      proteinController.text = nutrients["protein"].toString();
      carbsController.text = nutrients["carbs"].toString();
      fatController.text = nutrients["fat"].toString();

      /// cache the result
      await supabase.from("food_cache").insert({

        "fdc_id": food["fdcId"],
        "name": food["name"],
        "calories": nutrients["calories"],
        "protein": nutrients["protein"],
        "carbs": nutrients["carbs"],
        "fat": nutrients["fat"]

      });

    } else {

      caloriesController.text = food["calories"].toString();
      proteinController.text = food["protein"].toString();
      carbsController.text = food["carbs"].toString();
      fatController.text = food["fat"].toString();

    }
  }

  Future<void> saveIngredient() async {

    await supabase.from("ingredients").insert({
      "meal_id": widget.mealId,
      "name": nameController.text,
      "quantity": quantityController.text,
      "unit": unitController.text,
      "calories": double.tryParse(caloriesController.text) ?? 0,
      "protein": double.tryParse(proteinController.text) ?? 0,
      "carbs": double.tryParse(carbsController.text) ?? 0,
      "fat": double.tryParse(fatController.text) ?? 0
    });

    Navigator.pop(context);
  }

  @override
  void dispose() {

    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();

    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Add Ingredient"),
      ),

      body: Padding(

        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text(
              "Search Ingredient",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),

            const SizedBox(height: 8),

           Autocomplete<Map<String, dynamic>>(

              displayStringForOption: (option) => option["name"],

              optionsBuilder: (textEditingValue) async {

                if (textEditingValue.text == "") {
                  return const Iterable<Map<String, dynamic>>.empty();
                }

                return await searchFoods(textEditingValue.text);
              },

              onSelected: (food) {
                selectFood(food);
              },

              fieldViewBuilder:
                  (context, controller, focusNode, onEditingComplete) {

                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Type chicken, rice, egg...",
                  ),
                );
              },
            ),

      
            const SizedBox(height: 20),

            Row(
              children: [

                Expanded(
                  child: TextField(
                    controller: quantityController,
                    decoration:
                        const InputDecoration(labelText: "Quantity"),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: TextField(
                    controller: unitController,
                    decoration:
                        const InputDecoration(labelText: "Unit"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            TextField(
              controller: caloriesController,
              decoration:
                  const InputDecoration(labelText: "Calories"),
            ),

            TextField(
              controller: proteinController,
              decoration:
                  const InputDecoration(labelText: "Protein"),
            ),

            TextField(
              controller: carbsController,
              decoration:
                  const InputDecoration(labelText: "Carbs"),
            ),

            TextField(
              controller: fatController,
              decoration:
                  const InputDecoration(labelText: "Fat"),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: saveIngredient,
                child: const Text("Save Ingredient"),
              ),
            )

          ],
        ),
      ),
    );
  }
}