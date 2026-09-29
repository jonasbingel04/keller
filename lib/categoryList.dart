import 'package:flutter/material.dart';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class Categorylist extends StatefulWidget {
  final String category;

  const Categorylist({super.key, required this.category});

  @override
  State<Categorylist> createState() => _CategorylistState();
}

class _CategorylistState extends State<Categorylist> {

  Future<void> _updateAmount(int id, int current, int sub) async {
    int newAmount = current - sub;
    if (newAmount <= 0) {
      await Supabase.instance.client
          .from("freezer")
          .delete()
          .eq("id", id);
    } else {
      await Supabase.instance.client
          .from("freezer")
          .update({"amount" : newAmount})
          .eq("id", id);
    }

  }

  Future<void> _modify(int id, int current, int add) async {
    int newAmount = current + add;
    await Supabase.instance.client
        .from("freezer")
        .update({"amount": newAmount})
        .eq("id", id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
        appBar: AppBar(
          title: Text(widget.category),
          centerTitle: true,
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client.from("freezer")
              .stream(primaryKey: ["id"])
              .eq("category", widget.category)
              .order("item", ascending: true),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text("Fehler: ${snapshot.error}"));
            }

            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return const Center(child: Text("Kategorie ist leer."),);
            }

            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  //leading: Icon(CommunityMaterialIcons.circle_medium, color: theme.colorScheme.secondary),
                  title: Text(item["item"] ?? "Unbekannt"),
                  subtitle: Wrap(
                    spacing: 2,
                    children: [
                      Text("Menge: ${item["amount"] ?? 0}"),
                      Text(" | "),
                      Text("Portion: ${item["portion_size"] ?? 0}"),
                      Text(" | "),
                      Text(DateFormat('MM/yy').format(DateTime.parse(item["date"]))),
                    ],
                  ),
                  trailing: Wrap(
                    spacing: 2,
                    children: [
                      IconButton(
                        icon: Icon(CommunityMaterialIcons.numeric_1_circle),
                        onPressed: () => _updateAmount(item["id"], item["amount"], 1),
                      ),
                      IconButton(
                        icon: Icon(CommunityMaterialIcons.numeric_5_circle),
                        onPressed: () => _updateAmount(item["id"], item["amount"], 5),
                      ),
                      IconButton(
                        icon: Icon(CommunityMaterialIcons.plus_circle),
                        onPressed: () => _modify(item["id"], item["amount"], 1),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        )
    );
  }
}