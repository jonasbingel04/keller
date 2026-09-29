import 'package:flutter/material.dart';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:keller/categoryList.dart';

class FreezerPage extends StatefulWidget {
  const FreezerPage({super.key});

  @override
  State<FreezerPage> createState() => _FreezerPageState();
}

class _FreezerPageState extends State<FreezerPage> {
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
        appBar: AppBar(
          title: const Text("Gefrierschrank"),
          centerTitle: true,
        ),
        body: GridView.count(
          primary: false,
          padding: const EdgeInsets.all(20),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          crossAxisCount: 2,
          childAspectRatio: 1.1,
          children: <Widget> [
            _buildMenuButton(CommunityMaterialIcons.food_drumstick, "Fleisch"),
            _buildMenuButton(CommunityMaterialIcons.fish, "Fisch"),
            _buildMenuButton(CommunityMaterialIcons.carrot, "Gemüse"),
            _buildMenuButton(CommunityMaterialIcons.food_apple, "Obst"),
            _buildMenuButton(CommunityMaterialIcons.baguette, "Backwaren"),
            _buildMenuButton(CommunityMaterialIcons.ice_pop, "Eis"),
            _buildMenuButton(CommunityMaterialIcons.pizza, "Fertiggerichte"),
            _buildMenuButton(CommunityMaterialIcons.food, "Sonstiges")


          ],
        )
    );
  }
  Widget _buildMenuButton(IconData icon, String label) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => Categorylist(category: label))
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40,),
            const SizedBox(height: 8,),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            )
          ],
        ),
      ),
    );
  }
}