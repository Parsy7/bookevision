import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/g_ai_assistant_controller.dart';
import '../theme/g_spacing.dart';
import '../widgets/g_ai_assistant_overlay.dart';
import '../widgets/g_app_bar.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_prose.dart';

/// Capítulo original, solo lectura. El sello lo deja claro en la barra.
///
/// Aquí el texto sí se puede seleccionar (a diferencia del lector, donde la
/// pulsación larga ya la usa la edición manual): seleccionar un fragmento
/// saca el botón flotante "Preguntar a la IA" junto a la selección.
class GOriginalScreen extends StatefulWidget {
  final String chapter;
  final String revisionId;
  const GOriginalScreen(
      {super.key, required this.chapter, required this.revisionId});

  @override
  State<GOriginalScreen> createState() => _GOriginalScreenState();
}

class _GOriginalScreenState extends State<GOriginalScreen>
    with GAiConAsistente<GOriginalScreen> {
  GAiAssistantController? _asistente;

  GAiAssistantController get _ai => _asistente ??= GAiAssistantController(
        api: context.read<ApiService>(),
        revisionId: widget.revisionId,
        // Aquí "el capítulo" es literalmente el original: sin componer.
        capituloActual: () => widget.chapter,
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
        appBar: const GAppBar(
          title: 'Original',
          trailing: [GStamp('Solo lectura')],
        ),
        // Esta pantalla no tiene barra inferior (la lleva GFoot en las demás,
        // y reserva ahí el hueco del menú de Android). Sin nada que lo haga,
        // el scroll llega hasta el borde y el último párrafo queda debajo del
        // menú de gestos o de los 3 botones del sistema.
        body: SingleChildScrollView(
          padding: GSpacing.pageScroll(context),
          child: GProseFlow(
            widget.chapter,
            onSeleccionCambia: seleccionCambia,
            onSeleccionVacia: ocultarPill,
          ),
        ),
      ),
      _ai,
    );
  }
}
