import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/libro.dart';
import '../../services/api_service.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_button.dart';
import 'g_create_libro_screen.dart';
import 'g_profile_screen.dart';
import 'g_review_list_screen.dart';

/// «Mis libros»: portada de la piel tras el login. Cada fila es un proyecto
/// de libro; entrar en uno lleva a su lista de capítulos (lo que antes era
/// la portada única de la app).
class GLibroListScreen extends StatefulWidget {
  const GLibroListScreen({super.key});

  @override
  State<GLibroListScreen> createState() => _GLibroListScreenState();
}

class _GLibroListScreenState extends State<GLibroListScreen> {
  late Future<List<Libro>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<ApiService>().getLibros();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Future<void> _nuevoLibro() async {
    final libro = await Navigator.of(context).push<Libro>(
      MaterialPageRoute(builder: (_) => const GCreateLibroScreen()),
    );
    if (!mounted) return;
    await _refresh();
    if (libro != null) _abrirLibro(libro);
  }

  void _abrirLibro(Libro libro) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => GReviewListScreen(
            libroId: libro.id,
            libroTitle: libro.title,
          ),
        ))
        .then((_) => _refresh());
  }

  void _abrirPerfil() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const GProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<Libro>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(color: GColors.ink));
            }
            if (snap.hasError) {
              return _Error(error: snap.error!, onRetry: _refresh);
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return _Vacia(onNuevo: _nuevoLibro, onPerfil: _abrirPerfil);
            }

            return Stack(
              children: [
                RefreshIndicator(
                  color: GColors.ink,
                  backgroundColor: GColors.sheet,
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: EdgeInsets.only(
                      bottom: GSpacing.fab +
                          GSpacing.page * 2 +
                          MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: items.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return _Hero(numero: items.length, onPerfil: _abrirPerfil);
                      }
                      final libro = items[i - 1];
                      return _Fila(libro: libro, onTap: () => _abrirLibro(libro));
                    },
                  ),
                ),
                Positioned(
                  right: GSpacing.page,
                  bottom: GSpacing.page + MediaQuery.paddingOf(context).bottom,
                  child: GFab(
                    label: 'Nuevo libro',
                    icon: Icons.add,
                    onPressed: _nuevoLibro,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final int numero;
  final VoidCallback onPerfil;

  const _Hero({required this.numero, required this.onPerfil});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          GSpacing.page, 22, GSpacing.page, GSpacing.gap),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const GMono('BOOKEVISION'),
              GestureDetector(
                onTap: onPerfil,
                child: const GMono.muted('Mi perfil'),
              ),
            ],
          ),
          const SizedBox(height: GSpacing.barTop),
          Text('Mis libros', style: GText.hero.copyWith(fontSize: 48)),
          const SizedBox(height: GSpacing.gapSm),
          Text(
            '$numero ${numero == 1 ? 'libro' : 'libros'}',
            style: GText.heroSub,
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  final Libro libro;
  final VoidCallback onTap;

  const _Fila({required this.libro, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: GSpacing.page, vertical: GSpacing.gap),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: GColors.ink, width: GSpacing.border),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(libro.title, style: GText.rowTitle),
                  const SizedBox(height: GSpacing.gapSm),
                  GMono.muted(
                    '${libro.capitulos} ${libro.capitulos == 1 ? 'capítulo' : 'capítulos'}',
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: GColors.ink),
          ],
        ),
      ),
    );
  }
}

class _Vacia extends StatelessWidget {
  final VoidCallback onNuevo;
  final VoidCallback onPerfil;
  const _Vacia({required this.onNuevo, required this.onPerfil});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Hero(numero: 0, onPerfil: onPerfil),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: GSpacing.page),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Da de alta tu primer libro para empezar a importar y '
                  'revisar capítulos.',
                  style: GText.prose,
                ),
                const SizedBox(height: GSpacing.page),
                GButton(
                  label: 'Nuevo libro',
                  icon: Icons.add,
                  fill: GFill.ink,
                  onPressed: onNuevo,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const _Error({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(GSpacing.page),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GMono.red('✕ No se pudo cargar'),
          const SizedBox(height: GSpacing.gapSm),
          Text('$error', style: GText.reason),
          const SizedBox(height: GSpacing.page),
          GButton(
            label: 'Reintentar',
            fill: GFill.ink,
            onPressed: () => onRetry(),
          ),
        ],
      ),
    );
  }
}
