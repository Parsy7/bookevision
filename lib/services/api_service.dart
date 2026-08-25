import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/review.dart';
import '../models/review_summary.dart';
import '../models/review_state.dart';

/// Cliente HTTP de la API del revisor (PHP + MariaDB). Sin login: no envía
/// cabecera de autorización.
class ApiService {
  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  Uri _u(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  // ---------- Revisiones ----------

  Future<List<ReviewSummary>> getRevisiones() async {
    final res = await http.get(_u('/revisiones'), headers: _headers);
    _checkOk(res);
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => ReviewSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Review> getRevision(String id) async {
    final res = await http.get(_u('/revisiones/$id'), headers: _headers);
    _checkOk(res);
    return Review.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Importa una revisión desde el JSON que el usuario pega/carga (formato
  /// `la-jaula-rota-review-v4` o un estado `la-jaula-rota-state-v2`). Devuelve
  /// la revisión ya creada. Lanza si el id ya existía (409).
  Future<Review> importRevision(Map<String, dynamic> json) async {
    final res = await http.post(
      _u('/revisiones'),
      headers: _headers,
      body: jsonEncode(json),
    );
    _checkOk(res);
    return Review.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteRevision(String id) async {
    final res = await http.delete(_u('/revisiones/$id'), headers: _headers);
    _checkOk(res);
  }

  // ---------- Estado ----------

  Future<ReviewState> getEstado(String id) async {
    final res =
        await http.get(_u('/revisiones/$id/estado'), headers: _headers);
    _checkOk(res);
    return ReviewState.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> putEstado(String id, ReviewState state) async {
    final res = await http.put(
      _u('/revisiones/$id/estado'),
      headers: _headers,
      body: jsonEncode(state.toJson()),
    );
    _checkOk(res);
  }

  /// Reset: borra decisiones y ediciones manuales en el servidor.
  Future<void> resetEstado(String id) async {
    final res =
        await http.delete(_u('/revisiones/$id/estado'), headers: _headers);
    _checkOk(res);
  }

  void _checkOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Error API (${res.statusCode}): ${res.body}');
    }
  }
}
