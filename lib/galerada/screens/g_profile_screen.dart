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
        padding: EdgeInsets.only(bottom: GSpacing.pageScroll(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_email != null)
              Container(
                padding: const EdgeInsets.all(GSpacing.page),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: GColors.ink, width: GSpacing.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: GSpacing.gapSm,
                  children: [
                    const GMono.muted('Cuenta'),
                    Text(_email!, style: GText.cardTitle),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(GSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const GMono.muted('Tema'),
                  const SizedBox(height: GSpacing.gapSm),
                  FutureBuilder<List<Tema>>(
                    future: _temas,
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: GSpacing.gap),
                          child: Center(
                            child:
                                CircularProgressIndicator(color: GColors.ink),
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: GSpacing.blockV,
                        children: [
                          for (final tema in snap.data!)
                            _TarjetaTema(
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
          ],
        ),
      ),
      bottomNavigationBar: GFoot.unica(
        label: _busy ? 'Un momento…' : 'Cerrar sesión',
        icon: Icons.logout,
        fill: _busy ? GFootFill.off : GFootFill.ink,
        onTap: _busy ? null : _cerrarSesion,
      ),
    );
  }
}

/// Un tema en «Mi perfil»: cabecera con el nombre y si está en uso (rellena
/// de tinta si lo está) y, debajo, una muestra pintada **con los colores de
/// ese tema** —no del activo—: un sello de pendientes, un titular con su
/// palabra destacada, una nota en gris y las cinco fichas de la paleta.
class _TarjetaTema extends StatelessWidget {
  final Tema tema;
  final bool activo;
  final VoidCallback? onTap;

  const _TarjetaTema(
      {required this.tema, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cabeceraFondo = activo ? GColors.ink : GColors.sheet;
    final cabeceraTexto = activo ? GColors.onInk : GColors.ink;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: GColors.ink, width: GSpacing.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: cabeceraFondo,
              padding: const EdgeInsets.symmetric(
                  horizontal: GSpacing.blockV, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(tema.nombre,
                        style: GText.rowTitle.copyWith(color: cabeceraTexto)),
                  ),
                  GMono(activo ? '✓ En uso' : 'Usar', color: cabeceraTexto),
                ],
              ),
            ),
            _Muestra(tema: tema),
          ],
        ),
      ),
    );
  }
}

class _Muestra extends StatelessWidget {
  final Tema tema;
  const _Muestra({required this.tema});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GSpacing.blockV),
      decoration: BoxDecoration(
        color: tema.paper,
        border:
            Border(top: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Container(
                  color: tema.acento,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  child: Text('● 3 PENDIENTES',
                      style: GText.monoSm.copyWith(color: tema.sobreAcento)),
                ),
                Text.rich(TextSpan(
                  style: GText.rowTitle.copyWith(color: tema.ink),
                  children: [
                    const TextSpan(text: 'La jaula '),
                    TextSpan(
                      text: 'rota',
                      style: GText.rowTitle.copyWith(
                          color: tema.acentoTexto, fontStyle: FontStyle.italic),
                    ),
                  ],
                )),
                Text('Una nota en gris, como las razones.',
                    style: GText.reason.copyWith(color: tema.grey1)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          for (final (i, color) in [
            tema.sheet,
            tema.ink,
            tema.acento,
            tema.blue,
            tema.grey2,
          ].indexed)
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                border: Border(
                  top: BorderSide(color: tema.ink, width: GSpacing.border),
                  bottom: BorderSide(color: tema.ink, width: GSpacing.border),
                  right: BorderSide(color: tema.ink, width: GSpacing.border),
                  left: i == 0
                      ? BorderSide(color: tema.ink, width: GSpacing.border)
                      : BorderSide.none,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
