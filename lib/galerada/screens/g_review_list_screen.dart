import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/review_summary.dart';
import '../../services/api_service.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_button.dart';
import '../widgets/g_dialog.dart';
import 'g_import_screen.dart';
import 'g_reviewer_screen.dart';

/// Portada de un libro: el hero con su título y una fila por capítulo, con
/// su número, su medidor de sugerencias y su sello de estado.
class GReviewListScreen extends StatefulWidget {
  final int libroId;
  final String libroTitle;

  const GReviewListScreen({
    super.key,
    required this.libroId,
    required this.libroTitle,
  });

  @override
  State<GReviewListScreen> createState() => _GReviewListScreenState();
}

class _GReviewListScreenState extends State<GReviewListScreen> {
  late Future<List<ReviewSummary>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context
        .read<ApiService>()
        .getRevisiones(libroId: widget.libroId.toString());
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Future<void> _openImport() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => GImportScreen(libroId: widget.libroId.toString()),
      ),
    );
    if (!mounted) return;
    await _refresh();
    if (id != null) _openReview(id);
  }

  void _openReview(String id) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => GReviewerScreen(reviewId: id)))
        .then((_) => _refresh());
  }

  Future<void> _delete(ReviewSummary r) async {
    final ok = await GDialog.confirmar(
      context,
      title: 'Borrar',
      keyword: 'revisión',
      message: '«${r.title}» y todas tus decisiones se borrarán. Esta acción '
          'no se puede deshacer.',
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ApiService>().deleteRevision(r.id);
      await _refresh();
    } catch (e) {
      if (mounted) _snack('No se pudo borrar: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.toUpperCase(),
            style: GText.mono.copyWith(color: GColors.onInk)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<ReviewSummary>>(
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
            if (items.isEmpty) return _Vacia(onImport: _openImport);

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
                        return _Hero(
                          numero: items.length,
                          titulo: widget.libroTitle,
                          subtitulo: '${items.length} '
                              '${items.length == 1 ? 'capítulo' : 'capítulos'} '
                              'en revisión',
                        );
                      }
                      final r = items[i - 1];
                      return _Fila(
                        numero: i,
                        review: r,
                        onTap: () => _openReview(r.id),
                        onDelete: () => _delete(r),
                      );
                    },
                  ),
                ),
                Positioned(
                  right: GSpacing.page,
                  bottom: GSpacing.page + MediaQuery.paddingOf(context).bottom,
                  child: GFab(
                    label: 'Importar',
                    icon: Icons.add,
                    onPressed: _openImport,
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

/// Cabecera de la portada: marca en mono, título del libro a 64px con la
/// palabra clave en rojo, y el subtítulo en cursiva.
class _Hero extends StatelessWidget {
  final int numero;
  final String subtitulo;
  final String titulo;

  /// Segunda palabra del título, en rojo — solo tiene sentido para el juego
  /// de palabras de la pantalla vacía («Página en blanco»). `null` pinta
  /// `titulo` entero en tinta, que es lo normal para el título real de un
  /// libro (dato dinámico, ya no un titular fijo partido en dos colores).
  final String? tituloEm;

  const _Hero({
    required this.numero,
    required this.subtitulo,
    required this.titulo,
    this.tituloEm,
  });

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat('MMM y', 'es').format(DateTime.now());
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
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const GMono.muted('← Volver'),
                  ),
                  const SizedBox(width: GSpacing.gap),
                  const GMono('BookeVision'),
                ],
              ),
              GMono.muted('Nº ${numero.toString().padLeft(2, '0')} · $fecha'),
            ],
          ),
          const SizedBox(height: GSpacing.barTop),
          Text.rich(
            TextSpan(
              style: GText.hero,
              children: [
                TextSpan(text: titulo),
                if (tituloEm != null)
                  TextSpan(
                      text: tituloEm,
                      style: GText.hero.copyWith(color: GColors.red)),
              ],
            ),
          ),
          const SizedBox(height: GSpacing.gapSm),
          Text(subtitulo, style: GText.heroSub),
        ],
      ),
    );
  }
}

/// Fila de capítulo: número | título + metadatos + medidor | sello.
class _Fila extends StatelessWidget {
  final int numero;
  final ReviewSummary review;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _Fila({
    required this.numero,
    required this.review,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final suelto = review.isDocument;
    final meta = StringBuffer(suelto
        ? 'Capítulo suelto'
        : '${review.total} ${review.total == 1 ? 'sugerencia' : 'sugerencias'}');
    if (review.manual > 0) meta.write(' · ${review.manual} a mano');

    return Dismissible(
      key: ValueKey(review.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // el borrado lo confirma el diálogo, no el gesto
      },
      background: Container(
        color: GColors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: GSpacing.page),
        child: GMono('Borrar', color: GColors.onRed),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: GSpacing.page, vertical: GSpacing.gap),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: GColors.ink, width: GSpacing.border),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                child: Text(numero.toString().padLeft(2, '0'),
                    style: GText.bigNumber),
              ),
              const SizedBox(width: GSpacing.blockV),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.title, style: GText.rowTitle),
                    const SizedBox(height: GSpacing.gapSm),
                    GMono.muted(meta.toString()),
                    if (!suelto) ...[
                      const SizedBox(height: GSpacing.barTop),
                      GMeter(total: review.total, done: review.resolved),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: GSpacing.blockV),
              GStamp(
                suelto
                    ? '.md'
                    : review.isComplete
                        ? 'Listo'
                        : 'En curso',
                filled: !suelto && review.isComplete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista vacía: «Página en blanco».
class _Vacia extends StatelessWidget {
  final VoidCallback onImport;
  const _Vacia({required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Hero(numero: 0, subtitulo: 'Aún no hay revisiones',
            titulo: 'Página en ', tituloEm: 'blanco'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: GSpacing.page),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Importa el JSON de una revisión, o un capítulo en .md, '
                  'para empezar a trabajar.',
                  style: GText.prose,
                ),
                const SizedBox(height: GSpacing.page),
                GButton(
                  label: 'Importar revisión',
                  icon: Icons.add,
                  fill: GFill.ink,
                  onPressed: onImport,
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(GSpacing.page),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: GColors.ink, width: GSpacing.border)),
            ),
            child: const GMono.muted('Formato · la-jaula-rota-review-v4'),
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
