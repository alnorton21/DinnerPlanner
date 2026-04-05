import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/nutrition_service.dart';
import 'barcode_scanner_screen.dart';

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final supabase = Supabase.instance.client;

  final mealNameController = TextEditingController();
  final instructionsController = TextEditingController();
  final servingsController = TextEditingController(text: '1');

  File? imageFile;
  String? imageUrl;

  // Ingredient controllers
  final ingredientNameController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();

  final caloriesController = TextEditingController();
  final proteinController = TextEditingController();
  final carbsController = TextEditingController();
  final fatController = TextEditingController();

  List<Map<String, dynamic>> ingredients = [];
  int? editingIndex;

  // Holds a reference to the Autocomplete widget's internal controller
  // so we can clear it after adding an ingredient.
  TextEditingController? _autocompleteController;

  // My Ingredients source
  bool _showUserIngredients = false;
  bool _userIngredientsLoaded = false;
  List<Map<String, dynamic>> _userIngredients = [];
  final _myIngredientFilterController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  // Base nutrition per 100g
  Map<String, double> baseNutrition = {
    "calories": 0,
    "protein": 0,
    "carbs": 0,
    "fat": 0,
  };

  // Unit conversion map
  final Map<String, double> unitToGram = {
    "g": 1,
    "kg": 1000,
    "oz": 28.3495,
    "lb": 453.592,
    "cup": 240,
    "tbsp": 15,
    "tsp": 5,
  };

  @override
  void initState() {
    super.initState();
    quantityController.addListener(scaleNutrition);
  }

  @override
  void dispose() {
    mealNameController.dispose();
    instructionsController.dispose();
    servingsController.dispose();
    ingredientNameController.dispose();
    quantityController.removeListener(scaleNutrition);
    quantityController.dispose();
    unitController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
    _myIngredientFilterController.dispose();
    super.dispose();
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
    setState(() {
      ingredientNameController.text = ing['name'];
      _autocompleteController?.text = ing['name'];
      quantityController.text = '100';
      unitController.text = unitToGram.containsKey(unit) ? unit : 'g';
      scaleNutrition();
    });
  }

  Future<void> pickImage() async {
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() {
        imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> uploadImage() async {
    if (imageFile == null) return;

    final fileName = 'meals/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage.from('meal-images').upload(fileName, imageFile!);
    imageUrl = supabase.storage.from('meal-images').getPublicUrl(fileName);
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
          "name": f["name"],
          "calories": f["calories"],
          "protein": f["protein"],
          "carbs": f["carbs"],
          "fat": f["fat"]
        };
      }).toList();
    }

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
    setState(() {
      ingredientNameController.text = food["name"];

      // Default quantity/unit
      quantityController.text = "100";
      unitController.text = "g";

      // Extract nutrients
      Map<String, double> nutrients;
      if (food.containsKey("nutrients")) {
        nutrients = NutritionService.extractNutrition(food["nutrients"]);
        supabase.from("food_cache").insert({
          "fdc_id": food["fdcId"],
          "name": food["name"],
          "calories": nutrients["calories"],
          "protein": nutrients["protein"],
          "carbs": nutrients["carbs"],
          "fat": nutrients["fat"]
        });
      } else {
        nutrients = {
          "calories": food["calories"]?.toDouble() ?? 0,
          "protein": food["protein"]?.toDouble() ?? 0,
          "carbs": food["carbs"]?.toDouble() ?? 0,
          "fat": food["fat"]?.toDouble() ?? 0,
        };
      }

      baseNutrition = nutrients;

      // Immediately scale nutrition
      scaleNutrition();

      editingIndex = null;
    });
  }

  void scaleNutrition() {
    final quantity = double.tryParse(quantityController.text) ?? 0;
    final unit = unitController.text.trim().toLowerCase();
    final factor = unitToGram[unit] ?? 1;
    final quantityInGrams = quantity * factor;
    if (quantityInGrams <= 0) return;

    setState(() {
      caloriesController.text =
          ((baseNutrition["calories"] ?? 0) * quantityInGrams / 100).toStringAsFixed(1);
      proteinController.text =
          ((baseNutrition["protein"] ?? 0) * quantityInGrams / 100).toStringAsFixed(1);
      carbsController.text =
          ((baseNutrition["carbs"] ?? 0) * quantityInGrams / 100).toStringAsFixed(1);
      fatController.text =
          ((baseNutrition["fat"] ?? 0) * quantityInGrams / 100).toStringAsFixed(1);
    });
  }

  void addIngredient() {
    if (ingredientNameController.text.trim().isEmpty ||
        quantityController.text.trim().isEmpty ||
        unitController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in name, quantity, and unit")),
      );
      return;
    }

    final newIngredient = {
      "name": ingredientNameController.text.trim(),
      "quantity": quantityController.text.trim(),
      "unit": unitController.text.trim(),
      "calories": double.tryParse(caloriesController.text) ?? 0,
      "protein": double.tryParse(proteinController.text) ?? 0,
      "carbs": double.tryParse(carbsController.text) ?? 0,
      "fat": double.tryParse(fatController.text) ?? 0
    };

    setState(() {
      if (editingIndex != null) {
        ingredients[editingIndex!] = newIngredient;
        editingIndex = null;
      } else {
        ingredients.add(newIngredient);
      }

      ingredientNameController.clear();
      _autocompleteController?.clear();
      quantityController.clear();
      unitController.clear();
      caloriesController.clear();
      proteinController.clear();
      carbsController.clear();
      fatController.clear();
    });
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
        const SnackBar(content: Text('Product not found. Enter details manually.')),
      );
      return;
    }

    // OpenFoodFacts values are per 100g — set baseNutrition so scaleNutrition works
    baseNutrition = {
      'calories': (result['calories'] as num).toDouble(),
      'protein': (result['protein'] as num).toDouble(),
      'carbs': (result['carbs'] as num).toDouble(),
      'fat': (result['fat'] as num).toDouble(),
    };
    setState(() {
      ingredientNameController.text = result['name'];
      _autocompleteController?.text = result['name'];
      unitController.text = 'g';
      quantityController.text = '100'; // triggers scaleNutrition via listener
    });
  }

  Future<void> saveMeal() async {
    if (mealNameController.text.trim().isEmpty) return;

    await uploadImage();

    final userId = supabase.auth.currentUser!.id;

    final mealResponse = await supabase.from('meals').insert({
      "name": mealNameController.text.trim(),
      "instructions": instructionsController.text.trim(),
      "image_url": imageUrl,
      "user_id": userId,
      "servings": int.tryParse(servingsController.text.trim()) ?? 1,
    }).select().single();

    final mealId = mealResponse['id'];

    for (var ing in ingredients) {
      await supabase.from('ingredients').insert({
        "meal_id": mealId,
        "name": ing["name"] ?? "",
        "quantity": ing["quantity"] ?? "",
        "unit": ing["unit"] ?? "",
        "calories": (ing["calories"] ?? 0).toDouble(),
        "protein": (ing["protein"] ?? 0).toDouble(),
        "carbs": (ing["carbs"] ?? 0).toDouble(),
        "fat": (ing["fat"] ?? 0).toDouble(),
      });
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Meal")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: mealNameController,
            decoration: const InputDecoration(labelText: "Meal Name"),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: instructionsController,
            decoration: const InputDecoration(
              labelText: "Instructions",
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            maxLines: null,
            minLines: 4,
            keyboardType: TextInputType.multiline,
          ),
          const SizedBox(height: 10),
          Row(children: [
            ElevatedButton(
              onPressed: pickImage,
              child: const Text("Pick Image"),
            ),
            const SizedBox(width: 10),
            imageFile != null
                ? Image.file(imageFile!, width: 80, height: 80, fit: BoxFit.cover)
                : const SizedBox()
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Text("Servings:"),
            const SizedBox(width: 12),
            SizedBox(
              width: 70,
              child: TextField(
                controller: servingsController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ]),
          const Divider(height: 30),
          const Text("Add Ingredients", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
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
              displayStringForOption: (option) => option["name"],
              optionsBuilder: (textEditingValue) async {
                if (textEditingValue.text.isEmpty) return const Iterable.empty();
                return await searchFoods(textEditingValue.text);
              },
              onSelected: selectFood,
              fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                _autocompleteController = controller;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (value) => ingredientNameController.text = value,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Search ingredient (e.g. chicken, rice...)",
                  ),
                );
              },
            ),
          ] else ...[
            TextField(
              controller: _myIngredientFilterController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Filter my ingredients...",
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
                      .where((ing) => _myIngredientFilterController.text.isEmpty ||
                          (ing['name'] as String)
                              .toLowerCase()
                              .contains(_myIngredientFilterController.text.toLowerCase()))
                      .map((ing) => ListTile(
                            dense: true,
                            title: Text(ing['name']),
                            subtitle: Text('${ing['unit']} · ${(ing['calories'] as num?)?.toStringAsFixed(0) ?? 0} cal/serving'),
                            onTap: () => _selectUserIngredient(ing),
                          ))
                      .toList(),
                ),
              ),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: "Quantity"),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: unitController.text.isEmpty ? 'g' : unitController.text,
                decoration: const InputDecoration(labelText: "Unit"),
                items: unitToGram.keys.map((unit) {
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(unit),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    unitController.text = val;
                    scaleNutrition();
                  });
                },
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: caloriesController,
                decoration: const InputDecoration(labelText: "Calories"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: proteinController,
                decoration: const InputDecoration(labelText: "Protein"),
              ),
            ),
          ]),
          Row(children: [
            Expanded(
              child: TextField(
                controller: carbsController,
                decoration: const InputDecoration(labelText: "Carbs"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: fatController,
                decoration: const InputDecoration(labelText: "Fat"),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: addIngredient,
              child: Text(editingIndex == null ? "Add Ingredient" : "Save Changes"),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Ingredient List", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...ingredients.map((ing) {
            final index = ingredients.indexOf(ing);
            return Card(
              child: ListTile(
                title: Text("${ing["quantity"]} ${ing["unit"]} ${ing["name"]}"),
                subtitle: Text(
                    "Calories: ${ing["calories"]}, Protein: ${ing["protein"]}, Carbs: ${ing["carbs"]}, Fat: ${ing["fat"]}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        setState(() {
                          ingredientNameController.text = ing["name"];
                          _autocompleteController?.text = ing["name"];
                          quantityController.text = ing["quantity"];
                          unitController.text = ing["unit"];
                          caloriesController.text = ing["calories"].toString();
                          proteinController.text = ing["protein"].toString();
                          carbsController.text = ing["carbs"].toString();
                          fatController.text = ing["fat"].toString();

                          // Reverse-engineer per-100g base nutrition
                          final qty = double.tryParse(ing["quantity"]?.toString() ?? '100') ?? 100;
                          final unit = ing["unit"]?.toString() ?? 'g';
                          final gramFactor = unitToGram[unit] ?? 1;
                          final grams = qty * gramFactor;
                          if (grams > 0) {
                            baseNutrition = {
                              "calories": ((ing["calories"] as num?)?.toDouble() ?? 0) / grams * 100,
                              "protein": ((ing["protein"] as num?)?.toDouble() ?? 0) / grams * 100,
                              "carbs": ((ing["carbs"] as num?)?.toDouble() ?? 0) / grams * 100,
                              "fat": ((ing["fat"] as num?)?.toDouble() ?? 0) / grams * 100,
                            };
                          }

                          editingIndex = index;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          ingredients.removeAt(index);
                          if (editingIndex == index) editingIndex = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: saveMeal,
              child: const Text("Save Meal"),
            ),
          ),
        ]),
      ),
    );
  }
}