import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_ingredient_screen.dart';

class EditMealScreen extends StatefulWidget {
  final Map<String, dynamic> meal;

  const EditMealScreen({super.key, required this.meal});

  @override
  State<EditMealScreen> createState() => _EditMealScreenState();
}

class _EditMealScreenState extends State<EditMealScreen> {
  final supabase = Supabase.instance.client;
  late final TextEditingController instructionsController;
  late final TextEditingController servingsController;

  File? newImageFile;
  bool loading = false;
  bool _ingredientsLoading = true;
  List _ingredients = [];

  @override
  void initState() {
    super.initState();
    instructionsController =
        TextEditingController(text: widget.meal['instructions'] ?? '');
    servingsController =
        TextEditingController(text: '${widget.meal['servings'] ?? 1}');
    _loadIngredients();
  }

  @override
  void dispose() {
    instructionsController.dispose();
    servingsController.dispose();
    super.dispose();
  }

  Future<void> _loadIngredients() async {
    final data = await supabase
        .from('ingredients')
        .select()
        .eq('meal_id', widget.meal['id'])
        .order('id');
    setState(() {
      _ingredients = data;
      _ingredientsLoading = false;
    });
  }

  Future<void> _deleteIngredient(int id) async {
    await supabase.from('ingredients').delete().eq('id', id);
    _loadIngredients();
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => newImageFile = File(picked.path));
  }

  Future<void> save() async {
    setState(() => loading = true);
    try {
      String? imageUrl = widget.meal['image_url'];
      if (newImageFile != null) {
        final path = 'meals/${widget.meal['id']}.jpg';
        await supabase.storage.from('meal-images').upload(
              path,
              newImageFile!,
              fileOptions: const FileOptions(upsert: true),
            );
        imageUrl = supabase.storage.from('meal-images').getPublicUrl(path);
      }
      await supabase.from('meals').update({
        'instructions': instructionsController.text.trim(),
        'servings': int.tryParse(servingsController.text.trim()) ?? 1,
        'image_url': imageUrl,
      }).eq('id', widget.meal['id']);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentImageUrl = widget.meal['image_url'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.meal['name']}'),
        actions: [
          TextButton(
            onPressed: loading ? null : save,
            child: loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add ingredient',
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AddIngredientScreen(mealId: widget.meal['id'] as int),
            ),
          );
          _loadIngredients();
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──────────────────────────────────────────────
            const Text('Image',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: pickImage,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: newImageFile != null
                    ? Image.file(newImageFile!,
                        height: 200, width: double.infinity, fit: BoxFit.cover)
                    : currentImageUrl != null
                        ? Image.network(currentImageUrl,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover)
                        : Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.grey[200],
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate,
                                    size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Tap to add image',
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
              ),
            ),
            if (newImageFile != null || currentImageUrl != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.photo_library, size: 18),
                label: const Text('Change image'),
              ),
            ],

            const SizedBox(height: 20),

            // ── Servings ───────────────────────────────────────────
            const Text('Servings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            SizedBox(
              width: 100,
              child: TextField(
                controller: servingsController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '1',
                ),
                keyboardType: TextInputType.number,
              ),
            ),

            const SizedBox(height: 20),

            // ── Instructions ───────────────────────────────────────
            const Text('Instructions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: instructionsController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: null,
              minLines: 5,
              keyboardType: TextInputType.multiline,
            ),

            const SizedBox(height: 28),

            // ── Ingredients ────────────────────────────────────────
            const Text('Ingredients',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (_ingredientsLoading)
              const Center(child: CircularProgressIndicator())
            else if (_ingredients.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No ingredients yet. Tap + to add.',
                    style: TextStyle(color: Colors.grey[600])),
              )
            else
              Column(
                children: _ingredients.map<Widget>((ing) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.kitchen),
                      title: Text(ing['name']),
                      subtitle: Text(
                          '${ing['quantity']} ${ing['unit']}  ·  ${(ing['calories'] ?? 0).toStringAsFixed(0)} cal'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddIngredientScreen(
                                    mealId: widget.meal['id'] as int,
                                    ingredient: ing,
                                  ),
                                ),
                              );
                              _loadIngredients();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () => _deleteIngredient(ing['id'] as int),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

            // Extra space so FAB doesn't overlap last item
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
