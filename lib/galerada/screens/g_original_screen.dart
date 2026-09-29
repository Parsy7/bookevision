import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/g_ai_assistant_controller.dart';
import '../theme/g_spacing.dart';
import '../widgets/g_ai_assistant_overlay.dart';
import '../widgets/g_ai_visuals.dart';
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
  const GOriginalScreen({super.key, required this.chapter, required this.revisionId});

  @override
  State<GOriginalScreen> createState() => _GOriginalScreenState();
}

class _GOriginalScreenState extends State<GOriginalScreen> {
  GAiAssistantController? _asistente;
  String? _seleccionPill;
  Offset? _anchorPill;

  GAiAssistantController get _ai => _asistente ??= GAiAssistantController(
        api: context.read<ApiService>(),
        revisionId: widget.revisionId,
      );

  @override
  void dispose() {
    _asistente?.dispose();
    super.dispose();
  }

  void _pedirIa(String seleccion, Offset anchor) {
    setState(() {
      _seleccionPill = seleccion;
      _anchorPill = anchor;
    });
  }

  void _ocultarPill() {
    if (_seleccionPill == null) return;
    setState(() {
      _seleccionPill = null;
      _anchorPill = null;
    });
  }

  void _abrirDesdePill() {
    final seleccion = _seleccionPill;
    if (seleccion == null) return;
    _ai.abrir(seleccion: seleccion);
    _ocultarPill();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
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
              onPedirIa: _pedirIa,
              onSeleccionVacia: _ocultarPill,
            ),
          ),
        ),
        if (_seleccionPill != null && _anchorPill != null)
          _PillPosicionada(anchor: _anchorPill!, onTap: _abrirDesdePill),
        GAiAssistantOverlay(controller: _ai),
      ],
    );
  }
}

/// Coloca el botón "Preguntar a la IA" junto al punto que Flutter habría
/// usado para el menú nativo de selección, sin salirse de la pantalla.
class _PillPosicionada extends StatelessWidget {
  final Offset anchor;
  final VoidCallback onTap;
  const _PillPosicionada({required this.anchor, required this.onTap});

  static const _width = 196.0;
  static const _height = 44.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final left = (anchor.dx - _width / 2).clamp(8.0, size.width - _width - 8.0);
    final top = (anchor.dy - _height - 12).clamp(8.0, size.height - _height - 8.0);
    return Positioned(
      left: left,
      top: top,
      child: GAiSelectionPill(onTap: onTap),
    );
  }
}
