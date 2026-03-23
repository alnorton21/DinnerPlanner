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
  final _myIngredientFilterController = TextEditingController();

  TextEditingController? _autocompleteController;

  bool _showUserIngredients = false;
  bool _userIngredientsLoaded = false;
  List<Map<String, dynamic>> _userIngredients = [];

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

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
    _myIngredientFilterController.dispose();
    super.dispose();
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
    _autocompleteController?.text = food['name'];

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

  Future<void> _loadUserIngredients() async {
    final mealsResponse = await supabase.from('meals').select('id');
    final mealIds = (mealsResponse as List).map((m) => m['id']).toList();
    if (mealIds.isEmpty) {
      setState(() => _userIngredientsLoaded = true);
      return;
    }
    final response = await supabase
        .from('ingredients')
        .select('name, unit, calories, protein, carbs, fat')
        .inFilter('meal_id', mealIds);
    final seen = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (final row in response as List) {
      final name = (row['name'] as String).toLowerCase();
      if (seen.add(name)) deduped.add(Map<String, dynamic>.from(row));
    }
    deduped.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    setState(() {
      _userIngredients = deduped;
      _userIngredientsLoaded = true;
    });
  }

  void _selectUserIngredient(Map<String, dynamic> ing) {
    setState(() {
      nameController.text = ing['name'];
      _autocompleteController?.text = ing['name'];
      quantityController.text = '100';
      unitController.text = ing['unit'] ?? 'g';
      caloriesController.text = (ing['calories'] as num?)?.toString() ?? '0';
      proteinController.text = (ing['protein'] as num?)?.toString() ?? '0';
      carbsController.text = (ing['carbs'] as num?)?.toString() ?? '0';
      fatController.text = (ing['fat'] as num?)?.toString() ?? '0';
    });
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

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Ingredient' : 'Add Ingredient'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingredient Name',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            // Source toggle
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Food Database'),
                    selected: !_showUserIngredients,
                    onSelected: (_) => setState(() => _showUserIngredients = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('My Ingredients'),
                    selected: _showUserIngredients,
                    onSelected: (_) {
                      setState(() => _showUserIngredients = true);
                      if (!_userIngredientsLoaded) _loadUserIngredients();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!_showUserIngredients) ...[
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
                  // Pre-fill when editing
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
            ] else ...[
              TextField(
                controller: _myIngredientFilterController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Filter my ingredients...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              if (!_userIngredientsLoaded)
                const Center(child: CircularProgressIndicator())
              else if (_userIngredients.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No saved ingredients yet. Add meals with ingredients first.'),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: _userIngredients
                        .where((ing) =>
                            _myIngredientFilterController.text.isEmpty ||
                            (ing['name'] as String)
                                .toLowerCase()
                                .contains(_myIngredientFilterController.text.toLowerCase()))
                        .map((ing) => ListTile(
                              dense: true,
                              title: Text(ing['name']),
                              subtitle: Text(
                                  '${ing['unit']} · ${(ing['calories'] as num?)?.toStringAsFixed(0) ?? 0} kcal/serving'),
                              onTap: () => _selectUserIngredient(ing),
                            ))
                        .toList(),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: proteinController,
              decoration: const InputDecoration(labelText: 'Protein'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: carbsController,
              decoration: const InputDecoration(labelText: 'Carbs'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: fatController,
              decoration: const InputDecoration(labelText: 'Fat'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
