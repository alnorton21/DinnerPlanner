import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/nutrition_service.dart';
import 'barcode_scanner_screen.dart';

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
  final caloriesController = TextEditingController();
  final proteinController = TextEditingController();
  final carbsController = TextEditingController();
  final fatController = TextEditingController();
  final _myIngredientFilterController = TextEditingController();

  TextEditingController? _autocompleteController;

  String _selectedUnit = 'g';

  final Map<String, double> unitToGram = {
    'g': 1,
    'kg': 1000,
    'oz': 28.3495,
    'lb': 453.592,
    'cup': 240,
    'tbsp': 15,
    'tsp': 5,
  };

  // Nutrition values per 100g — drives scaleNutrition
  Map<String, double> baseNutrition = {
    'calories': 0,
    'protein': 0,
    'carbs': 0,
    'fat': 0,
  };

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

      final qty = double.tryParse(ing['quantity']?.toString() ?? '100') ?? 100;
      final unit = ing['unit']?.toString() ?? 'g';
      _selectedUnit = unitToGram.containsKey(unit) ? unit : 'g';
      quantityController.text =
          qty == qty.truncateToDouble() ? qty.toInt().toString() : qty.toString();

      final cal = (ing['calories'] as num?)?.toDouble() ?? 0;
      final pro = (ing['protein'] as num?)?.toDouble() ?? 0;
      final carb = (ing['carbs'] as num?)?.toDouble() ?? 0;
      final fat = (ing['fat'] as num?)?.toDouble() ?? 0;

      caloriesController.text = cal.toStringAsFixed(1);
      proteinController.text = pro.toStringAsFixed(1);
      carbsController.text = carb.toStringAsFixed(1);
      fatController.text = fat.toStringAsFixed(1);

      // Reverse-engineer per-100g base nutrition
      final gramFactor = unitToGram[_selectedUnit] ?? 1;
      final grams = qty * gramFactor;
      if (grams > 0) {
        baseNutrition = {
          'calories': cal / grams * 100,
          'protein': pro / grams * 100,
          'carbs': carb / grams * 100,
          'fat': fat / grams * 100,
        };
      }
    }

    // Add listener AFTER setting initial values to avoid triggering during init
    quantityController.addListener(scaleNutrition);
  }

  @override
  void dispose() {
    quantityController.removeListener(scaleNutrition);
    nameController.dispose();
    quantityController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
    _myIngredientFilterController.dispose();
    super.dispose();
  }

  void scaleNutrition() {
    final quantity = double.tryParse(quantityController.text) ?? 0;
    final factor = unitToGram[_selectedUnit] ?? 1;
    final grams = quantity * factor;
    if (grams <= 0) return;
    setState(() {
      caloriesController.text =
          ((baseNutrition['calories'] ?? 0) * grams / 100).toStringAsFixed(1);
      proteinController.text =
          ((baseNutrition['protein'] ?? 0) * grams / 100).toStringAsFixed(1);
      carbsController.text =
          ((baseNutrition['carbs'] ?? 0) * grams / 100).toStringAsFixed(1);
      fatController.text =
          ((baseNutrition['fat'] ?? 0) * grams / 100).toStringAsFixed(1);
    });
  }

  Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    if (query.length < 2) return [];
    final cached = await supabase
        .from('food_cache')
        .select()
        .ilike('name', '%$query%')
        .limit(10);
    if (cached.isNotEmpty) {
      return cached.map<Map<String, dynamic>>((f) => {
            'name': f['name'],
            'calories': f['calories'],
            'protein': f['protein'],
            'carbs': f['carbs'],
            'fat': f['fat'],
          }).toList();
    }
    final apiFoods = await NutritionService.searchFood(query);
    return apiFoods.map<Map<String, dynamic>>((food) => {
          'fdcId': food['fdcId'],
          'name': food['description'],
          'nutrients': food['foodNutrients'],
        }).toList();
  }

  Future<void> selectFood(Map food) async {
    Map<String, double> nutrients;
    if (food.containsKey('nutrients')) {
      nutrients = NutritionService.extractNutrition(food['nutrients']);
      await supabase.from('food_cache').insert({
        'fdc_id': food['fdcId'],
        'name': food['name'],
        'calories': nutrients['calories'],
        'protein': nutrients['protein'],
        'carbs': nutrients['carbs'],
        'fat': nutrients['fat'],
      });
    } else {
      nutrients = {
        'calories': (food['calories'] as num?)?.toDouble() ?? 0,
        'protein': (food['protein'] as num?)?.toDouble() ?? 0,
        'carbs': (food['carbs'] as num?)?.toDouble() ?? 0,
        'fat': (food['fat'] as num?)?.toDouble() ?? 0,
      };
    }
    nameController.text = food['name'];
    _autocompleteController?.text = food['name'];
    // Set baseNutrition (USDA values are per 100g)
    baseNutrition = Map<String, double>.from(nutrients);
    quantityController.text = '100';
    setState(() => _selectedUnit = 'g');
    // Listener fires from quantityController.text change and calls scaleNutrition
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
        .select('name, quantity, unit, calories, protein, carbs, fat')
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
    final qty = double.tryParse(ing['quantity']?.toString() ?? '100') ?? 100;
    final unit = ing['unit']?.toString() ?? 'g';
    final gramFactor = unitToGram[unit] ?? 1;
    final grams = qty * gramFactor;
    if (grams > 0) {
      baseNutrition = {
        'calories': ((ing['calories'] as num?)?.toDouble() ?? 0) / grams * 100,
        'protein': ((ing['protein'] as num?)?.toDouble() ?? 0) / grams * 100,
        'carbs': ((ing['carbs'] as num?)?.toDouble() ?? 0) / grams * 100,
        'fat': ((ing['fat'] as num?)?.toDouble() ?? 0) / grams * 100,
      };
    }
    nameController.text = ing['name'];
    _autocompleteController?.text = ing['name'];
    setState(() => _selectedUnit = unitToGram.containsKey(unit) ? unit : 'g');
    quantityController.text = '100';
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode == null || !mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Looking up product...')));

    final result = await NutritionService.lookupBarcode(barcode);

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Product not found. Enter details manually.')),
      );
      return;
    }

    // OpenFoodFacts values are per 100g
    baseNutrition = {
      'calories': (result['calories'] as num).toDouble(),
      'protein': (result['protein'] as num).toDouble(),
      'carbs': (result['carbs'] as num).toDouble(),
      'fat': (result['fat'] as num).toDouble(),
    };
    nameController.text = result['name'];
    _autocompleteController?.text = result['name'];
    setState(() => _selectedUnit = 'g');
    quantityController.text = '100'; // triggers scaleNutrition via listener
  }

  Future<void> saveIngredient() async {
    if (nameController.text.trim().isEmpty ||
        quantityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name and quantity.')),
      );
      return;
    }
    final data = {
      'meal_id': widget.mealId,
      'name': nameController.text.trim(),
      'quantity': quantityController.text.trim(),
      'unit': _selectedUnit,
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
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Food Database'),
                    selected: !_showUserIngredients,
                    onSelected: (_) =>
                        setState(() => _showUserIngredients = false),
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
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _scanBarcode,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Barcode'),
              ),
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
                fieldViewBuilder:
                    (context, controller, focusNode, onEditingComplete) {
                  _autocompleteController = controller;
                  if (isEditing &&
                      controller.text.isEmpty &&
                      nameController.text.isNotEmpty) {
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
                  child: Text('No saved ingredients yet.'),
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
                            (ing['name'] as String).toLowerCase().contains(
                                _myIngredientFilterController.text
                                    .toLowerCase()))
                        .map((ing) => ListTile(
                              dense: true,
                              title: Text(ing['name']),
                              subtitle: Text(
                                  '${ing['unit']} · ${(ing['calories'] as num?)?.toStringAsFixed(0) ?? 0} cal'),
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedUnit,
                        isDense: true,
                        items: unitToGram.keys
                            .map((u) =>
                                DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _selectedUnit = val);
                          scaleNutrition();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: caloriesController,
                  decoration: const InputDecoration(labelText: 'Calories'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: proteinController,
                  decoration: const InputDecoration(labelText: 'Protein (g)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: carbsController,
                  decoration: const InputDecoration(labelText: 'Carbs (g)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: fatController,
                  decoration: const InputDecoration(labelText: 'Fat (g)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ]),
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
