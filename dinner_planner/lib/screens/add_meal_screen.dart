import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/nutrition_service.dart';
import '../services/local_cache_service.dart';
import 'barcode_scanner_screen.dart';
import 'ingredient_search_screen.dart';

const _kCategories = [
  'Breakfast', 'Lunch', 'Dinner', 'Snack', 'Main', 'Side',
];

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final supabase = Supabase.instance.client;

  final _nameController = TextEditingController();
  final _servingsController = TextEditingController(text: '1');
  final _sourceUrlController = TextEditingController();
  bool _showSourceUrl = false;

  // Selected categories
  final Set<String> _selectedCategories = {};

  // Photo
  File? _imageFile;
  String? _imageUrl;
  final ImagePicker _picker = ImagePicker();

  // Ingredient form
  final _ingNameController = TextEditingController();
  final _qtyController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  String _selectedUnit = 'g';

  // Per-100g nutrition base used for barcode/ingredient-search pre-fill scaling
  Map<String, double> _baseNutrition = {
    'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0,
  };

  final Map<String, double> _unitToGram = {
    'g': 1, 'kg': 1000, 'oz': 28.3495, 'lb': 453.592,
    'cup': 240, 'tbsp': 15, 'tsp': 5,
  };

  final List<Map<String, dynamic>> _ingredients = [];
  int? _editingIndex;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _qtyController.addListener(_scaleNutrition);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingsController.dispose();
    _sourceUrlController.dispose();
    _ingNameController.dispose();
    _qtyController.removeListener(_scaleNutrition);
    _qtyController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  // ── Photo ──────────────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 70);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
        _imageUrl = null;
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;
    final fileName = 'meals/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage.from('meal-images').upload(fileName, _imageFile!);
    _imageUrl = supabase.storage.from('meal-images').getPublicUrl(fileName);
  }

  // ── Nutrition scaling ──────────────────────────────────────────────────────

  void _scaleNutrition() {
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final grams = qty * (_unitToGram[_selectedUnit] ?? 1);
    if (grams <= 0) return;
    setState(() {
      _caloriesController.text =
          ((_baseNutrition['calories'] ?? 0) * grams / 100).toStringAsFixed(1);
      _proteinController.text =
          ((_baseNutrition['protein'] ?? 0) * grams / 100).toStringAsFixed(1);
      _carbsController.text =
          ((_baseNutrition['carbs'] ?? 0) * grams / 100).toStringAsFixed(1);
      _fatController.text =
          ((_baseNutrition['fat'] ?? 0) * grams / 100).toStringAsFixed(1);
    });
  }

  void _prefillIngredient(Map<String, dynamic> ing) {
    final qty = double.tryParse(ing['quantity']?.toString() ?? '100') ?? 100;
    final unit = (ing['unit']?.toString() ?? 'g');
    final safeUnit = _unitToGram.containsKey(unit) ? unit : 'g';
    final grams = qty * (_unitToGram[safeUnit] ?? 1);
    if (grams > 0) {
      _baseNutrition = {
        'calories': ((ing['calories'] as num?)?.toDouble() ?? 0) / grams * 100,
        'protein': ((ing['protein'] as num?)?.toDouble() ?? 0) / grams * 100,
        'carbs': ((ing['carbs'] as num?)?.toDouble() ?? 0) / grams * 100,
        'fat': ((ing['fat'] as num?)?.toDouble() ?? 0) / grams * 100,
      };
    }
    setState(() {
      _ingNameController.text = ing['name'] ?? '';
      _selectedUnit = safeUnit;
      _qtyController.text = '100';
    });
    _scaleNutrition();
  }

  // ── Barcode scan ───────────────────────────────────────────────────────────

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
    _baseNutrition = {
      'calories': (result['calories'] as num).toDouble(),
      'protein': (result['protein'] as num).toDouble(),
      'carbs': (result['carbs'] as num).toDouble(),
      'fat': (result['fat'] as num).toDouble(),
    };
    setState(() {
      _ingNameController.text = result['name'];
      _selectedUnit = 'g';
      _qtyController.text = '100';
    });
    _scaleNutrition();
  }

  // ── Ingredient search screen ───────────────────────────────────────────────

  Future<void> _openIngredientSearch() async {
    final selected = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const IngredientSearchScreen()),
    );
    if (selected != null && mounted) {
      _prefillIngredient(selected);
    }
  }

  // ── Add / update ingredient ────────────────────────────────────────────────

  void _addIngredient() {
    if (_ingNameController.text.trim().isEmpty ||
        _qtyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in ingredient name and quantity')),
      );
      return;
    }
    final entry = {
      'name': _ingNameController.text.trim(),
      'quantity': _qtyController.text.trim(),
      'unit': _selectedUnit,
      'calories': double.tryParse(_caloriesController.text) ?? 0.0,
      'protein': double.tryParse(_proteinController.text) ?? 0.0,
      'carbs': double.tryParse(_carbsController.text) ?? 0.0,
      'fat': double.tryParse(_fatController.text) ?? 0.0,
    };
    setState(() {
      if (_editingIndex != null) {
        _ingredients[_editingIndex!] = entry;
        _editingIndex = null;
      } else {
        _ingredients.add(entry);
      }
      _clearIngredientForm();
    });
  }

  void _clearIngredientForm() {
    _ingNameController.clear();
    _qtyController.clear();
    _caloriesController.clear();
    _proteinController.clear();
    _carbsController.clear();
    _fatController.clear();
    _selectedUnit = 'g';
    _baseNutrition = {'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0};
  }

  void _editIngredient(int index) {
    final ing = _ingredients[index];
    final unit = ing['unit']?.toString() ?? 'g';
    final safeUnit = _unitToGram.containsKey(unit) ? unit : 'g';
    final qty = double.tryParse(ing['quantity']?.toString() ?? '100') ?? 100;
    final grams = qty * (_unitToGram[safeUnit] ?? 1);
    if (grams > 0) {
      _baseNutrition = {
        'calories': ((ing['calories'] as num?)?.toDouble() ?? 0) / grams * 100,
        'protein': ((ing['protein'] as num?)?.toDouble() ?? 0) / grams * 100,
        'carbs': ((ing['carbs'] as num?)?.toDouble() ?? 0) / grams * 100,
        'fat': ((ing['fat'] as num?)?.toDouble() ?? 0) / grams * 100,
      };
    }
    setState(() {
      _ingNameController.text = ing['name'] ?? '';
      _qtyController.text = ing['quantity']?.toString() ?? '';
      _selectedUnit = safeUnit;
      _caloriesController.text = ing['calories']?.toString() ?? '';
      _proteinController.text = ing['protein']?.toString() ?? '';
      _carbsController.text = ing['carbs']?.toString() ?? '';
      _fatController.text = ing['fat']?.toString() ?? '';
      _editingIndex = index;
    });
  }

  // ── Save meal ──────────────────────────────────────────────────────────────

  Future<void> _saveMeal() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meal name')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _uploadImage();
      final userId = supabase.auth.currentUser!.id;
      final mealRow = await supabase.from('meals').insert({
        'name': _nameController.text.trim(),
        'instructions': '',
        'image_url': _imageUrl,
        'user_id': userId,
        'servings': int.tryParse(_servingsController.text.trim()) ?? 1,
        'categories': _selectedCategories.toList(),
        if (_sourceUrlController.text.trim().isNotEmpty)
          'source_url': _sourceUrlController.text.trim(),
      }).select().single();

      final mealId = mealRow['id'] as int;

      for (final ing in _ingredients) {
        await supabase.from('ingredients').insert({
          'meal_id': mealId,
          'name': ing['name'] ?? '',
          'quantity': ing['quantity'] ?? '',
          'unit': ing['unit'] ?? '',
          'calories': (ing['calories'] ?? 0.0).toDouble(),
          'protein': (ing['protein'] ?? 0.0).toDouble(),
          'carbs': (ing['carbs'] ?? 0.0).toDouble(),
          'fat': (ing['fat'] ?? 0.0).toDouble(),
        });
      }

      // Update local cache with the new meal
      await LocalCacheService.upsertMeals([mealRow]);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving meal: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  Widget _card({required String title, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
          const SizedBox(height: 10),
          ...children,
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Meal'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveMeal,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Meal Details ───────────────────────────────────────────────
          _card(title: 'MEAL DETAILS', children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Meal Name *',

                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 10),
            Row(children: [
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _servingsController,
                  decoration: const InputDecoration(
                    labelText: 'Servings',
    
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              if (_showSourceUrl)
                Expanded(
                  child: TextField(
                    controller: _sourceUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Source URL',
                      prefixIcon: Icon(Icons.link, size: 16),

                      isDense: true,
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
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4)),
                ),
            ]),
          ]),

          // ── Category ───────────────────────────────────────────────────
          _card(title: 'CATEGORY', children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _kCategories.map((cat) {
                final selected = _selectedCategories.contains(cat);
                return FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (val) => setState(() {
                    val
                        ? _selectedCategories.add(cat)
                        : _selectedCategories.remove(cat);
                  }),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ]),

          // ── Photo ──────────────────────────────────────────────────────
          _card(title: 'PHOTO', children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              GestureDetector(
                onTap: () => _pickImage(ImageSource.gallery),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _imageFile != null
                      ? Image.file(_imageFile!,
                          width: 72, height: 72, fit: BoxFit.cover)
                      : _imageUrl != null
                          ? Image.network(_imageUrl!,
                              width: 72, height: 72, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _photoPlaceholder())
                          : _photoPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text('Camera'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8)),
                    ),
                  ),
                ]),
              ),
            ]),
          ]),

          // ── Ingredients ────────────────────────────────────────────────
          _card(title: 'INGREDIENTS', children: [
            // Name + qty + unit on one compact row
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _ingNameController,
                  decoration: const InputDecoration(
                    labelText: 'Ingredient',
    
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _qtyController,
                  decoration: const InputDecoration(
                    labelText: 'Qty',
    
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_selectedUnit),
                  initialValue: _selectedUnit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
    
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                  items: _unitToGram.keys
                      .map((u) =>
                          DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _selectedUnit = val;
                      _scaleNutrition();
                    });
                  },
                ),
              ),
            ]),
            const SizedBox(height: 8),

            // Nutrition 2×2 grid
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _caloriesController,
                  decoration: const InputDecoration(
                      labelText: 'Calories',

                      isDense: true,
                      suffixText: 'cal'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _proteinController,
                  decoration: const InputDecoration(
                      labelText: 'Protein',

                      isDense: true,
                      suffixText: 'g'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _carbsController,
                  decoration: const InputDecoration(
                      labelText: 'Carbs',

                      isDense: true,
                      suffixText: 'g'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _fatController,
                  decoration: const InputDecoration(
                      labelText: 'Fat',

                      isDense: true,
                      suffixText: 'g'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ]),
            const SizedBox(height: 10),

            // Action buttons
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner, size: 16),
                  label: const Text('Scan Barcode',
                      style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openIngredientSearch,
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('My Ingredients',
                      style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9)),
                ),
              ),
            ]),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: _addIngredient,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          _editingIndex == null ? Icons.add : Icons.check,
                          size: 18),
                      const SizedBox(width: 6),
                      Text(_editingIndex == null
                          ? 'Add Ingredient'
                          : 'Save Changes'),
                    ]),
              ),
            ),
          ]),

          // ── Added ingredients list ─────────────────────────────────────
          if (_ingredients.isNotEmpty)
            _card(
              title: 'ADDED (${_ingredients.length})',
              children: _ingredients.asMap().entries.map((e) {
                final index = e.key;
                final ing = e.value;
                final cal =
                    (ing['calories'] as num).toStringAsFixed(0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ing["quantity"]} ${ing["unit"]}  ${ing["name"]}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '$cal cal · P ${(ing["protein"] as num).toStringAsFixed(0)}g · C ${(ing["carbs"] as num).toStringAsFixed(0)}g · F ${(ing["fat"] as num).toStringAsFixed(0)}g',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                            ),
                          ]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _editIngredient(index),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 17, color: Colors.redAccent),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() {
                        _ingredients.removeAt(index);
                        if (_editingIndex == index) _editingIndex = null;
                      }),
                    ),
                  ]),
                );
              }).toList(),
            ),
        ]),
      ),
    );
  }

  Widget _photoPlaceholder() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Icon(Icons.add_a_photo_outlined, size: 26,
          color: cs.onSurface.withValues(alpha: 0.4)),
    );
  }
}
