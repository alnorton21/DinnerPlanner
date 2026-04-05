import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/meal_plan.dart';
import '../models/shopping_item.dart';
import '../models/store_info.dart';
import '../services/supabase_service.dart';
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
  List<ShoppingItem> _customItems = [];

  // User's selected stores
  List<String> _selectedStores = [];

  // Per-item store assignment:  itemKey → store name
  final Map<String, String> _assignments = {};

  // Per-item price:  itemKey → price (user-entered)
  final Map<String, double?> _prices = {};

  // Checked-off items (keys of items the user has ticked while shopping)
  final Set<String> _checkedItems = {};

  Timer? _saveTimer;

  final _service = SupabaseService();

  String get _weekStartStr =>
      widget.weekStart.toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.wait([_buildShoppingList(), _loadStorePreferences()]);
    await _loadPersistedState();
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

  Future<void> _loadPersistedState() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final row = await _service.loadShoppingState(userId, _weekStartStr);
    if (row == null) return;

    // Restore assignments
    final rawAssignments = row['assignments'] as Map<String, dynamic>? ?? {};
    for (final e in rawAssignments.entries) {
      _assignments[e.key] = e.value as String;
    }

    // Restore prices
    final rawPrices = row['prices'] as Map<String, dynamic>? ?? {};
    for (final e in rawPrices.entries) {
      _prices[e.key] = (e.value as num?)?.toDouble();
    }

    // Restore custom items and append to _items
    final rawCustom = row['custom_items'] as List? ?? [];
    _customItems = rawCustom
        .map((e) => ShoppingItem.fromCustomJson(e as Map<String, dynamic>))
        .toList();
    _items = [..._items, ..._customItems];

    // Restore checked items
    final rawChecked = row['checked_items'] as List? ?? [];
    _checkedItems.addAll(rawChecked.map((e) => e as String));
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _persistState);
  }

  Future<void> _persistState() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _service.saveShoppingState(
        userId,
        _weekStartStr,
        Map<String, dynamic>.from(_assignments),
        Map<String, dynamic>.from(_prices.map((k, v) => MapEntry(k, v))),
        _customItems.map((i) => i.toCustomJson()).toList(),
        _checkedItems.toList(),
      );
    } catch (_) {
      // Save errors are non-blocking
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

  void _toggleChecked(ShoppingItem item) {
    final key = _itemKey(item);
    setState(() {
      if (_checkedItems.contains(key)) {
        _checkedItems.remove(key);
      } else {
        _checkedItems.add(key);
      }
    });
    _scheduleSave();
  }

  void _clearChecked() {
    setState(() => _checkedItems.clear());
    _scheduleSave();
  }

  void _assignStore(ShoppingItem item, String storeName) {
    final key = _itemKey(item);
    setState(() {
      if (_assignments[key] == storeName) {
        _assignments.remove(key);
      } else {
        _assignments[key] = storeName;
      }
    });
    _scheduleSave();
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
              _scheduleSave();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              setState(() {
                if (val != null) _prices[key] = val;
              });
              _scheduleSave();
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editQuantity(ShoppingItem item) {
    final qty = item.totalQuantity % 1 == 0
        ? item.totalQuantity.toInt().toString()
        : item.totalQuantity.toStringAsFixed(1);
    final controller = TextEditingController(text: qty);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantity for ${item.name}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Quantity (${item.unit})',
            border: const OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                setState(() => item.totalQuantity = val);
                _scheduleSave();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final qtyController = TextEditingController();
    final unitController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Item name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: qtyController,
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit (e.g. cups)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final qty = double.tryParse(qtyController.text.trim()) ?? 1.0;
              final unit = unitController.text.trim();
              if (name.isNotEmpty) {
                final newItem = ShoppingItem(
                  name: name,
                  totalQuantity: qty,
                  unit: unit,
                  totalCalories: 0,
                  totalProtein: 0,
                  totalCarbs: 0,
                  totalFat: 0,
                  isCustom: true,
                );
                setState(() {
                  _items.add(newItem);
                  _customItems.add(newItem);
                });
                _scheduleSave();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteItem(ShoppingItem item) {
    final key = _itemKey(item);
    setState(() {
      _items.remove(item);
      if (item.isCustom) _customItems.remove(item);
      _assignments.remove(key);
      _prices.remove(key);
      _checkedItems.remove(key);
    });
    _scheduleSave();
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
          if (_checkedItems.isNotEmpty)
            TextButton(
              onPressed: _clearChecked,
              child: Text(
                'Clear checked (${_checkedItems.length})',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
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

        // ── Add item button ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add item'),
                onPressed: _showAddItemDialog,
              ),
              if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    'No meals planned — add items manually',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Ingredient list ─────────────────────────────────────────────────
        Expanded(
          child: _items.isEmpty
              ? const Center(child: Text('No items yet. Tap "Add item" above.'))
              : Builder(builder: (_) {
                  // Checked items sort to the bottom
                  final sorted = [
                    ..._items.where((i) => !_checkedItems.contains(_itemKey(i))),
                    ..._items.where((i) => _checkedItems.contains(_itemKey(i))),
                  ];
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (_, i) => Dismissible(
                      key: Key(_itemKey(sorted[i])),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red.shade400,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteItem(sorted[i]),
                      child: _buildItemTile(sorted[i]),
                    ),
                  );
                }),
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
    final isChecked = _checkedItems.contains(key);
    final assignedStore = _assignments[key];
    final price = _prices[key];
    final qty = item.totalQuantity % 1 == 0
        ? item.totalQuantity.toInt().toString()
        : item.totalQuantity.toStringAsFixed(1);
    final displayName =
        item.name[0].toUpperCase() + item.name.substring(1);

    return Opacity(
      opacity: isChecked ? 0.45 : 1.0,
      child: InkWell(
        onTap: () => _toggleChecked(item),
        child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Item name + quantity + price ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(
                  isChecked
                      ? Icons.check_circle
                      : item.isCustom
                          ? Icons.edit_note_rounded
                          : Icons.shopping_basket_outlined,
                  size: 20,
                  color: isChecked
                      ? Colors.green
                      : item.isCustom
                          ? Colors.blue.shade300
                          : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            decoration: isChecked
                                ? TextDecoration.lineThrough
                                : null)),
                    GestureDetector(
                      onTap: () => _editQuantity(item),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$qty ${item.unit}',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[600])),
                          const SizedBox(width: 4),
                          Icon(Icons.edit, size: 11, color: Colors.grey[400]),
                        ],
                      ),
                    ),
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
                        price != null ? Icons.attach_money : Icons.add,
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
                  // "Find online" chip — uses assigned store if set
                  ActionChip(
                    avatar: const Icon(Icons.open_in_new, size: 14),
                    label: Text(assignedStore != null
                        ? 'Find at $assignedStore'
                        : 'Find online'),
                    labelStyle: const TextStyle(fontSize: 11),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final store = assignedStore != null
                          ? storeByName(assignedStore)
                          : null;
                      final url = store?.searchUrl(item.name) ??
                          'https://www.google.com/search?q=${Uri.encodeComponent("${item.name} grocery price")}&tbm=shop';
                      _launch(Uri.parse(url));
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
        ),
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
                child: Icon(Icons.check_circle, size: 13, color: color),
              ),
            Icon(store?.icon ?? Icons.store,
                size: 13,
                color: isAssigned ? color : Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              storeName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isAssigned ? FontWeight.w600 : FontWeight.normal,
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
            child: Text(actionLabel, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
