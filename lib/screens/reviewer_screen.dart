import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/review.dart';
import '../services/api_service.dart';
import '../services/review_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_icon.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../utils/export_md.dart';
import '../utils/reader_layout.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/progress_header.dart';
import '../widgets/prose_block.dart';
import '../widgets/save_indicator.dart';
import '../widgets/suggestion_card.dart';
import 'confirm_screen.dart';
import 'preview_screen.dart';

/// Lector completo de una revisión: capítulo con las tarjetas de sugerencia
/// intercaladas en su posición real, edición manual de prosa, navegación entre
/// pendientes, vista previa, confirmación y export .md.
class ReviewerScreen extends StatelessWidget {
  final String reviewId;
  const ReviewerScreen({super.key, required this.reviewId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReviewSession>(
      create: (ctx) =>
          ReviewSession(api: ctx.read<ApiService>())..load(reviewId),
      child: const _ReviewerView(),
    );
  }
}

class _ReviewerView extends StatefulWidget {
  const _ReviewerView();

  @override
  State<_ReviewerView> createState() => _ReviewerViewState();
}

class _ReviewerViewState extends State<_ReviewerView> {
  List<ReaderPiece>? _pieces;
  String? _piecesForId;
  final Map<int, GlobalKey> _cardKeys = {};
  int _lastFocused = -1;

  /// Acciones del bloque de prosa que se está editando, si hay alguno. La barra
  /// de abajo las pinta en lugar de la navegación entre pendientes: dentro del
  /// bloque quedarían fuera de pantalla en cuanto el bloque es largo.
  ProseEditActions? _edicion;

  /// Solo se puede editar un bloque a la vez: si empiezas otro, el anterior se
  /// cancela. El aviso de salida del anterior llega *después* del de entrada
  /// del nuevo, por eso se compara la identidad antes de quitar la barra.
  void _cambioEdicion(ProseEditActions acciones, {required bool activa}) {
    if (activa) {
      final anterior = _edicion;
      setState(() => _edicion = acciones);
      if (anterior != null) anterior.cancelar();
    } else if (identical(_edicion, acciones)) {
      setState(() => _edicion = null);
    }
  }

  void _ensurePieces(Review r) {
    if (_piecesForId == r.id && _pieces != null) return;
    _pieces = buildReaderPieces(r);
    _piecesForId = r.id;
    _cardKeys.clear();
    for (final p in _pieces!) {
      if (p is CardPiece) _cardKeys[p.index] = GlobalKey();
    }
  }

  List<int> _pendingIndices(ReviewSession s) => [
        for (var i = 0; i < s.suggestions.length; i++)
          if (!s.isResolved(i)) i
      ];

  void _jumpTo(int index) {
    _lastFocused = index;
    final ctx = _cardKeys[index]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.1);
    }
  }

  void _nextPending(ReviewSession s) {
    final p = _pendingIndices(s);
    if (p.isEmpty) return;
    final next = p.firstWhere((i) => i > _lastFocused, orElse: () => p.first);
    _jumpTo(next);
  }

  void _prevPending(ReviewSession s) {
    final p = _pendingIndices(s);
    if (p.isEmpty) return;
    final prev =
        p.lastWhere((i) => i < _lastFocused, orElse: () => p.last);
    _jumpTo(prev);
  }

  Future<void> _reset(ReviewSession s) async {
    final ok = await AppDialog.confirm(
      context,
      title: 'Borrar decisiones',
      message: 'Se perderán todas las respuestas y las ediciones manuales '
          'de este capítulo.',
      confirmLabel: 'Borrar',
      danger: true,
    );
    if (ok == true) await s.reset();
  }

  void _openPreview(ReviewSession s) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PreviewScreen(
        title: s.review!.title,
        text: s.currentText(),
        counts: s.counts(),
      ),
    ));
  }

  void _openConfirm(ReviewSession s) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ConfirmScreen(
        title: s.review!.title,
        text: s.currentText(),
        counts: s.counts(),
      ),
    ));
  }

  void _openOriginal(ReviewSession s) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _OriginalScreen(chapter: s.review!.chapter),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ReviewSession>();

    return PopScope(
      canPop: true,
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) {
        if (session.canSave) session.saveNow();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(session.review?.title ?? 'Revisión'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SaveIndicator(status: session.saveStatus),
            ),
            TextButton(
              onPressed: session.canSave ? () => session.saveNow() : null,
              child: const Text('Guardar'),
            ),
            if (session.loadStatus == LoadStatus.ready)
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'preview':
                      _openPreview(session);
                      break;
                    case 'export':
                      ExportMd.share(
                          session.review!.title, 'avance', session.currentText());
                      break;
                    case 'original':
                      _openOriginal(session);
                      break;
                    case 'reset':
                      _reset(session);
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'preview', child: Text('Vista previa')),
                  PopupMenuItem(value: 'export', child: Text('Exportar avance (.md)')),
                  PopupMenuItem(value: 'original', child: Text('Ver original')),
                  PopupMenuItem(value: 'reset', child: Text('Borrar decisiones')),
                ],
              ),
          ],
        ),
        body: _body(context, session),
        bottomNavigationBar: session.loadStatus == LoadStatus.ready
            ? _bottomBar(context, session)
            : null,
      ),
    );
  }

  Widget _body(BuildContext context, ReviewSession session) {
    switch (session.loadStatus) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case LoadStatus.error:
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('No se pudo abrir la revisión',
                    style: AppText.titleSection, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.gapSm),
                Text('${session.lastError}',
                    style: AppText.caption, textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      case LoadStatus.ready:
        _ensurePieces(session.review!);
        final c = session.counts();
        final pieces = _pieces!;
        return Column(
          children: [
            ProgressHeader(done: c.done, total: c.total),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < pieces.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.gapMd),
                      _piece(pieces[i]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _piece(ReaderPiece p) {
    switch (p) {
      case ProsePiece():
        return ProseBlock(
          key: ValueKey(p.blockId),
          text: p.text,
          start: p.start,
          end: p.end,
          onEditing: _cambioEdicion,
        );
      case AffectedPiece():
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.card),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            p.text,
            style: AppText.bodyText.copyWith(
              color: AppColors.textMuted,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.textMuted,
            ),
          ),
        );
      case InsertMarkerPiece():
        return Center(
          child: Text('＋ Posible inserción aquí',
              style: AppText.caption.copyWith(color: AppColors.primary)),
        );
      case CardPiece():
        return Container(
          key: _cardKeys[p.index],
          child: SuggestionCard(index: p.index),
        );
    }
  }

  /// Barra fija mientras se edita un bloque: Guardar y Cancelar siempre a mano,
  /// sin depender de dónde acabe el bloque.
  ///
  /// El `Scaffold` **no** sube el `bottomNavigationBar` por encima del teclado
  /// (solo encoge el cuerpo), así que el hueco del teclado se reserva aquí a
  /// mano; si no, la barra queda justo debajo y no se ve.
  Widget _barraEdicion(BuildContext context, ProseEditActions a) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.gapSm),
          decoration: const BoxDecoration(
            color: AppColors.bg,
            border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(child: AppButton(label: 'Guardar', onPressed: a.guardar)),
              const SizedBox(width: AppSpacing.gapSm),
              Expanded(
                child: AppButton(
                  label: 'Cancelar',
                  variant: AppButtonVariant.cancel,
                  onPressed: a.cancelar,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context, ReviewSession session) {
    final edicion = _edicion;
    if (edicion != null) return _barraEdicion(context, edicion);
    final c = session.counts();
    final allResolved = session.allResolved;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.gapSm),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: AppIcon.md),
              tooltip: 'Pendiente anterior',
              onPressed: () => _prevPending(session),
            ),
            Expanded(
              child: AppButton(
                label: allResolved
                    ? 'Revisar y confirmar'
                    : '${c.pending} pendientes',
                onPressed: allResolved ? () => _openConfirm(session) : null,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: AppIcon.md),
              tooltip: 'Pendiente siguiente',
              onPressed: () => _nextPending(session),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lector del capítulo original, de solo lectura.
class _OriginalScreen extends StatelessWidget {
  final String chapter;
  const _OriginalScreen({required this.chapter});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capítulo original')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: SelectableText(chapter, style: AppText.readerText),
      ),
    );
  }
}
