import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/review_session.dart';
import '../../utils/reader_layout.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import 'g_bits.dart';
import 'g_foot.dart';
import 'g_paragraphs.dart';
import 'g_prose.dart';
import 'g_suggestion_card.dart';

/// Lleva la cuenta de dónde está cada tarjeta de sugerencia del lector y de
/// cuál se miró la última vez, para saltar a la siguiente o a la anterior
/// pendiente. Lo crea quien aloja el lector (el móvil o el escritorio) y se
/// lo pasa al [GLectorCuerpo] y a la [GLectorBarra].
class GLectorNavegador {
  final Map<int, GlobalKey> _tarjetas = {};
  int _ultima = -1;

  /// Estrena una clave por tarjeta; se llama cuando cambian las piezas.
  void registrar(List<ReaderPiece> piezas) {
    _tarjetas.clear();
    for (final p in piezas) {
      if (p is CardPiece) _tarjetas[p.index] = GlobalKey();
    }
  }

  /// Clave de la tarjeta [index], para colgarla de su widget.
  GlobalKey? claveDe(int index) => _tarjetas[index];

  List<int> _pendientes(ReviewSession s) => [
        for (var i = 0; i < s.suggestions.length; i++)
          if (!s.isResolved(i)) i
      ];

  void saltarA(int index) {
    _ultima = index;
    final ctx = _tarjetas[index]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.1);
    }
  }

  void siguiente(ReviewSession s) {
    final p = _pendientes(s);
    if (p.isEmpty) return;
    saltarA(p.firstWhere((i) => i > _ultima, orElse: () => p.first));
  }

  void anterior(ReviewSession s) {
    final p = _pendientes(s);
    if (p.isEmpty) return;
    saltarA(p.lastWhere((i) => i < _ultima, orElse: () => p.last));
  }
}

/// El capítulo con las tarjetas intercaladas y la prosa numerada por
/// párrafos, más la franja de progreso. Es lo mismo en el móvil, donde lo
/// aloja `GReviewerScreen`, que en el escritorio, donde lo aloja
/// `GEscritorioScreen`: lee la [ReviewSession] del árbol.
class GLectorCuerpo extends StatefulWidget {
  final GLectorNavegador navegador;

  /// Se avisa de qué bloque se está editando (`null` al terminar), para que
  /// quien aloja el lector pinte su barra de edición.
  final ValueChanged<GProseEditActions?> onEdicion;

  /// Si es `null` no hay asistente y la selección de texto no hace nada.
  final void Function(String seleccion, {bool anclable})? onSeleccionCambia;
  final VoidCallback? onSeleccionVacia;

  /// Ancho máximo de la columna de texto; en escritorio el texto no se
  /// estira por una ventana de 1600px.
  final double? anchoMax;

  const GLectorCuerpo({
    super.key,
    required this.navegador,
    required this.onEdicion,
    this.onSeleccionCambia,
    this.onSeleccionVacia,
    this.anchoMax,
  });

  @override
  State<GLectorCuerpo> createState() => _GLectorCuerpoState();
}

class _GLectorCuerpoState extends State<GLectorCuerpo> {
  List<ReaderPiece>? _pieces;
  String? _piecesForId;
  GProseEditActions? _edicion;

  void _ensurePieces(ReviewSession session) {
    final r = session.review!;
    if (_piecesForId == r.id && _pieces != null) return;
    _pieces = buildReaderPieces(r);
    _piecesForId = r.id;
    widget.navegador.registrar(_pieces!);
  }

  /// Solo un bloque en edición a la vez: empezar otro cancela el anterior. El
  /// aviso de salida del anterior llega después del de entrada del nuevo, por
  /// eso se compara la identidad.
  void _cambioEdicion(GProseEditActions acciones, {required bool activa}) {
    if (activa) {
      final anterior = _edicion;
      setState(() => _edicion = acciones);
      widget.onEdicion(acciones);
      if (anterior != null) anterior.cancelar();
    } else if (identical(_edicion, acciones)) {
      setState(() => _edicion = null);
      widget.onEdicion(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ReviewSession>();
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
        _ensurePieces(session);
        final c = session.counts();
        final chapter = session.review!.chapter;
        Widget texto = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _pieces!.length; i++) ...[
              if (i > 0) const SizedBox(height: GSpacing.gap),
              _pieza(_pieces![i], chapter),
            ],
          ],
        );
        final max = widget.anchoMax;
        if (max != null) {
          texto = Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: max), child: texto),
          );
        }
        return Column(
          children: [
            if (c.total > 0) GProgresoLector(done: c.done, total: c.total),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(GSpacing.page),
                child: texto,
              ),
            ),
          ],
        );
    }
  }

  /// En «Galerada» el original tachado y el contexto de una inserción viven
  /// **dentro** de la tarjeta, así que el fragmento afectado y el marcador de
  /// inserción del lector anterior ya no se pintan sueltos.
  Widget _pieza(ReaderPiece p, String chapter) {
    final alSeleccionar = widget.onSeleccionCambia;
    final alVaciar = widget.onSeleccionVacia;
    switch (p) {
      case ProsePiece():
        return GProseBlock(
          key: ValueKey(p.blockId),
          text: p.text,
          start: p.start,
          end: p.end,
          number: GParagraphs.at(chapter, p.start),
          siempreEditando: context.read<ReviewSession>().esSuelto,
          onEditing: _cambioEdicion,
          onSeleccionCambia:
              alSeleccionar == null ? null : (s) => alSeleccionar(s),
          onSeleccionVacia: alSeleccionar == null ? null : alVaciar,
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
          key: widget.navegador.claveDe(p.index),
          child: GSuggestionCard(
            index: p.index,
            paragraphs: etiqueta,
            // Lo escrito a mano no existe en el original: no se puede anclar.
            onSeleccionCambia: alSeleccionar == null
                ? null
                : (s) => alSeleccionar(s, anclable: false),
            onSeleccionVacia: alSeleccionar == null ? null : alVaciar,
          ),
        );
    }
  }
}

/// Barra de abajo del lector: la navegación entre pendientes, la CTA de
/// confirmar o, mientras se edita un bloque, Guardar · Cancelar.
class GLectorBarra extends StatelessWidget {
  final ReviewSession session;
  final GLectorNavegador navegador;

  /// El bloque que se está editando ahora mismo, si hay alguno.
  final GProseEditActions? edicion;
  final VoidCallback onConfirmar;

  const GLectorBarra({
    super.key,
    required this.session,
    required this.navegador,
    required this.edicion,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    final e = edicion;
    if (e != null && session.esSuelto) return _suelto(e);
    if (e != null) {
      return GFoot.partida(
        leftLabel: 'Guardar',
        rightLabel: 'Cancelar',
        leftFill: GFootFill.red,
        rightFill: GFootFill.off,
        onLeft: e.guardar,
        onRight: e.cancelar,
      );
    }

    final c = session.counts();
    final todo = session.allResolved;
    if (c.total == 0) {
      return GFoot.unica(
        label: 'Revisar y confirmar',
        fill: GFootFill.red,
        onTap: onConfirmar,
      );
    }
    return GFoot.navegada(
      label: todo
          ? 'Revisar y confirmar'
          : '${c.pending} ${c.pending == 1 ? 'pendiente' : 'pendientes'}',
      fill: todo ? GFootFill.ink : GFootFill.red,
      onMain: todo ? onConfirmar : null,
      onUp: () => navegador.anterior(session),
      onDown: () => navegador.siguiente(session),
    );
  }

  /// Capítulo suelto, siempre en edición: la CTA de siempre y, pegadas a su
  /// derecha, Guardar · Deshacer · Cancelar. Guardar y Cancelar solo se
  /// activan con cambios sin guardar; Deshacer, mientras haya historial.
  Widget _suelto(GProseEditActions e) {
    final sinGuardar = session.sinGuardar;
    return ValueListenableBuilder<UndoHistoryValue>(
      valueListenable: e.historial,
      builder: (context, historial, _) => GFoot.conIconos(
        label: 'Revisar y confirmar',
        fill: GFootFill.red,
        onMain: onConfirmar,
        iconos: [
          GFootIcono(
            icon: Icons.save_outlined,
            tooltip: 'Guardar',
            onTap: sinGuardar ? e.guardar : null,
            acento: true,
          ),
          GFootIcono(
            icon: Icons.undo,
            tooltip: 'Deshacer',
            onTap: historial.canUndo ? e.historial.undo : null,
          ),
          GFootIcono(
            icon: Icons.close,
            tooltip: 'Descartar cambios',
            onTap: sinGuardar ? e.cancelar : null,
          ),
        ],
      ),
    );
  }
}

/// Estado del guardado en mono, bajo el título. Un borrador sin guardar manda
/// sobre todo lo demás y va en el acento, para que no pase desapercibido.
class GEstadoGuardado extends StatelessWidget {
  final SaveStatus status;
  final bool sinGuardar;
  const GEstadoGuardado(
      {super.key, required this.status, this.sinGuardar = false});

  @override
  Widget build(BuildContext context) {
    if (sinGuardar) return const GMono.red('● Cambios sin guardar');
    final (String texto, Color color) = switch (status) {
      SaveStatus.idle => ('', GColors.grey2),
      SaveStatus.pending => ('○ Sin guardar', GColors.grey2),
      SaveStatus.saving => ('↻ Guardando…', GColors.grey2),
      SaveStatus.saved => ('✓ Guardado', GColors.grey2),
      SaveStatus.error => ('✕ Error', GColors.accent),
    };
    if (texto.isEmpty) return const SizedBox.shrink();
    return GMono(texto, color: color);
  }
}

/// Franja de progreso: «2/5», una celda por sugerencia y las pendientes en
/// rojo.
class GProgresoLector extends StatelessWidget {
  final int done;
  final int total;

  const GProgresoLector({super.key, required this.done, required this.total});

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
