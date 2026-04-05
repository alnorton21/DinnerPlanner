import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/shopping_item.dart';
import '../models/store_info.dart';

class StoreListScreen extends StatelessWidget {
  final List<ShoppingItem> items;
  final Map<String, String> assignments;  // key → store name
  final Map<String, double?> prices;      // key → price (null = not set)
  final DateTime weekStart;

  static const List<String> _monthAbbr = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  const StoreListScreen({
    super.key,
    required this.items,
    required this.assignments,
    required this.prices,
    required this.weekStart,
  });

  String _itemKey(ShoppingItem item) =>
      '${item.name.toLowerCase()}_${item.unit.toLowerCase()}';

  String _fmtQty(double q) =>
      q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    // Group items by assigned store
    final Map<String, List<ShoppingItem>> byStore = {};
    final List<ShoppingItem> unassigned = [];

    for (final item in items) {
      final store = assignments[_itemKey(item)];
      if (store != null && store.isNotEmpty) {
        byStore.putIfAbsent(store, () => []).add(item);
      } else {
        unassigned.add(item);
      }
    }

    // Sort stores alphabetically, put unassigned at end
    final storeNames = byStore.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping by Store'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy full list',
            onPressed: () => _copyAll(context, storeNames, byStore, unassigned),
          ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('No items on your shopping list.'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (byStore.isEmpty && unassigned.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No items assigned yet. Go back and assign each '
                      'ingredient to a store.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final storeName in storeNames) ...[
                  _StoreGroupHeader(
                    storeName: storeName,
                    itemCount: byStore[storeName]!.length,
                    total: _storeTotal(byStore[storeName]!, assignments, prices),
                    onCopy: () => _copyStore(
                        context, storeName, byStore[storeName]!, prices),
                  ),
                  ...byStore[storeName]!.map(
                    (item) => _ItemRow(
                      item: item,
                      price: prices[_itemKey(item)],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (unassigned.isNotEmpty) ...[
                  _StoreGroupHeader(
                    storeName: 'Unassigned',
                    itemCount: unassigned.length,
                    total: null,
                    onCopy: null,
                    isUnassigned: true,
                  ),
                  ...unassigned.map((item) => _ItemRow(item: item)),
                ],
              ],
            ),
    );
  }

  double? _storeTotal(
    List<ShoppingItem> storeItems,
    Map<String, String> assignments,
    Map<String, double?> prices,
  ) {
    double total = 0;
    bool hasAny = false;
    for (final item in storeItems) {
      final p = prices['${item.name.toLowerCase()}_${item.unit.toLowerCase()}'];
      if (p != null) {
        total += p;
        hasAny = true;
      }
    }
    return hasAny ? total : null;
  }

  void _copyStore(BuildContext context, String storeName,
      List<ShoppingItem> storeItems, Map<String, double?> prices) {
    final buf = StringBuffer();
    buf.writeln('── $storeName ──');
    for (final item in storeItems) {
      final key = _itemKey(item);
      final p = prices[key];
      final price = p != null ? '  \$${p.toStringAsFixed(2)}' : '';
      buf.writeln('• ${_cap(item.name)}: ${_fmtQty(item.totalQuantity)} ${item.unit}$price');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$storeName list copied')));
  }

  void _copyAll(
    BuildContext context,
    List<String> storeNames,
    Map<String, List<ShoppingItem>> byStore,
    List<ShoppingItem> unassigned,
  ) {
    final buf = StringBuffer();
    buf.writeln(
        'Shopping List – Week of ${_monthAbbr[weekStart.month]} ${weekStart.day}');
    buf.writeln('');
    for (final storeName in storeNames) {
      buf.writeln('── $storeName ──');
      for (final item in byStore[storeName]!) {
        final key = _itemKey(item);
        final p = prices[key];
        final price = p != null ? '  \$${p.toStringAsFixed(2)}' : '';
        buf.writeln('• ${_cap(item.name)}: ${_fmtQty(item.totalQuantity)} ${item.unit}$price');
      }
      buf.writeln('');
    }
    if (unassigned.isNotEmpty) {
      buf.writeln('── Unassigned ──');
      for (final item in unassigned) {
        buf.writeln('• ${_cap(item.name)}: ${_fmtQty(item.totalQuantity)} ${item.unit}');
      }
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Full list copied to clipboard')));
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _StoreGroupHeader extends StatelessWidget {
  final String storeName;
  final int itemCount;
  final double? total;
  final VoidCallback? onCopy;
  final bool isUnassigned;

  const _StoreGroupHeader({
    required this.storeName,
    required this.itemCount,
    required this.total,
    required this.onCopy,
    this.isUnassigned = false,
  });

  @override
  Widget build(BuildContext context) {
    final store = storeByName(storeName);
    final color = isUnassigned
        ? Colors.grey
        : (store?.color ?? Colors.grey);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (!isUnassigned && store != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(store.icon, color: color, size: 18),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color,
                  ),
                ),
                Text(
                  '$itemCount item${itemCount == 1 ? '' : 's'}'
                  '${total != null ? '  ·  est. \$${total!.toStringAsFixed(2)}' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: 'Copy $storeName list',
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final ShoppingItem item;
  final double? price;

  const _ItemRow({required this.item, this.price});

  @override
  Widget build(BuildContext context) {
    final qty = item.totalQuantity % 1 == 0
        ? item.totalQuantity.toInt().toString()
        : item.totalQuantity.toStringAsFixed(1);
    final name = item.name.isEmpty
        ? item.name
        : item.name[0].toUpperCase() + item.name.substring(1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text('$name  $qty ${item.unit}',
                style: const TextStyle(fontSize: 14)),
          ),
          if (price != null)
            Text(
              '\$${price!.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}
