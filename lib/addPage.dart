import 'package:flutter/material.dart';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:keller/addPageFreezer.dart';
import 'package:keller/addPagePantry.dart';

class AddPage extends StatelessWidget {
  const AddPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hinzufügen'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                //Gefrierschrank
                _buildSquareButton(
                  context: context,
                  icon: CommunityMaterialIcons.snowflake,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddPageFreezer(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                //Vorratskeller
                _buildSquareButton(
                  context: context,
                  icon: Icons.food_bank,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddPagePantry(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSquareButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 160,
      height: 150,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: Icon(
              icon,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}