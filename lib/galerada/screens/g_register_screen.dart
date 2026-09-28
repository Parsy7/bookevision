import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import '../widgets/g_app_bar.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_field.dart';
import '../widgets/g_foot.dart';

/// Registro por email+contraseña.
class GRegisterScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const GRegisterScreen({super.key, required this.onAuthenticated});

  @override
  State<GRegisterScreen> createState() => _GRegisterScreenState();
}

class _GRegisterScreenState extends State<GRegisterScreen> {
  final _auth = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        await GColors.sincronizarDesdeServidor(context.read<ApiService>());
      }
      widget.onAuthenticated();
      // GRegisterScreen se abre con Navigator.push encima de GLoginScreen:
      // el nuevo GAuthGate ya está construido por debajo, pero esta pantalla
      // sigue tapándolo hasta que se cierra ella misma.
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GAppBar(title: 'Crear cuenta'),
      body: SingleChildScrollView(
        padding: GSpacing.pageScroll(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Con tu email y una contraseña podrás dar de alta tus libros y '
              'acceder a ellos desde cualquier dispositivo.',
              style: GText.reason.copyWith(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: GSpacing.gap),
            GField(
              label: 'Email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              hint: 'tu@email.com',
            ),
            const SizedBox(height: GSpacing.gap),
            GField(
              label: 'Contraseña',
              controller: _passwordController,
              obscureText: true,
              hint: 'Mínimo 8 caracteres',
            ),
            if (_error != null) ...[
              const SizedBox(height: GSpacing.gap),
              GMono.red('✕ ${_error!}'),
            ],
          ],
        ),
      ),
      bottomNavigationBar: GFoot.unica(
        label: _busy ? 'Creando…' : 'Crear cuenta',
        fill: _busy ? GFootFill.off : GFootFill.red,
        onTap: _busy ? null : _registrar,
      ),
    );
  }
}
