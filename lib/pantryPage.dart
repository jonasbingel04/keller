import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:keller/bringService.dart';

class PantryPage extends StatefulWidget {
  const PantryPage({super.key});

  @override
  State<PantryPage> createState() => _PantryPageState();
}

class _PantryPageState extends State<PantryPage> {
  late final Stream<List<Map<String, dynamic>>> _pantryStream;
  bool _isSyncing = false;

  // Controller & Query für die Suchfunktion
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _pantryStream = Supabase.instance.client
        .from('pantry')
        .stream(primaryKey: ['id'])
        .order('item', ascending: true);

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  // Dialog für das Bearbeiten (Swipe von Links nach Rechts)
  Future<void> _showEditDialog(Map<String, dynamic> entry) async {
    final int id = entry['id'] as int;
    final String currentName = (entry['item'] ?? '').toString();
    final int currentAmount = (entry['amount'] ?? 0) as int;

    final nameController = TextEditingController(text: currentName);
    final amountController = TextEditingController(text: currentAmount.toString());

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eintrag bearbeiten'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Menge'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                final newAmount = int.tryParse(amountController.text) ?? currentAmount;

                if (newName.isNotEmpty) {
                  await Supabase.instance.client.from("pantry").update({
                    "item": newName,
                    "amount": newAmount,
                    "in_stock": newAmount > 0,
                  }).eq("id", id);
                }
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendAllOutOfStockToBring(List<Map<String, dynamic>> outOfStockItems) async {
    if (outOfStockItems.isEmpty || _isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    int successCount = 0;

    for (var entry in outOfStockItems) {
      final String itemName = (entry['item'] ?? '').toString().trim();
      if (itemName.isNotEmpty) {
        final success = await HomeAssistantBringService.addToShoppingList(itemName);
        if (success) successCount++;
      }
    }

    if (!mounted) return;

    setState(() {
      _isSyncing = false;
    });

    if (successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount Artikel zur Bring!-Liste hinzugefügt!'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fehler beim Hinzufügen der Artikel zu Bring!'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      body: Column(
        children: [
          // Suchleiste
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Vorratskeller durchsuchen...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
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

                // Filterung nach Suchbegriff
                final filteredItems = allItems.where((entry) {
                  final String itemName = (entry['item'] ?? '').toString().toLowerCase();
                  return itemName.contains(_searchQuery);
                }).toList();

                if (filteredItems.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'Keine Einträge im Vorratskeller vorhanden.'
                          : 'Keine Ergebnisse für "$_searchQuery"',
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }

                final inStockItems =
                filteredItems.where((i) => i['in_stock'] == true).toList();
                final outOfStockItems =
                filteredItems.where((i) => i['in_stock'] == false).toList();

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
                            padding: const EdgeInsets.only(top: 16, bottom: 4, left: 8),
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
                          ...letterItems.map((entry) => _buildDismissibleItemTile(entry, false)),
                        ],
                      );
                    }),

                    if (outOfStockItems.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const Divider(thickness: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
                      ...outOfStockItems.map((entry) => _buildDismissibleItemTile(entry, true)),

                      const SizedBox(height: 24),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isSyncing
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(CommunityMaterialIcons.cart_plus),
                          label: Text(
                            _isSyncing
                                ? 'Wird an Bring! gesendet...'
                                : 'Fehlende Artikel zu Bring! hinzufügen',
                            style: const TextStyle(fontSize: 15),
                          ),
                          onPressed: _isSyncing
                              ? null
                              : () => _sendAllOutOfStockToBring(outOfStockItems),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Wrappt die Item-Tile in ein Dismissible für Swipe-Gesten (Bearbeiten & Löschen)
  Widget _buildDismissibleItemTile(Map<String, dynamic> entry, bool isOutOfStock) {
    final int id = entry['id'] as int;

    return Dismissible(
      key: Key('pantry_item_$id'),
      // Erlaubt sowohl Swipe nach links (Delete) als auch nach rechts (Edit)
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Links -> Rechts: Bearbeiten
          await _showEditDialog(entry);
          return false; // Eintrag in der Liste behalten
        } else if (direction == DismissDirection.endToStart) {
          // Rechts -> Links: Löschen
          return true; // Löschen bestätigen
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        color: Colors.green.shade600,
        child: const Icon(
          Icons.edit,
          color: Colors.white,
          size: 24,
        ),
      ),
      secondaryBackground: Container(
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
        if (direction == DismissDirection.endToStart) {
          final String itemName = (entry['item'] ?? 'Unbenannt').toString();
          _deleteItem(id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$itemName wurde gelöscht'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: _buildItemTile(entry, isOutOfStock),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> entry, bool isOutOfStock) {
    final String itemName = (entry['item'] ?? 'Unbenannt').toString();
    final int amount = (entry['amount'] ?? 0) as int;
    final int id = entry['id'] as int;
    final bool isStock = entry['in_stock'] ?? true;

    final double textOpacity = isOutOfStock ? 0.35 : 1.0;

    return Padding(
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
  }
}