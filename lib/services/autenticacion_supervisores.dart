import 'package:flutter/services.dart';
import 'dart:convert';

class AuthService {
  static Future<List<Map<String, dynamic>>> loadSupervisores() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/supervisores.json');
      final List<dynamic> jsonData = json.decode(jsonString);
      return jsonData.cast<Map<String, dynamic>>();
    } catch (e) {
      print("Error cargando supervisores: $e");
      return [];
    }
  }

  static Future<bool> validarSupervisor(String email, String password) async {
    final supervisores = await loadSupervisores();
    return supervisores.any((sup) =>
    sup['email'] == email && sup['password'] == password);
  }
}