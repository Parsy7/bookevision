import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../theme/g_colors.dart';
import '../theme/g_marca.dart';
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

  void _abrirRegistro() => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              GRegisterScreen(onAuthenticated: widget.onAuthenticated),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Cabecera(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(GSpacing.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                      GMono('✕ ${_error!}', color: GColors.danger),
                    ],
                  ],
                ),
              ),
            ),
            _FilaRegistro(onTap: _busy ? null : _abrirRegistro),
          ],
        ),
      ),
      bottomNavigationBar: GFoot.unica(
        label: _busy ? '↻ Entrando…' : 'Entrar',
        fill: _busy ? GFootFill.off : GFootFill.red,
        onTap: _busy ? null : _entrar,
      ),
    );
  }
}

/// El logo y, debajo, el nombre: centrados, con raya de tinta al pie.
class _Cabecera extends StatelessWidget {
  const _Cabecera();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          GSpacing.page, 44, GSpacing.page, GSpacing.page),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: GColors.ink, width: GSpacing.border),
            ),
            child: Image.asset(
              GMarca.logo,
              width: GSpacing.logoLogin,
              height: GSpacing.logoLogin,
              semanticLabel: 'bookevision',
            ),
          ),
          const SizedBox(height: GSpacing.gap),
          Text('Bookevision', style: GText.hero.copyWith(fontSize: 52)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// «¿No tienes cuenta? Crear una *cuenta*», con raya de tinta encima.
class _FilaRegistro extends StatelessWidget {
  final VoidCallback? onTap;

  const _FilaRegistro({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: GSpacing.page, vertical: GSpacing.gap),
        decoration: BoxDecoration(
          border: Border(
              top: BorderSide(color: GColors.ink, width: GSpacing.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: GSpacing.gapXs,
                children: [
                  const GMono.muted('¿No tienes cuenta?'),
                  Text.rich(TextSpan(
                    style: GText.rowTitle,
                    children: [
                      const TextSpan(text: 'Crear una '),
                      TextSpan(
                        text: 'cuenta',
                        style: GText.rowTitle.copyWith(
                            color: GColors.accentText,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  )),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 24, color: GColors.ink),
          ],
        ),
      ),
    );
  }
}
