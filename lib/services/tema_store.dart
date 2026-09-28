import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tema.dart';

/// Tema elegido, cacheado localmente para poder pintar sin red en arranques
/// posteriores. Mismo patrón que `TrackableOrderStore` en Anotto.
class TemaStore {
  static const _key = 'tema_actual';

  Future<Tema?> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return Tema.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> guardar(Tema tema) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(tema.toJson()));
  }
}
