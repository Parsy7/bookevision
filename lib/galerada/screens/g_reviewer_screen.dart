import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/g_ai_assistant_controller.dart';
import '../../services/review_session.dart';
import '../../utils/export_md.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import '../widgets/g_ai_assistant_overlay.dart';
import '../widgets/g_app_bar.dart';
import '../widgets/g_dialog.dart';
import '../widgets/g_lector.dart';
import '../widgets/g_prose.dart';
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
  final _navegador = GLectorNavegador();
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

  /// Atrás con el campo sin guardar: se avisa antes de perderlo.
  Future<void> _salirSinGuardar(ReviewSession s) async {
    final ok = await GDialog.confirmar(
      context,
      title: 'Descartar',
      keyword: 'cambios',
      message: 'Hay cambios sin guardar en el capítulo. Si sales ahora, se '
          'perderán.',
      confirmLabel: 'Descartar',
      cancelLabel: 'Seguir editando',
    );
    if (ok != true || !mounted) return;
    s.sinGuardar = false;
    Navigator.of(context).pop();
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
      canPop: !session.sinGuardar,
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) {
        if (!didPop) {
          _salirSinGuardar(session);
          return;
        }
        if (session.canSave) session.saveNow();
      },
      child: conAsistente(
        Scaffold(
          appBar: GAppBar(
            title: session.review?.title ?? 'Revisión',
            subtitulo: session.loadStatus == LoadStatus.ready &&
                    (session.saveStatus != SaveStatus.idle ||
                        session.sinGuardar)
                ? GEstadoGuardado(
                    status: session.saveStatus, sinGuardar: session.sinGuardar)
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
          body: _cuerpo(ai),
          bottomNavigationBar: session.loadStatus == LoadStatus.ready
              ? GLectorBarra(
                  session: session,
                  navegador: _navegador,
                  edicion: _edicion,
                  onConfirmar: () => _abrirConfirmacion(session),
                )
              : null,
        ),
        ai,
        extraBottomOffset: GSpacing.foot,
      ),
    );
  }

  Widget _cuerpo(GAiAssistantController? ai) {
    return GLectorCuerpo(
      navegador: _navegador,
      onEdicion: (acciones) => setState(() => _edicion = acciones),
      onSeleccionCambia: ai == null ? null : seleccionCambia,
      onSeleccionVacia: ai == null ? null : ocultarPill,
    );
  }

  void _abrirConfirmacion(ReviewSession s) => _abrir(GConfirmScreen(
        title: s.review!.title,
        text: s.currentText(),
        counts: s.counts(),
      ));
}
