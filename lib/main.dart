import 'package:flutter/material.dart';
import 'package:community_material_icon/community_material_icon.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:keller/categoryList.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:keller/addPage.dart';

Future<void> main()  async{
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!
  );

  runApp(const InventoryApp());
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Keller',
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blueGrey,
              brightness: Brightness.light
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.blueGrey,
          )
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blueGrey.shade800,
          foregroundColor: Colors.white,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
        appBar: AppBar(
          title: const Text("Bingel's Gefrierschrank"),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddPage()));
              },
            ),
          ],
        ),
        body: GridView.count(
          primary: false,
          padding: const EdgeInsets.all(20),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          crossAxisCount: 2,
          childAspectRatio: 1,
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