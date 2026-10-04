import 'package:flutter/material.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';

/// En una ventana más ancha que [GSpacing.anchoApp] (escritorio, tablet en
/// horizontal), la app queda como una columna centrada de ese ancho, con una
/// raya de tinta a cada lado; en el móvil no cambia nada.
///
/// Dentro, `MediaQuery` dice el ancho de la columna y no el de la ventana:
/// lo que se mide con `MediaQuery.sizeOf` (el panel de la IA, por ejemplo)
/// se ajusta a la columna en vez de salirse de ella.
class GAnchoApp extends StatelessWidget {
  final Widget child;

  const GAnchoApp({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth <= GSpacing.anchoApp + 2 * GSpacing.border) return child;
      final mq = MediaQuery.of(context);
      return ColoredBox(
        color: GColors.paper,
        child: Center(
          child: Container(
            width: GSpacing.anchoApp + 2 * GSpacing.border,
            // El borde ya reserva su hueco dentro: la app mide anchoApp.
            decoration: BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: GColors.ink, width: GSpacing.border),
              ),
            ),
            child: MediaQuery(
              data: mq.copyWith(size: Size(GSpacing.anchoApp, mq.size.height)),
              child: child,
            ),
          ),
        ),
      );
    });
  }
}
