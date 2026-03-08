import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

  Future<int> addMeal(String name, String instructions) async {
    final response = await client
        .from('meals')
        .insert({
          'name': name,
          'instructions': instructions,
        })
        .select()
        .single();

    return response['id'];
  }

  Future<void> updateMealImage(int mealId, String imageUrl) async {
    await client
        .from('meals')
        .update({'image_url': imageUrl}).eq('id', mealId);
  }

  Future<String?> uploadMealImage(File image, int mealId) async {
    final path = 'meals/$mealId.jpg';

    await client.storage
        .from('meal-images')
        .upload(path, image, fileOptions: const FileOptions(upsert: true));

    return client.storage
        .from('meal-images')
        .getPublicUrl(path);
  }
}