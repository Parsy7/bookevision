import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../theme/g_colors.dart';
import 'g_libro_list_screen.dart';
import 'g_login_screen.dart';

/// Punto de entrada de la piel Galerada: si hay sesión guardada va directo a
/// «Mis libros», si no, pide login antes de nada.
class GAuthGate extends StatefulWidget {
  const GAuthGate({super.key});

  @override
  State<GAuthGate> createState() => _GAuthGateState();
}

class _GAuthGateState extends State<GAuthGate> {
  final _auth = AuthService();
  late Future<String?> _tokenFuture;

  @override
  void initState() {
    super.initState();
    _tokenFuture = _auth.readToken();
  }

  void _onAuthenticated() {
    // Con llaves: con flecha, la asignación devolvería el Future y setState
    // lo rechaza (en debug salta un error; en release pasa sin avisar).
    setState(() {
      _tokenFuture = _auth.readToken();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _tokenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator(color: GColors.ink)),
          );
        }
        return snapshot.data != null
            ? const GLibroListScreen()
            : GLoginScreen(onAuthenticated: _onAuthenticated);
      },
    );
  }
}
