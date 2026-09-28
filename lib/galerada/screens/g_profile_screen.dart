import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tema.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/tema_store.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import '../widgets/g_app_bar.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_foot.dart';
import 'g_auth_gate.dart';

/// "Mi perfil": email de la cuenta, elegir tema de color, cerrar sesión.
class GProfileScreen extends StatefulWidget {
  const GProfileScreen({super.key});

  @override
  State<GProfileScreen> createState() => _GProfileScreenState();
}

class _GProfileScreenState extends State<GProfileScreen> {
  late Future<List<Tema>> _temas;
  String? _email;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _temas = context.read<ApiService>().getTemas();
    AuthService().readEmail().then((e) {
      if (mounted) setState(() => _email = e);
    });
  }

  /// Cambiar de tema o cerrar sesión vacía la pila de navegación y vuelve a
  /// construir la app desde `GAuthGate`: es la única forma de que **todas**
  /// las pantallas (no solo esta) recojan el cambio, ya que `GColors` no usa
  /// `Theme.of(context)` en ningún sitio. Como efecto, se vuelve siempre a
  /// "Mis libros".
  void _reiniciar() {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const GAuthGate()),
      (route) => false,
    );
  }

  Future<void> _elegirTema(Tema tema) async {
    if (_busy) return;
    setState(() => _busy = true);
    GColors.aplicar(tema);
    await TemaStore().guardar(tema);
    try {
      await context.read<ApiService>().setTema(tema.id);
    } catch (_) {
      // El tema ya se aplicó y quedó guardado en el dispositivo aunque el
      // servidor no se haya podido avisar ahora mismo.
    }
    if (!mounted) return;
    _reiniciar();
  }

  Future<void> _cerrarSesion() async {
    if (_busy) return;
    setState(() => _busy = true);
    await AuthService().logout();
    if (!mounted) return;
    _reiniciar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GAppBar(title: 'Mi perfil'),
      body: SingleChildScrollView(
        padding: GSpacing.pageScroll(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_email != null) ...[
              const GMono.muted('Cuenta'),
              const SizedBox(height: GSpacing.gapSm),
              Text(_email!, style: GText.rowTitle),
              const SizedBox(height: GSpacing.page),
            ],
            const GMono.muted('Tema'),
            const SizedBox(height: GSpacing.gapSm),
            FutureBuilder<List<Tema>>(
              future: _temas,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: GSpacing.gap),
                    child: Center(
                      child: CircularProgressIndicator(color: GColors.ink),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final tema in snap.data!)
                      _FilaTema(
                        tema: tema,
                        activo: tema.id == GColors.actual.id,
                        onTap: _busy ? null : () => _elegirTema(tema),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: GFoot.unica(
        label: _busy ? 'Un momento…' : 'Cerrar sesión',
        fill: _busy ? GFootFill.off : GFootFill.ink,
        onTap: _busy ? null : _cerrarSesion,
      ),
    );
  }
}

class _FilaTema extends StatelessWidget {
  final Tema tema;
  final bool activo;
  final VoidCallback? onTap;

  const _FilaTema({required this.tema, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: GSpacing.card, vertical: GSpacing.blockV),
        decoration: BoxDecoration(
          border: Border.all(color: GColors.ink, width: GSpacing.border),
        ),
        margin: const EdgeInsets.only(bottom: GSpacing.gapSm),
        child: Row(
          children: [
            _Muestra(color: tema.paper),
            _Muestra(color: tema.ink),
            _Muestra(color: tema.acento),
            const SizedBox(width: GSpacing.blockV),
            Expanded(child: Text(tema.nombre, style: GText.rowTitle)),
            if (activo) Icon(Icons.check, color: GColors.ink),
          ],
        ),
      ),
    );
  }
}

class _Muestra extends StatelessWidget {
  final Color color;
  const _Muestra({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 20,
        height: 20,
        margin: const EdgeInsets.only(right: GSpacing.gapXs),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: GColors.ink, width: GSpacing.border),
        ),
      );
}
