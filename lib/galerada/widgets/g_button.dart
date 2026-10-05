import 'package:flutter/material.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';

/// Relleno de un [GButton]. Sin variantes paralelas: un solo botón con
/// modificador, como manda la filosofía del proyecto.
enum GFill { ink, red, outline }

/// Botón de pantalla: 52dp de alto, radio 0, borde de tinta. El rótulo va en
/// Instrument Serif.
class GButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final GFill fill;

  /// `null` lo deja deshabilitado.
  final VoidCallback? onPressed;

  const GButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fill = GFill.outline,
  });

  @override
  Widget build(BuildContext context) {
    final habilitado = onPressed != null;
    final (Color? fondo, Color texto, Color borde) = switch (fill) {
      GFill.ink => (GColors.ink, GColors.onInk, GColors.ink),
      GFill.red => (GColors.accent, GColors.onRed, GColors.accent),
      GFill.outline => (null, GColors.ink, GColors.ink),
    };

    return InkWell(
      onTap: onPressed,
      child: Container(
        height: GSpacing.actionBtn,
        decoration: BoxDecoration(
          color: habilitado ? fondo : null,
          border: Border.all(
            color: habilitado ? borde : GColors.grey3,
            width: GSpacing.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: habilitado ? texto : GColors.grey3),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GText.button
                    .copyWith(color: habilitado ? texto : GColors.grey3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón de icono: 40×40, relleno de tinta o con contorno. Sin [onPressed]
/// queda apagado en gris.
class GIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool outlined;

  /// En vez de los 40×40 de siempre, ocupa el alto que le dé el padre (p. ej.
  /// para igualarlo al campo de texto de al lado, dentro de un `IntrinsicHeight`).
  final bool stretch;

  const GIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.outlined = false,
    this.stretch = false,
  });

  @override
  Widget build(BuildContext context) {
    final tinta = onPressed == null ? GColors.grey3 : GColors.ink;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: GSpacing.iconBtn,
          height: stretch ? null : GSpacing.iconBtn,
          alignment: stretch ? Alignment.center : null,
          decoration: BoxDecoration(
            color: outlined ? null : tinta,
            border: Border.all(color: tinta, width: GSpacing.border),
          ),
          child: Icon(
            icon,
            size: 20,
            color: outlined ? tinta : GColors.onInk,
          ),
        ),
      ),
    );
  }
}
