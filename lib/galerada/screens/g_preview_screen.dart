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
import '../widgets/g_bits.dart';
import '../widgets/g_foot.dart';
import '../widgets/g_prose.dart';

/// Vista previa del capítulo con todas las decisiones aplicadas: tira de
/// recuentos en tres columnas, prosa numerada y la CTA de tinta para exportar.
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

class _GPreviewScreenState extends State<GPreviewScreen>
    with GAiConAsistente<GPreviewScreen> {
  GAiAssistantController? _asistente;

  GAiAssistantController get _ai => _asistente ??= GAiAssistantController(
        api: context.read<ApiService>(),
        revisionId: widget.revisionId,
        // Ya es el compuesto con las decisiones aplicadas: es justo lo que
        // se ve en esta pantalla.
        capituloActual: () => widget.text,
      );

  @override
  void dispose() {
    _asistente?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return conAsistente(
      Scaffold(
        appBar: const GAppBar(title: 'Vista previa'),
        body: Column(
          children: [
            _Recuento(counts: widget.counts),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(GSpacing.page),
                child: GProseFlow(
                  widget.text,
                  onSeleccionCambia: (s) => seleccionCambia(s, anclable: false),
                  onSeleccionVacia: ocultarPill,
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
      _ai,
      extraBottomOffset: GSpacing.foot,
    );
  }
}

/// Resueltas · Pendientes · Editado, en tres columnas sobre la hoja: la cifra
/// en titular y la etiqueta en mono debajo.
class _Recuento extends StatelessWidget {
  final Counts counts;

  const _Recuento({required this.counts});

  @override
  Widget build(BuildContext context) {
    final columnas = [
      ('${counts.done}/${counts.total}', 'Resueltas'),
      ('${counts.pending}', 'Pendientes'),
      ('${counts.manual}', counts.manual == 1 ? 'Editado' : 'Editados'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: GColors.sheet,
        border: Border(
            bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, (cifra, etiqueta)) in columnas.indexed)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: GSpacing.page, vertical: GSpacing.barTop),
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : Border(
                            left: BorderSide(
                                color: GColors.ink, width: GSpacing.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: GSpacing.gapXs,
                    children: [
                      Text(cifra, style: GText.rowTitle),
                      GMono.muted(etiqueta, small: true),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
