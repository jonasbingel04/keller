import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:keller/bringService.dart';

class PantryPage extends StatefulWidget {
  const PantryPage({super.key});

  @override
  State<PantryPage> createState() => _PantryPageState();
}

class _PantryPageState extends State<PantryPage> {
  late final Stream<List<Map<String, dynamic>>> _pantryStream;
  bool _isSyncing = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
  ItemPositionsListener.create();

  bool _isDraggingIndex = false;
  double _bubbleY = 0.0;
  String _draggedLetter = '#';
  final GlobalKey _alphabetKey = GlobalKey();

  String _activeLetter = '#';
  final List<String> _alphabet = '#ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');

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

  void _scrollToIndex(int index) {
    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onIndexInteractionUpdate(
      Offset localPosition,
      Map<String, int> letterIndexes,
      int? outOfStockIndex,
      ) {
    final RenderBox? renderBox =
    _alphabetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final double height = renderBox.size.height;
    final int itemCount = _alphabet.length + 1;
    final double itemHeight = height / itemCount;

    int index = (localPosition.dy / itemHeight).floor();
    index = index.clamp(0, itemCount - 1);

    final double clampedY = localPosition.dy.clamp(20.0, height - 20.0);

    String newLetter;
    if (index < _alphabet.length) {
      newLetter = _alphabet[index];
    } else {
      newLetter = 'CACHE';
    }

    if (newLetter != _draggedLetter || _bubbleY != clampedY) {
      if (newLetter != _draggedLetter) {
        HapticFeedback.selectionClick();
      }
      setState(() {
        _draggedLetter = newLetter;
        _bubbleY = clampedY;
      });

      if (newLetter == 'CACHE') {
        if (outOfStockIndex != null) {
          _scrollToIndex(outOfStockIndex);
        }
      } else if (letterIndexes.containsKey(newLetter)) {
        _scrollToIndex(letterIndexes[newLetter]!);
      }
    }
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
    await Supabase.instance.client.from("pantry").delete().eq("id", id);
  }

  Future<void> _showEditDialog(Map<String, dynamic> entry) async {
    final int id = int.tryParse(entry['id']?.toString() ?? '0') ?? 0;
    final String currentName = (entry['item'] ?? '').toString();
    final int currentAmount =
        int.tryParse(entry['amount']?.toString() ?? '0') ?? 0;

    final nameController = TextEditingController(text: currentName);
    final amountController =
    TextEditingController(text: currentAmount.toString());

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
                final newAmount =
                    int.tryParse(amountController.text) ?? currentAmount;

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

  Future<void> _sendAllOutOfStockToBring(
      List<Map<String, dynamic>> outOfStockItems) async {
    if (outOfStockItems.isEmpty || _isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    int successCount = 0;

    for (var entry in outOfStockItems) {
      final String itemName = (entry['item'] ?? '').toString().trim();
      if (itemName.isNotEmpty) {
        final success =
        await HomeAssistantBringService.addToShoppingList(itemName);
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

      String firstLetter = itemName[0].toUpperCase();
      if (!RegExp(r'[A-Z]').hasMatch(firstLetter)) {
        firstLetter = '#';
      }

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
                  onPressed: () => _searchController.clear(),
                )
                    : null,
                contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
                  debugPrint('Pantry Stream Error: ${snapshot.error}');
                  return Center(
                    child: Text(
                      'Fehler beim Laden: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final allItems = snapshot.data ?? [];

                final filteredItems = allItems.where((entry) {
                  final String itemName =
                  (entry['item'] ?? '').toString().toLowerCase();
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

                final sortedAlphabetKeys = groupedInStock.keys.toList()
                  ..sort((a, b) {
                    if (a == '#') return -1;
                    if (b == '#') return 1;
                    return a.compareTo(b);
                  });

                final List<Widget> listWidgets = [];
                final Map<String, int> letterIndexes = {};
                final Map<int, String> indexToLetter = {};
                int? outOfStockIndex;

                for (var letter in sortedAlphabetKeys) {
                  final int headerIndex = listWidgets.length;
                  letterIndexes[letter] = headerIndex;
                  indexToLetter[headerIndex] = letter;

                  listWidgets.add(
                    Padding(
                      padding: const EdgeInsets.only(
                          top: 16, bottom: 4, left: 16, right: 36),
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
                  );

                  final letterItems = groupedInStock[letter]!;
                  for (var entry in letterItems) {
                    final int itemIndex = listWidgets.length;
                    indexToLetter[itemIndex] = letter;
                    listWidgets.add(
                      Padding(
                        padding: const EdgeInsets.only(right: 28),
                        child: _buildDismissibleItemTile(entry, false),
                      ),
                    );
                  }
                }

                if (outOfStockItems.isNotEmpty) {
                  listWidgets.add(const SizedBox(height: 32));
                  listWidgets.add(const Divider(thickness: 1));

                  outOfStockIndex = listWidgets.length;
                  indexToLetter[outOfStockIndex] = 'CACHE';

                  listWidgets.add(
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
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
                  );

                  for (var entry in outOfStockItems) {
                    final int itemIndex = listWidgets.length;
                    indexToLetter[itemIndex] = 'CACHE';
                    listWidgets.add(
                      Padding(
                        padding: const EdgeInsets.only(right: 28),
                        child: _buildDismissibleItemTile(entry, true),
                      ),
                    );
                  }

                  listWidgets.add(
                    Padding(
                      padding: const EdgeInsets.all(16),
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
                          child:
                          CircularProgressIndicator(strokeWidth: 2),
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
                  );
                }

                return ValueListenableBuilder<Iterable<ItemPosition>>(
                  valueListenable: _itemPositionsListener.itemPositions,
                  builder: (context, positions, child) {
                    if (positions.isNotEmpty && !_isDraggingIndex) {
                      final firstVisible = positions.reduce((a, b) =>
                      a.itemLeadingEdge < b.itemLeadingEdge ? a : b);
                      final currentLetter = indexToLetter[firstVisible.index];
                      if (currentLetter != null &&
                          currentLetter != _activeLetter) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _activeLetter = currentLetter;
                            });
                          }
                        });
                      }
                    }

                    final String activeDisplay =
                    _isDraggingIndex ? _draggedLetter : _activeLetter;

                    return Stack(
                      children: [
                        ScrollablePositionedList.builder(
                          itemScrollController: _itemScrollController,
                          itemPositionsListener: _itemPositionsListener,
                          itemCount: listWidgets.length,
                          itemBuilder: (context, index) => listWidgets[index],
                        ),

                        if (_isDraggingIndex)
                          Positioned(
                            right: 48,
                            top: _bubbleY - 26,
                            child: Material(
                              elevation: 6,
                              shape: const CircleBorder(),
                              color: Theme.of(context).colorScheme.primary,
                              child: Container(
                                width: 52,
                                height: 52,
                                alignment: Alignment.center,
                                child: activeDisplay == 'CACHE'
                                    ? const Icon(
                                  Icons.receipt,
                                  size: 26,
                                  color: Colors.white,
                                )
                                    : Text(
                                  activeDisplay,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragStart: (details) {
                              setState(() {
                                _isDraggingIndex = true;
                              });
                              _onIndexInteractionUpdate(
                                details.localPosition,
                                letterIndexes,
                                outOfStockIndex,
                              );
                            },
                            onVerticalDragUpdate: (details) {
                              _onIndexInteractionUpdate(
                                details.localPosition,
                                letterIndexes,
                                outOfStockIndex,
                              );
                            },
                            onVerticalDragEnd: (_) {
                              setState(() {
                                _isDraggingIndex = false;
                              });
                            },
                            onVerticalDragCancel: () {
                              setState(() {
                                _isDraggingIndex = false;
                              });
                            },
                            child: Container(
                              key: _alphabetKey,
                              padding: const EdgeInsets.only(
                                  right: 6, left: 24, top: 8, bottom: 8),
                              color: Colors.transparent,
                              child: Center(
                                child: SingleChildScrollView(
                                  physics: const NeverScrollableScrollPhysics(),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ..._alphabet.map((letter) {
                                        final bool hasItems =
                                        letterIndexes.containsKey(letter);
                                        final bool isActive =
                                            activeDisplay == letter;

                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 1, horizontal: 4),
                                          child: Text(
                                            letter,
                                            style: TextStyle(
                                              fontSize: isActive ? 13 : 11,
                                              fontWeight: isActive
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: hasItems
                                                  ? (isActive
                                                  ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface)
                                                  : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.2),
                                            ),
                                          ),
                                        );
                                      }),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2, horizontal: 4),
                                        child: Icon(
                                          Icons.receipt,
                                          size: activeDisplay == 'CACHE'
                                              ? 16
                                              : 14,
                                          color: outOfStockIndex != null
                                              ? (activeDisplay == 'CACHE'
                                              ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                              : Theme.of(context)
                                              .colorScheme
                                              .onSurface)
                                              : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissibleItemTile(
      Map<String, dynamic> entry, bool isOutOfStock) {
    final int id = int.tryParse(entry['id']?.toString() ?? '0') ?? 0;

    return Dismissible(
      key: Key('pantry_item_$id'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _showEditDialog(entry);
          return false;
        } else if (direction == DismissDirection.endToStart) {
          return true;
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        color: Colors.green.shade600,
        child: const Icon(Icons.edit, color: Colors.white, size: 24),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
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
    final int amount = int.tryParse(entry['amount']?.toString() ?? '0') ?? 0;
    final int id = int.tryParse(entry['id']?.toString() ?? '0') ?? 0;
    final bool isStock = entry['in_stock'] == true;

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