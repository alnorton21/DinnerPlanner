import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/meal_plan.dart';
import '../models/shopping_item.dart';
import '../models/store_info.dart';
import 'store_preferences_screen.dart';
import 'store_list_screen.dart';

class ShoppingListScreen extends StatefulWidget {
  final List<MealPlan> plans;
  final DateTime weekStart;

  const ShoppingListScreen({
    super.key,
    required this.plans,
    required this.weekStart,
  });

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  static const List<String> _monthAbbr = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  bool _loading = true;
  List<ShoppingItem> _items = [];

  // User's selected stores
  List<String> _selectedStores = [];

  // Per-item store assignment:  itemKey → store name
  final Map<String, String> _assignments = {};

  // Per-item price:  itemKey → price (user-entered)
  final Map<String, double?> _prices = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([_buildShoppingList(), _loadStorePreferences()]);
    setState(() => _loading = false);
  }

  String _itemKey(ShoppingItem item) =>
      '${item.name.toLowerCase()}_${item.unit.toLowerCase()}';

  Future<void> _buildShoppingList() async {
    final mealIdCounts = <int, int>{};
    for (final p in widget.plans.where((p) => p.mealId != null)) {
      mealIdCounts[p.mealId!] = (mealIdCounts[p.mealId!] ?? 0) + 1;
    }
    if (mealIdCounts.isEmpty) return;

    final response = await Supabase.instance.client
        .from('ingredients')
        .select()
        .inFilter('meal_id', mealIdCounts.keys.toList());

    final rows = response as List;
    final Map<String, ShoppingItem> aggregated = {};
    for (final row in rows) {
      final name = (row['name'] as String? ?? '').trim();
      final unit = (row['unit'] as String? ?? '').trim();
      final key = '${name.toLowerCase()}_${unit.toLowerCase()}';
      final count = mealIdCounts[row['meal_id']] ?? 1;
      final qty = (double.tryParse(row['quantity'].toString()) ?? 0.0) * count;
      final cal = ((row['calories'] as num?)?.toDouble() ?? 0.0) * count;
      final pro = ((row['protein'] as num?)?.toDouble() ?? 0.0) * count;
      final carb = ((row['carbs'] as num?)?.toDouble() ?? 0.0) * count;
      final fat = ((row['fat'] as num?)?.toDouble() ?? 0.0) * count;

      if (aggregated.containsKey(key)) {
        aggregated[key]!.totalQuantity += qty;
        aggregated[key]!.totalCalories += cal;
        aggregated[key]!.totalProtein += pro;
        aggregated[key]!.totalCarbs += carb;
        aggregated[key]!.totalFat += fat;
      } else {
        aggregated[key] = ShoppingItem(
          name: name,
          totalQuantity: qty,
          unit: unit,
          totalCalories: cal,
          totalProtein: pro,
          totalCarbs: carb,
          totalFat: fat,
        );
      }
    }
    _items = aggregated.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> _loadStorePreferences() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('user_store_preferences')
          .select('stores')
          .eq('user_id', userId)
          .maybeSingle();
      if (data != null) {
        _selectedStores = List<String>.from(data['stores'] as List);
      }
    } catch (_) {
      _selectedStores = [];
    }
  }

  Future<void> _openStorePreferences() async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => const StorePreferencesScreen()),
    );
    if (result != null) {
      setState(() => _selectedStores = result);
    }
  }

  Future<void> _launch(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link.')),
        );
      }
    }
  }

  void _assignStore(ShoppingItem item, String storeName) {
    final key = _itemKey(item);
    setState(() {
      if (_assignments[key] == storeName) {
        // Tap same store again → unassign
        _assignments.remove(key);
      } else {
        _assignments[key] = storeName;
      }
    });
  }

  void _editPrice(ShoppingItem item) {
    final key = _itemKey(item);
    final controller =
        TextEditingController(text: _prices[key]?.toStringAsFixed(2) ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Price for ${item.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            prefixText: '\$ ',
            labelText: 'Estimated price',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _prices.remove(key));
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              setState(() {
                if (val != null) {
                  _prices[key] = val;
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _copyList() {
    if (_items.isEmpty) return;
    final buf = StringBuffer();
    buf.writeln(
        'Shopping List – Week of ${_monthAbbr[widget.weekStart.month]} ${widget.weekStart.day}');
    buf.writeln('');
    for (final item in _items) {
      final qty = item.totalQuantity % 1 == 0
          ? item.totalQuantity.toInt().toString()
          : item.totalQuantity.toStringAsFixed(1);
      final store = _assignments[_itemKey(item)];
      final storeLabel = store != null ? '  [$store]' : '';
      final price = _prices[_itemKey(item)];
      final priceLabel = price != null ? '  \$${price.toStringAsFixed(2)}' : '';
      buf.writeln('• ${item.name}: $qty ${item.unit}$storeLabel$priceLabel');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shopping list copied to clipboard')),
    );
  }

  int get _assignedCount =>
      _items.where((i) => _assignments.containsKey(_itemKey(i))).length;

  @override
  Widget build(BuildContext context) {
    final weekLabel =
        '${_monthAbbr[widget.weekStart.month]} ${widget.weekStart.day}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Week of $weekLabel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.store_rounded),
            tooltip: 'My stores',
            onPressed: _openStorePreferences,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy list',
            onPressed: _copyList,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: _items.isNotEmpty
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.list_alt_rounded),
              label: Text(_assignedCount > 0
                  ? 'View by store ($_assignedCount/${_items.length})'
                  : 'View by store'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoreListScreen(
                    items: _items,
                    assignments: Map.from(_assignments),
                    prices: Map.from(_prices),
                    weekStart: widget.weekStart,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_items.isEmpty) {
      return const Center(child: Text('No meals planned this week.'));
    }

    return Column(
      children: [
        // ── Store preference banner (shown when no stores selected) ─────────
        if (_selectedStores.isEmpty)
          _InfoBanner(
            message:
                'Tap the store icon above to select your preferred stores, '
                'then assign each ingredient.',
            actionLabel: 'Select stores',
            onAction: _openStorePreferences,
          )
        else
          _buildStoreSummaryBar(),

        const Divider(height: 1),

        // ── Ingredient list ─────────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: _items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (_, i) => _buildItemTile(_items[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreSummaryBar() {
    final total = _prices.values
        .where((p) => p != null)
        .fold<double>(0, (sum, p) => sum + p!);
    final hasPrice = _prices.values.any((p) => p != null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).primaryColor.withValues(alpha: 0.07),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedStores.length} store${_selectedStores.length == 1 ? '' : 's'} selected',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '$_assignedCount of ${_items.length} items assigned'
                  '${hasPrice ? '  ·  est. \$${total.toStringAsFixed(2)}' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.tune, size: 16),
            label: const Text('Edit'),
            style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            onPressed: _openStorePreferences,
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(ShoppingItem item) {
    final key = _itemKey(item);
    final assignedStore = _assignments[key];
    final price = _prices[key];
    final qty = item.totalQuantity % 1 == 0
        ? item.totalQuantity.toInt().toString()
        : item.totalQuantity.toStringAsFixed(1);
    final displayName =
        item.name[0].toUpperCase() + item.name.substring(1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Item name + quantity + price ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(Icons.shopping_basket_outlined,
                    size: 20, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
                    Text('$qty ${item.unit}',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ),
              // Price chip / button
              GestureDetector(
                onTap: () => _editPrice(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: price != null
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: price != null
                          ? Colors.green.shade300
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        price != null
                            ? Icons.attach_money
                            : Icons.add,
                        size: 14,
                        color: price != null
                            ? Colors.green.shade700
                            : Colors.grey[600],
                      ),
                      Text(
                        price != null
                            ? price.toStringAsFixed(2)
                            : 'Price',
                        style: TextStyle(
                          fontSize: 12,
                          color: price != null
                              ? Colors.green.shade700
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Store chips ──────────────────────────────────────────────────
          if (_selectedStores.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final storeName in _selectedStores)
                    _buildStoreChip(item, storeName, assignedStore),
                  // "Find online" chip
                  ActionChip(
                    avatar: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('Find online'),
                    labelStyle: const TextStyle(fontSize: 11),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _launch(Uri.parse(
                        'https://www.google.com/search?q=${Uri.encodeComponent("${item.name} grocery price")}&tbm=shop')),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStoreChip(
      ShoppingItem item, String storeName, String? assignedStore) {
    final store = storeByName(storeName);
    final isAssigned = assignedStore == storeName;
    final color = store?.color ?? Colors.grey;

    return GestureDetector(
      onTap: () => _assignStore(item, storeName),
      onLongPress: () => _launch(
          Uri.parse(store?.searchUrl(item.name) ??
              'https://www.google.com/search?q=${Uri.encodeComponent(item.name)}')),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isAssigned
              ? color.withValues(alpha: 0.15)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isAssigned ? color : Colors.grey.shade300,
            width: isAssigned ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAssigned)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child:
                    Icon(Icons.check_circle, size: 13, color: color),
              ),
            Icon(store?.icon ?? Icons.store,
                size: 13,
                color: isAssigned ? color : Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              storeName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isAssigned
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: isAssigned ? color : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _InfoBanner({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel,
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
