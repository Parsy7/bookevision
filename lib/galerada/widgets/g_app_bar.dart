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

  /// Segunda línea bajo el título, p. ej. el estado del autoguardado.
  /// Se alinea con el título, dejando libre el hueco del botón de atrás.
  final Widget? subtitulo;

  const GAppBar({
    super.key,
    required this.title,
    this.trailing = const [],
    this.onBack,
    this.subtitulo,
  });

  static const double _alto =
      GSpacing.iconBtn + GSpacing.barTop + GSpacing.barBottom + GSpacing.border;

  /// Alto de la barra **sin** la barra de estado. El alto real lo mide el
  /// `Scaffold` sobre el widget ya construido, que incluye el hueco.
  @override
  Size get preferredSize => Size.fromHeight(
      _alto + (subtitulo == null ? 0 : GSpacing.appBarSubtitulo));

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
    final subtitulo = this.subtitulo;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          GSpacing.page, GSpacing.barTop, GSpacing.page, GSpacing.barBottom),
      decoration: BoxDecoration(
        color: GColors.paper,
        border: Border(
            bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              GIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Atrás',
                outlined: true,
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: GSpacing.barTop),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GText.appBar,
                    ),
                    if (subtitulo != null) ...[
                      const SizedBox(height: GSpacing.gapXs),
                      subtitulo,
                    ],
                  ],
                ),
              ),
              for (final w in trailing) ...[
                const SizedBox(width: GSpacing.barTop),
                w,
              ],
            ],
          ),
        ],
      ),
    );
  }
}
