import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_field.dart';
import '../widgets/g_foot.dart';
import 'g_register_screen.dart';

/// Login por email+contraseña. Raíz de la piel cuando no hay sesión.
class GLoginScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const GLoginScreen({super.key, required this.onAuthenticated});

  @override
  State<GLoginScreen> createState() => _GLoginScreenState();
}

class _GLoginScreenState extends State<GLoginScreen> {
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

  Future<void> _entrar() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        await GColors.sincronizarDesdeServidor(context.read<ApiService>());
      }
      widget.onAuthenticated();
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GSpacing.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const GMono('BOOKEVISION'),
                const SizedBox(height: GSpacing.barTop),
                Text('Entrar', style: GText.appBar),
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
                  hint: '••••••••',
                ),
                if (_error != null) ...[
                  const SizedBox(height: GSpacing.gap),
                  GMono.red('✕ ${_error!}'),
                ],
                const SizedBox(height: GSpacing.gap),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GRegisterScreen(
                                onAuthenticated: widget.onAuthenticated,
                              ),
                            ),
                          ),
                  child: const GMono('¿No tienes cuenta? Regístrate'),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: GFoot.unica(
        label: _busy ? 'Entrando…' : 'Entrar',
        fill: _busy ? GFootFill.off : GFootFill.red,
        onTap: _busy ? null : _entrar,
      ),
    );
  }
}
