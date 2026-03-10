import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/nutrition_service.dart';

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final supabase = Supabase.instance.client;

  final mealNameController = TextEditingController();
  final instructionsController = TextEditingController();

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
    ingredientNameController.dispose();
    quantityController.removeListener(scaleNutrition);
    quantityController.dispose();
    unitController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
    super.dispose();
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
      quantityController.clear();
      unitController.clear();
      caloriesController.clear();
      proteinController.clear();
      carbsController.clear();
      fatController.clear();
    });
  }

  Future<void> saveMeal() async {
    if (mealNameController.text.trim().isEmpty) return;

    await uploadImage();

    final mealResponse = await supabase.from('meals').insert({
      "name": mealNameController.text.trim(),
      "instructions": instructionsController.text.trim(),
      "image_url": imageUrl,
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

    Navigator.pop(context);
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
            decoration: const InputDecoration(labelText: "Instructions"),
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
          const Divider(height: 30),
          const Text("Add Ingredients", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Autocomplete<Map<String, dynamic>>(
            displayStringForOption: (option) => option["name"],
            optionsBuilder: (textEditingValue) async {
              if (textEditingValue.text.isEmpty) return const Iterable.empty();
              return await searchFoods(textEditingValue.text);
            },
            onSelected: selectFood,
            fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
              return TextField(
                controller: ingredientNameController,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Search Ingredient",
                ),
              );
            },
          ),
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
                          quantityController.text = ing["quantity"];
                          unitController.text = ing["unit"];
                          caloriesController.text = ing["calories"].toString();
                          proteinController.text = ing["protein"].toString();
                          carbsController.text = ing["carbs"].toString();
                          fatController.text = ing["fat"].toString();

                          baseNutrition = {
                            "calories": ing["calories"],
                            "protein": ing["protein"],
                            "carbs": ing["carbs"],
                            "fat": ing["fat"],
                          };

                          editingIndex = index;
                          scaleNutrition();
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