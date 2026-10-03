import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/review.dart';
import '../../services/api_service.dart';
import '../../services/g_ai_assistant_controller.dart';
import '../../services/review_session.dart';
import '../../utils/export_md.dart';
import '../../utils/reader_layout.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import '../widgets/g_ai_assistant_overlay.dart';
import '../widgets/g_app_bar.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_dialog.dart';
import '../widgets/g_foot.dart';
import '../widgets/g_paragraphs.dart';
import '../widgets/g_prose.dart';
import '../widgets/g_suggestion_card.dart';
import 'g_confirm_screen.dart';
import 'g_original_screen.dart';
import 'g_preview_screen.dart';

/// Lector de «Galerada»: el capítulo con las tarjetas intercaladas, la prosa
/// numerada por párrafos y la barra inferior con la navegación entre
/// pendientes. La lógica es la misma de siempre; cambia la piel.
class GReviewerScreen extends StatelessWidget {
  final String reviewId;
  const GReviewerScreen({super.key, required this.reviewId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReviewSession>(
      create: (ctx) =>
          ReviewSession(api: ctx.read<ApiService>())..load(reviewId),
      child: const _Vista(),
    );
  }
}

class _Vista extends StatefulWidget {
  const _Vista();

  @override
  State<_Vista> createState() => _VistaState();
}

class _VistaState extends State<_Vista> with GAiConAsistente<_Vista> {
  List<ReaderPiece>? _pieces;
  String? _piecesForId;
  final Map<int, GlobalKey> _cardKeys = {};
  int _lastFocused = -1;
  GProseEditActions? _edicion;
  bool _generandoIA = false;
  GAiAssistantController? _asistente;

  @override
  void dispose() {
    _asistente?.dispose();
    super.dispose();
  }

  /// Se crea en el primer build con la revisión ya cargada (hasta entonces no
  /// hay `revisionId`), y arranca como burbuja: es un acceso permanente al
  /// chat con la IA, ya no un ítem del menú de 3 puntos.
  GAiAssistantController _aiPara(ReviewSession session) {
    final actual = _asistente;
    if (actual != null) return actual;
    final nuevo = GAiAssistantController(
      api: context.read<ApiService>(),
      revisionId: session.review!.id,
      // El compuesto con las decisiones ya tomadas, no el original a pelo:
      // es "el capítulo" tal como lo ves ahora mismo en el revisor.
      capituloActual: session.currentText,
    )..mode = GAiAssistantMode.bubble;
    _asistente = nuevo;
    return nuevo;
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

  /// Solo un bloque en edición a la vez: empezar otro cancela el anterior. El
  /// aviso de salida del anterior llega después del de entrada del nuevo, por
  /// eso se compara la identidad.
  void _cambioEdicion(GProseEditActions acciones, {required bool activa}) {
    if (activa) {
      final anterior = _edicion;
      setState(() => _edicion = acciones);
      if (anterior != null) anterior.cancelar();
    } else if (identical(_edicion, acciones)) {
      setState(() => _edicion = null);
    }
  }

  List<int> _pendientes(ReviewSession s) => [
        for (var i = 0; i < s.suggestions.length; i++)
          if (!s.isResolved(i)) i
      ];

  void _saltarA(int index) {
    _lastFocused = index;
    final ctx = _cardKeys[index]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.1);
    }
  }

  void _siguiente(ReviewSession s) {
    final p = _pendientes(s);
    if (p.isEmpty) return;
    _saltarA(p.firstWhere((i) => i > _lastFocused, orElse: () => p.first));
  }

  void _anterior(ReviewSession s) {
    final p = _pendientes(s);
    if (p.isEmpty) return;
    _saltarA(p.lastWhere((i) => i < _lastFocused, orElse: () => p.last));
  }

  Future<void> _reset(ReviewSession s) async {
    final ok = await GDialog.confirmar(
      context,
      title: 'Borrar',
      keyword: 'decisiones',
      message: 'Se perderán todas las respuestas y las ediciones manuales de '
          'este capítulo.',
    );
    if (ok == true) await s.reset();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.toUpperCase(),
            style: GText.mono.copyWith(color: GColors.onInk)),
      ),
    );
  }

  Future<void> _generarSugerenciasIA(ReviewSession session) async {
    if (_generandoIA) return;
    final id = session.review!.id;
    setState(() => _generandoIA = true);
    _snack('Generando sugerencias…');
    try {
      await context.read<ApiService>().generarSugerencias(id);
      if (!mounted) return;
      await session.load(id);
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudo generar: $e');
    } finally {
      if (mounted) setState(() => _generandoIA = false);
    }
  }

  Future<void> _alternarFinalizada(ReviewSession session) async {
    final finalizar = !session.finalizada;
    try {
      await session.setFinalizada(finalizar);
      _snack(finalizar ? 'Capítulo finalizado' : 'Capítulo reabierto');
    } catch (e) {
      if (mounted) _snack('No se pudo guardar: $e');
    }
  }

  void _abrir(Widget pantalla) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ReviewSession>();
    final ai = session.loadStatus == LoadStatus.ready ? _aiPara(session) : null;

    return PopScope(
      canPop: true,
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) {
        if (session.canSave) session.saveNow();
      },
      child: conAsistente(
        Scaffold(
          appBar: GAppBar(
            title: session.review?.title ?? 'Revisión',
            subtitulo: session.loadStatus == LoadStatus.ready &&
                    session.saveStatus != SaveStatus.idle
                ? _EstadoGuardado(status: session.saveStatus)
                : null,
            trailing: [
              if (session.loadStatus == LoadStatus.ready) ...[
                GMenu(
                  items: [
                    const GMenuItem(
                        label: 'Vista previa',
                        icon: Icons.visibility,
                        value: 'preview'),
                    const GMenuItem(
                        label: 'Exportar avance (.md)',
                        icon: Icons.ios_share,
                        value: 'export'),
                    const GMenuItem(
                        label: 'Ver original',
                        icon: Icons.menu_book,
                        value: 'original'),
                    const GMenuItem(
                        label: 'Generar sugerencias',
                        icon: Icons.auto_awesome,
                        value: 'sugerencias_ia'),
                    if (session.esSuelto)
                      session.finalizada
                          ? const GMenuItem(
                              label: 'Reabrir capítulo',
                              icon: Icons.undo,
                              value: 'finalizar')
                          : const GMenuItem(
                              label: 'Marcar como finalizado',
                              icon: Icons.check,
                              value: 'finalizar'),
                    const GMenuItem(
                        label: 'Borrar decisiones',
                        icon: Icons.restart_alt,
                        value: 'reset',
                        danger: true),
                  ],
                  onSelected: (v) {
                    switch (v) {
                      case 'preview':
                        _abrir(GPreviewScreen(
                          title: session.review!.title,
                          text: session.currentText(),
                          revisionId: session.review!.id,
                          counts: session.counts(),
                        ));
                      case 'sugerencias_ia':
                        _generarSugerenciasIA(session);
                      case 'export':
                        ExportMd.share(session.review!.title, 'avance',
                            session.currentText());
                      case 'original':
                        _abrir(GOriginalScreen(
                          chapter: session.review!.chapter,
                          revisionId: session.review!.id,
                        ));
                      case 'finalizar':
                        _alternarFinalizada(session);
                      case 'reset':
                        _reset(session);
                    }
                  },
                ),
              ],
            ],
          ),
          body: _cuerpo(session, ai),
          bottomNavigationBar:
              session.loadStatus == LoadStatus.ready ? _barra(session) : null,
        ),
        ai,
        extraBottomOffset: GSpacing.foot,
      ),
    );
  }

  Widget _cuerpo(ReviewSession session, GAiAssistantController? ai) {
    switch (session.loadStatus) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return Center(child: CircularProgressIndicator(color: GColors.ink));
      case LoadStatus.error:
        return Padding(
          padding: const EdgeInsets.all(GSpacing.page),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GMono.red('✕ No se pudo abrir la revisión'),
                const SizedBox(height: GSpacing.gapSm),
                Text('${session.lastError}',
                    style: GText.reason, textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      case LoadStatus.ready:
        _ensurePieces(session.review!);
        final c = session.counts();
        final chapter = session.review!.chapter;
        return Column(
          children: [
            if (c.total > 0) _Progreso(done: c.done, total: c.total),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(GSpacing.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _pieces!.length; i++) ...[
                      if (i > 0) const SizedBox(height: GSpacing.gap),
                      _pieza(_pieces![i], chapter, ai),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }

  /// En «Galerada» el original tachado y el contexto de una inserción viven
  /// **dentro** de la tarjeta, así que el fragmento afectado y el marcador de
  /// inserción del lector anterior ya no se pintan sueltos.
  Widget _pieza(ReaderPiece p, String chapter, GAiAssistantController? ai) {
    switch (p) {
      case ProsePiece():
        return GProseBlock(
          key: ValueKey(p.blockId),
          text: p.text,
          start: p.start,
          end: p.end,
          number: GParagraphs.at(chapter, p.start),
          onEditing: _cambioEdicion,
          onSeleccionCambia: ai == null ? null : seleccionCambia,
          onSeleccionVacia: ai == null ? null : ocultarPill,
        );
      case AffectedPiece():
      case InsertMarkerPiece():
        return const SizedBox.shrink();
      case CardPiece():
        final s = context.read<ReviewSession>().suggestionAt(p.index);
        final inicio = s.isReplace
            ? chapter.indexOf(s.original ?? '')
            : chapter.indexOf(s.anchor ?? '');
        final etiqueta = s.isReplace
            ? GParagraphs.label(chapter, inicio < 0 ? 0 : inicio)
            : GParagraphs.label(
                chapter,
                inicio < 0 ? 0 : inicio,
                end: (inicio < 0 ? 0 : inicio) + (s.anchor ?? '').length + 2,
              );
        return Container(
          key: _cardKeys[p.index],
          child: GSuggestionCard(
            index: p.index,
            paragraphs: etiqueta,
            // Lo escrito a mano no existe en el original: no se puede anclar.
            onSeleccionCambia:
                ai == null ? null : (s) => seleccionCambia(s, anclable: false),
            onSeleccionVacia: ai == null ? null : ocultarPill,
          ),
        );
    }
  }

  Widget _barra(ReviewSession session) {
    final edicion = _edicion;
    if (edicion != null) {
      return GFoot.partida(
        leftLabel: 'Guardar',
        rightLabel: 'Cancelar',
        leftFill: GFootFill.ink,
        rightFill: GFootFill.off,
        onLeft: edicion.guardar,
        onRight: edicion.cancelar,
      );
    }

    final c = session.counts();
    final todo = session.allResolved;
    if (c.total == 0) {
      return GFoot.unica(
        label: 'Revisar y confirmar',
        fill: GFootFill.ink,
        onTap: () => _abrirConfirmacion(session),
      );
    }
    return GFoot.navegada(
      label: todo
          ? 'Revisar y confirmar'
          : '${c.pending} ${c.pending == 1 ? 'pendiente' : 'pendientes'}',
      fill: todo ? GFootFill.ink : GFootFill.red,
      onMain: todo ? () => _abrirConfirmacion(session) : null,
      onUp: () => _anterior(session),
      onDown: () => _siguiente(session),
    );
  }

  void _abrirConfirmacion(ReviewSession s) => _abrir(GConfirmScreen(
        title: s.review!.title,
        text: s.currentText(),
        counts: s.counts(),
      ));
}

/// Estado del autoguardado en mono, a la derecha de la barra superior.
class _EstadoGuardado extends StatelessWidget {
  final SaveStatus status;
  const _EstadoGuardado({required this.status});

  @override
  Widget build(BuildContext context) {
    final (String texto, Color color) = switch (status) {
      SaveStatus.idle => ('', GColors.grey2),
      SaveStatus.pending => ('○ Sin guardar', GColors.grey2),
      SaveStatus.saving => ('↻ Guardando…', GColors.grey2),
      SaveStatus.saved => ('✓ Guardado', GColors.grey2),
      SaveStatus.error => ('✕ Error', GColors.red),
    };
    if (texto.isEmpty) return const SizedBox.shrink();
    return GMono(texto, color: color);
  }
}

/// Franja de progreso: «2/5», una celda por sugerencia y las pendientes en
/// rojo.
class _Progreso extends StatelessWidget {
  final int done;
  final int total;

  const _Progreso({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final pendientes = total - done;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: GSpacing.page, vertical: GSpacing.barTop),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Row(
        children: [
          GMono('$done/$total'),
          const SizedBox(width: GSpacing.blockV),
          Expanded(child: GTicks(total: total, done: done)),
          const SizedBox(width: GSpacing.blockV),
          if (pendientes > 0)
            GMono.red(
                '$pendientes ${pendientes == 1 ? 'pendiente' : 'pendientes'}')
          else
            const GMono('Completado'),
        ],
      ),
    );
  }
}
