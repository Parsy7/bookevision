import 'package:flutter/material.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import 'g_button.dart';

/// Barra superior de «Galerada»: atrás con contorno, título en Instrument
/// Serif y lo que haga falta a la derecha. Borde inferior de tinta.
///
/// No es un `AppBar` de Material: aquí la barra es una fila más de la
/// pantalla, sin elevación ni radio.
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

  @override
  Size get preferredSize => const Size.fromHeight(_alto);

  @override
  Widget build(BuildContext context) {
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
