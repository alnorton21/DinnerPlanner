import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart' show themeNotifier;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;

  final _nameController = TextEditingController();

  // Goal values driven by sliders; controllers stay in sync
  double _calorieGoal = 2000;
  double _proteinGoal = 150;
  double _carbGoal = 250;
  double _fatGoal = 65;

  late TextEditingController _calCtrl;
  late TextEditingController _proCtrl;
  late TextEditingController _carbCtrl;
  late TextEditingController _fatCtrl;

  bool _isDarkMode = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _calCtrl  = TextEditingController(text: _calorieGoal.round().toString());
    _proCtrl  = TextEditingController(text: _proteinGoal.round().toString());
    _carbCtrl = TextEditingController(text: _carbGoal.round().toString());
    _fatCtrl  = TextEditingController(text: _fatGoal.round().toString());
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _calCtrl.dispose();
    _proCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser!.id;
    final data = await _supabase
        .from('user_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (data != null) {
      setState(() {
        _nameController.text = data['display_name'] ?? '';
        _calorieGoal = (data['calorie_goal'] as num?)?.toDouble() ?? 2000;
        _proteinGoal = (data['protein_goal'] as num?)?.toDouble() ?? 150;
        _carbGoal    = (data['carb_goal']    as num?)?.toDouble() ?? 250;
        _fatGoal     = (data['fat_goal']     as num?)?.toDouble() ?? 65;
        _isDarkMode  = (data['dark_mode']    as bool?) ?? false;
      });
      _calCtrl.text  = _calorieGoal.round().toString();
      _proCtrl.text  = _proteinGoal.round().toString();
      _carbCtrl.text = _carbGoal.round().toString();
      _fatCtrl.text  = _fatGoal.round().toString();
    }

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('user_profiles').upsert({
        'user_id':       userId,
        'display_name':  _nameController.text.trim(),
        'calorie_goal':  _calorieGoal.roundToDouble(),
        'protein_goal':  _proteinGoal.roundToDouble(),
        'carb_goal':     _carbGoal.roundToDouble(),
        'fat_goal':      _fatGoal.roundToDouble(),
        'dark_mode':     _isDarkMode,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _supabase.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Goals'),
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Profile ─────────────────────────────────────────────
                  _sectionHeader('Profile', Icons.person_outline),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    controller: TextEditingController(text: email),
                  ),

                  const SizedBox(height: 20),

                  // ── Appearance ───────────────────────────────────────────
                  _sectionHeader('Appearance', Icons.palette_outlined),
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    child: SwitchListTile(
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Switch between light and dark theme'),
                      secondary: Icon(
                        _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      value: _isDarkMode,
                      onChanged: (val) {
                        setState(() => _isDarkMode = val);
                        themeNotifier.value =
                            val ? ThemeMode.dark : ThemeMode.light;
                      },
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Nutrition goals ──────────────────────────────────────
                  _sectionHeader('Daily Nutrition Goals', Icons.track_changes),
                  const SizedBox(height: 4),
                  Text(
                    'These are used as targets in your weekly meal planner.',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 20),

                  _GoalSlider(
                    label: 'Calories',
                    unit: 'cal',
                    value: _calorieGoal,
                    min: 500,
                    max: 5000,
                    color: Colors.orange,
                    controller: _calCtrl,
                    onChanged: (v) => setState(() {
                      _calorieGoal = v;
                      _calCtrl.text = v.round().toString();
                    }),
                  ),
                  const SizedBox(height: 20),

                  _GoalSlider(
                    label: 'Protein',
                    unit: 'g',
                    value: _proteinGoal,
                    min: 10,
                    max: 400,
                    color: Colors.blue,
                    controller: _proCtrl,
                    onChanged: (v) => setState(() {
                      _proteinGoal = v;
                      _proCtrl.text = v.round().toString();
                    }),
                  ),
                  const SizedBox(height: 20),

                  _GoalSlider(
                    label: 'Carbohydrates',
                    unit: 'g',
                    value: _carbGoal,
                    min: 10,
                    max: 600,
                    color: Colors.green,
                    controller: _carbCtrl,
                    onChanged: (v) => setState(() {
                      _carbGoal = v;
                      _carbCtrl.text = v.round().toString();
                    }),
                  ),
                  const SizedBox(height: 20),

                  _GoalSlider(
                    label: 'Fat',
                    unit: 'g',
                    value: _fatGoal,
                    min: 5,
                    max: 200,
                    color: Colors.redAccent,
                    controller: _fatCtrl,
                    onChanged: (v) => setState(() {
                      _fatGoal = v;
                      _fatCtrl.text = v.round().toString();
                    }),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ── Slider + text field widget ─────────────────────────────────────────────

class _GoalSlider extends StatelessWidget {
  final String label;
  final String unit;
  final double value;
  final double min;
  final double max;
  final Color color;
  final TextEditingController controller;
  final ValueChanged<double> onChanged;

  const _GoalSlider({
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            // Text input
            SizedBox(
              width: 90,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  suffixText: unit,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: color),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: color, width: 2),
                  ),
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null &&
                      parsed >= min &&
                      parsed <= max) {
                    onChanged(parsed);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.2),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.12),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${min.toInt()} $unit',
                  style: TextStyle(
                      fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
              Text('${max.toInt()} $unit',
                  style: TextStyle(
                      fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        ),
      ],
    );
  }
}
