import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icon.dart';
import '../theme/app_radius.dart';
import '../theme/app_text.dart';

/// Estilo visual del [AppButton]: relleno, contorno, destructivo, discreto o
/// cancelar.
enum AppButtonVariant { primary, secondary, danger, ghost, cancel }

/// Botón de ancho completo, altura mínima 44dp, sin sombra. Un solo estilo por
/// variante — no pasar colores sueltos por fuera de [AppButtonVariant].
class AppButton extends StatelessWidget {
  /// Texto del botón.
  final String label;

  /// `null` para dejarlo deshabilitado (p. ej. mientras se guarda).
  final VoidCallback? onPressed;

  /// Por defecto [AppButtonVariant.primary].
  final AppButtonVariant variant;

  /// Icono opcional a la izquierda del texto.
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color? border;

    switch (variant) {
      case AppButtonVariant.primary:
        bg = AppColors.primary;
        fg = AppColors.textInverse;
        border = null;
        break;
      case AppButtonVariant.secondary:
        bg = Colors.transparent;
        fg = AppColors.primary;
        border = AppColors.borderStrong;
        break;
      case AppButtonVariant.danger:
        bg = AppColors.error;
        fg = AppColors.onError;
        border = null;
        break;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AppColors.textMuted;
        border = null;
        break;
      case AppButtonVariant.cancel:
        bg = AppColors.bgElevated;
        fg = AppColors.text;
        border = null;
        break;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            elevation: 0,
            side: border != null
                ? BorderSide(color: border, width: 1)
                : BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppIcon.sm),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: AppText.bodyText
                      .copyWith(color: fg, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
