import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../utils/image_helper.dart';

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {

  final nameController = TextEditingController();
  final instructionsController = TextEditingController();

  final picker = ImagePicker();
  File? image;

  final service = SupabaseService();

  Future<void> pickImage(ImageSource source) async {

    final picked = await picker.pickImage(source: source);

    if (picked != null) {
      setState(() {
        image = File(picked.path);
      });
    }
  }

  Future<void> saveMeal() async {

    int mealId = await service.addMeal(
      nameController.text,
      instructionsController.text,
    );

    if (image != null) {

      final compressed = await compressImage(image!);

      final imageUrl =
          await service.uploadMealImage(compressed, mealId);

      if (imageUrl != null) {
        await service.updateMealImage(mealId, imageUrl);
      }
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Add Meal")),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: ListView(
          children: [

            image != null
                ? Image.file(image!, height: 200)
                : Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(Icons.restaurant, size: 80),
                  ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                ElevatedButton.icon(
                  onPressed: () => pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo),
                  label: const Text("Gallery"),
                ),

                const SizedBox(width: 10),

                ElevatedButton.icon(
                  onPressed: () => pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Camera"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Meal Name"),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: instructionsController,
              decoration: const InputDecoration(labelText: "Instructions"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: saveMeal,
              child: const Text("Save Meal"),
            )
          ],
        ),
      ),
    );
  }
}