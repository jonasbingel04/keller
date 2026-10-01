import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class HomeAssistantBringService {
  static String get _haUrl => dotenv.env['HA_URL'] ?? '';
  static String get _haToken => dotenv.env['HA_TOKEN'] ?? '';
  static const String _bringEntityId = 'todo.einkaufen';

  static Future<bool> addToShoppingList(String itemName) async {
    final url = Uri.parse('$_haUrl/api/services/todo/add_item');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_haToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'entity_id': _bringEntityId,
          'item': itemName,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Fehler bei HA-Verbindung: $e');
      return false;
    }
  }
}