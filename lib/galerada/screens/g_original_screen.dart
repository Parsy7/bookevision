import 'package:flutter/material.dart';
import '../theme/g_spacing.dart';
import '../widgets/g_app_bar.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_prose.dart';

/// Capítulo original, solo lectura. El sello lo deja claro en la barra.
class GOriginalScreen extends StatelessWidget {
  final String chapter;
  final String revisionId;
  const GOriginalScreen({super.key, required this.chapter, required this.revisionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: GProseFlow(chapter, revisionId: revisionId),
      ),
    );
  }
}
