import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AuthUser {
  final int id;
  final String email;
  final String? name;

  AuthUser({required this.id, required this.email, this.name});

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as int,
        email: json['email'] as String,
        name: json['name'] as String?,
      );
}

/// Login/registro y sesión (token opaco guardado en el almacenamiento seguro
/// del dispositivo). Ver AuthController.php en el backend.
class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _emailKey = 'auth_email';

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  /// Email de la sesión activa, guardado localmente en el login/registro
  /// (evita una llamada a /auth/me solo para mostrarlo en "Mi cuenta").
  Future<String?> readEmail() => _storage.read(key: _emailKey);

  Future<void> logout() async {
    final token = await readToken();
    if (token != null) {
      try {
        await http.post(
          Uri.parse('${AppConfig.apiBaseUrl}/auth/logout'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } catch (_) {
        // Best-effort: si falla la llamada, igualmente borramos la sesión local.
      }
    }
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _emailKey);
  }

  Future<AuthUser> register({
    required String email,
    required String password,
    String? name,
  }) {
    return _authRequest('/auth/register', {
      'email': email,
      'password': password,
      'name': name,
    });
  }

  Future<AuthUser> login({required String email, required String password}) {
    return _authRequest('/auth/login', {'email': email, 'password': password});
  }

  Future<AuthUser> _authRequest(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(decoded['error'] ?? 'Error de autenticación');
    }
    final user = AuthUser.fromJson(decoded['user'] as Map<String, dynamic>);
    final token = decoded['token'] as String;
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _emailKey, value: user.email);
    return user;
  }
}
