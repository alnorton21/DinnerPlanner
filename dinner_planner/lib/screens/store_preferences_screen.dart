import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/store_info.dart';

class StorePreferencesScreen extends StatefulWidget {
  const StorePreferencesScreen({super.key});

  @override
  State<StorePreferencesScreen> createState() => _StorePreferencesScreenState();
}

class _StorePreferencesScreenState extends State<StorePreferencesScreen> {
  final _supabase = Supabase.instance.client;
  Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser!.id;
    final data = await _supabase
        .from('user_store_preferences')
        .select('stores')
        .eq('user_id', userId)
        .maybeSingle();
    setState(() {
      if (data != null) {
        _selected = Set<String>.from(data['stores'] as List);
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('user_store_preferences').upsert({
        'user_id': userId,
        'stores': _selected.toList(),
      });
      if (mounted) Navigator.pop(context, _selected.toList());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stores'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Select the stores you want to shop at. Each ingredient '
                    'on your shopping list will show a chip for each selected '
                    'store so you can assign where to buy it.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    children: kAvailableStores.map((store) {
                      final selected = _selected.contains(store.name);
                      return CheckboxListTile(
                        secondary: CircleAvatar(
                          backgroundColor:
                              store.color.withValues(alpha: 0.12),
                          child: Icon(store.icon,
                              color: store.color, size: 20),
                        ),
                        title: Text(store.name),
                        value: selected,
                        activeColor: store.color,
                        onChanged: (val) => setState(() {
                          if (val == true) {
                            _selected.add(store.name);
                          } else {
                            _selected.remove(store.name);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }
}
