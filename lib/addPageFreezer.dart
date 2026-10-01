import 'package:flutter/material.dart';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddPageFreezer extends StatefulWidget{
  const AddPageFreezer({super.key});

  @override
  State<AddPageFreezer> createState() => _AddPageFreezerState();
}

class _AddPageFreezerState extends State<AddPageFreezer> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _portionController = TextEditingController();

  final List<String> _categories = ["Fleisch", "Fisch", "Gemüse", "Obst", "Backwaren", "Eis", "Fertiggerichte", "Sonstiges"];
  String _selectedCategory = "Fleisch";

  final _selectedDate = DateTime.now();

  @override
  void initState(){
    super.initState();
    _selectedCategory = _categories.first;
  }

  Future<void> _saveItem() async {
    final name = _nameController.text;
    final amount = int.tryParse(_amountController.text) ?? 0;
    final portion = _portionController.text;

    if (name.isEmpty || amount <= 0 || portion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bitte alle Felder ausfüllen!"))
      );
      return;
    }

    try {
      await Supabase.instance.client.from("freezer").insert({
        "item": name,
        "amount": amount,
        "portion_size": portion,
        "category": _selectedCategory,
        "date": _selectedDate.toIso8601String().split("T")[0],
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      print("Fehler beim Speichern $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Neu"),),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Name"),),
            TextField(controller: _amountController, decoration: const InputDecoration(labelText: "Anzahl"), keyboardType: TextInputType.number,),
            TextField(controller: _portionController, decoration: const InputDecoration(labelText: "Portionsgröße"),),
            const SizedBox(height: 15,),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: "Kategorie",
                border: OutlineInputBorder(),
              ),
              items: _categories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue!;
                });
              },
            ),



            const SizedBox(height: 20,),
            ElevatedButton(
                onPressed: _saveItem,
                child: Text("Speichern")),
          ],
        ),
      ),
    );
  }
}