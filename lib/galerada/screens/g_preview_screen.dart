import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/g_ai_assistant_controller.dart';
import '../../services/review_session.dart';
import '../../utils/export_md.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../widgets/g_ai_assistant_overlay.dart';
import '../widgets/g_ai_visuals.dart';
import '../widgets/g_app_bar.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_foot.dart';
import '../widgets/g_prose.dart';

/// Vista previa del capítulo con todas las decisiones aplicadas: tira de
/// recuentos en mono, prosa numerada y la CTA de tinta para exportar.
///
/// Es la versión ya compuesta (con ediciones aplicadas), así que seleccionar
/// un fragmento y preguntarle a la IA tiene todo el sentido — es justo lo que
/// va a quedar —, pero esa respuesta no se puede "usar como sugerencia": el
/// fragmento no tiene por qué existir tal cual en el capítulo original, que
/// es lo que esa conversión necesita para anclarse.
class GPreviewScreen extends StatefulWidget {
  final String title;
  final String text;
  final String revisionId;
  final Counts counts;

  const GPreviewScreen({
    super.key,
    required this.title,
    required this.text,
    required this.revisionId,
    required this.counts,
  });

  @override
  State<GPreviewScreen> createState() => _GPreviewScreenState();
}

class _GPreviewScreenState extends State<GPreviewScreen> {
  GAiAssistantController? _asistente;
  String? _seleccionPill;

  GAiAssistantController get _ai => _asistente ??= GAiAssistantController(
        api: context.read<ApiService>(),
        revisionId: widget.revisionId,
      );

  @override
  void dispose() {
    _asistente?.dispose();
    super.dispose();
  }

  void _seleccionCambia(String seleccion) {
    setState(() => _seleccionPill = seleccion);
  }

  void _ocultarPill() {
    if (_seleccionPill == null) return;
    setState(() => _seleccionPill = null);
  }

  void _abrirDesdePill() {
    final seleccion = _seleccionPill;
    if (seleccion == null) return;
    _ai.abrir(seleccion: seleccion, anclable: false);
    _ocultarPill();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: const GAppBar(title: 'Vista previa'),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: GSpacing.page, vertical: GSpacing.barTop),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: GColors.ink, width: GSpacing.border),
                  ),
                ),
                child: GMono(
                  '${widget.counts.done}/${widget.counts.total} resueltas · '
                  '${widget.counts.pending} pendientes · '
                  '${widget.counts.manual} ${widget.counts.manual == 1 ? 'editado' : 'editados'}',
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(GSpacing.page),
                  child: GProseFlow(
                    widget.text,
                    onSeleccionCambia: _seleccionCambia,
                    onSeleccionVacia: _ocultarPill,
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: GFoot.unica(
            label: 'Exportar .md',
            icon: Icons.ios_share,
            fill: GFootFill.ink,
            onTap: () => ExportMd.share(widget.title, 'avance', widget.text),
          ),
        ),
        if (_seleccionPill != null)
          GAiSelectionPillOverlay(onTap: _abrirDesdePill),
        GAiAssistantOverlay(controller: _ai),
      ],
    );
  }
}
