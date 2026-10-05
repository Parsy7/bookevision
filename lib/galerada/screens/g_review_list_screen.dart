import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/capitulo.dart';
import '../../models/libro.dart';
import '../../models/review_summary.dart';
import '../../services/api_service.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_dialog.dart';
import '../widgets/g_lista.dart';
import 'g_import_screen.dart';
import 'g_reviewer_screen.dart';

/// Portada de un capítulo: una fila por revisión, con su medidor de
/// sugerencias y su sello de estado.
class GReviewListScreen extends StatefulWidget {
  final Libro libro;
  final Capitulo capitulo;

  const GReviewListScreen({
    super.key,
    required this.libro,
    required this.capitulo,
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
        .getRevisiones(capituloId: widget.capitulo.id);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Future<void> _openImport() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
          builder: (_) => GImportScreen(capituloId: widget.capitulo.id)),
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

  Future<void> _opciones(ReviewSummary r) async {
    final opcion = await GMenu.hoja(
      context,
      titulo: r.title,
      items: const [
        GMenuItem(
            label: 'Mover a otro capítulo',
            icon: Icons.drive_file_move_outline,
            value: 'mover'),
        GMenuItem(
            label: 'Borrar revisión',
            icon: Icons.delete_outline,
            value: 'borrar',
            danger: true),
      ],
    );
    if (!mounted) return;
    switch (opcion) {
      case 'mover':
        await _mover(r);
      case 'borrar':
        await _delete(r);
    }
  }

  Future<void> _mover(ReviewSummary r) async {
    final api = context.read<ApiService>();
    try {
      final otros = (await api.getCapitulos(widget.libro.id))
          .where((c) => c.id != widget.capitulo.id)
          .toList();
      if (!mounted) return;
      if (otros.isEmpty) {
        _snack('Este libro no tiene más capítulos');
        return;
      }
      final elegido = await GMenu.hoja(
        context,
        titulo: 'Mover a…',
        items: [
          for (final c in otros)
            GMenuItem(
                label: '${c.numero} · ${c.titulo}',
                icon: Icons.menu_book,
                value: '${c.id}'),
        ],
      );
      if (elegido == null || !mounted) return;
      await api.moverRevision(r.id, int.parse(elegido));
      await _refresh();
    } catch (e) {
      if (mounted) _snack('No se pudo mover: $e');
    }
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

  GHero _hero(int numero, {String? titulo, String? tituloEm}) => GHero(
        titulo: titulo ?? widget.capitulo.titulo,
        tituloEm: tituloEm,
        subtitulo: numero == 0
            ? 'Aún no hay revisiones'
            : '$numero ${numero == 1 ? 'revisión' : 'revisiones'} · ${widget.libro.title}',
        meta: 'Capítulo ${widget.capitulo.numero.toString().padLeft(2, '0')}',
        compacto: true,
        onVolver: () => Navigator.of(context).maybePop(),
        logo: false,
      );

  @override
  Widget build(BuildContext context) {
    return GPantallaLista<ReviewSummary>(
      future: _future,
      onRefresh: _refresh,
      hero: (items) => _hero(items.length),
      fila: (r, i) => _fila(r, i + 1),
      vacia: GListaVacia(
        hero: _hero(0, titulo: 'Página en ', tituloEm: 'blanco'),
        texto: 'Importa el JSON de una revisión o un capítulo en .md, o '
            'empieza uno en blanco.',
        boton: 'Nuevo',
        onBoton: _openImport,
        pie: SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(GSpacing.page),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: GColors.ink, width: GSpacing.border)),
            ),
            child: const GMono.muted('Formato · la-jaula-rota-review-v4'),
          ),
        ),
      ),
      pieLabel: 'Nuevo',
      pieIcon: Icons.add,
      onPie: _openImport,
    );
  }

  Widget _fila(ReviewSummary r, int numero) {
    final suelto = r.isDocument;
    final meta = StringBuffer(suelto
        ? 'Capítulo suelto'
        : '${r.total} ${r.total == 1 ? 'sugerencia' : 'sugerencias'}');
    if (r.manual > 0) meta.write(' · ${r.manual} a mano');

    return GFila(
      id: r.id,
      numero: numero,
      titulo: r.title,
      meta: meta.toString(),
      debajo: suelto ? null : GMeter(total: r.total, done: r.resolved),
      derecha: GStamp(
        r.isComplete ? 'Listo' : (suelto ? '.md' : 'En curso'),
        filled: r.isComplete,
      ),
      onTap: () => _openReview(r.id),
      onLongPress: () => _opciones(r),
      onBorrar: () => _delete(r),
    );
  }
}
