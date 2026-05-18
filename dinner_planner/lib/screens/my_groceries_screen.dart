import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pantry_item.dart';
import '../services/nutrition_service.dart';
import '../services/supabase_service.dart';
import 'barcode_scanner_screen.dart';

const _kUnits = [
  'item', 'g', 'oz', 'lb', 'kg',
  'cup', 'tbsp', 'tsp', 'L', 'mL',
  'can', 'box', 'bag', 'bottle',
];

class MyGroceriesScreen extends StatefulWidget {
  const MyGroceriesScreen({super.key});

  @override
  State<MyGroceriesScreen> createState() => _MyGroceriesScreenState();
}

class _MyGroceriesScreenState extends State<MyGroceriesScreen> {
  final _service = SupabaseService();
  final _searchController = TextEditingController();

  List<PantryItem> _items = [];
  List<PantryItem> _filtered = [];
  bool _loading = true;

  String get _userId =>
      Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.getPantryItems(_userId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      _applyFilter();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_items)
          : _items
              .where((i) => i.name.toLowerCase().contains(q))
              .toList();
    });
  }

  // ── Add / Edit dialog ────────────────────────────────────────────────────

  Future<void> _showAddOptions() async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.qr_code_scanner,
                      color: cs.onPrimaryContainer),
                ),
                title: const Text('Scan Barcode',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Auto-fill product details'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _scanBarcode();
                },
              ),
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit_outlined,
                      color: cs.onSecondaryContainer),
                ),
                title: const Text('Add Manually',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Enter product details by hand'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _showItemDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Looking up product...')),
    );

    final result = await NutritionService.lookupBarcode(barcode);
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    await _showItemDialog(
      prefillName: result?['name'] as String?,
      prefillCalories: (result?['calories'] as num?)?.toDouble(),
      prefillProtein: (result?['protein'] as num?)?.toDouble(),
      prefillCarbs: (result?['carbs'] as num?)?.toDouble(),
      prefillFat: (result?['fat'] as num?)?.toDouble(),
      barcode: barcode,
    );
  }

  Future<void> _showItemDialog({
    PantryItem? editing,
    String? prefillName,
    double? prefillCalories,
    double? prefillProtein,
    double? prefillCarbs,
    double? prefillFat,
    String? barcode,
  }) async {
    final nameCtrl = TextEditingController(
        text: editing?.name ?? prefillName ?? '');
    final qtyCtrl = TextEditingController(
        text: (editing?.quantity ?? 1).toString());
    String unit = editing?.unit ?? 'item';
    DateTime? expiryDate = editing?.expirationDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          final cs = Theme.of(ctx).colorScheme;
          final mq = MediaQuery.of(ctx);

          return Padding(
            padding:
                EdgeInsets.fromLTRB(20, 12, 20, mq.viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Text(
                  editing != null ? 'Edit Item' : 'Add Grocery',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),

                // Name
                TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Product name *'),
                  textCapitalization: TextCapitalization.words,
                  autofocus: editing == null && (prefillName == null),
                ),
                const SizedBox(height: 12),

                // Qty + Unit
                Row(children: [
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: qtyCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Quantity'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(unit),
                      initialValue: unit,
                      decoration:
                          const InputDecoration(labelText: 'Unit'),
                      items: _kUnits
                          .map((u) => DropdownMenuItem(
                              value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) =>
                          setSheet(() => unit = v ?? unit),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),

                // Expiry date
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: expiryDate ??
                          DateTime.now()
                              .add(const Duration(days: 7)),
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 1)),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setSheet(() => expiryDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Expiration date (optional)',
                      suffixIcon:
                          Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                    child: Text(
                      expiryDate != null
                          ? _fmtDate(expiryDate!)
                          : 'Tap to set',
                      style: TextStyle(
                        color: expiryDate != null
                            ? cs.onSurface
                            : cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
                if (expiryDate != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap),
                      onPressed: () =>
                          setSheet(() => expiryDate = null),
                      child: const Text('Clear date'),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final qty =
                          double.tryParse(qtyCtrl.text.trim()) ?? 1;

                      final data = PantryItem(
                        id: editing?.id,
                        name: name,
                        quantity: qty,
                        unit: unit,
                        barcode: editing?.barcode ?? barcode,
                        calories: editing?.calories ?? prefillCalories,
                        protein: editing?.protein ?? prefillProtein,
                        carbs: editing?.carbs ?? prefillCarbs,
                        fat: editing?.fat ?? prefillFat,
                        expirationDate: expiryDate,
                      ).toJson();

                      Navigator.pop(ctx);

                      if (editing != null) {
                        await _service.updatePantryItem(
                            editing.id!, data);
                      } else {
                        await _service.addPantryItem(_userId, data);
                      }
                      await _load();
                    },
                    child: Text(
                        editing != null ? 'Save Changes' : 'Add to Pantry'),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _confirmDelete(PantryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text('Remove "${item.name}" from your groceries?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && item.id != null) {
      await _service.deletePantryItem(item.id!);
      await _load();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.year}';

  Color _cardColor(PantryItem item, ColorScheme cs) {
    if (item.isExpired) return cs.errorContainer;
    if (item.isExpiringSoon) return cs.errorContainer.withValues(alpha: 0.5);
    return cs.surfaceContainerLow;
  }

  Color _expiryTextColor(PantryItem item, ColorScheme cs) {
    if (item.isExpired || item.isExpiringSoon) return cs.error;
    return cs.onSurface.withValues(alpha: 0.55);
  }

  String _expiryLabel(PantryItem item) {
    if (item.expirationDate == null) return '';
    if (item.isExpired) return 'Expired ${_fmtDate(item.expirationDate!)}';
    final days = item.expirationDate!
        .difference(DateTime.now())
        .inDays;
    if (days == 0) return 'Expires today!';
    if (days == 1) return 'Expires tomorrow!';
    if (item.isExpiringSoon) return 'Expires in $days days!';
    return 'Exp ${_fmtDate(item.expirationDate!)}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final expiring = _filtered
        .where((i) => i.isExpired || i.isExpiringSoon)
        .toList();
    final normal =
        _filtered.where((i) => !i.isExpired && !i.isExpiringSoon).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Groceries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add item',
            onPressed: _showAddOptions,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search groceries...',
                    prefixIcon: Icon(Icons.search,
                        color: cs.onSurface.withValues(alpha: 0.5)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                  ),
                ),
              ),

              // List
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.kitchen_outlined,
                                  size: 64,
                                  color: cs.onSurface
                                      .withValues(alpha: 0.2)),
                              const SizedBox(height: 16),
                              Text(
                                _items.isEmpty
                                    ? 'No groceries yet'
                                    : 'No items match your search',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.5)),
                              ),
                              if (_items.isEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Tap + to scan or add an item',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.4)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          children: [
                            // Expiring soon
                            if (expiring.isNotEmpty) ...[
                              _SectionHeader(
                                icon: Icons.warning_amber_rounded,
                                label: 'Expiring Soon',
                                color: cs.error,
                              ),
                              ...expiring.map((item) => Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 8),
                                    child: _GroceryCard(
                                      item: item,
                                      cardColor:
                                          _cardColor(item, cs),
                                      expiryLabel:
                                          _expiryLabel(item),
                                      expiryColor:
                                          _expiryTextColor(item, cs),
                                      onEdit: () =>
                                          _showItemDialog(editing: item),
                                      onDelete: () =>
                                          _confirmDelete(item),
                                    ),
                                  )),
                              const SizedBox(height: 8),
                            ],

                            // All other items
                            if (normal.isNotEmpty) ...[
                              if (expiring.isNotEmpty)
                                _SectionHeader(
                                  icon: Icons.inventory_2_outlined,
                                  label: 'In Stock',
                                  color: cs.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ...normal.map((item) => Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 8),
                                    child: _GroceryCard(
                                      item: item,
                                      cardColor:
                                          _cardColor(item, cs),
                                      expiryLabel:
                                          _expiryLabel(item),
                                      expiryColor:
                                          _expiryTextColor(item, cs),
                                      onEdit: () =>
                                          _showItemDialog(editing: item),
                                      onDelete: () =>
                                          _confirmDelete(item),
                                    ),
                                  )),
                            ],
                          ],
                        ),
                      ),
              ),
            ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHeader(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: color),
        ),
      ]),
    );
  }
}

class _GroceryCard extends StatelessWidget {
  final PantryItem item;
  final Color cardColor;
  final String expiryLabel;
  final Color expiryColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GroceryCard({
    required this.item,
    required this.cardColor,
    required this.expiryLabel,
    required this.expiryColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final qty = item.quantity % 1 == 0
        ? item.quantity.toInt().toString()
        : item.quantity.toStringAsFixed(1);

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(children: [
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '$qty ${item.unit}',
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.65)),
                ),
                if (expiryLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    expiryLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: expiryColor),
                  ),
                ],
              ],
            ),
          ),
          // Actions
          IconButton(
            icon: Icon(Icons.edit_outlined,
                size: 19,
                color: cs.onSurface.withValues(alpha: 0.5)),
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 19,
                color: cs.onSurface.withValues(alpha: 0.4)),
            onPressed: onDelete,
          ),
        ]),
      ),
    );
  }
}
