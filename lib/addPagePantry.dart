import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddPagePantry extends StatefulWidget {
  const AddPagePantry({super.key});

  @override
  State<AddPagePantry> createState() => _AddPagePantryState();
}

class _AddPagePantryState extends State<AddPagePantry> {
  final MobileScannerController _controller = MobileScannerController();

  String? _scannedBarcode;
  String? _productName;
  String? _brand;
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchProductInfo(String barcode) async {
    setState(() {
      _scannedBarcode = barcode;
      _isLoading = true;
      _productName = null;
      _brand = null;
    });

    try {
      final client = Supabase.instance.client;

      final dbResponse = await client
          .from('pantry')
          .select('item, brand')
          .eq('barcode', barcode)
          .maybeSingle();

      if (dbResponse != null && dbResponse['item'] != null) {
        setState(() {
          _productName = dbResponse['item'] as String;
          _brand = (dbResponse['brand'] ?? '') as String;
          _isLoading = false;
        });
        return;
      }

      final url = Uri.parse(
          'https://world.openfoodfacts.org/api/v2/product/$barcode.json');

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'KellerApp - Android - Version 1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 1 && data['product'] != null) {
          final product = data['product'];
          setState(() {
            _productName = product['product_name'] ??
                product['product_name_de'] ??
                'Unbekanntes Produkt';
            _brand = product['brands'] ?? '';
            _isLoading = false;
          });
          return;
        }
      }

      setState(() {
        _productName = 'Unbekanntes Produkt';
        _brand = '';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Fehler beim Abrufen der Produktdaten: $e');
      setState(() {
        _productName = 'Fehler beim Laden';
        _isLoading = false;
      });
    }
  }

  Future<void> _addOrUpdateInDatabase(
      String item, String brand, int amountToAdd, String? barcode) async {
    try {
      final client = Supabase.instance.client;

      List<Map<String, dynamic>> existingItems = [];

      if (barcode != null && barcode.isNotEmpty) {
        final response = await client
            .from('pantry')
            .select()
            .eq('barcode', barcode);
        existingItems = List<Map<String, dynamic>>.from(response);
      }

      if (existingItems.isNotEmpty) {
        final existingProduct = existingItems.first;
        final int currentAmount = (existingProduct['amount'] ?? 0) as int;
        final int newAmount = currentAmount + amountToAdd;
        final int id = existingProduct['id'] as int;

        await client.from('pantry').update({
          'amount': newAmount,
          'in_stock': true,
          'item': item,
          'brand': brand.isEmpty ? null : brand,
        }).eq('id', id);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Menge von "$item" auf $newAmount erhöht (+$amountToAdd)!'),
            backgroundColor: Colors.blue.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        await client.from('pantry').insert({
          'item': item,
          'brand': brand.isEmpty ? null : brand,
          'amount': amountToAdd,
          'in_stock': true,
          'barcode': barcode,
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '$item ($amountToAdd Stk.) neu zum Vorratskeller hinzugefügt!'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Fehler beim Speichern in Supabase: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Speichern: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddDialog({bool isManual = false}) {
    final nameController =
    TextEditingController(text: isManual ? '' : _productName);
    final brandController =
    TextEditingController(text: isManual ? '' : (_brand ?? ''));
    int amount = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isManual
                  ? 'Manuell hinzufügen'
                  : 'Zum Vorrat hinzufügen'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: isManual,
                    decoration: const InputDecoration(
                      labelText: 'Produktbezeichnung',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: brandController,
                    decoration: const InputDecoration(
                      labelText: 'Marke (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Menge:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: amount > 1
                                ? () {
                              setDialogState(() {
                                amount--;
                              });
                            }
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '$amount',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: () {
                              setDialogState(() {
                                amount++;
                              });
                            },
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final String itemText = nameController.text.trim();
                    if (itemText.isEmpty) return;

                    Navigator.pop(context);
                    _addOrUpdateInDatabase(
                      itemText,
                      brandController.text.trim(),
                      amount,
                      isManual ? null : _scannedBarcode,
                    );
                  },
                  child: const Text('Hinzufügen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vorratskeller Scannen'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.on:
                    return const Icon(Icons.flash_on);
                  case TorchState.off:
                  default:
                    return const Icon(Icons.flash_off);
                }
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Manuell ohne Barcode hinzufügen',
            onPressed: () => _showAddDialog(isManual: true),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? rawValue = barcode.rawValue;
                if (rawValue != null &&
                    rawValue != _scannedBarcode &&
                    !_isLoading) {
                  _fetchProductInfo(rawValue);
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color:
                  Theme.of(context).colorScheme.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text('Lebensmittel wird gesucht ($_scannedBarcode)...',
                          style: const TextStyle(fontSize: 14)),
                    ] else if (_scannedBarcode == null) ...[
                      Text(
                        'Halte einen Barcode in den Rahmen',
                        style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                    ] else ...[
                      InkWell(
                        onTap: () => _showAddDialog(isManual: false),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _productName ?? 'Unbekannt',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.edit_note,
                                    size: 20,
                                    color:
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ],
                              ),
                              if (_brand != null && _brand!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Marke: $_brand',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'Code: $_scannedBarcode',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showAddDialog(isManual: false),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Menge wählen & Hinzufügen'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}