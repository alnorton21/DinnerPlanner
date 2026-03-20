import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/nutrition_service.dart';

class AddIngredientScreen extends StatefulWidget {
  final int mealId;
  final Map<String, dynamic>? ingredient; // non-null when editing

  const AddIngredientScreen({
    super.key,
    required this.mealId,
    this.ingredient,
  });

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

  TextEditingController? _autocompleteController;

  bool get isEditing => widget.ingredient != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final ing = widget.ingredient!;
      nameController.text = ing['name'] ?? '';
      quantityController.text = ing['quantity']?.toString() ?? '';
      unitController.text = ing['unit'] ?? '';
      caloriesController.text = ing['calories']?.toString() ?? '';
      proteinController.text = ing['protein']?.toString() ?? '';
      carbsController.text = ing['carbs']?.toString() ?? '';
      fatController.text = ing['fat']?.toString() ?? '';
    }
  }

  Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    if (query.length < 2) return [];

    final cached = await supabase
        .from('food_cache')
        .select()
        .ilike('name', '%$query%')
        .limit(10);

    if (cached.isNotEmpty) {
      return cached.map<Map<String, dynamic>>((f) {
        return {
          'name': f['name'],
          'calories': f['calories'],
          'protein': f['protein'],
          'carbs': f['carbs'],
          'fat': f['fat'],
        };
      }).toList();
    }

    final apiFoods = await NutritionService.searchFood(query);
    return apiFoods.map<Map<String, dynamic>>((food) {
      return {
        'fdcId': food['fdcId'],
        'name': food['description'],
        'nutrients': food['foodNutrients'],
      };
    }).toList();
  }

  Future<void> selectFood(Map food) async {
    nameController.text = food['name'];

    if (food.containsKey('nutrients')) {
      final nutrients = NutritionService.extractNutrition(food['nutrients']);
      caloriesController.text = nutrients['calories'].toString();
      proteinController.text = nutrients['protein'].toString();
      carbsController.text = nutrients['carbs'].toString();
      fatController.text = nutrients['fat'].toString();

      await supabase.from('food_cache').insert({
        'fdc_id': food['fdcId'],
        'name': food['name'],
        'calories': nutrients['calories'],
        'protein': nutrients['protein'],
        'carbs': nutrients['carbs'],
        'fat': nutrients['fat'],
      });
    } else {
      caloriesController.text = food['calories'].toString();
      proteinController.text = food['protein'].toString();
      carbsController.text = food['carbs'].toString();
      fatController.text = food['fat'].toString();
    }
  }

  Future<void> saveIngredient() async {
    final data = {
      'meal_id': widget.mealId,
      'name': nameController.text,
      'quantity': quantityController.text,
      'unit': unitController.text,
      'calories': double.tryParse(caloriesController.text) ?? 0,
      'protein': double.tryParse(proteinController.text) ?? 0,
      'carbs': double.tryParse(carbsController.text) ?? 0,
      'fat': double.tryParse(fatController.text) ?? 0,
    };

    if (isEditing) {
      await supabase
          .from('ingredients')
          .update(data)
          .eq('id', widget.ingredient!['id']);
    } else {
      await supabase.from('ingredients').insert(data);
    }

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
        title: Text(isEditing ? 'Edit Ingredient' : 'Add Ingredient'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search Ingredient',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Autocomplete<Map<String, dynamic>>(
              displayStringForOption: (option) => option['name'],
              optionsBuilder: (textEditingValue) async {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<Map<String, dynamic>>.empty();
                }
                return await searchFoods(textEditingValue.text);
              },
              onSelected: (food) => selectFood(food),
              fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                _autocompleteController = controller;
                // Pre-fill the autocomplete field when editing
                if (isEditing && controller.text.isEmpty && nameController.text.isNotEmpty) {
                  controller.text = nameController.text;
                }
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (value) => nameController.text = value,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Type chicken, rice, egg...',
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
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: unitController,
                    decoration: const InputDecoration(labelText: 'Unit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: caloriesController,
              decoration: const InputDecoration(labelText: 'Calories'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: proteinController,
              decoration: const InputDecoration(labelText: 'Protein'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: carbsController,
              decoration: const InputDecoration(labelText: 'Carbs'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: fatController,
              decoration: const InputDecoration(labelText: 'Fat'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveIngredient,
                child: Text(isEditing ? 'Save Changes' : 'Save Ingredient'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
