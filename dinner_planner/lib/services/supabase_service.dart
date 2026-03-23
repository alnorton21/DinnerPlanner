import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal_plan.dart';

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

  Future<List<MealPlan>> getMealPlan(DateTime weekStart) async {
    final weekStartStr = weekStart.toIso8601String().substring(0, 10);
    final response = await client
        .from('meal_plans')
        .select('*, meals(name, image_url)')
        .eq('week_start', weekStartStr);
    return (response as List).map((e) => MealPlan.fromJson(e)).toList();
  }

  Future<void> addMealPlanEntry(MealPlan plan) async {
    await client.from('meal_plans').insert(plan.toJson());
  }

  Future<void> clearMealPlanSlot(int planId) async {
    await client.from('meal_plans').delete().eq('id', planId);
  }
}