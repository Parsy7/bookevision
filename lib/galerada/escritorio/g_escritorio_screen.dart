import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/capitulo.dart';
import '../../models/libro.dart';
import '../../models/review_summary.dart';
import '../../services/api_service.dart';
import '../../services/g_ai_assistant_controller.dart';
import '../../services/review_session.dart';
import '../../utils/export_md.dart';
import '../../utils/texto_capitulo.dart';
import '../screens/g_capitulo_form_screen.dart';
import '../screens/g_confirm_screen.dart';
import '../screens/g_import_screen.dart';
import '../screens/g_preview_screen.dart';
import '../screens/g_profile_screen.dart';
import '../theme/g_colors.dart';
import '../theme/g_marca.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import '../widgets/g_ai_assistant_overlay.dart';
import '../widgets/g_ancho_app.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_button.dart';
import '../widgets/g_dialog.dart';
import '../widgets/g_lector.dart';
import '../widgets/g_prose.dart';
import 'g_escritorio.dart';
import 'g_escritorio_capitulos.dart';
import 'g_escritorio_exportar.dart';

/// El editor en tres columnas para Windows y tablets grandes: los capítulos
/// del libro a la izquierda, el capítulo abierto en el centro y el asistente
/// de IA a la derecha. Usa el mismo lector, la misma sesión de revisión y la
/// misma API que el móvil; solo cambia cómo se reparte la pantalla.
///
/// Se abre con [GEscritorio.abrir] (que quita la columna estrecha de la app),
/// y las pantallas del móvil que cuelgan de esta (vista previa, perfil…) se
/// abren envueltas en una [GColumna].
class GEscritorioScreen extends StatefulWidget {
  final Libro libro;

  const GEscritorioScreen({super.key, required this.libro});

  @override
  State<GEscritorioScreen> createState() => _GEscritorioScreenState();
}

class _GEscritorioScreenState extends State<GEscritorioScreen>
    with GAiConAsistente<GEscritorioScreen> {
  late final ApiService _api = context.read<ApiService>();

  List<Capitulo>? _capitulos;
  Object? _errorCapitulos;
  Capitulo? _capitulo;
  List<ReviewSummary> _revisiones = const [];
  String? _revisionId;

  late ReviewSession _session = ReviewSession(api: _api);
  GAiAssistantController? _ai;

  final _navegador = GLectorNavegador();
  final _cuerpoKey = GlobalKey();
  GProseEditActions? _edicion;

  bool _vistaRevisiones = false;
  bool _panelIzq = true;
  bool _panelIA = true;
  bool _foco = false;
  bool _split = false;
  bool _generandoIA = false;
  bool _inicializado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inicializado) return;
    _inicializado = true;
    final vista = View.of(context);
    final ancho = vista.physicalSize.width / vista.devicePixelRatio;
    // En una ventana justa, el asistente espera a que se le llame.
    _panelIA = ancho >= GSpacing.escAnchoAsistente;
    _cargarCapitulos(abrirInicial: true);
  }

  @override
  void dispose() {
    _session.dispose();
    _ai?.dispose();
    super.dispose();
  }

  // ---------- Carga ----------

  Future<void> _cargarCapitulos(
      {bool abrirInicial = false, int? seleccionarId}) async {
    try {
      final lista = await _api.getCapitulos(widget.libro.id);
      if (!mounted) return;
      final buscado = seleccionarId ?? _capitulo?.id;
      final actual = buscado == null
          ? null
          : lista.where((c) => c.id == buscado).firstOrNull;
      setState(() {
        _capitulos = lista;
        _errorCapitulos = null;
        if (actual != null) _capitulo = actual; // con sus cuentas al día
      });
      if (actual == null && _capitulo != null) {
        // El capítulo abierto ya no existe (se borró).
        setState(() {
          _capitulo = null;
          _revisiones = const [];
          _vistaRevisiones = false;
        });
        _ponerRevision(null);
      } else if (actual == null && abrirInicial && lista.isNotEmpty) {
        await _abrirCapitulo(lista.firstWhere((c) => c.revisiones > 0,
            orElse: () => lista.first));
      }
    } catch (e) {
      if (mounted) setState(() => _errorCapitulos = e);
    }
  }

  Future<void> _cargarRevisiones(
      {bool abrirMasReciente = false, String? abrirId}) async {
    final c = _capitulo;
    if (c == null) return;
    try {
      final lista = await _api.getRevisiones(capituloId: c.id);
      if (!mounted || _capitulo?.id != c.id) return;
      setState(() => _revisiones = lista);
      if (abrirId != null) {
        _ponerRevision(abrirId);
      } else if (abrirMasReciente) {
        _ponerRevision(_masReciente(lista)?.id);
      }
    } catch (e) {
      if (mounted) _snack('No se pudieron cargar las revisiones: $e');
    }
  }

  /// La última tocada: es con la que se estaba trabajando.
  ReviewSummary? _masReciente(List<ReviewSummary> lista) {
    ReviewSummary? mejor;
    for (final r in lista) {
      final f = r.updatedAt;
      final m = mejor?.updatedAt;
      if (mejor == null || (f != null && (m == null || f.isAfter(m)))) {
        mejor = r;
      }
    }
    return mejor;
  }

  // ---------- Cambiar de capítulo y de revisión ----------

  /// Con un borrador a medias en el campo, se pregunta antes de perderlo.
  Future<bool> _confirmarSalida() async {
    if (!_session.sinGuardar) return true;
    final ok = await GDialog.confirmar(
      context,
      title: 'Descartar',
      keyword: 'cambios',
      message: 'Hay cambios sin guardar en el capítulo. Si sigues, se '
          'perderán.',
      confirmLabel: 'Descartar',
      cancelLabel: 'Seguir editando',
    );
    if (ok != true || !mounted) return false;
    _session.sinGuardar = false;
    return true;
  }

  Future<void> _guardarPendiente() async {
    if (_session.canSave) await _session.saveNow();
  }

  Future<void> _abrirCapitulo(Capitulo c, {bool verRevisiones = false}) async {
    if (c.id != _capitulo?.id) {
      if (!await _confirmarSalida()) return;
      await _guardarPendiente();
      if (!mounted) return;
      setState(() {
        _capitulo = c;
        _revisiones = const [];
      });
      _ponerRevision(null);
      await _cargarRevisiones(abrirMasReciente: true);
    }
    if (mounted) setState(() => _vistaRevisiones = verRevisiones);
  }

  Future<void> _abrirRevision(String id) async {
    if (id == _revisionId) return;
    if (!await _confirmarSalida()) return;
    await _guardarPendiente();
    if (mounted) _ponerRevision(id);
  }

  /// Cambia la revisión abierta: una sesión y un asistente nuevos para ella.
  /// Las viejas se sueltan cuando termina el fotograma, que es cuando ya
  /// nadie las está pintando.
  void _ponerRevision(String? id) {
    if (id == _revisionId) return;
    final vieja = _session;
    final viejaIA = _ai;
    final nueva = ReviewSession(api: _api);
    if (id != null) nueva.load(id);
    setState(() {
      _session = nueva;
      _revisionId = id;
      _ai = null;
      _edicion = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      vieja.dispose();
      viejaIA?.dispose();
    });
  }

  GAiAssistantController _aiPara(ReviewSession session) {
    final actual = _ai;
    if (actual != null) return actual;
    return _ai = GAiAssistantController(
      api: _api,
      revisionId: session.review!.id,
      // El compuesto con las decisiones ya tomadas, no el original a pelo.
      capituloActual: session.currentText,
    );
  }

  // ---------- Acciones ----------

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.toUpperCase(),
            style: GText.mono.copyWith(color: GColors.onInk)),
      ),
    );
  }

  /// Una pantalla del móvil, en su columna estrecha, encima del escritorio.
  Future<T?> _empujar<T>(Widget pantalla) => Navigator.of(context).push<T>(
        MaterialPageRoute(builder: (_) => GColumna(child: pantalla)),
      );

  void _alternarFoco() => setState(() => _foco = !_foco);

  Future<void> _perfil() async {
    if (!await _confirmarSalida()) return;
    await _guardarPendiente();
    if (mounted) await _empujar<void>(const GProfileScreen());
  }

  Future<void> _nuevoCapitulo() async {
    final nuevo =
        await _empujar<Capitulo>(GCapituloFormScreen(libroId: widget.libro.id));
    if (!mounted || nuevo == null) return;
    await _cargarCapitulos(seleccionarId: nuevo.id);
    if (!mounted) return;
    final c = _capitulos?.where((c) => c.id == nuevo.id).firstOrNull ?? nuevo;
    await _abrirCapitulo(c);
  }

  Future<void> _opcionesCapitulo(Capitulo c, String opcion) async {
    switch (opcion) {
      case 'editar':
        final editado = await _empujar<Capitulo>(
            GCapituloFormScreen(libroId: widget.libro.id, capitulo: c));
        if (editado != null && mounted) await _cargarCapitulos();
      case 'borrar':
        final ok = await GDialog.confirmar(
          context,
          title: 'Borrar',
          keyword: 'capítulo',
          message: c.revisiones == 0
              ? '«${c.titulo}» no tiene revisiones.'
              : '«${c.titulo}» y sus ${c.revisiones} '
                  '${c.revisiones == 1 ? 'revisión' : 'revisiones'}, con '
                  'todas tus decisiones, se borrarán. Esta acción no se '
                  'puede deshacer.',
        );
        if (ok != true || !mounted) return;
        try {
          await _api.deleteCapitulo(c.id);
          if (mounted) await _cargarCapitulos();
        } catch (e) {
          if (mounted) _snack('No se pudo borrar: $e');
        }
    }
  }

  /// Importar un JSON o un `.md` como revisión nueva del capítulo abierto.
  Future<void> _nuevaRevision() async {
    final c = _capitulo;
    if (c == null) return;
    if (!await _confirmarSalida()) return;
    await _guardarPendiente();
    if (!mounted) return;
    final id = await _empujar<String>(GImportScreen(capituloId: c.id));
    if (!mounted) return;
    await _cargarCapitulos();
    await _cargarRevisiones(abrirId: id);
  }

  Future<void> _opcionesRevision(ReviewSummary r, String opcion) async {
    switch (opcion) {
      case 'mover':
        try {
          final otros = (await _api.getCapitulos(widget.libro.id))
              .where((c) => c.id != _capitulo?.id)
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
          if (r.id == _revisionId) {
            if (!await _confirmarSalida()) return;
            await _guardarPendiente();
          }
          await _api.moverRevision(r.id, int.parse(elegido));
          if (!mounted) return;
          if (r.id == _revisionId) _ponerRevision(null);
          await _cargarCapitulos();
          await _cargarRevisiones(abrirMasReciente: r.id == _revisionId);
        } catch (e) {
          if (mounted) _snack('No se pudo mover: $e');
        }
      case 'borrar':
        final ok = await GDialog.confirmar(
          context,
          title: 'Borrar',
          keyword: 'revisión',
          message: '«${r.title}» y todas tus decisiones se borrarán. Esta '
              'acción no se puede deshacer.',
        );
        if (ok != true || !mounted) return;
        try {
          final eraLaAbierta = r.id == _revisionId;
          if (eraLaAbierta) _session.sinGuardar = false;
          await _api.deleteRevision(r.id);
          if (!mounted) return;
          if (eraLaAbierta) _ponerRevision(null);
          await _cargarCapitulos();
          await _cargarRevisiones(abrirMasReciente: eraLaAbierta);
        } catch (e) {
          if (mounted) _snack('No se pudo borrar: $e');
        }
    }
  }

  Future<void> _exportar(ReviewSession session) async {
    final ok = await GExportarDialogo.mostrar(context,
        tituloCapitulo: session.review!.title);
    if (ok != true || !mounted) return;
    await ExportMd.share(
        session.review!.title, 'avance', session.currentText());
  }

  Future<void> _generarSugerenciasIA(ReviewSession session) async {
    if (_generandoIA) return;
    final id = session.review!.id;
    setState(() => _generandoIA = true);
    _snack('Generando sugerencias…');
    try {
      await _api.generarSugerencias(id);
      if (!mounted) return;
      await session.load(id);
      if (mounted) await _cargarRevisiones();
    } catch (e) {
      if (mounted) _snack('No se pudo generar: $e');
    } finally {
      if (mounted) setState(() => _generandoIA = false);
    }
  }

  Future<void> _alternarFinalizada(ReviewSession session) async {
    final finalizar = !session.finalizada;
    try {
      await session.setFinalizada(finalizar);
      _snack(finalizar ? 'Capítulo finalizado' : 'Capítulo reabierto');
      if (mounted) {
        await _cargarCapitulos();
        await _cargarRevisiones();
      }
    } catch (e) {
      if (mounted) _snack('No se pudo guardar: $e');
    }
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

  void _menu(String valor, ReviewSession session) {
    switch (valor) {
      case 'preview':
        _empujar<void>(GPreviewScreen(
          title: session.review!.title,
          text: session.currentText(),
          revisionId: session.review!.id,
          counts: session.counts(),
        ));
      case 'export':
        ExportMd.share(session.review!.title, 'avance', session.currentText());
      case 'original':
        setState(() => _split = true);
      case 'sugerencias_ia':
        _generarSugerenciasIA(session);
      case 'finalizar':
        _alternarFinalizada(session);
      case 'reset':
        _reset(session);
    }
  }

  void _confirmar(ReviewSession s) => _empujar<void>(GConfirmScreen(
        title: s.review!.title,
        text: s.currentText(),
        counts: s.counts(),
      ));

  // ---------- Pintado ----------

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReviewSession>.value(
      value: _session,
      child: Consumer<ReviewSession>(
        builder: (context, session, _) => _pantalla(session),
      ),
    );
  }

  Widget _pantalla(ReviewSession session) {
    final listo = session.loadStatus == LoadStatus.ready;
    final ai = listo ? _aiPara(session) : null;
    final texto = listo ? session.currentText() : '';
    final palabras = listo ? TextoCapitulo.palabras(texto) : null;

    final cuerpo = Scaffold(
      backgroundColor: GColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            if (!_foco) _barraSuperior(session, listo),
            Expanded(
              child: Row(
                children: [
                  if (_panelIzq && !_foco) _panelCapitulos(palabras),
                  Expanded(child: _centro(session, listo, texto, palabras, ai)),
                  if (_panelIA && !_foco && ai != null) _panelAsistente(ai),
                ],
              ),
            ),
            if (!_foco) _barraEstado(palabras),
          ],
        ),
      ),
    );

    return PopScope(
      canPop: !session.sinGuardar,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          if (session.canSave) session.saveNow();
          return;
        }
        if (await _confirmarSalida() && mounted) {
          Navigator.of(context).pop();
        }
      },
      // Los atajos van **fuera** del Focus: el evento sube desde el nodo que
      // tiene el foco hacia sus ancestros, y no baja a sus hijos.
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f11): _alternarFoco,
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_foco) _alternarFoco();
          },
        },
        child: Focus(
          autofocus: true,
          child: conAsistente(
            cuerpo,
            ai,
            flotante: false,
            alPreguntar: () => setState(() => _panelIA = true),
          ),
        ),
      ),
    );
  }

  Widget _panelCapitulos(int? palabras) => GPanelCapitulos(
        libro: widget.libro,
        capitulos: _capitulos,
        error: _errorCapitulos,
        actual: _capitulo,
        palabrasActual: palabras,
        verRevisiones: _vistaRevisiones,
        revisiones: _revisiones,
        revisionId: _revisionId,
        onAbrir: _abrirCapitulo,
        onVerRevisiones: (c) => _abrirCapitulo(c, verRevisiones: true),
        onVolverACapitulos: () => setState(() => _vistaRevisiones = false),
        onAbrirRevision: _abrirRevision,
        onNuevoCapitulo: _nuevoCapitulo,
        onNuevaRevision: _capitulo == null ? null : _nuevaRevision,
        onOpcionesCapitulo: _opcionesCapitulo,
        onOpcionesRevision: _opcionesRevision,
        onOcultar: () => setState(() => _panelIzq = false),
        onReintentar: () => _cargarCapitulos(abrirInicial: true),
      );

  Widget _barraSuperior(ReviewSession session, bool listo) {
    return Container(
      height: GSpacing.escBarra,
      padding: const EdgeInsets.symmetric(horizontal: GSpacing.page),
      decoration: BoxDecoration(
        color: GColors.paper,
        border: Border(
            bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: GColors.ink, width: GSpacing.border),
            ),
            child: Image.asset(GMarca.logo,
                width: GSpacing.iconBtn - GSpacing.gapSm,
                height: GSpacing.iconBtn - GSpacing.gapSm,
                excludeFromSemantics: true),
          ),
          const SizedBox(width: GSpacing.gapSm),
          const GMono('bookevision'),
          const SizedBox(width: GSpacing.gap),
          // Con la ventana justa las pestañas se desplazan en vez de salirse.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _Pestana('Biblioteca',
                      onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: GSpacing.gapXs),
                  const _Pestana('Editor de manuscrito', activa: true),
                  const SizedBox(width: GSpacing.gapXs),
                  // Las notas críticas aún no existen.
                  const _Pestana('Aparato crítico y notas'),
                ],
              ),
            ),
          ),
          if (listo)
            GEstadoGuardado(
                status: session.saveStatus, sinGuardar: session.sinGuardar),
          const SizedBox(width: GSpacing.gap),
          GChip('Mi perfil', onTap: _perfil),
        ],
      ),
    );
  }

  Widget _centro(ReviewSession session, bool listo, String texto, int? palabras,
      GAiAssistantController? ai) {
    final c = _capitulo;
    if (c == null) {
      return _Vacio(
        texto: _capitulos == null
            ? 'Cargando el libro…'
            : (_capitulos!.isEmpty
                ? 'Crea el primer capítulo para empezar.'
                : 'Elige un capítulo de la lista.'),
        mostrarPanel: !_panelIzq && !_foco,
        onMostrarPanel: () => setState(() => _panelIzq = true),
      );
    }
    if (_revisionId == null) {
      return _Vacio(
        texto: _revisiones.isEmpty
            ? '«${c.titulo}» aún no tiene revisiones. Importa el JSON de una '
                'revisión o un capítulo en .md, o empieza uno en blanco.'
            : 'Elige una revisión de «${c.titulo}».',
        boton: 'Importar revisión o .md',
        onBoton: _nuevaRevision,
        mostrarPanel: !_panelIzq && !_foco,
        onMostrarPanel: () => setState(() => _panelIzq = true),
      );
    }

    final editor = GLectorCuerpo(
      key: _cuerpoKey,
      navegador: _navegador,
      onEdicion: (a) => setState(() => _edicion = a),
      onSeleccionCambia: ai == null ? null : seleccionCambia,
      onSeleccionVacia: ai == null ? null : ocultarPill,
      anchoMax: GSpacing.escTexto,
    );

    return Column(
      children: [
        _barraEditor(session, listo, c, texto, palabras),
        Expanded(
          child: !_split || !listo
              ? editor
              : Row(
                  children: [
                    Expanded(child: editor),
                    Container(width: GSpacing.border, color: GColors.ink),
                    Expanded(
                      child: _Original(
                        texto: session.review!.chapter,
                        ai: ai,
                        onSeleccionCambia: seleccionCambia,
                        onSeleccionVacia: ocultarPill,
                        onCerrar: () => setState(() => _split = false),
                      ),
                    ),
                  ],
                ),
        ),
        if (listo)
          GLectorBarra(
            session: session,
            navegador: _navegador,
            edicion: _edicion,
            onConfirmar: () => _confirmar(session),
          ),
      ],
    );
  }

  Widget _barraEditor(ReviewSession session, bool listo, Capitulo c,
      String texto, int? palabras) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: GSpacing.page, vertical: GSpacing.gapSm),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Row(
        children: [
          if (!_panelIzq && !_foco) ...[
            GIconButton(
              icon: Icons.menu_book,
              tooltip: 'Mostrar los capítulos',
              outlined: true,
              onPressed: () => setState(() => _panelIzq = true),
            ),
            const SizedBox(width: GSpacing.gap),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${TextoCapitulo.romano(c.numero)}. ${c.titulo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GText.appBar,
                ),
                if (listo)
                  GMono.muted(
                    '${TextoCapitulo.parrafos(texto)} párrafos · '
                    '${TextoCapitulo.miles(palabras ?? 0)} palabras',
                    small: true,
                  ),
              ],
            ),
          ),
          const SizedBox(width: GSpacing.gap),
          // Flexible: en un centro estrecho los botones pasan a otra línea.
          Flexible(
            flex: 2,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: GSpacing.gapSm,
              runSpacing: GSpacing.gapSm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                GChip('Edición activa',
                    onTap: listo ? () => setState(() => _split = false) : null,
                    filled: !_split),
                GChip('Ver original / split',
                    onTap: listo ? () => setState(() => _split = true) : null,
                    filled: _split),
                GChip('Exportar (.md)',
                    onTap: listo ? () => _exportar(session) : null),
                if (listo)
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
                        GMenuItem(
                            label: session.finalizada
                                ? 'Reabrir capítulo'
                                : 'Marcar como finalizado',
                            icon: session.finalizada ? Icons.undo : Icons.check,
                            value: 'finalizar'),
                      const GMenuItem(
                          label: 'Borrar decisiones',
                          icon: Icons.restart_alt,
                          value: 'reset',
                          danger: true),
                    ],
                    onSelected: (v) => _menu(v, session),
                  ),
                if (!_panelIA && !_foco && listo)
                  GIconButton(
                    icon: Icons.auto_awesome,
                    tooltip: 'Mostrar el asistente',
                    outlined: true,
                    onPressed: () => setState(() => _panelIA = true),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelAsistente(GAiAssistantController ai) {
    return Container(
      width: GSpacing.escPanelIA,
      decoration: BoxDecoration(
        border: Border(
            left: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: GAiPanelAcoplado(
        controller: ai,
        onCerrar: () => setState(() => _panelIA = false),
        bajoCabecera: const _PestanasAsistente(),
        sobreEntrada: _AccionesRapidas(ai: ai),
      ),
    );
  }

  Widget _barraEstado(int? palabras) {
    final n = _capitulos?.length ?? widget.libro.capitulos;
    return Container(
      height: GSpacing.escEstado,
      padding: const EdgeInsets.symmetric(horizontal: GSpacing.page),
      decoration: BoxDecoration(
        border:
            Border(top: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Row(
        children: [
          GMono.muted('Capítulos: $n', small: true),
          if (palabras != null) ...[
            const SizedBox(width: GSpacing.gap),
            GMono.muted(
                'Palabras del capítulo: ${TextoCapitulo.miles(palabras)}',
                small: true),
          ],
          const Spacer(),
          InkWell(
            onTap: _alternarFoco,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: GSpacing.gapXs),
              child: GMono('Modo foco (F11)', small: true),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una pestaña de la barra superior: la activa va rellena de tinta; la que
/// no tiene [onTap] ni es la activa está apagada (aún no hace nada).
class _Pestana extends StatelessWidget {
  final String rotulo;
  final bool activa;
  final VoidCallback? onTap;

  const _Pestana(this.rotulo, {this.activa = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final apagada = !activa && onTap == null;
    final tinta = apagada ? GColors.grey3 : GColors.ink;
    return Semantics(
      button: true,
      enabled: !apagada,
      selected: activa,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: GSpacing.blockV, vertical: GSpacing.chipV),
          decoration: BoxDecoration(
            color: activa ? GColors.ink : null,
            border: Border.all(color: tinta, width: GSpacing.border),
          ),
          child:
              GMono(rotulo, color: activa ? GColors.onInk : tinta, small: true),
        ),
      ),
    );
  }
}

/// «Diálogo y trama» es el chat de siempre; el diff de estilo aún no existe.
class _PestanasAsistente extends StatelessWidget {
  const _PestanasAsistente();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Row(
        children: [
          Expanded(child: _pestana('Diálogo y trama', activa: true)),
          Expanded(child: _pestana('Diff de estilo', activa: false)),
        ],
      ),
    );
  }

  Widget _pestana(String rotulo, {required bool activa}) {
    return Semantics(
      selected: activa,
      enabled: activa,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: GSpacing.gapSm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: activa ? GColors.ink : null,
        ),
        child: GMono(rotulo,
            color: activa ? GColors.onInk : GColors.grey3, small: true),
      ),
    );
  }
}

/// Atajos que mandan una petición ya escrita al chat. «Verificar canon»
/// necesita que la IA conozca el libro entero, y aún no es así.
class _AccionesRapidas extends StatelessWidget {
  final GAiAssistantController ai;
  const _AccionesRapidas({required this.ai});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ai,
      builder: (context, _) {
        final libre = !ai.enviando;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(GSpacing.gapSm),
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: GColors.ink, width: GSpacing.border)),
          ),
          child: Wrap(
            spacing: GSpacing.chipGap,
            runSpacing: GSpacing.chipGap,
            children: [
              GChip('Resumir escena',
                  onTap: libre
                      ? () => ai.enviar('Resume esta escena en pocas líneas.')
                      : null),
              GChip('Pulir metáforas',
                  onTap: libre
                      ? () => ai.enviar('Revisa las metáforas y propón '
                          'versiones más pulidas.')
                      : null),
              const GChip('Verificar canon', onTap: null),
            ],
          ),
        );
      },
    );
  }
}

/// El capítulo original, solo lectura, al lado del editor.
class _Original extends StatelessWidget {
  final String texto;
  final GAiAssistantController? ai;
  final void Function(String seleccion, {bool anclable}) onSeleccionCambia;
  final VoidCallback onSeleccionVacia;
  final VoidCallback onCerrar;

  const _Original({
    required this.texto,
    required this.ai,
    required this.onSeleccionCambia,
    required this.onSeleccionVacia,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: GSpacing.page, vertical: GSpacing.gapSm),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
          ),
          child: Row(
            children: [
              const Expanded(child: GMono('Original · solo lectura')),
              GIconButton(
                icon: Icons.close,
                tooltip: 'Cerrar el original',
                outlined: true,
                onPressed: onCerrar,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GSpacing.page),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: GSpacing.escTexto),
                child: GProseFlow(
                  texto,
                  onSeleccionCambia:
                      ai == null ? null : (s) => onSeleccionCambia(s),
                  onSeleccionVacia: ai == null ? null : onSeleccionVacia,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// El centro cuando no hay revisión que enseñar: un capítulo sin elegir o sin
/// revisiones.
class _Vacio extends StatelessWidget {
  final String texto;
  final String? boton;
  final VoidCallback? onBoton;
  final bool mostrarPanel;
  final VoidCallback onMostrarPanel;

  const _Vacio({
    required this.texto,
    this.boton,
    this.onBoton,
    required this.mostrarPanel,
    required this.onMostrarPanel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: GSpacing.escDialogo),
        child: Padding(
          padding: const EdgeInsets.all(GSpacing.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: GSpacing.gap,
            children: [
              Text('Página en ', style: GText.hero, textAlign: TextAlign.center)
                  .withEm('blanco'),
              Text(texto, style: GText.heroSub, textAlign: TextAlign.center),
              if (boton != null)
                GButton(label: boton!, fill: GFill.red, onPressed: onBoton),
              if (mostrarPanel)
                GButton(
                    label: 'Mostrar los capítulos', onPressed: onMostrarPanel),
            ],
          ),
        ),
      ),
    );
  }
}

extension on Text {
  /// «Página en *blanco*»: el titular con la palabra clave en cursiva y el
  /// acento, como el hero de las portadas.
  Widget withEm(String clave) => Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(text: data),
            TextSpan(
                text: clave,
                style: style!.copyWith(
                    color: GColors.accentText, fontStyle: FontStyle.italic)),
          ],
        ),
        textAlign: textAlign,
      );
}
