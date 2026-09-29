import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:community_material_icon/community_material_icon.dart';

class PantryPage extends StatefulWidget {
  const PantryPage({super.key});

  @override
  State<PantryPage> createState() => _PantryPageState();
}

class _PantryPageState extends State<PantryPage> {
  late final Stream<List<Map<String, dynamic>>> _pantryStream;

  @override
  void initState() {
    super.initState();
    _pantryStream = Supabase.instance.client
        .from('pantry')
        .stream(primaryKey: ['id'])
        .order('item', ascending: true);
  }

  Future<void> _modify(int id, int currentAmount, bool isStock) async {
    int newAmount = currentAmount + 1;
    await Supabase.instance.client.from("pantry").update({
      "amount": newAmount,
      "in_stock": true,
    }).eq("id", id);
  }


  Future<void> _decrease(int id, int currentAmount) async {
    int newAmount = currentAmount - 1;
    if (newAmount <= 0) {
      await Supabase.instance.client.from("pantry").update({
        "amount": 0,
        "in_stock": false,
      }).eq("id", id);
    } else {
      await Supabase.instance.client.from("pantry").update({
        "amount": newAmount,
      }).eq("id", id);
    }
  }

  Future<void> _deleteItem(int id) async {
    await Supabase.instance.client
        .from("pantry")
        .delete()
        .eq("id", id);
  }

  Map<String, List<Map<String, dynamic>>> _groupItemsByAlphabet(
      List<Map<String, dynamic>> items) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var entry in items) {
      final String itemName = (entry['item'] ?? '').toString().trim();
      if (itemName.isEmpty) continue;

      final String firstLetter = itemName[0].toUpperCase();

      if (!grouped.containsKey(firstLetter)) {
        grouped[firstLetter] = [];
      }
      grouped[firstLetter]!.add(entry);
    }

    grouped.forEach((key, list) {
      list.sort((a, b) => (a['item'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['item'] ?? '').toString().toLowerCase()));
    });

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vorratskeller'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _pantryStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Fehler beim Laden: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final allItems = snapshot.data ?? [];

          if (allItems.isEmpty) {
            return const Center(
              child: Text(
                'Keine Einträge im Vorratskeller vorhanden.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final inStockItems =
          allItems.where((i) => i['in_stock'] == true).toList();
          final outOfStockItems =
          allItems.where((i) => i['in_stock'] == false).toList();

          final groupedInStock = _groupItemsByAlphabet(inStockItems);
          final sortedAlphabetKeys = groupedInStock.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              ...sortedAlphabetKeys.map((letter) {
                final letterItems = groupedInStock[letter]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                      const EdgeInsets.only(top: 16, bottom: 4, left: 8),
                      child: Text(
                        letter,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                        ),
                      ),
                    ),
                    ...letterItems.map((entry) => _buildItemTile(entry, false)),
                  ],
                );
              }),

              // --- SECTION 2: AUSVERKAUFTE ITEMS (Ausgegrauter Cache unten) ---
              if (outOfStockItems.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Divider(thickness: 1),
                Padding(
                  padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: Text(
                    'Nicht auf Lager',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.4),
                    ),
                  ),
                ),
                ...outOfStockItems.map((entry) => _buildItemTile(entry, true)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> entry, bool isOutOfStock) {
    final String itemName = (entry['item'] ?? 'Unbenannt').toString();
    final int amount = (entry['amount'] ?? 0) as int;
    final int id = entry['id'] as int;
    final bool isStock = entry['in_stock'] ?? true;

    final double textOpacity = isOutOfStock ? 0.35 : 1.0;

    final Widget tileContent = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.normal,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(textOpacity),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOutOfStock ? 'Menge: 0' : 'Menge: $amount',
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(isOutOfStock ? 0.3 : 0.6),
                  ),
                ),
              ],
            ),
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isOutOfStock)
                IconButton(
                  icon: const Icon(CommunityMaterialIcons.numeric_1_circle),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _decrease(id, amount),
                ),
              IconButton(
                icon: Icon(
                  CommunityMaterialIcons.plus_circle,
                  color: isOutOfStock
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.6)
                      : null,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () => _modify(id, amount, isStock),
              ),
            ],
          ),
        ],
      ),
    );

    // Swipe-to-Delete
    if (isOutOfStock) {
      return Dismissible(
        key: Key('pantry_item_$id'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          color: Colors.red.shade400,
          child: const Icon(
            Icons.delete_outline,
            color: Colors.white,
            size: 24,
          ),
        ),
        onDismissed: (direction) {
          _deleteItem(id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$itemName wurde gelöscht'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: tileContent,
      );
    }

    return tileContent;
  }
}