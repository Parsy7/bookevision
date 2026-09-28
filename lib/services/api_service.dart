import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/libro.dart';
import '../models/review.dart';
import '../models/review_summary.dart';
import '../models/review_state.dart';
import '../models/tema.dart';
import 'auth_service.dart';

/// Cliente HTTP de la API del revisor (PHP + MariaDB). Adjunta el token de
/// sesión (ver AuthService) en cada petición.
class ApiService {
  final AuthService _auth = AuthService();

  Future<Map<String, String>> get _headers async {
    final token = await _auth.readToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _u(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  // ---------- Libros ----------

  Future<List<Libro>> getLibros() async {
    final res = await http.get(_u('/libros'), headers: await _headers);
    _checkOk(res);
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Libro.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Libro> createLibro(String title) async {
    final res = await http.post(
      _u('/libros'),
      headers: await _headers,
      body: jsonEncode({'title': title}),
    );
    _checkOk(res);
    return Libro.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteLibro(int id) async {
    final res = await http.delete(_u('/libros/$id'), headers: await _headers);
    _checkOk(res);
  }

  // ---------- Temas ----------

  Future<List<Tema>> getTemas() async {
    final res = await http.get(_u('/temas'), headers: await _headers);
    _checkOk(res);
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Tema.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> setTema(int temaId) async {
    final res = await http.put(
      _u('/auth/tema'),
      headers: await _headers,
      body: jsonEncode({'tema_id': temaId}),
    );
    _checkOk(res);
  }

  /// `tema_id` del usuario logueado, o `null` si nunca ha elegido uno.
  Future<int?> getMiTemaId() async {
    final res = await http.get(_u('/auth/me'), headers: await _headers);
    _checkOk(res);
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return (decoded['tema_id'] as num?)?.toInt();
  }

  // ---------- Revisiones ----------

  Future<List<ReviewSummary>> getRevisiones({String? libroId}) async {
    final path = libroId == null ? '/revisiones' : '/revisiones?libro_id=$libroId';
    final res = await http.get(_u(path), headers: await _headers);
    _checkOk(res);
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => ReviewSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Review> getRevision(String id) async {
    final res = await http.get(_u('/revisiones/$id'), headers: await _headers);
    _checkOk(res);
    return Review.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Importa una revisión desde el JSON que el usuario pega/carga (formato
  /// `la-jaula-rota-review-v4` o un estado `la-jaula-rota-state-v2`). Devuelve
  /// la revisión ya creada. Lanza si el id ya existía (409).
  Future<Review> importRevision(Map<String, dynamic> json, {String? libroId}) async {
    final body = libroId == null ? json : {...json, 'libro_id': libroId};
    final res = await http.post(
      _u('/revisiones'),
      headers: await _headers,
      body: jsonEncode(body),
    );
    _checkOk(res);
    return Review.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteRevision(String id) async {
    final res = await http.delete(_u('/revisiones/$id'), headers: await _headers);
    _checkOk(res);
  }

  // ---------- Estado ----------

  Future<ReviewState> getEstado(String id) async {
    final res =
        await http.get(_u('/revisiones/$id/estado'), headers: await _headers);
    _checkOk(res);
    return ReviewState.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> putEstado(String id, ReviewState state) async {
    final res = await http.put(
      _u('/revisiones/$id/estado'),
      headers: await _headers,
      body: jsonEncode(state.toJson()),
    );
    _checkOk(res);
  }

  /// Reset: borra decisiones y ediciones manuales en el servidor.
  Future<void> resetEstado(String id) async {
    final res =
        await http.delete(_u('/revisiones/$id/estado'), headers: await _headers);
    _checkOk(res);
  }

  void _checkOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Error API (${res.statusCode}): ${res.body}');
    }
  }
}
