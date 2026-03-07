import 'package:flutter/material.dart';
import '../models/meal.dart';
import '../models/ingredient.dart';
import '../services/supabase_client.dart';

class AddMealScreen extends StatefulWidget {
  final VoidCallback? onMealAdded; // callback to refresh meal list

  AddMealScreen({this.onMealAdded});

  @override
  _AddMealScreenState createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mealNameController = TextEditingController();
  final _instructionsController = TextEditingController();

  final SupabaseService _service = SupabaseService();

  List<IngredientInput> _ingredients = [IngredientInput()];

  // -------------------
  // Build Ingredient Input Fields
  // -------------------
  List<Widget> _buildIngredientFields() {
    return List.generate(_ingredients.length, (index) {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: _ingredients[index].nameController,
              decoration: InputDecoration(labelText: 'Ingredient Name'),
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _ingredients[index].quantityController,
              decoration: InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
              validator: (val) => val!.isEmpty ? 'Required' : null,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _ingredients[index].unitController,
              decoration: InputDecoration(labelText: 'Unit'),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              setState(() {
                _ingredients.removeAt(index);
              });
            },
          ),
        ],
      );
    });
  }

  // -------------------
  // Add Meal Action
  // -------------------
  Future<void> _submitMeal() async {
    if (_formKey.currentState!.validate()) {
      // build ingredient objects
      final ingredients = _ingredients.map((i) {
        return Ingredient(
          name: i.nameController.text,
          quantity: double.tryParse(i.quantityController.text) ?? 0,
          unit: i.unitController.text,
          calories: 0, // can extend later
          protein: 0,
          carbs: 0,
          fat: 0,
        );
      }).toList();

      final meal = Meal(
        id: '', // Supabase will generate
        name: _mealNameController.text,
        instructions: _instructionsController.text,
        ingredients: ingredients,
      );

      await _service.addMeal(meal);

      // call callback to refresh meal list
      if (widget.onMealAdded != null) widget.onMealAdded!();

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Meal')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _mealNameController,
                decoration: InputDecoration(labelText: 'Meal Name'),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _instructionsController,
                decoration: InputDecoration(labelText: 'Instructions'),
              ),
              SizedBox(height: 16),
              Text('Ingredients', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._buildIngredientFields(),
              SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _ingredients.add(IngredientInput());
                  });
                },
                icon: Icon(Icons.add),
                label: Text('Add Ingredient'),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitMeal,
                child: Text('Save Meal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper class for ingredient input fields
class IngredientInput {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
}