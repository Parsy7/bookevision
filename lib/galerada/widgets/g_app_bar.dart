import 'package:flutter/material.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import 'g_button.dart';

/// Barra superior de «Galerada»: atrás con contorno, título en Instrument
/// Serif y lo que haga falta a la derecha. Borde inferior de tinta.
///
/// No es un `AppBar` de Material: aquí la barra es una fila más de la
/// pantalla, sin elevación ni radio. Por eso tiene que reservarse **ella
/// misma** el hueco de la barra de estado: el `Scaffold` solo se lo da al
/// `AppBar` de Material, que lo hace por dentro. Sin eso, el reloj y los
/// iconos del sistema caen encima de los botones y no se pueden pulsar.
class GAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> trailing;
  final VoidCallback? onBack;

  const GAppBar({
    super.key,
    required this.title,
    this.trailing = const [],
    this.onBack,
  });

  static const double _alto =
      GSpacing.iconBtn + GSpacing.barTop + GSpacing.barBottom + GSpacing.border;

  /// Alto de la barra **sin** la barra de estado. El alto real lo mide el
  /// `Scaffold` sobre el widget ya construido, que incluye el hueco.
  @override
  Size get preferredSize => const Size.fromHeight(_alto);

  @override
  Widget build(BuildContext context) {
    return Container(
      // El papel sigue detrás de la barra de estado; la línea de tinta se
      // queda abajo del todo, donde acaba la barra.
      color: GColors.paper,
      child: SafeArea(
        bottom: false,
        child: _barra(context),
      ),
    );
  }

  Widget _barra(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          GSpacing.page, GSpacing.barTop, GSpacing.page, GSpacing.barBottom),
      decoration: const BoxDecoration(
        color: GColors.paper,
        border: Border(bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Row(
        children: [
          GIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Atrás',
            outlined: true,
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: GSpacing.barTop),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GText.appBar,
            ),
          ),
          for (final w in trailing) ...[
            const SizedBox(width: GSpacing.barTop),
            w,
          ],
        ],
      ),
    );
  }
}
