import 'package:flutter/material.dart';
import '../../models/capitulo.dart';
import '../../models/libro.dart';
import '../../models/review_summary.dart';
import '../../utils/texto_capitulo.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_button.dart';
import '../widgets/g_dialog.dart';

/// Columna izquierda del escritorio: los capítulos del libro y, al pulsar el
/// reloj de uno, sus revisiones.
class GPanelCapitulos extends StatelessWidget {
  final Libro libro;

  /// `null` mientras carga.
  final List<Capitulo>? capitulos;
  final Object? error;
  final Capitulo? actual;

  /// Palabras del capítulo abierto: es el único cuyo texto está cargado, así
  /// que es el único que puede decirlo.
  final int? palabrasActual;

  /// Muestra las revisiones de [actual] en lugar de los capítulos.
  final bool verRevisiones;
  final List<ReviewSummary> revisiones;
  final String? revisionId;

  final ValueChanged<Capitulo> onAbrir;
  final ValueChanged<Capitulo> onVerRevisiones;
  final VoidCallback onVolverACapitulos;
  final ValueChanged<String> onAbrirRevision;
  final VoidCallback onNuevoCapitulo;

  /// Importa una revisión (un JSON o un `.md`) en el capítulo abierto; `null`
  /// si no hay ninguno.
  final VoidCallback? onNuevaRevision;
  final void Function(Capitulo, String opcion) onOpcionesCapitulo;
  final void Function(ReviewSummary, String opcion) onOpcionesRevision;
  final VoidCallback onOcultar;
  final VoidCallback onReintentar;

  const GPanelCapitulos({
    super.key,
    required this.libro,
    required this.capitulos,
    required this.error,
    required this.actual,
    required this.palabrasActual,
    required this.verRevisiones,
    required this.revisiones,
    required this.revisionId,
    required this.onAbrir,
    required this.onVerRevisiones,
    required this.onVolverACapitulos,
    required this.onAbrirRevision,
    required this.onNuevoCapitulo,
    required this.onNuevaRevision,
    required this.onOpcionesCapitulo,
    required this.onOpcionesRevision,
    required this.onOcultar,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    final cap = actual;
    return Container(
      width: GSpacing.escPanelIzq,
      decoration: BoxDecoration(
        color: GColors.paper,
        border: Border(
            right: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cabecera(verRevisiones && cap != null ? cap : null),
          Expanded(
            child: verRevisiones && cap != null
                ? _Revisiones(
                    revisiones: revisiones,
                    revisionId: revisionId,
                    onAbrir: onAbrirRevision,
                    onOpciones: onOpcionesRevision,
                  )
                : _Capitulos(
                    capitulos: capitulos,
                    error: error,
                    actual: actual,
                    palabrasActual: palabrasActual,
                    onAbrir: onAbrir,
                    onVerRevisiones: onVerRevisiones,
                    onOpciones: onOpcionesCapitulo,
                    onReintentar: onReintentar,
                  ),
          ),
          _pie(verRevisiones && cap != null),
        ],
      ),
    );
  }

  Widget _cabecera(Capitulo? capituloDeRevisiones) {
    final n = capitulos?.length ?? libro.capitulos;
    return Container(
      padding: const EdgeInsets.all(GSpacing.page),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GMono.muted(capituloDeRevisiones == null
                    ? 'Libro en curso'
                    : 'Revisiones'),
              ),
              GIconButton(
                icon: Icons.keyboard_double_arrow_left,
                tooltip: 'Ocultar los capítulos',
                outlined: true,
                onPressed: onOcultar,
              ),
            ],
          ),
          const SizedBox(height: GSpacing.gapSm),
          Text(
            capituloDeRevisiones == null
                ? libro.title
                : '${TextoCapitulo.romano(capituloDeRevisiones.numero)}. '
                    '${capituloDeRevisiones.titulo}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GText.appBar,
          ),
          const SizedBox(height: GSpacing.gapXs),
          Text(
            capituloDeRevisiones == null
                ? '$n ${n == 1 ? 'capítulo' : 'capítulos'}'
                : '${revisiones.length} '
                    '${revisiones.length == 1 ? 'revisión' : 'revisiones'} · '
                    '${libro.title}',
            style: GText.heroSub,
          ),
          if (capituloDeRevisiones == null) ...[
            const SizedBox(height: GSpacing.gapSm),
            // Aún no hay partes ni tomos que agrupar.
            const Wrap(children: [GChip('Partes', onTap: null)]),
          ],
        ],
      ),
    );
  }

  Widget _pie(bool enRevisiones) {
    return Container(
      padding: const EdgeInsets.all(GSpacing.gapSm),
      decoration: BoxDecoration(
        border:
            Border(top: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GSpacing.gapSm,
        children: enRevisiones
            ? [
                GButton(
                    label: 'Nueva revisión del capítulo',
                    icon: Icons.difference_outlined,
                    onPressed: onNuevaRevision),
                GButton(
                    label: 'Ver todos los capítulos',
                    icon: Icons.list,
                    onPressed: onVolverACapitulos),
              ]
            : [
                GButton(
                    label: 'Nuevo capítulo',
                    icon: Icons.post_add,
                    fill: GFill.red,
                    onPressed: onNuevoCapitulo),
                GButton(
                    label: 'Importar archivo .md',
                    icon: Icons.file_open_outlined,
                    onPressed: onNuevaRevision),
              ],
      ),
    );
  }
}

class _Capitulos extends StatelessWidget {
  final List<Capitulo>? capitulos;
  final Object? error;
  final Capitulo? actual;
  final int? palabrasActual;
  final ValueChanged<Capitulo> onAbrir;
  final ValueChanged<Capitulo> onVerRevisiones;
  final void Function(Capitulo, String opcion) onOpciones;
  final VoidCallback onReintentar;

  const _Capitulos({
    required this.capitulos,
    required this.error,
    required this.actual,
    required this.palabrasActual,
    required this.onAbrir,
    required this.onVerRevisiones,
    required this.onOpciones,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    final lista = capitulos;
    if (error != null && lista == null) {
      return Padding(
        padding: const EdgeInsets.all(GSpacing.page),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const GMono.red('✕ No se pudieron cargar los capítulos'),
            const SizedBox(height: GSpacing.gapSm),
            Text('$error', style: GText.reason, textAlign: TextAlign.center),
            const SizedBox(height: GSpacing.gap),
            GChip('Reintentar', onTap: onReintentar),
          ],
        ),
      );
    }
    if (lista == null) {
      return Center(child: CircularProgressIndicator(color: GColors.ink));
    }
    if (lista.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(GSpacing.page),
        child: Center(
          child: Text(
              'Crea el primer capítulo para importar sus revisiones '
              'dentro.',
              style: GText.reason,
              textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      itemCount: lista.length,
      itemBuilder: (_, i) {
        final c = lista[i];
        final esActual = actual?.id == c.id;
        return _FilaCapitulo(
          capitulo: c,
          seleccionado: esActual,
          palabras: esActual ? palabrasActual : null,
          onAbrir: () => onAbrir(c),
          onVerRevisiones: () => onVerRevisiones(c),
          onOpciones: (o) => onOpciones(c, o),
        );
      },
    );
  }
}

class _FilaCapitulo extends StatelessWidget {
  final Capitulo capitulo;
  final bool seleccionado;
  final int? palabras;
  final VoidCallback onAbrir;
  final VoidCallback onVerRevisiones;
  final ValueChanged<String> onOpciones;

  const _FilaCapitulo({
    required this.capitulo,
    required this.seleccionado,
    required this.palabras,
    required this.onAbrir,
    required this.onVerRevisiones,
    required this.onOpciones,
  });

  @override
  Widget build(BuildContext context) {
    final c = capitulo;
    final revs = c.revisiones == 0 ? 'sin revisiones' : '${c.revisiones} rev.';
    final meta = palabras == null
        ? revs
        : '${TextoCapitulo.miles(palabras!)} palabras · $revs';
    return Semantics(
      selected: seleccionado,
      child: InkWell(
        onTap: onAbrir,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
              GSpacing.page, GSpacing.blockV, GSpacing.gapSm, GSpacing.blockV),
          decoration: BoxDecoration(
            color: seleccionado ? GColors.sheet : null,
            border: Border(
              left: BorderSide(
                color: seleccionado ? GColors.accent : Colors.transparent,
                width: GSpacing.stripe,
              ),
              bottom: BorderSide(color: GColors.ink, width: GSpacing.border),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: GSpacing.escNumeral,
                child: Text(TextoCapitulo.romano(c.numero),
                    style: GText.rowTitle.copyWith(
                        color: seleccionado ? GColors.accentText : null)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GText.rowTitle),
                    const SizedBox(height: GSpacing.gapXs),
                    GMono.muted(meta, small: true),
                    const SizedBox(height: GSpacing.gapSm),
                    GStamp(
                      c.isComplete
                          ? 'Listo'
                          : (c.revisiones == 0 ? 'Vacío' : 'En curso'),
                      filled: c.isComplete,
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  GIconButton(
                    icon: Icons.history,
                    tooltip: 'Revisiones de «${c.titulo}»',
                    outlined: true,
                    onPressed: onVerRevisiones,
                  ),
                  const SizedBox(height: GSpacing.gapXs),
                  GMenu(
                    items: const [
                      GMenuItem(
                          label: 'Editar número y título',
                          icon: Icons.edit,
                          value: 'editar'),
                      GMenuItem(
                          label: 'Borrar capítulo',
                          icon: Icons.delete_outline,
                          value: 'borrar',
                          danger: true),
                    ],
                    onSelected: onOpciones,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Revisiones extends StatelessWidget {
  final List<ReviewSummary> revisiones;
  final String? revisionId;
  final ValueChanged<String> onAbrir;
  final void Function(ReviewSummary, String opcion) onOpciones;

  const _Revisiones({
    required this.revisiones,
    required this.revisionId,
    required this.onAbrir,
    required this.onOpciones,
  });

  @override
  Widget build(BuildContext context) {
    if (revisiones.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(GSpacing.page),
        child: Center(
          child: Text(
              'Este capítulo aún no tiene revisiones. Importa el JSON '
              'de una revisión o un capítulo en .md.',
              style: GText.reason,
              textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      itemCount: revisiones.length,
      itemBuilder: (_, i) => _FilaRevision(
        revision: revisiones[i],
        abierta: revisiones[i].id == revisionId,
        onAbrir: () => onAbrir(revisiones[i].id),
        onOpciones: (o) => onOpciones(revisiones[i], o),
      ),
    );
  }
}

class _FilaRevision extends StatelessWidget {
  final ReviewSummary revision;
  final bool abierta;
  final VoidCallback onAbrir;
  final ValueChanged<String> onOpciones;

  const _FilaRevision({
    required this.revision,
    required this.abierta,
    required this.onAbrir,
    required this.onOpciones,
  });

  @override
  Widget build(BuildContext context) {
    final r = revision;
    final meta = StringBuffer(r.isDocument
        ? 'Capítulo suelto'
        : '${r.total} ${r.total == 1 ? 'sugerencia' : 'sugerencias'}');
    if (r.manual > 0) meta.write(' · ${r.manual} a mano');
    final fecha = r.updatedAt;
    return InkWell(
      onTap: onAbrir,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            GSpacing.page, GSpacing.blockV, GSpacing.gapSm, GSpacing.blockV),
        decoration: BoxDecoration(
          color: abierta ? GColors.sheet : null,
          border: Border(
            left: BorderSide(
              color: abierta ? GColors.accent : Colors.transparent,
              width: GSpacing.stripe,
            ),
            bottom: BorderSide(color: GColors.ink, width: GSpacing.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: GMono(
                      fecha == null ? 'Sin fecha' : TextoCapitulo.fecha(fecha),
                      color: abierta ? GColors.accentText : GColors.grey2,
                      small: true),
                ),
                if (abierta) const GMono('En el editor', small: true),
                GMenu(
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
                  onSelected: onOpciones,
                ),
              ],
            ),
            Text(r.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GText.rowTitle),
            const SizedBox(height: GSpacing.gapXs),
            GMono.muted(meta.toString(), small: true),
            if (!r.isDocument) ...[
              const SizedBox(height: GSpacing.gapSm),
              GMeter(total: r.total, done: r.resolved),
            ],
            const SizedBox(height: GSpacing.gapSm),
            Wrap(
              spacing: GSpacing.chipGap,
              runSpacing: GSpacing.chipGap,
              children: [
                GStamp(
                    r.isComplete
                        ? 'Listo'
                        : (r.isDocument ? '.md' : 'En curso'),
                    filled: r.isComplete),
                // Aún no hay historial de versiones del texto.
                if (!abierta) const GChip('Restaurar', onTap: null),
                if (!abierta) const GChip('Comparar', onTap: null),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
