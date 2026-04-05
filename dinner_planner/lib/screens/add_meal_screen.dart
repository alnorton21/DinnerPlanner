import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/nutrition_service.dart';
import '../services/recipe_import_service.dart';
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
  final _sourceUrlController = TextEditingController();
  final _importUrlController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _pasteTextController = TextEditingController();

  File? imageFile;
  String? imageUrl;
  bool _importing = false;
  bool _parsing = false;
  bool _showSourceUrl = false;
  bool _importTab = false; // false = URL, true = Paste text

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

  TextEditingController? _autocompleteController;

  bool _showUserIngredients = false;
  bool _userIngredientsLoaded = false;
  List<Map<String, dynamic>> _userIngredients = [];
  final _myIngredientFilterController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  Map<String, double> baseNutrition = {
    "calories": 0, "protein": 0, "carbs": 0, "fat": 0,
  };

  final Map<String, double> unitToGram = {
    "g": 1, "kg": 1000, "oz": 28.3495, "lb": 453.592,
    "cup": 240, "tbsp": 15, "tsp": 5,
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
    _sourceUrlController.dispose();
    _importUrlController.dispose();
    _imageUrlController.dispose();
    _pasteTextController.dispose();
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

  // ── Recipe text paste ─────────────────────────────────────────────────────

  Future<void> _parseFromText() async {
    final text = _pasteTextController.text.trim();
    if (text.isEmpty) return;

    final result = RecipeTextParser.parseRecipeText(text);

    if (result.ingredients.isEmpty && result.instructions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find ingredients in the pasted text. Check the format and try again.')),
      );
      return;
    }

    setState(() => _parsing = true);

    // Look up nutrition for each parsed ingredient
    final resolved = <Map<String, dynamic>>[];
    for (final ing in result.ingredients) {
      final unit = ing.unit == 'item' ? 'g' : ing.unit;
      final qty = ing.quantity;

      Map<String, double> nutrition = {'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0};

      try {
        // Check food_cache first
        final cached = await supabase
            .from('food_cache')
            .select()
            .ilike('name', '%${ing.name}%')
            .limit(1);

        if ((cached as List).isNotEmpty) {
          final f = cached.first;
          final gramFactor = unitToGram[unit] ?? 1;
          final grams = qty * gramFactor;
          final per100 = grams > 0 ? grams / 100 : 1;
          nutrition = {
            'calories': ((f['calories'] as num?)?.toDouble() ?? 0) * per100,
            'protein': ((f['protein'] as num?)?.toDouble() ?? 0) * per100,
            'carbs': ((f['carbs'] as num?)?.toDouble() ?? 0) * per100,
            'fat': ((f['fat'] as num?)?.toDouble() ?? 0) * per100,
          };
        } else {
          // Fall back to API
          final apiFoods = await NutritionService.searchFood(ing.name);
          if (apiFoods.isNotEmpty) {
            final food = apiFoods.first;
            final nutrients = NutritionService.extractNutrition(food['foodNutrients']);
            // Cache it
            supabase.from('food_cache').insert({
              'fdc_id': food['fdcId'],
              'name': food['description'],
              'calories': nutrients['calories'],
              'protein': nutrients['protein'],
              'carbs': nutrients['carbs'],
              'fat': nutrients['fat'],
            }).catchError((_) => null);
            final gramFactor = unitToGram[unit] ?? 1;
            final grams = qty * gramFactor;
            final per100 = grams > 0 ? grams / 100 : 1;
            nutrition = {
              'calories': (nutrients['calories'] ?? 0) * per100,
              'protein': (nutrients['protein'] ?? 0) * per100,
              'carbs': (nutrients['carbs'] ?? 0) * per100,
              'fat': (nutrients['fat'] ?? 0) * per100,
            };
          }
        }
      } catch (_) {
        // nutrition stays 0 — user can fill in manually
      }

      resolved.add({
        'name': ing.name,
        'quantity': qty.toString(),
        'unit': unit,
        'calories': nutrition['calories'],
        'protein': nutrition['protein'],
        'carbs': nutrition['carbs'],
        'fat': nutrition['fat'],
      });
    }

    if (!mounted) return;
    setState(() {
      _parsing = false;
      if (result.instructions.isNotEmpty) {
        instructionsController.text = result.instructions;
      }
      ingredients = resolved;
    });

    final withNutrition = resolved.where((i) => (i['calories'] as double) > 0).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${resolved.length} ingredient${resolved.length == 1 ? '' : 's'} found, $withNutrition with nutrition data. Enter the meal name and save.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Recipe import ──────────────────────────────────────────────────────────

  Future<void> _importFromUrl() async {
    final url = _importUrlController.text.trim();
    if (url.isEmpty) return;
    setState(() => _importing = true);

    ImportedRecipe? recipe;
    String? errorMsg;

    try {
      recipe = await RecipeImportService.importFromUrl(url);
    } on ImportException catch (e) {
      errorMsg = switch (e.failure) {
        ImportFailure.network =>
          'Could not reach that URL. Check your connection and try again.',
        ImportFailure.blocked =>
          'This site blocked the request. Try copying the URL into the browser to get the full link, or enter the recipe manually.',
        ImportFailure.noRecipe =>
          'No recipe data found. This site may not support auto-import — try a different recipe site like AllRecipes, Food Network, or NYT Cooking.',
      };
    } catch (_) {
      errorMsg = 'Something went wrong. Try again or enter the recipe manually.';
    }

    if (!mounted) return;
    setState(() => _importing = false);

    if (errorMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), duration: const Duration(seconds: 5)),
      );
      return;
    }
    if (recipe == null) return;
    final r = recipe; // promote to non-null for use inside closure

    setState(() {
      mealNameController.text = r.name;
      instructionsController.text = r.instructions;
      servingsController.text = r.servings.toString();
      _sourceUrlController.text = r.sourceUrl;
      _showSourceUrl = true;

      // Use imported image URL directly (no upload needed)
      if (r.imageUrl != null) {
        imageUrl = r.imageUrl;
        imageFile = null;
      }

      // Populate ingredients from import (nutrition is 0 — user can look up)
      ingredients = r.ingredients
          .map((ing) => {
                'name': ing.name,
                'quantity': ing.quantity.toString(),
                'unit': ing.unit == 'item' ? 'g' : ing.unit,
                'calories': 0.0,
                'protein': 0.0,
                'carbs': 0.0,
                'fat': 0.0,
              })
          .toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Recipe imported — ${r.ingredients.length} ingredient${r.ingredients.length == 1 ? '' : 's'} added. Review and save.',
        ),
      ),
    );
  }

  // ── Image helpers ──────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile =
        await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        imageFile = File(pickedFile.path);
        imageUrl = null;
        _imageUrlController.clear();
      });
    }
  }

  void _applyImageUrl() {
    final url = _imageUrlController.text.trim();
    if (url.isNotEmpty) {
      setState(() {
        imageUrl = url;
        imageFile = null;
      });
    }
  }

  Future<void> uploadImage() async {
    if (imageFile == null) return;
    final fileName = 'meals/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage.from('meal-images').upload(fileName, imageFile!);
    imageUrl =
        supabase.storage.from('meal-images').getPublicUrl(fileName);
  }

  // ── Ingredient helpers ─────────────────────────────────────────────────────

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
    deduped.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String));
    setState(() {
      _userIngredients = deduped;
      _userIngredientsLoaded = true;
    });
  }

  void _selectUserIngredient(Map<String, dynamic> ing) {
    final qty =
        double.tryParse(ing['quantity']?.toString() ?? '100') ?? 100;
    final unit = ing['unit']?.toString() ?? 'g';
    final gramFactor = unitToGram[unit] ?? 1;
    final grams = qty * gramFactor;
    if (grams > 0) {
      baseNutrition = {
        'calories':
            ((ing['calories'] as num?)?.toDouble() ?? 0) / grams * 100,
        'protein':
            ((ing['protein'] as num?)?.toDouble() ?? 0) / grams * 100,
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

  Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    if (query.length < 2) return [];
    final cached = await supabase
        .from('food_cache')
        .select()
        .ilike('name', '%$query%')
        .limit(10);
    if (cached.isNotEmpty) {
      return (cached as List).map<Map<String, dynamic>>((f) => {
            "name": f["name"],
            "calories": f["calories"],
            "protein": f["protein"],
            "carbs": f["carbs"],
            "fat": f["fat"]
          }).toList();
    }
    final apiFoods = await NutritionService.searchFood(query);
    return apiFoods.map<Map<String, dynamic>>((food) => {
          "fdcId": food["fdcId"],
          "name": food["description"],
          "nutrients": food["foodNutrients"]
        }).toList();
  }

  Future<void> selectFood(Map food) async {
    setState(() {
      ingredientNameController.text = food["name"];
      quantityController.text = "100";
      unitController.text = "g";
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
          ((baseNutrition["calories"] ?? 0) * quantityInGrams / 100)
              .toStringAsFixed(1);
      proteinController.text =
          ((baseNutrition["protein"] ?? 0) * quantityInGrams / 100)
              .toStringAsFixed(1);
      carbsController.text =
          ((baseNutrition["carbs"] ?? 0) * quantityInGrams / 100)
              .toStringAsFixed(1);
      fatController.text =
          ((baseNutrition["fat"] ?? 0) * quantityInGrams / 100)
              .toStringAsFixed(1);
    });
  }

  void addIngredient() {
    if (ingredientNameController.text.trim().isEmpty ||
        quantityController.text.trim().isEmpty ||
        unitController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please fill in name, quantity, and unit")),
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
        const SnackBar(
            content: Text('Product not found. Enter details manually.')),
      );
      return;
    }
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
      quantityController.text = '100';
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
      if (_sourceUrlController.text.trim().isNotEmpty)
        "source_url": _sourceUrlController.text.trim(),
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

  // ── Build ──────────────────────────────────────────────────────────────────

  static const _outlineBorder = OutlineInputBorder();

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.black54,
                    letterSpacing: 0.4)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Meal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── 1. Import ─────────────────────────────────────────────────
          Card(
            color: primary.withValues(alpha: 0.06),
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Tab toggle
                Row(children: [
                  _importTabBtn(Icons.link_rounded, 'URL', selected: !_importTab,
                      onTap: () => setState(() => _importTab = false)),
                  const SizedBox(width: 8),
                  _importTabBtn(Icons.content_paste_rounded, 'Paste Text', selected: _importTab,
                      onTap: () => setState(() => _importTab = true)),
                ]),
                const SizedBox(height: 12),

                if (!_importTab) ...[
                  // URL tab
                  Text(
                    'Works with AllRecipes, Food Network, NYT Cooking, and more.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _importUrlController,
                        decoration: const InputDecoration(
                          hintText: 'https://...',
                          border: _outlineBorder,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _importing
                        ? const SizedBox(
                            width: 36, height: 36,
                            child: CircularProgressIndicator(strokeWidth: 2.5))
                        : FilledButton(
                            onPressed: _importFromUrl,
                            style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                            child: const Text('Import'),
                          ),
                  ]),
                ] else ...[
                  // Paste text tab
                  Text(
                    'Copy the recipe from TikTok, Instagram, or any website and paste it below. Ingredients will be detected automatically.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pasteTextController,
                    decoration: const InputDecoration(
                      hintText: 'Paste the full recipe here…',
                      border: _outlineBorder,
                      alignLabelWithHint: true,
                    ),
                    maxLines: 8,
                    minLines: 4,
                    keyboardType: TextInputType.multiline,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: _parsing
                        ? const Center(child: CircularProgressIndicator())
                        : FilledButton.icon(
                            onPressed: _parseFromText,
                            icon: const Icon(Icons.auto_fix_high, size: 18),
                            label: const Text('Extract Ingredients'),
                            style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12)),
                          ),
                  ),
                ],
              ]),
            ),
          ),

          // ── 2. Meal Details ────────────────────────────────────────────
          _sectionCard(title: 'MEAL DETAILS', children: [
            TextField(
              controller: mealNameController,
              decoration: const InputDecoration(
                labelText: 'Meal Name *',
                border: _outlineBorder,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: instructionsController,
              decoration: const InputDecoration(
                labelText: 'Instructions (optional)',
                alignLabelWithHint: true,
                border: _outlineBorder,
              ),
              maxLines: null,
              minLines: 3,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(
                width: 90,
                child: TextField(
                  controller: servingsController,
                  decoration: const InputDecoration(
                    labelText: 'Servings',
                    border: _outlineBorder,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              if (_showSourceUrl || _sourceUrlController.text.isNotEmpty)
                Expanded(
                  child: TextField(
                    controller: _sourceUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Source URL',
                      prefixIcon: Icon(Icons.link, size: 18),
                      border: _outlineBorder,
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                  ),
                )
              else
                TextButton.icon(
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Add source URL',
                      style: TextStyle(fontSize: 13)),
                  onPressed: () => setState(() => _showSourceUrl = true),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ),
            ]),
          ]),

          // ── 3. Photo ───────────────────────────────────────────────────
          _sectionCard(title: 'PHOTO', children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Preview thumbnail
              GestureDetector(
                onTap: () => _pickImage(ImageSource.gallery),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageFile != null
                      ? Image.file(imageFile!,
                          width: 80, height: 80, fit: BoxFit.cover)
                      : imageUrl != null
                          ? Image.network(imageUrl!,
                              width: 80, height: 80, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _photoPlaceholder())
                          : _photoPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library, size: 16),
                          label: const Text('Gallery'),
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt, size: 16),
                          label: const Text('Camera'),
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _imageUrlController,
                          decoration: const InputDecoration(
                            hintText: 'Paste image URL',
                            border: _outlineBorder,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 9),
                          ),
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          onSubmitted: (_) => _applyImageUrl(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                          onPressed: _applyImageUrl,
                          style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 9),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          child: const Text('Use')),
                    ]),
                  ],
                ),
              ),
            ]),
          ]),

          // ── 4. Ingredients ─────────────────────────────────────────────
          _sectionCard(title: 'INGREDIENTS (OPTIONAL)', children: [
            // Source toggle
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    label: Text('Food Database'),
                    icon: Icon(Icons.search, size: 16)),
                ButtonSegment(
                    value: true,
                    label: Text('My Ingredients'),
                    icon: Icon(Icons.history, size: 16)),
              ],
              selected: {_showUserIngredients},
              onSelectionChanged: (s) {
                setState(() => _showUserIngredients = s.first);
                if (s.first && !_userIngredientsLoaded) _loadUserIngredients();
              },
              style: ButtonStyle(
                  visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 10),

            // Barcode scan
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _scanBarcode,
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('Scan Barcode'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
            const SizedBox(height: 10),

            // Search / filter
            if (!_showUserIngredients) ...[
              Autocomplete<Map<String, dynamic>>(
                displayStringForOption: (option) => option["name"],
                optionsBuilder: (textEditingValue) async {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable.empty();
                  }
                  return await searchFoods(textEditingValue.text);
                },
                onSelected: selectFood,
                fieldViewBuilder:
                    (context, controller, focusNode, onEditingComplete) {
                  _autocompleteController = controller;
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: (v) => ingredientNameController.text = v,
                    decoration: const InputDecoration(
                      border: _outlineBorder,
                      hintText: 'Search ingredient (e.g. chicken, rice...)',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                  );
                },
              ),
            ] else ...[
              TextField(
                controller: _myIngredientFilterController,
                decoration: const InputDecoration(
                  border: _outlineBorder,
                  hintText: 'Filter my ingredients...',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              if (!_userIngredientsLoaded)
                const Center(child: CircularProgressIndicator())
              else if (_userIngredients.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('No saved ingredients yet.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
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
                              trailing: Text(
                                  '${(ing['calories'] as num?)?.toStringAsFixed(0) ?? 0} cal',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              onTap: () => _selectUserIngredient(ing),
                            ))
                        .toList(),
                  ),
                ),
            ],
            const SizedBox(height: 12),

            // Qty + Unit
            Row(children: [
              Expanded(
                child: TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                      labelText: 'Quantity', border: _outlineBorder),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue:
                      unitController.text.isEmpty ? 'g' : unitController.text,
                  decoration: const InputDecoration(
                      labelText: 'Unit', border: _outlineBorder),
                  items: unitToGram.keys
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
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

            // Nutrition (2×2 grid)
            Row(children: [
              Expanded(
                child: TextField(
                  controller: caloriesController,
                  decoration: const InputDecoration(
                      labelText: 'Calories', border: _outlineBorder,
                      suffixText: 'kcal'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: proteinController,
                  decoration: const InputDecoration(
                      labelText: 'Protein', border: _outlineBorder,
                      suffixText: 'g'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: carbsController,
                  decoration: const InputDecoration(
                      labelText: 'Carbs', border: _outlineBorder,
                      suffixText: 'g'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: fatController,
                  decoration: const InputDecoration(
                      labelText: 'Fat', border: _outlineBorder,
                      suffixText: 'g'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: addIngredient,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(editingIndex == null ? Icons.add : Icons.check, size: 18),
                  const SizedBox(width: 6),
                  Text(editingIndex == null ? 'Add Ingredient' : 'Save Changes'),
                ]),
              ),
            ),
          ]),

          // ── 5. Ingredient list ─────────────────────────────────────────
          if (ingredients.isNotEmpty)
            _sectionCard(
              title: 'ADDED INGREDIENTS (${ingredients.length})',
              children: [
                ...ingredients.map((ing) {
                  final index = ingredients.indexOf(ing);
                  final cal = (ing["calories"] as num).toStringAsFixed(0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ing["quantity"]} ${ing["unit"]}  ${ing["name"]}',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '$cal kcal · P ${(ing["protein"] as num).toStringAsFixed(0)}g · C ${(ing["carbs"] as num).toStringAsFixed(0)}g · F ${(ing["fat"] as num).toStringAsFixed(0)}g',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
                            final qty = double.tryParse(
                                    ing["quantity"]?.toString() ?? '100') ??
                                100;
                            final unit = ing["unit"]?.toString() ?? 'g';
                            final grams = qty * (unitToGram[unit] ?? 1);
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
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18,
                            color: Colors.redAccent),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            ingredients.removeAt(index);
                            if (editingIndex == index) editingIndex = null;
                          });
                        },
                      ),
                    ]),
                  );
                }),
              ],
            ),

          // ── Save ───────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: saveMeal,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save Meal',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _importTabBtn(IconData icon, String label,
      {required bool selected, required VoidCallback onTap}) {
    final color = Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade400),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: selected ? Colors.white : Colors.grey[700]),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey[700])),
        ]),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Icon(Icons.add_a_photo_outlined,
          size: 28, color: Colors.grey.shade400),
    );
  }
}
